Fiery Crucible
==============

A minimalist type safe Swift dependency injector factory. Where all true instances are forged.

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
            return shared {
                "application",
                factory: CustomApplication(),
                configure: { [unowned self] (instance) in
                    instance.factory = self
                }
            }
        }
        
        func mainWindow() -> UIWindow {
            return shared {
                "mainWindow",
                factory: UIWindow(frame: UIScreen.mainScreen().bounds),
                configure: { [unowned self] (instance) in
                    instance.rootViewController = self.rootViewController()
                }
            }
        }
        
        func rootViewController() -> UIViewController {
            return scoped {
                "rootViewController",
                factory: UITabBarController(),
                configure: { [unowned self] (instance) in
                    instance.viewControllers = [
                        self.tab0ViewController(),
                        self.tab1ViewController(),
                    ]
                }
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
