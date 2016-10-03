Fiery Crucible
==============

A minimalist type safe Swift dependency injector factory. Where all true instances are forged.

[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

#### Changelog

#####Version 2.0.3
* Rebuild project and directory structure using Swift Package Manager.

#####Version 2.0.2
* Fix for Carthage building.
* Skipped 2.0.1 as I forgot to update the README.
* Thanks to Alexander Baranovski for pointing out the breakage.

#####Version 2.0.0
* Updated for Swift 3.0 and Xcode 8 GM release
* Initial attempt at Swift Package Manager support
* Added tests to help make sure everything works as expected and to provide examples of usage
* Cleaned up the API to remove the method that required a specific name parameter (left over from before #function was used for the name)
* A belated thanks to Anton Beloglazov for help with fixing circular dependencies back around 1.0.0

#####Version 1.3.3
* Thanks to Or Rosenblatt for updating code to support Swift 3.0.

#####Version 1.3.2
* Thanks to Tim Ward for updating code to support Swift 2.2.

#####Version 1.3.1
* There is a new form of each method where you are now able to set properties directly after initialization has occured in the factory parameter, this allows you to setup the object (with non-circular dependencies) before the object becomes available to other objects. See the updated example below.

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
			return shared(
				factory: {
					let instance = UIWindow(frame: UIScreen.mainScreen().bounds)
					instance.backgroundColor = UIColor.whiteColor()
					return instance
				},
				configure: { instance in
					instance.rootViewController = self.rootViewController()
				}
			)
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
