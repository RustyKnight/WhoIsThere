//
//  Peripheral.swift
//  whoisthere
//
//  Created by Efe Kocabas on 06/07/2017.
//  Copyright © 2017 Efe Kocabas. All rights reserved.
//

import Foundation
import CoreBluetooth

class Device {
	
	var peripheral : CBPeripheral
	var name : String
//	var messages = Array<String>()
	
	var rssi: NSNumber
	
	var lastUpdated: Date
	
	init(peripheral: CBPeripheral, name:String, rssi: NSNumber) {
		self.peripheral = peripheral
		self.name = name
		self.rssi = rssi
		self.lastUpdated = Date()
	}
}
