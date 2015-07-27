Fiery Crucible
==============

A minimalist type safe Swift dependency injector factory. Where all true instances are forged.

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

#### Changelog

#####Version 1.3.0
* Added support for Swift 2

#####Version 1.2.0
* Should now work with Carthage
* Whole Module Optimization has been enabled to speed up compile times
* Tightened up the access restrictions on the API
* You no longer have to specify the name parameter (see updated examples below)

#### Features
* Constructor injection
* Setter injection
* Simple understandable code
* Type safety
* Four types of memory management:
  + *Shared* - A globally shared instance that will live as long as the factory does.
  + *Weak Shared* - A globally shared instance that will live as long as some object (not including the factory) has a strong reference to it.
  + *Unshared* - A unique instance is created every time it is requested, another object must keep a strong reference to it for it to stick around.
  + *Scoped* - A unique instance is created every time it is requested. During the request, any other object that refers to it will receive the same instance, after the request is complete a different and unique instance will be created. Another object must keep a strong reference to it for it to stick around.

#### Circular Dependencies
Circular refrences are handled only by using setter injection. This works because all the instances are created in a construction phase before setter injection is triggered allowing references to exist before they are needed.

#### How to use
You can either copy the source into your project, or setup a git submodle of this repo and drag the project into your project as a subproject.

#### A code example

    import FieryCrucible
    import UIKit
    
    class CustomFactory : DependencyFactory {
        func application() -> CustomApplication {
            return shared(CustomApplication()) { instance in
                instance.factory = self
            }
        }
        
        func mainWindow() -> UIWindow {
            return shared(UIWindow(frame: UIScreen.mainScreen().bounds)) { instance in
                instance.rootViewController = self.rootViewController()
            }
        }
        
        func rootViewController() -> UIViewController {
            return scoped(UITabBarController()) { instance in
                instance.viewControllers = [
                    self.tab0ViewController(),
                    self.tab1ViewController(),
                ]
            }
        }
        
        ...
    }
    
    class CustomApplication {
        var factory: CustomFactory!
        
        func launch() {
            factory.mainWindow().makeKeyAndVisible()
        }
    }
    
    @UIApplicationMain
    class AppDelegate: UIResponder, UIApplicationDelegate {
        var factory: CustomFactory!
    
        func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
            factory = CustomFactory()
            factory.application().launch()
            return true
        }
    }
