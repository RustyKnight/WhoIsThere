//
//  ChatViewController.swift
//  whoisthere
//
//  Created by Efe Kocabas on 12/07/2017.
//  Copyright © 2017 Efe Kocabas. All rights reserved.
//

import UIKit
import CoreBluetooth

class ChatViewController: UIViewController {
	
	var device: Device?
	
//	var deviceUUID : UUID?
//	var deviceAttributes : String = ""
	var selectedPeripheral : CBPeripheral?
//	var centralManager: CBCentralManager?
//	var peripheralManager = CBPeripheralManager()
	var messages = Array<Message>()
	
	let cellDefinition = "ChatCell"
	
	var serialService: CBMutableService?
	
	@IBOutlet weak var messageTopConstraint: NSLayoutConstraint!
	@IBOutlet weak var messageBottomConstraint: NSLayoutConstraint!
	
	@IBOutlet weak var tableView: UITableView!
	@IBOutlet weak var messageTextField: UITextField!
	@IBOutlet weak var sendButton: UIButton!
	@IBOutlet weak var bottomContainer: UIView!
	
	@IBAction func sendButtonClick(_ sender: Any) {
		guard let device = device else {
			AlertHelper.warn(delegate: self, message: "Not configured to deliver messages")
			return
		}
		messageTextField.resignFirstResponder()
		guard let text = messageTextField.text else {
			return
		}
		guard !text.isEmpty else {
			return
		}
		log(debug: "Send message: [\(text)]")
		do {
			try ChatServiceManager.shared.write(text, to: device)
		} catch let error {
			AlertHelper.warn(delegate: self, message: "\(error)")
		}
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		tableView.estimatedRowHeight = 68.0
		tableView.rowHeight = UITableViewAutomaticDimension
		
		tableView.register(UINib(nibName: cellDefinition, bundle: nil), forCellReuseIdentifier: cellDefinition)
		
//		centralManager = CBCentralManager(delegate: self, queue: DispatchQueue.main)
//		peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
		messageTextField.delegate = self
		registerForKeyboardNotifications()
		
		setDeviceValues()
		sendButton.setTitle("_chat_send_button".localized, for: .normal)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		NotificationCenter.default.addObserver(self, selector: #selector(didReceiveWrite), name: .BTPeripherialManagerDidReceiveWrite, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(messageDelivered), name: .CSMessageDelivered, object: nil)
	}
	
	override func viewDidDisappear(_ animated: Bool) {
		super.viewDidDisappear(animated)
		NotificationCenter.default.removeObserver(self)
//		disposeService()
	}
	
	func setDeviceValues() {
		guard let device = device else {
			return
		}
		let name = device.name
		
		let deviceData = name.components(separatedBy: "|")
		if (deviceData.count > 2) {
			self.navigationItem.title = deviceData[0]
			tableView.backgroundColor = Constants.colors[Int(deviceData[2])!]
		}
		
	}
	
	override func viewWillDisappear(_ animated: Bool) {
		deregisterFromKeyboardNotifications()
	}
	
	// Following methods are needed for pushing bottomContainer view up and down when keyboard is shown and hidden.
	func registerForKeyboardNotifications()
	{
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWasShown(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillBeHidden(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
	}
	
	
	func deregisterFromKeyboardNotifications()
	{
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillShow, object: nil)
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name.UIKeyboardWillHide, object: nil)
	}
	
	@objc func keyboardWasShown(notification: NSNotification){
		animateViewMoving(up: true, notification: notification)
	}
	
	@objc func keyboardWillBeHidden(notification: NSNotification){
		
		animateViewMoving(up: false, notification: notification)
	}
	
	func animateViewMoving (up:Bool, notification :NSNotification){
		guard let userInfo = notification.userInfo else {
			return
		}
		
		let endFrame = (userInfo[UIKeyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
		let endFrameY = endFrame?.origin.y ?? 0
		let duration:TimeInterval = (userInfo[UIKeyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0
		let animationCurveRawNSN = userInfo[UIKeyboardAnimationCurveUserInfoKey] as? NSNumber
		let animationCurveRaw = animationCurveRawNSN?.uintValue ?? UIViewAnimationOptions.curveEaseInOut.rawValue
		let animationCurve:UIViewAnimationOptions = UIViewAnimationOptions(rawValue: animationCurveRaw)
		if endFrameY >= UIScreen.main.bounds.size.height {
			self.messageBottomConstraint.constant = 0.0
			self.messageTopConstraint.constant = 0.0
		} else {
			if var height = endFrame?.size.height {
				if #available(iOS 11.0, *) {
					height -= (view.safeAreaInsets.bottom)
				}
				self.messageBottomConstraint.constant = height
			} else {
				self.messageTopConstraint.constant = 0.0
				self.messageBottomConstraint.constant = 0.0
			}
		}
		UIView.animate(withDuration: duration,
									 delay: TimeInterval(0),
									 options: animationCurve,
									 animations: { self.view.layoutIfNeeded() },
									 completion: nil)
		//		let movementDuration:TimeInterval = 0.3
//
//		var info = notification.userInfo!
//		let keyboardSize = (info[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue.size
//		let moveValue = keyboardSize?.height ?? 0
//		let movement:CGFloat = ( up ? -moveValue : 0)
//
//		UIView.beginAnimations("animateView", context: nil)
//		UIView.setAnimationBeginsFromCurrentState(true)
//		UIView.setAnimationDuration(movementDuration)
//
//		log(debug: movement)
//		self.bottomContainer.frame = bottomContainer.frame.offsetBy(dx: 0, dy: movement)
//		UIView.commitAnimations()
	}
	
	// MARK: Notifications
	
	@objc func didReceiveWrite(_ notification: Notification) {
		log(debug: "")
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.didReceiveWrite(notification)
			}
			return
		}
		guard let device = device else {
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
		log(debug: "Message = \(text)")
		guard device.peripheral.identifier == messageDevice.peripheral.identifier else {
			let name = ChatServiceManager.shared.displayName(for: messageDevice)
			AlertHelper.alert(delegate: self, message: "\(name) said: \"\(text)\"")
			return
		}
		appendMessageToChat(message: Message(text: text, isSent: false))
	}

	@objc func messageDelivered(_ notification: Notification) {
		guard Thread.isMainThread else {
			DispatchQueue.main.async {
				self.messageDelivered(notification)
			}
			return
		}
		// No point, we shouldn't be able to send
		guard let device = device else {
			return
		}
		guard let userInfo = notification.userInfo else {
			log(debug: "messageDelivered notification without userInfo")
			return
		}
		guard let messageDevice = userInfo[ChatServiceManagerKey.device] as? Device else {
			log(debug: "messageDelivered notification without device")
			return
		}
		guard messageDevice.peripheral.identifier == device.peripheral.identifier else {
			return
		}
		guard let data = userInfo[ChatServiceManagerKey.message] as? Data else {
			log(debug: "messageDelivered notification without data")
			return
		}
		guard let notificationMessage = String(data: data, encoding: .utf8) else {
			log(debug: "messageDelivered unable to decode data as text")
			return
		}
		guard let text = messageTextField.text else {
			log(debug: "messageDelivered by view does not have any text")
			return
		}
		// Do we really care?
		guard text == notificationMessage else {
			log(debug: "messageDelivered message text mismatch")
			return
		}
		appendMessageToChat(message: Message(text: text, isSent: true))
		messageTextField.text = ""
	}

	// end of keyboard animation related methods
	
//	func updateAdvertisingData() {
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
//
//
//	func initService() {
//
//		serialService = CBMutableService(type: Constants.SERVICE_UUID, primary: true)
//		let rx = CBMutableCharacteristic(type: Constants.RX_UUID, properties: Constants.RX_PROPERTIES, value: nil, permissions: Constants.RX_PERMISSIONS)
//		serialService!.characteristics = [rx]
//
//		peripheralManager.add(serialService!)
//	}
//
//	func disposeService() {
//		guard let serialService = serialService else {
//			return
//		}
//		peripheralManager.remove(serialService)
//		self.serialService = nil
//	}

	func appendMessageToChat(message: Message) {
		
		messages.append(message)
		tableView.reloadData()
	}
	
}

//extension ChatViewController : CBCentralManagerDelegate {
//
//	func centralManagerDidUpdateState(_ central: CBCentralManager) {
//
//		if (central.state == .poweredOn){
//
//			self.centralManager?.scanForPeripherals(withServices: [Constants.SERVICE_UUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey : true])
//
//		}
//	}
//
//	func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
//
//		if (peripheral.identifier == deviceUUID) {
//
//			selectedPeripheral = peripheral
//		}
//	}
//
//
//	func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
//
//		peripheral.delegate = self
//		peripheral.discoverServices(nil)
//
//	}
//}

//extension ChatViewController : CBPeripheralDelegate {
//
//	func peripheral( _ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
//
//		for service in peripheral.services! {
//
//			peripheral.discoverCharacteristics(nil, for: service)
//		}
//	}
//
//	func peripheral(_ peripheral: CBPeripheral, didModifyServices invalidatedServices: [CBService]) {
//	}
//
//	func peripheral(
//		_ peripheral: CBPeripheral,
//		didDiscoverCharacteristicsFor service: CBService,
//		error: Error?) {
//
//		for characteristic in service.characteristics! {
//
//			let characteristic = characteristic as CBCharacteristic
//			if (characteristic.uuid.isEqual(Constants.RX_UUID)) {
//				if let messageText = messageTextField.text {
//					let data = messageText.data(using: .utf8)
//					peripheral.writeValue(data!, for: characteristic, type: CBCharacteristicWriteType.withResponse)
//					appendMessageToChat(message: Message(text: messageText, isSent: true))
//					messageTextField.text = ""
//
//				}
//			}
//
//		}
//	}
//}

//extension ChatViewController : CBPeripheralManagerDelegate {
//
////	func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
////
////		if (peripheral.state == .poweredOn){
////
////			initService()
////			updateAdvertisingData()
////		}
////	}
//
//	func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
//
//		for request in requests {
//			if let value = request.value {
//
//				let messageText = String(data: value, encoding: String.Encoding.utf8) as String!
//				appendMessageToChat(message: Message(text: messageText!, isSent: false))
//			}
//			self.peripheralManager.respond(to: request, withResult: .success)
//		}
//	}
//}

extension ChatViewController : UITextFieldDelegate {
	
	func textFieldShouldReturn(_ textField: UITextField) -> Bool {
		textField.resignFirstResponder();
		
		return true
	}
}

extension ChatViewController: UITableViewDelegate,UITableViewDataSource {
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return messages.count
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		
		let message = messages[indexPath.row]
		let cell  = tableView.dequeueReusableCell(withIdentifier: "ChatCell", for: indexPath) as! ChatCell
		
		if (message.isSent) {
			
			cell.receivedMessage.isHidden = true
			cell.sentMessage.isHidden = false
			cell.sentMessage.text = message.text
			cell.sentMessage.sizeToFit()
		}
		else {
			
			cell.sentMessage.isHidden = true
			cell.receivedMessage.isHidden = false
			cell.receivedMessage.text = message.text
			cell.receivedMessage.sizeToFit()
		}
		
		return cell
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		
		return UITableViewAutomaticDimension
	}
	
	
	
}
