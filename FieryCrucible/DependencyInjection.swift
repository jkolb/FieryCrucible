//
// DependencyInjection.swift
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

class StrongContainer<C> {
    var instance: C
    
    init(instance: C) {
        self.instance = instance
    }
}

class WeakContainer<C: AnyObject> {
    weak var instance: C?
    
    init(instance: C) {
        self.instance = instance
    }
}

public class DependencyFactory {
    var sharedInstances = [String:AnyObject](minimumCapacity: 8)
    var weakSharedInstances = [String:AnyObject](minimumCapacity: 8)
    var scopedInstances = [String:AnyObject](minimumCapacity: 8)
    
    public func shared<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        if let container = sharedInstances[name] as? StrongContainer<T> {
            return container.instance
        }
        
        let instance = factory()
        let container = StrongContainer(instance: instance)
        sharedInstances[name] = container
        
        if let configure = configureOrNil {
            configure(instance)
        }
        
        return instance
    }
    
    public func weakShared<T: AnyObject>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        if let container = weakSharedInstances[name] as? WeakContainer<T> {
            if let instance = container.instance {
                return instance
            }
        }
        
        let instance = factory()
        let container = WeakContainer(instance: instance)
        weakSharedInstances[name] = container
        
        if let configure = configureOrNil {
            configure(instance)
        }
        
        return instance
    }
    
    public func unshared<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        let instance = factory()
        
        if let configure = configureOrNil {
            configure(instance)
        }
        
        return instance
    }
    
    public func scoped<T>(name: String, factory: @autoclosure () -> T, configure configureOrNil: ((T) -> ())? = nil) -> T {
        if let container = scopedInstances[name] as? StrongContainer<T> {
            return container.instance
        }
        
        let instance = factory()
        let container = StrongContainer(instance: instance)
        scopedInstances[name] = container
        
        if let configure = configureOrNil {
            configure(instance)
        }
        
        scopedInstances.removeValueForKey(name)
        
        return instance
    }
}
