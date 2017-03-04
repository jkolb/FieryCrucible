/*
 The MIT License (MIT)
 
 Copyright (c) 2016 Justin Kolb
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

private struct Weak<Instance: AnyObject> {
    weak var instance: Instance?
    
    init(_ instance: Instance) {
        self.instance = instance
    }
}

open class DependencyFactory {
    enum Lifecyle {
        case shared
        case weakShared
        case unshared
        case scoped
    }
    
    struct InstanceKey : Hashable, CustomStringConvertible {
        let lifecycle: Lifecyle
        let name: String
        
        var hashValue: Int {
            return lifecycle.hashValue ^ name.hashValue
        }
        
        var description: String {
            return "\(lifecycle)(\(name))"
        }

        static func ==(lhs: InstanceKey, rhs: InstanceKey) -> Bool {
            return (lhs.lifecycle == rhs.lifecycle) && (lhs.name == rhs.name)
        }
    }
    
    private var sharedInstances: [String:Any] = [:]
    private var weakSharedInstances: [String:Any] = [:]
    private var scopedInstances: [String:Any] = [:]
    private var instanceStack: [InstanceKey] = []
    private var configureStack: [() -> ()] = []
    private var requestDepth = 0
    
    public init() { }
    
    public final func shared<T>(name: String = #function, factory: () -> T, configure: ((T) -> Void)? = nil) -> T {
        return shared(name: name, factory(), configure: configure)
    }
    
    public final func shared<T>(name: String = #function, _ factory: @autoclosure () -> T, configure: ((T) -> Void)? = nil) -> T {
        if let instance = sharedInstances[name] as? T {
            return instance
        }
        
        return inject(
            lifecyle: .shared,
            name: name,
            instances: &sharedInstances,
            factory: factory,
            configure: configure
        )
    }
    
    public final func weakShared<T: AnyObject>(name: String = #function, factory: () -> T, configure: ((T) -> Void)? = nil) -> T {
        return weakShared(name: name, factory(), configure: configure)
    }
    
    public final func weakShared<T: AnyObject>(name: String = #function, _ factory: @autoclosure () -> T, configure: ((T) -> Void)? = nil) -> T {
        if let weakInstance = weakSharedInstances[name] as? Weak<T> {
            if let instance = weakInstance.instance {
                return instance
            }
        }

        var instance: T! // Keep instance alive for duration of method
        let weakInstance: Weak<T> = inject(
            lifecyle: .weakShared,
            name: name,
            instances: &weakSharedInstances,
            factory: {
                instance = factory()
                return Weak(instance)
            },
            configure: { configure?($0.instance!) }
        )
        return weakInstance.instance!
    }
    
    public final func unshared<T>(name: String = #function, factory: () -> T, configure: ((T) -> Void)? = nil) -> T {
        return unshared(name: name, factory(), configure: configure)
    }
    
    public final func unshared<T>(name: String = #function, _ factory: @autoclosure () -> T, configure: ((T) -> Void)? = nil) -> T {
        var unsharedInstances: [String:Any] = [:]
        return inject(
            lifecyle: .unshared,
            name: name,
            instances: &unsharedInstances,
            factory: factory,
            configure: configure
        )
    }
    
    public final func scoped<T>(name: String = #function, factory: () -> T, configure: ((T) -> Void)? = nil) -> T {
        return scoped(name: name, factory(), configure: configure)
    }
    
    public final func scoped<T>(name: String = #function, _ factory: @autoclosure () -> T, configure: ((T) -> Void)? = nil) -> T {
        if let instance = scopedInstances[name] as? T {
            return instance
        }
        
        return inject(
            lifecyle: .scoped,
            name: name,
            instances: &scopedInstances,
            factory: factory,
            configure: configure
        )
    }
    
    private final func inject<T>(lifecyle: Lifecyle, name: String, instances: inout [String:Any], factory: () -> T, configure: ((T) -> Void)?) -> T {
        let key = InstanceKey(lifecycle: lifecyle, name: name)
        
        if lifecyle != .unshared && instanceStack.contains(key) {
            fatalError("Circular dependency from one of \(instanceStack) to \(key) in initializer")
        }
        
        instanceStack.append(key)
        let instance = factory()
        instanceStack.removeLast()
        
        instances[name] = instance
        
        if let configure = configure {
            configureStack.append({configure(instance)})
        }
        
        if instanceStack.count == 0 {
            // A configure call may trigger another instance stack to be generated, so must make a
            // copy of the current configure stack and clear it out for the upcoming requested
            // instances.
            let delayedConfigures = configureStack
            configureStack.removeAll(keepingCapacity: true)
            
            requestDepth += 1
            
            for delayedConfigure in delayedConfigures {
                delayedConfigure()
            }
            
            requestDepth -= 1
            
            if requestDepth == 0 {
                // This marks the end of an entire instance request tree. Must do final cleanup here.
                // Make sure scoped instances survive until the entire request is complete.
                scopedInstances.removeAll(keepingCapacity: true)
            }
        }
        
        return instance
    }
}
