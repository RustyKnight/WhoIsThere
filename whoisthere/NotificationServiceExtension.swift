//
//  NotificationServiceExtension.swift
//  whoisthere
//
//  Created by Shane Whitehead on 9/2/18.
//  Copyright © 2018 Efe Kocabas. All rights reserved.
//

import Foundation
import UserNotifications
import BeamUserNotificationKit
import Hydra

//enum UNNotificationActionIdentifier: String, StringIdentifiable {
//	case retry = "UNNotificationActionIdentifier.retry"
//	case accept = "UNNotificationActionIdentifier.accept"
//	case cancel = "UNNotificationActionIdentifier.cancel"
//	case show = "UNNotificationActionIdentifier.show"
//	case view = "UNNotificationActionIdentifier.view"
//	case ignore = "UNNotificationActionIdentifier.ignore"
//
//	var stringIdentifier: String {
//		return self.rawValue
//	}
//}
//
//struct NotificationActionStrings {
//	static let retry: String = "alert.action.retry".localized
//	static let cancel: String = "general.cancel".localized
//	static let accept: String = "alert.action.accept".localized
//	static let show: String = "alert.action.show".localized
//	static let view: String = "messaging.action.view".localized
//	static let ignore: String = "alert.action.ignore".localized
//}


enum NotificationTitles: String, StringIdentifiable {
	case error = "Error"
	case warning = "Warning"
	case info = "Info"
	
	var stringIdentifier: String { return self.rawValue.localized }
}

enum NotificationThreads: String, StringIdentifiable {
	case error = "Notification.thread.error"
	case warning = "Notification.thread.warning"
	case info = "Notification.thread.info"
	var stringIdentifier: String { return self.rawValue }
}

extension NotificationService {
	
	// MARK: Custom Actions
//
//	var retryAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.retry)
//			.withIdentifier(UNNotificationActionIdentifier.retry)
//			.build()
//	}
//
//	var cancelAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.cancel)
//			.withIdentifier(UNNotificationActionIdentifier.cancel)
//			.build()
//	}
//
//	var acceptAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.accept)
//			.withIdentifier(UNNotificationActionIdentifier.accept)
//			.build()
//	}
//
//	var showAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.show)
//			.withIdentifier(UNNotificationActionIdentifier.show)
//			.build()
//	}
//
//	var ignoreAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.ignore)
//			.withIdentifier(UNNotificationActionIdentifier.ignore)
//			.build()
//	}
//
//	var viewAction: UNNotificationAction {
//		return UserNotificationActionBuilder()
//			.withTitle(NotificationActionStrings.view)
//			.withIdentifier(UNNotificationActionIdentifier.view)
//			.build()
//	}
	
	// MARK: Custom Categories
	
//	var retryCancelCategory: UNNotificationCategory {
//		return UNNotificationCategory(
//			identifier: UNNotificationCategoryIdentifier.retryCancel,
//			actions: [retryAction, cancelAction],
//			intentIdentifiers: [],
//			options: [])
//	}
//
//	var acceptCancelCategory: UNNotificationCategory {
//		return UNNotificationCategory(
//			identifier: UNNotificationCategoryIdentifier.acceptCancel,
//			actions: [acceptAction, cancelAction],
//			intentIdentifiers: [],
//			options: [])
//	}
//
//	var showIgnoreCategory: UNNotificationCategory {
//		return UNNotificationCategory(
//			identifier: UNNotificationCategoryIdentifier.showIgnore,
//			actions: [showAction, ignoreAction],
//			intentIdentifiers: [],
//			options: [])
//	}
//
//	var viewIgnoreCategory: UNNotificationCategory {
//		return UNNotificationCategory(
//			identifier: UNNotificationCategoryIdentifier.viewIgnore,
//			actions: [viewAction, ignoreAction],
//			intentIdentifiers: [],
//			options: [])
//	}
//
//	var showCategory: UNNotificationCategory {
//		return UNNotificationCategory(
//			identifier: UNNotificationCategoryIdentifier.show,
//			actions: [showAction,],
//			intentIdentifiers: [],
//			options: [])
//	}
//
//	var categories: Set<UNNotificationCategory> {
//		return Set<UNNotificationCategory>([
//			retryCancelCategory,
//			acceptCancelCategory,
//			showIgnoreCategory,
//			viewIgnoreCategory,
//			showCategory
//			])
//	}
	
