//
//  ViewController.swift
//  whoisthere
//
//  Created by Efe Kocabas on 05/07/2017.
//  Copyright © 2017 Efe Kocabas. All rights reserved.
//

import CoreBluetooth
import UIKit
import BeamUserNotificationKit
import Hydra
import UserNotifications

class MainViewController: UICollectionViewController {
	
	let mainCellReuseIdentifier = "MainCell"
	let columnCount = 2
	let margin : CGFloat = 10
	var visibleDevices = Array<Device>()
	var cachedDevices = Array<Device>()
//	var cachedPeripheralNames = Dictionary<String, String>()
	var timer: Timer?
	
//	var peripheralManager = CBPeripheralManager()
//	var centralManager: CBCentralManager?

//	var serialService: CBMutableService?

	override func viewDidLoad() {
		super.viewDidLoad()
		
		let rightButtonItem = UIBarButtonItem.init(
			title: "_profile_title".localized,
			style: .done,
			target: self,
			action: #selector(rightButtonAction)
		)
		
		self.navigationItem.rightBarButtonItem = rightButtonItem

	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		// Need to update the view data
		for cache in BTService.shared.deviceCache {
			addOrUpdatePeripheralList(device: cache.value, list: &visibleDevices)
			addOrUpdatePeripheralList(device: cache.value, list: &cachedDevices)
		}

		scheduledTimerWithTimeInterval()
		
		addMessagingNotifications()

		NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: .UIApplicationDidEnterBackground, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground), name: .UIApplicationWillEnterForeground, object: nil)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		log(debug: "")
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self)
		if let timer = timer {
			timer.invalidate()
		}
		timer = nil
	}

	func addMessagingNotifications() {
		log(debug: "")
		NotificationCenter.default.addObserver(self, selector: #selector(newPeripheralDiscovered), name: .BTNewPeripherialDiscovered, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(peripheralUpdated), name: .BTPeripherialUpdated, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(didReceiveWrite), name: .BTPeripherialManagerDidReceiveWrite, object: nil)
	}

	func removeMessagingNotifications() {
		log(debug: "")
		NotificationCenter.default.removeObserver(self, name: .BTNewPeripherialDiscovered, object: nil)
		NotificationCenter.default.removeObserver(self, name: .BTPeripherialUpdated, object: nil)
		NotificationCenter.default.removeObserver(self, name: .BTPeripherialManagerDidReceiveWrite, object: nil)
	}
	
	@objc func didEnterBackground(_ notification: Notification) {
		log(debug: "")
		removeMessagingNotifications()
	}
	
	@objc func willEnterForeground(_ notification: Notification) {
		log(debug: "")
		addMessagingNotifications()
	}

	@objc func rightButtonAction(sender: UIBarButtonItem) {
		
		let registerVC = self.storyboard?.instantiateViewController(withIdentifier: "RegisterController") as! RegisterViewController
		self.navigationController?.pushViewController(registerVC, animated: true)
	}
	
	func scheduledTimerWithTimeInterval(){
		if let timer = timer {
			timer.invalidate()
			self.timer = nil
		}
		timer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.clearPeripherals), userInfo: nil, repeats: true)
	}
	
	@objc func clearPeripherals(){		
		ChatServiceManager.shared.removePeripherialsWith(timeout: 5.0)
		
		visibleDevices.removeAll()
		cachedDevices.removeAll()
		visibleDevices.append(contentsOf: BTService.shared.deviceCache.values)
		collectionView?.reloadData()
	}
	
//	func updateAdvertisingData() {
//
//		guard peripheralManager.state == .poweredOn else {
//			return
//		}
//
//		if (peripheralManager.isAdvertising) {
//			peripheralManager.stopAdvertising()
//		}
//
//		let userData = UserData()
//		let advertisementData = String(format: "%@|%d|%d", userData.name, userData.avatarId, userData.colorId)
//
//		peripheralManager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[Constants.SERVICE_UUID], CBAdvertisementDataLocalNameKey: advertisementData])
//	}
	
	func addOrUpdatePeripheralList(device: Device, list: inout Array<Device>) {
		
		if !list.contains(where: { $0.peripheral.identifier == device.peripheral.identifier }) {
			
			list.append(device)
			collectionView?.reloadData()
		}
		else if list.contains(where: { $0.peripheral.identifier == device.peripheral.identifier
			&& $0.name == "unknown"}) && device.name != "unknown" {
			
			for index in 0..<list.count {
				
				if (list[index].peripheral.identifier == device.peripheral.identifier) {
					
					list[index].name = device.name
					collectionView?.reloadData()
					break
				}
			}
			
		}
	}
	
	// MARK: Notitifcations
	
	func processDevice(notification: NSNotification) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.processDevice(notification: notification)
			}
			return
		}
		guard let userInfo = notification.userInfo else {
			log(debug: "No user info in notification")
			return
		}
		guard let device = userInfo[BTNotificationKey.device] as? Device else {
			log(debug: "No device in notification")
			return
		}
		addOrUpdatePeripheralList(device: device, list: &visibleDevices)
		addOrUpdatePeripheralList(device: device, list: &cachedDevices)
	}
	
	@objc func newPeripheralDiscovered(_ notification: NSNotification) {
		processDevice(notification: notification)
	}

	@objc func peripheralUpdated(_ notification: NSNotification) {
		processDevice(notification: notification)
	}
	
	@objc func didReceiveWrite(_ notification: Notification) {
		log(debug: "")
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.didReceiveWrite(notification)
			}
			return
		}
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

		log(debug: "Message = \(text);\n\tfrom: \(name)")

		NotificationServiceManager.shared.add(identifier: UUID().uuidString, title: "\(name) said", body: text).catch { (error) -> (Void) in
			log(debug: "Failed to deliver notification \(error)")
		}
		
