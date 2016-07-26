// Copyright (c) 2016 Justin Kolb - http://franticapparatus.net
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

private protocol InstanceContainer : class {
    associatedtype InstanceType
    
    var instance: InstanceType? { get }
}

private class StrongContainer<C> : InstanceContainer {
    var strongInstance: C?
    
    var instance: C? {
        return strongInstance
    }
    
    init(instance: C) {
        strongInstance = instance
    }
}

private class WeakContainer<C: AnyObject> : InstanceContainer {
    weak var weakInstance: C?
    
    var instance: C? {
        return weakInstance
    }
    
    init(instance: C) {
        weakInstance = instance
    }
}

private  func ==(lhs: DependencyFactory.InstanceKey, rhs: DependencyFactory.InstanceKey) -> Bool {
    return (lhs.lifecycle == rhs.lifecycle) && (lhs.name == rhs.name)
}

public class DependencyFactory {
    private enum Lifecyle : String, CustomStringConvertible {
        case Shared = "shared"
        case WeakShared = "weakShared"
        case Unshared = "unshared"
        case Scoped = "scoped"
        
        var description: String {
            return self.rawValue
        }
    }
    
    private struct InstanceKey : Hashable, CustomStringConvertible {
        let lifecycle: Lifecyle
        let name: String
        
        var hashValue: Int {
            return lifecycle.hashValue ^ name.hashValue
        }
        
        var description: String {
            return "\(lifecycle)(\(name))"
        }
    }
    
    private var sharedInstances: [String:AnyObject] = [:]
    private var weakSharedInstances: [String:AnyObject] = [:]
    private var scopedInstances: [String:AnyObject] = [:]
    private var instanceStack: [InstanceKey] = []
    private var configureStack: [() -> ()] = []
    private var requestDepth = 0
    
    public init() { }
    
    public final func shared<T>(factory: @noescape () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return shared(name, factory: factory(), configure: configure)
    }
    
    public final func shared<T>(factory: @autoclosure () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return shared(name, factory: factory, configure: configure)
    }
    
    public final func shared<T>(_ name: String, factory: @autoclosure () -> T, configure: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .Shared,
            name: name,
            instancePool: &sharedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configure
        )
    }
    
    public final func weakShared<T: AnyObject>(factory: @noescape () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return weakShared(name, factory: factory(), configure: configure)
    }
    
    public final func weakShared<T: AnyObject>(factory: @autoclosure () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return weakShared(name, factory: factory, configure: configure)
    }
    
    public final func weakShared<T: AnyObject>(_ name: String, factory: @autoclosure () -> T, configure: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .WeakShared,
            name: name,
            instancePool: &weakSharedInstances,
            containerFactory: { WeakContainer(instance: $0) },
            factory: factory,
            configure: configure
        )
    }
    
    public final func unshared<T>(factory: @noescape () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return unshared(name, factory: factory(), configure: configure)
    }
    
    public final func unshared<T>(factory: @autoclosure () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return unshared(name, factory: factory, configure: configure)
    }
    
    public final func unshared<T>(_ name: String, factory: @autoclosure () -> T, configure: ((T) -> ())? = nil) -> T {
        var unsharedInstances: [String:AnyObject] = [:]
        return inject(
            lifecyle: .Unshared,
            name: name,
            instancePool: &unsharedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configure
        )
    }
    
    public final func scoped<T>(factory: @noescape () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return scoped(name, factory: factory(), configure: configure)
    }
    
    public final func scoped<T>(factory: @autoclosure () -> T, name: String = #function, configure: ((T) -> ())? = nil) -> T {
        return scoped(name, factory: factory, configure: configure)
    }
    
    public final func scoped<T>(_ name: String, factory: @autoclosure () -> T, configure: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .Scoped,
            name: name,
            instancePool: &scopedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configure
        )
    }
    
    private final func inject<T, C: InstanceContainer where C.InstanceType == T>(lifecyle: Lifecyle, name: String, instancePool: inout [String:AnyObject], containerFactory: (T) -> C, factory: @autoclosure () -> T, configure: ((T) -> ())?) -> T {
        if let container = instancePool[name] as? C {
            if let instance = container.instance {
                return instance
            }
        }
        
        let key = InstanceKey(lifecycle: lifecyle, name: name)
        
        if lifecyle != .Unshared && instanceStack.contains(key) {
            fatalError("Circular dependency from one of \(instanceStack) to \(key) in initializer")
        }
        
        instanceStack.append(key)
        let instance = factory()
        instanceStack.removeLast()
        
        let container = containerFactory(instance)
        instancePool[name] = container
        
        if let configure = configure {
            configureStack.append({configure(instance)})
        }
        
        if instanceStack.count == 0 {
            // A configure call may trigger another instance stack to be generated, so must make a
            // copy of the current configure stack and clear it out for the upcoming requested
            // instances.
            let delayedConfigures = configureStack
            configureStack.removeAll(keepCapacity: true)
            
            requestDepth += 1
            
            for delayedConfigure in delayedConfigures {
                delayedConfigure()
            }
            
            requestDepth -= 1
            
            if requestDepth == 0 {
                // This marks the end of an entire instance request tree. Must do final cleanup here.
                // Make sure scoped instances survive until the entire request is complete.
                scopedInstances.removeAll(keepCapacity: true)
            }
        }
        
        return instance
    }
}
