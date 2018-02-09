//
//  AppDelegate.swift
//  whoisthere
//
//  Created by Efe Kocabas on 05/07/2017.
//  Copyright © 2017 Efe Kocabas. All rights reserved.
//

import UIKit
import UserNotifications
import BeamUserNotificationKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
	
	var window: UIWindow?
	
	func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
		// Override point for customization after application launch.
		
		LogService.shared.initialize(consoleLogLevel: .verbose, fileLogLevel: .verbose)
		
		UNUserNotificationCenter.current().authorise(options: [.alert, .badge, .sound]).always {
		}.catch { (error) -> (Void) in
			log(debug: "Aurthorisation request faield: \(error)")
		}

		_ = NotificationServiceManager.shared.set(categories: [])//NotificationServiceManager.shared.categories)

		let userData =  UserData()
		
		// check if all register information required (name, avatar, color) is filled
		if (userData.hasAllDataFilled) {
			
			let storyboard = UIStoryboard(name: "Main", bundle: nil)
			let viewController = storyboard.instantiateViewController(withIdentifier: "MainViewController") as! MainViewController
			let navigationController:UINavigationController = UINavigationController(rootViewController: viewController);
			window?.rootViewController = navigationController
			window?.makeKeyAndVisible()
		}
		
		// Just need to get this party started
		ChatServiceManager.shared.start()
		
		return true
	}
	
	func applicationWillEnterForeground(_ application: UIApplication) {
		log(debug: "")
		NotificationCenter.default.removeObserver(self)
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		log(debug: "Register for background notification")
		NotificationCenter.default.addObserver(self, selector: #selector(didReceiveWrite), name: .BTPeripherialManagerDidReceiveWrite, object: nil)
	}

	@objc func didReceiveWrite(_ notification: Notification) {
		guard let userInfo = notification.userInfo else {
			log(debug: "didReceiveWrite notification without userInfo")
			return
		}
		guard let messageDevice = userInfo[BTNotificationKey.device] as? Device else {
			log(debug: "didReceiveWrite notification without device")
			return
		}
		guard let data = userInfo[BTNotificationKey.request] as? Data else {
			log(debug: "didReceiveWrite notification without data")
			return
		}
		guard let text = String(data: data, encoding: .utf8) else {
			log(debug: "didReceiveWrite unable to decode data as text")
			return
		}
		let name = ChatServiceManager.shared.displayName(for: messageDevice)
		log(debug: "Message = \(text)\n\tfrom: \(name)")
		NotificationServiceManager.shared.add(identifier: UUID().uuidString, title: "\(name) said", body: text).catch { (error) -> (Void) in
			log(debug: "Failed to deliver notification \(error)")
		}
	}
}