//		AlertHelper.alert(delegate: self, message: "\(name) said: \"\(text)\"")
	}

}

// MARK: - UICollectionViewDataSource protocol
extension MainViewController {
	
	override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return visibleDevices.count
	}
	
	// make a cell for each cell index path
	override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		
		let cell = collectionView.dequeueReusableCell(withReuseIdentifier: mainCellReuseIdentifier, for: indexPath as IndexPath) as! MainCell
		
		let device = visibleDevices[indexPath.row]
		
		let advertisementData = device.name.components(separatedBy: "|")
		
		if (advertisementData.count > 1) {
			
			cell.nameLabel?.text = advertisementData[0]
			cell.avatarImageView.image = UIImage(named: String(format: "%@%@", Constants.kAvatarImagePrefix, advertisementData[1]))
			cell.backgroundColor = Constants.colors[Int(advertisementData[2])!]
		}
		else {
			cell.nameLabel?.text = device.name
			cell.avatarImageView.image = UIImage(named: "avatar0")
			cell.backgroundColor = UIColor.gray
		}
		
		return cell
	}
}

// MARK: - UICollectionViewDelegate protocol
extension MainViewController {
	
	override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
		
		let chatViewController = ChatViewController()
		chatViewController.device = visibleDevices[indexPath.row]
//		chatViewController.deviceUUID = visibleDevices[indexPath.row].peripheral.identifier
//		chatViewController.deviceAttributes = visibleDevices[indexPath.row].name
		self.navigationController?.pushViewController(chatViewController, animated: true)
	}
}

extension MainViewController : UICollectionViewDelegateFlowLayout {
	
	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let flowLayout = collectionView.collectionViewLayout as! UICollectionViewFlowLayout
		let marginsAndInsets = flowLayout.sectionInset.left + flowLayout.sectionInset.right + flowLayout.minimumInteritemSpacing * CGFloat(columnCount - 1)
		let itemWidth = ((collectionView.bounds.size.width - marginsAndInsets) / CGFloat(columnCount)).rounded(.down)
		return CGSize(width: itemWidth, height: itemWidth)
	}
}

//extension MainViewController : CBPeripheralManagerDelegate {
//
//	func initService() {
//		guard peripheralManager.state == .poweredOn else {
//			return
//		}
//		if let serialService = serialService {
//			peripheralManager.remove(serialService)
//			self.serialService = nil
//		}
//		serialService = CBMutableService(type: Constants.SERVICE_UUID, primary: true)
//		guard let serialService = serialService else {
//			return
//		}
//		let rx = CBMutableCharacteristic(type: Constants.RX_UUID, properties: Constants.RX_PROPERTIES, value: nil, permissions: Constants.RX_PERMISSIONS)
//		serialService.characteristics = [rx]
//		peripheralManager.add(serialService)
//	}
//
//	func disposeService() {
//		guard let serialService = serialService else {
//			return
//		}
//		peripheralManager.remove(serialService)
//		self.serialService = nil
//	}
//
//	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
//
//		if (peripheral.state == .poweredOn){
//			initService()
//			updateAdvertisingData()
//		}
//	}
//
//	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
////		let peripheralName = name(from: peripheral)
//		for request in requests {
//			guard var name = cachedPeripheralNames[request.central.identifier.uuidString] else {
//				continue
//			}
//			name = name.components(separatedBy: "|")[0]
//			if let value = request.value {
//
//				guard let messageText = String(data: value, encoding: String.Encoding.utf8) else {
//					continue
//				}
//				AlertHelper.alert(delegate: self, message: "\(name) said \"\(messageText)\"")
//			}
//			self.peripheralManager.respond(to: request, withResult: .success)
//		}
//	}
//}
//
//extension MainViewController : CBCentralManagerDelegate {
//
//	func name(from peripheral: CBPeripheral, advertisementData: [String : Any]? = nil) -> String {
//
//		var peripheralName = cachedPeripheralNames[peripheral.identifier.description] ?? "unknown"
//
//		if let advertisementData = advertisementData {
//			if let advertisementName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
//
//				peripheralName = advertisementName
//				cachedPeripheralNames[peripheral.identifier.description] = peripheralName
//			}
//		}
//		return peripheralName
//
//	}
//
//	func centralManagerDidUpdateState(_ central: CBCentralManager) {
//		if (central.state == .poweredOn){
//
//			self.centralManager?.scanForPeripherals(withServices: [Constants.SERVICE_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
//
//		}
//	}
//
//	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//
//		let peripheralName = name(from: peripheral, advertisementData: advertisementData)
//		let device = Device(peripheral: peripheral, name: peripheralName)
//
//		self.addOrUpdatePeripheralList(device: device, list: &visibleDevices)
//		self.addOrUpdatePeripheralList(device: device, list: &cachedDevices)
//	}
//}










