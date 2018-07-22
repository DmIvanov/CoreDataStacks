//
//  AppDelegate.swift
//  СoreDataStacksPerformance
//
//  Created by Dmitrii on 21/07/2018.
//  Copyright © 2018 DI. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        let vc = UIStoryboard(name: "Main", bundle: nil).instantiateInitialViewController() as! ViewController
        vc.stack = stack()

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = vc
        window?.makeKeyAndVisible()

        return true
    }


    private func stack() -> CoreDataStackProtocol {
        //return Simple()

        //return PersistentContainer()
        //return PersistentContainerMerging()

        return NestedStack()
        //return NestedStackProp()

        //return SharedPSC()
        //return SharedPSCMerging()

        //return SharedStore()
    }
}

