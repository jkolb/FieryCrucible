//
// DependencyFactory.swift
// FieryCrucible
//
// Copyright (c) 2014 Justin Kolb - http://franticapparatus.net
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
//

protocol InstanceContainer : class {
    typealias InstanceType
    
    var instance: InstanceType? { get }
}

class StrongContainer<C> : InstanceContainer {
    var instance: C?
    
    init(instance: C) {
        self.instance = instance
    }
}

class WeakContainer<C: AnyObject> : InstanceContainer {
    weak var instance: C?
    
    init(instance: C) {
        self.instance = instance
    }
}

func ==(lhs: DependencyFactory.InstanceKey, rhs: DependencyFactory.InstanceKey) -> Bool {
    return (lhs.lifecycle == rhs.lifecycle) && (lhs.name == rhs.name)
}

public class DependencyFactory {
    enum Lifecyle : String, Printable {
        case Shared = "shared"
        case WeakShared = "weakShared"
        case Unshared = "unshared"
        case Scoped = "scoped"
        
        var description: String {
            return self.rawValue
        }
    }
    
    struct InstanceKey : Hashable, Printable {
        let lifecycle: Lifecyle
        let name: String
        
        var hashValue: Int {
            return lifecycle.hashValue ^ name.hashValue
        }
        
        var description: String {
            return "\(lifecycle)(\(name))"
        }
    }
    
    var sharedInstances: [String:AnyObject] = [:]
    var weakSharedInstances: [String:AnyObject] = [:]
    var scopedInstances: [String:AnyObject] = [:]
    var instanceStack: [InstanceKey] = []
    var configureStack: [() -> ()] = []
    var requestDepth = 0
    
    public init() { }
    
    public func shared<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .Shared,
            name: name,
            instancePool: &sharedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configureOrNil
        )
    }
    
    public func weakShared<T: AnyObject>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .WeakShared,
            name: name,
            instancePool: &weakSharedInstances,
            containerFactory: { WeakContainer(instance: $0) },
            factory: factory,
            configure: configureOrNil
        )
    }
    
    public func unshared<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        var unsharedInstances: [String:AnyObject] = [:]
        return inject(
            lifecyle: .Unshared,
            name: name,
            instancePool: &unsharedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configureOrNil
        )
    }
    
    public func scoped<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        return inject(
            lifecyle: .Scoped,
            name: name,
            instancePool: &scopedInstances,
            containerFactory: { StrongContainer(instance: $0) },
            factory: factory,
            configure: configureOrNil
        )
    }
    
    func inject<T, C: InstanceContainer where C.InstanceType == T>(# lifecyle: Lifecyle, name: String, inout instancePool: [String:AnyObject], containerFactory: (T) -> C, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())?) -> T {
        if let container = instancePool[name] as? C {
            if let instance = container.instance {
                return instance
            }
        }
        
        let key = InstanceKey(lifecycle: lifecyle, name: name)
        
        if lifecyle != .Unshared && contains(instanceStack, key) {
            fatalError("Circular dependency from one of \(instanceStack) to \(key) in initailizer")
        }
        
        instanceStack.append(key)
        let instance = factory()
        instanceStack.removeLast()
        
        let container = containerFactory(instance)
        instancePool[name] = container
        
        if let configure = configureOrNil {
            configureStack.append({configure(instance)})
        }
        
        if instanceStack.count == 0 {
            // A configure call may trigger another instance stack to be generated, so must make a
            // copy of the current configure stack and clear it out for the upcoming requested
            // instances.
            let delayedConfigures = configureStack
            configureStack.removeAll(keepCapacity: true)
            
            ++requestDepth
            
            for delayedConfigure in delayedConfigures {
                delayedConfigure()
            }
            
            --requestDepth
            
            if requestDepth == 0 {
                // This marks the end of an entire instance request tree. Must do final cleanup here.
                // Make sure scoped instances survive until the entire request is complete.
                scopedInstances.removeAll(keepCapacity: true)
            }
        }
        
        return instance
    }
}