	// MARK: Add "custom category" based notification requests
	
	func addInfo(identifier: StringIdentifiable = UUID().uuidString,
							 title: StringIdentifiable = NotificationTitles.info,
							 subtitle: StringIdentifiable? = nil,
							 body: StringIdentifiable,
							 badge: NSNumber? = nil,
							 alertStyle: AlertStyle? = nil,
							 userInfo: [AnyHashable: Any]? = nil,
							 attachments: [UNNotificationAttachment]? = nil,
							 category: StringIdentifiable? = nil,
							 thread: StringIdentifiable? = NotificationThreads.info) -> Promise<Void> {
		return add(identifier: identifier,
							 title: title,
							 subtitle: subtitle,
							 body: body,
							 badge: badge,
							 alertStyle: alertStyle,
							 userInfo: userInfo,
							 attachments: attachments,
							 category: category,
							 thread: thread)
	}
	
	func addError(identifier: StringIdentifiable = UUID().uuidString,
								title: StringIdentifiable = NotificationTitles.error,
								subtitle: StringIdentifiable? = nil,
								body: StringIdentifiable,
								badge: NSNumber? = nil,
								alertStyle: AlertStyle? = nil,
								userInfo: [AnyHashable: Any]? = nil,
								attachments: [UNNotificationAttachment]? = nil,
								category: StringIdentifiable? = nil,
								thread: StringIdentifiable? = NotificationThreads.error) -> Promise<Void> {
		return add(identifier: identifier,
							 title: title,
							 subtitle: subtitle,
							 body: body,
							 badge: badge,
							 alertStyle: alertStyle,
							 userInfo: userInfo,
							 attachments: attachments,
							 category: category,
							 thread: thread)
	}
	func addError(ignoreIfOnBackground: Bool = true,
								identifier: StringIdentifiable = UUID().uuidString,
								title: StringIdentifiable = NotificationTitles.error,
								subtitle: StringIdentifiable? = nil,
								body: StringIdentifiable,
								badge: NSNumber? = nil,
								alertStyle: AlertStyle? = nil,
								userInfo: [AnyHashable: Any]? = nil,
								attachments: [UNNotificationAttachment]? = nil,
								category: StringIdentifiable? = nil,
								thread: StringIdentifiable? = NotificationThreads.error) -> Promise<Void> {
		guard UIApplication.shared.applicationState != .background else {
			return Promise<Void>(resolved: (()))
		}
		return add(identifier: identifier,
							 title: title,
							 subtitle: subtitle,
							 body: body,
							 badge: badge,
							 alertStyle: alertStyle,
							 userInfo: userInfo,
							 attachments: attachments,
							 category: category,
							 thread: thread)
	}
	
