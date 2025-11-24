//
//  AppDelegate.swift
//  GMJuice
//

import UIKit
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {

    static var orientationLock = UIInterfaceOrientationMask.all

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        
        FirebaseApp.configure()
        
        return AppDelegate.orientationLock
    }
}
