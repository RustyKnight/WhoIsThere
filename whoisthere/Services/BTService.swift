//
//  BTService.swift
//  whoisthere
//
//  Created by Shane Whitehead on 8/2/18.
//  Copyright © 2018 Efe Kocabas. All rights reserved.
//

import Foundation
import CoreBluetooth

extension NSNotification.Name {
	public static let BTNewPeripherialDiscovered: NSNotification.Name = NSNotification.Name("BT.newPeripherialDiscovered")
	public static let BTPeripherialUpdated: NSNotification.Name = NSNotification.Name("BT.peripherialUpdated")
	public static let BTPeripherialDidConnect: NSNotification.Name = NSNotification.Name("BT.peripherialDidConnect")
	
	public static let BTPeripherialManagerDidUpdateState: NSNotification.Name = NSNotification.Name("BT.peripherialManagerDidUpdateState")
	public static let BTPeripherialManagerDidReceiveWrite: NSNotification.Name = NSNotification.Name("BT.peripherialManagerDidReceiveWrite")
}

struct BTNotificationKey {
	static let device = "BT.key.device"
	static let request = "BT.key.request"
	static let peripheral = "BT.key.peripheral"
}

class BTService: NSObject {
	static let shared: BTService = BTService()
	
	var peripheralManager: CBPeripheralManager?
	var centralManager: CBCentralManager?
	
	var scanPeripheralServices: [CBUUID]? = nil
	var scanPeripheralOptions: [String: Any]? = nil
	
	var deviceCache: [UUID: Device] = [:]
	var cachedPeripheralNames: [String: String] = [:]
	
	var defaultUnknownDeviceName: String = "Unknown"
	
	override private init() {
		super.init()
	}
	
	func startCentralManager(queue: DispatchQueue? = nil) {
		log(debug: "")
		stopCentralManager()
		centralManager = CBCentralManager(delegate: self, queue: queue)
	}
	
	func startPeripheralManager(peripheralQueue: DispatchQueue? = nil, peripheralOptions options: [String : Any]? = nil) {
		log(debug: "")
		stopPeripheralManager()
		peripheralManager = CBPeripheralManager(delegate: self, queue: peripheralQueue, options: options)
	}
	
	func stopCentralManager() {
		guard let manager = centralManager else {
			return
		}
		log(debug: "")
		if manager.state == .poweredOn {
			manager.stopScan()
		}
		self.centralManager = nil
	}
	
	func stopPeripheralManager() {
		guard let manager = peripheralManager else {
			return
		}
		log(debug: "")
		if manager.state == .poweredOn {
			if manager.isAdvertising {
				manager.stopAdvertising()
			}
			manager.removeAllServices()
		}
		self.peripheralManager = nil
	}
	
}

extension BTService: CBCentralManagerDelegate {
	
	// MARK: CBCentralManagerDelegate
	
	func centralManagerDidUpdateState(_ central: CBCentralManager) {
		guard central.state == .poweredOn else {
			return
		}
		guard let manager = centralManager else {
			return
		}
		log(debug: "")
		manager.scanForPeripherals(withServices: scanPeripheralServices, options: scanPeripheralOptions)
	}
	
	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
		let peripheralName = name(of: peripheral, advertisementData: advertisementData)

		if let device = deviceCache[peripheral.identifier] {
			// Because we need the last updated state, this will always
			// trigger a state change
			device.name = peripheralName
			device.rssi = RSSI
			device.lastUpdated = Date()
			let userInfo: [String: Any] = [ BTNotificationKey.device: device ]
			NotificationCenter.default.post(name: .BTPeripherialUpdated, object: nil, userInfo: userInfo)
		} else {
			let device = Device(peripheral: peripheral, name: peripheralName, rssi: RSSI)
			log(debug: "peripheralName = \(peripheralName)")
			deviceCache[peripheral.identifier] = device
			let userInfo: [String: Any] = [ BTNotificationKey.device: device ]
			log(debug: "Generate notification")
			NotificationCenter.default.post(name: .BTNewPeripherialDiscovered, object: nil, userInfo: userInfo)
		}
	}
	
	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
		let userInfo: [String: Any] = [
			BTNotificationKey.peripheral: peripheral
		]
		log(debug: "didConnect peripheral \(peripheral.identifier)")
		log(debug: "Generate notification")
		NotificationCenter.default.post(name: .BTPeripherialDidConnect, object: nil, userInfo: userInfo)
	}
	
	// MARK: Support
	
	func name(of peripheral: CBPeripheral, advertisementData: [String : Any]? = nil) -> String {
		var peripheralName = cachedPeripheralNames[peripheral.identifier.description] ?? defaultUnknownDeviceName

		guard let advertisementData = advertisementData else {
			return peripheralName
		}
		guard let advertisementName = advertisementData[CBAdvertisementDataLocalNameKey] as? String else {
			return peripheralName
		}
		guard advertisementName != peripheralName else {
			return peripheralName
		}
		
		peripheralName = advertisementName
		cachedPeripheralNames[peripheral.identifier.description] = peripheralName
		
		return peripheralName
	}
	
}

extension BTService: CBPeripheralManagerDelegate {
	
	func advertise(data: [String: Any]? = nil) {
		guard let manager = peripheralManager else {
			return
		}
		guard manager.state == .poweredOn else {
			return
		}
		stopAdvertising()
		manager.startAdvertising(data)
	}
	
	func stopAdvertising() {
		guard let manager = peripheralManager else {
			return
		}
		guard manager.state == .poweredOn else {
			return
		}
		guard manager.isAdvertising else {
			return
		}
		manager.stopAdvertising()
	}
	
	func add(peripheralService service: CBMutableService) {
		guard let manager = peripheralManager else {
			return
		}
		guard manager.state == .poweredOn else {
			return
		}
		manager.add(service)
	}
	
	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
		log(debug: "")
		log(debug: "Generate notification")
		NotificationCenter.default.post(name: .BTPeripherialManagerDidUpdateState, object: nil, userInfo: nil)
	}
	
	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
		for request in requests {
			if let value = request.value {
				let identifier = request.central.identifier
				if let device = deviceCache[identifier] {
					let userInfo: [String: Any] = [
						BTNotificationKey.request: value,
						BTNotificationKey.device: device
					]
					log(debug: "Generate notification")
					NotificationCenter.default.post(name: .BTPeripherialManagerDidReceiveWrite, object: nil, userInfo: userInfo)
				}
			}
			peripheral.respond(to: request, withResult: .success)
		}
	}
	
	//	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
	//
	//	}
	
}
