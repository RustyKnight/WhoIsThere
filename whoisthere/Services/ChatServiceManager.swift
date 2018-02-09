//
//  ChatServiceManager.swift
//  whoisthere
//
//  Created by Shane Whitehead on 9/2/18.
//  Copyright © 2018 Efe Kocabas. All rights reserved.
//

import Foundation
import CoreBluetooth

enum ChatServiceManagerError: String, Error, CustomStringConvertible {
	case messageConverstionFailed = "Failed to convert message to data"
	case serviceNotRunning = "Central Service is not running"
	
	var description: String {
		return rawValue
	}
}

extension NSNotification.Name {
	static let CSMessageDelivered = NSNotification.Name(rawValue: "ChatService.messageDelivered")
}

struct ChatServiceManagerKey {
	static let message = "Key.chatService.message"
	static let device = "Key.chatService.device"
}

// This is the application level manager, it monitors aspects of the BlueTooth service
// it needs and makes updates as required
class ChatServiceManager: NSObject {
	static let shared: ChatServiceManager = ChatServiceManager()
	
	override private init() {
		super.init()
		NotificationCenter.default.addObserver(self, selector: #selector(peripherialManagerStateChanged), name: .BTPeripherialManagerDidUpdateState, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(peripherialDidConnect), name: .BTPeripherialDidConnect, object: nil)
	}
	
	func start() {
		log(debug: "")
//		BTService.shared.scanPeripheralServices = [Constants.SERVICE_UUID]
		BTService.shared.scanPeripheralOptions = [CBCentralManagerScanOptionAllowDuplicatesKey : true]
		
		BTService.shared.startCentralManager()
		BTService.shared.startPeripheralManager()
	}
	
	func stop() {
		log(debug: "")
		BTService.shared.stopPeripheralManager()
		BTService.shared.stopCentralManager()
	}
	
	func displayName(for device: Device) -> String {
		let name = device.name
		let deviceData = name.components(separatedBy: "|")
		return deviceData[0]
	}

	@objc func peripherialManagerStateChanged(_ notification: Notification) {
		log(debug: "")
		initService()
		updateAdvertisingData()
	}
	
	@objc func peripherialDidConnect(_ notification: Notification) {
		log(debug: "")
		guard let userInfo = notification.userInfo else {
			log(debug: "peripherialDidConnect without userInfo")
			return
		}
		guard let peripheral = userInfo[BTNotificationKey.peripheral] as? CBPeripheral else {
			log(debug: "peripherialDidConnect without peripheral")
			return
		}
		guard hasMoreMessages(for: peripheral) else {
			// Probably not for us
			return
		}
		peripheral.discoverServices(nil)
	}
	
	func initService() {
		log(debug: "")
		guard let manager = BTService.shared.peripheralManager else {
			return
		}
		guard manager.state == .poweredOn else {
			return
		}
		let serialService = CBMutableService(type: Constants.SERVICE_UUID, primary: true)
		let rx = CBMutableCharacteristic(type: Constants.RX_UUID, properties: Constants.RX_PROPERTIES, value: nil, permissions: Constants.RX_PERMISSIONS)
		serialService.characteristics = [rx]
		manager.add(serialService)
	}
	
	func updateAdvertisingData() {
		log(debug: "")
		guard let manager = BTService.shared.peripheralManager else {
			return
		}
		guard manager.state == .poweredOn else {
			return
		}
		
		if (manager.isAdvertising) {
			manager.stopAdvertising()
		}
		
		let userData = UserData()
		let advertisementData = String(format: "%@|%d|%d", userData.name, userData.avatarId, userData.colorId)
		
		manager.startAdvertising([CBAdvertisementDataServiceUUIDsKey:[Constants.SERVICE_UUID], CBAdvertisementDataLocalNameKey: advertisementData])
	}
	
	// MARK: Clean cache
	
	// This will remove peripherials which haven't been updated within
	// the specified timeout range.  It would be reasonable to assume
	// that these peripherials are no longer avaliable
	func removePeripherialsWith(timeout: TimeInterval) {
		let now = Date()
		var tmp: [Device] = []
		tmp.append(contentsOf: BTService.shared.deviceCache.values)
		let oldDevices = tmp.filter { now.timeIntervalSince($0.lastUpdated) >= timeout }
		for entry in oldDevices {
			BTService.shared.deviceCache[entry.peripheral.identifier] = nil
		}
	}
	
	// MARK: Messaging Support
	
	fileprivate var messageQueue: [(Device, Data)] = []

	func write(_ message: String, to device: Device) throws {
		guard let data = message.data(using: .utf8) else {
			throw ChatServiceManagerError.messageConverstionFailed
		}
		log(debug: "")
		try write(data, to: device)
	}

	func write(_ message: Data, to device: Device) throws {
		guard let manager = BTService.shared.centralManager else {
			throw ChatServiceManagerError.serviceNotRunning
		}
		log(debug: "")
		messageQueue.append((device, message))
		device.peripheral.delegate = self
		manager.connect(device.peripheral, options: nil)
	}
}

extension ChatServiceManager: CBPeripheralDelegate {
	
	func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
		log(debug: "peripheral = \(peripheral.identifier)")
		for service in invalidatedServices {
			log(debug: "service = \(service)")
		}
		
		peripheral.discoverServices(nil)
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
		log(debug: "")
		if let error = error {
			log(debug: "didDiscoverServices error: \(error)")
			return
		}
		guard let services = peripheral.services else {
			return
		}
		for service in services {
			peripheral.discoverCharacteristics(nil, for: service)
		}
	}
	
	func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
		if let error = error {
			log(error: "didDiscoverCharacteristicsFor error: \(error)")
			return
		}
		guard let entry = firstMessage(for: peripheral) else {
			log(error: "didDiscoverCharacteristicsFor - no messages for peripheral \(peripheral.identifier)")
			return
		}
		guard var characteristics = service.characteristics else {
			return
		}
		characteristics = characteristics.filter { $0.uuid.isEqual(Constants.RX_UUID) }
		guard characteristics.count > 0 else {
			// Do we really care??
			return
		}
		
		let device = entry.0
		let data = entry.1
		
		
		
		log(debug: "Write: [\(String(data: data, encoding: .utf8) ?? "?")] to \(peripheral.identifier)")
		
		for characteristic in characteristics {
			peripheral.writeValue(data, for: characteristic, type: CBCharacteristicWriteType.withResponse)
		}
		removeFirstMessage(for: peripheral)
		let userInfo: [String: Any] = [
			ChatServiceManagerKey.device: device,
			ChatServiceManagerKey.message: data
		]
		NotificationCenter.default.post(name: .CSMessageDelivered, object: nil, userInfo: userInfo)
		
		guard !hasMoreMessages(for: peripheral) else {
			return
		}
		device.peripheral.delegate = nil
	}
	
	func hasMoreMessages(for peripheral: CBPeripheral) -> Bool {
		return firstMessage(for: peripheral) != nil
	}
	
	func firstMessage(for peripheral: CBPeripheral) -> (Device, Data)? {
		guard let entry = (messageQueue.first { $0.0.peripheral.identifier == peripheral.identifier }) else {
			return nil
		}
		return entry
	}
	
	func removeFirstMessage(for peripheral: CBPeripheral) {
		guard let index = (messageQueue.index {$0.0.peripheral.identifier == peripheral.identifier}) else {
			return
		}
		messageQueue.remove(at: index)
	}
}