	func addWarning(identifier: StringIdentifiable = UUID().uuidString,
									title: StringIdentifiable = NotificationTitles.warning,
									subtitle: StringIdentifiable? = nil,
									body: StringIdentifiable,
									badge: NSNumber? = nil,
									alertStyle: AlertStyle? = nil,
									userInfo: [AnyHashable: Any]? = nil,
									attachments: [UNNotificationAttachment]? = nil,
									category: StringIdentifiable? = nil,
									thread: StringIdentifiable? = NotificationThreads.warning) -> Promise<Void> {
		return add(identifier: identifier,
							 title: title,
							 subtitle: subtitle,
							 body: body,
							 badge: badge,
							 alertStyle: alertStyle,
							 userInfo: userInfo,
							 attachments: attachments,
							 category: category,
							 thread: thread)
	}
	
//	func addRetryCancel(identifier: StringIdentifiable,
//											title: StringIdentifiable,
//											subtitle: StringIdentifiable? = nil,
//											body: StringIdentifiable,
//											badge: NSNumber? = nil,
//											alertStyle: AlertStyle? = nil,
//											userInfo: [AnyHashable: Any]? = nil,
//											attachments: [UNNotificationAttachment]? = nil,
//											thread: StringIdentifiable? = nil) -> Promise<Void> {
//		return add(identifier: identifier,
//							 title: title,
//							 subtitle: subtitle,
//							 body: body,
//							 badge: badge,
//							 alertStyle: alertStyle,
//							 userInfo: userInfo,
//							 attachments: attachments,
//							 category: UNNotificationCategoryIdentifier.retryCancel.rawValue,
//							 thread: thread)
//	}
//	
//	func addAcceptCancel(identifier: StringIdentifiable,
//											 title: StringIdentifiable,
//											 subtitle: StringIdentifiable? = nil,
//											 body: StringIdentifiable,
//											 badge: NSNumber? = nil,
//											 alertStyle: AlertStyle? = nil,
//											 userInfo: [AnyHashable: Any]? = nil,
//											 attachments: [UNNotificationAttachment]? = nil,
//											 thread: StringIdentifiable? = nil) -> Promise<Void> {
//		return add(identifier: identifier,
//							 title: title,
//							 subtitle: subtitle,
//							 body: body,
//							 badge: badge,
//							 alertStyle: alertStyle,
//							 userInfo: userInfo,
//							 attachments: attachments,
//							 category: UNNotificationCategoryIdentifier.acceptCancel.rawValue,
//							 thread: thread)
//	}
//	
//	func addShowIgnore(identifier: StringIdentifiable,
//										 title: StringIdentifiable,
//										 subtitle: StringIdentifiable? = nil,
//										 body: StringIdentifiable,
//										 badge: NSNumber? = nil,
//										 alertStyle: AlertStyle? = nil,
//										 userInfo: [AnyHashable: Any]? = nil,
//										 attachments: [UNNotificationAttachment]? = nil,
//										 thread: StringIdentifiable? = nil) -> Promise<Void> {
//		return add(identifier: identifier,
//							 title: title,
//							 subtitle: subtitle,
//							 body: body,
//							 badge: badge,
//							 alertStyle: alertStyle,
//							 userInfo: userInfo,
//							 attachments: attachments,
//							 category: UNNotificationCategoryIdentifier.showIgnore.rawValue,
//							 thread: thread)
//	}
//	
//	func addViewIgnore(identifier: StringIdentifiable,
//										 title: StringIdentifiable,
//										 subtitle: StringIdentifiable? = nil,
//										 body: StringIdentifiable,
//										 badge: NSNumber? = nil,
//										 alertStyle: AlertStyle? = nil,
//										 userInfo: [AnyHashable: Any]? = nil,
//										 attachments: [UNNotificationAttachment]? = nil,
//										 thread: StringIdentifiable? = nil) -> Promise<Void> {
//		return add(identifier: identifier,
//							 title: title,
//							 subtitle: subtitle,
//							 body: body,
//							 badge: badge,
//							 alertStyle: alertStyle,
//							 userInfo: userInfo,
//							 attachments: attachments,
//							 category: UNNotificationCategoryIdentifier.viewIgnore.rawValue,
//							 thread: thread)
//	}
//	
//	func addShow(identifier: StringIdentifiable,
//							 title: StringIdentifiable,
//							 subtitle: StringIdentifiable? = nil,
//							 body: StringIdentifiable,
//							 badge: NSNumber? = nil,
//							 alertStyle: AlertStyle? = nil,
//							 userInfo: [AnyHashable: Any]? = nil,
//							 attachments: [UNNotificationAttachment]? = nil,
//							 thread: StringIdentifiable? = nil) -> Promise<Void> {
//		return add(identifier: identifier,
//							 title: title,
//							 subtitle: subtitle,
//							 body: body,
//							 badge: badge,
//							 alertStyle: alertStyle,
//							 userInfo: userInfo,
//							 attachments: attachments,
//							 category: UNNotificationCategoryIdentifier.show.rawValue,
//							 thread: thread)
//	}
}

