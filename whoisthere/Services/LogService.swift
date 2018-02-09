//
//  LogSrvice.swift
//  whoisthere
//
//  Created by Shane Whitehead on 9/2/18.
//  Copyright © 2018 Efe Kocabas. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import LogWrapperKit

public enum LogLevel {
	
	/**
	Provides LogLevel
	
	- returns: Returns the current LogLevel
	*/
	case error, warning, info, verbose
	
	/**
	Get the current LogLevel
	
	- returns: DDLogLevel
	*/
	func getDDLogLevel() -> DDLogLevel {
		switch self {
		case .error:
			return DDLogLevel.error
		case .warning:
			return DDLogLevel.warning
		case .info:
			return DDLogLevel.info
		case .verbose:
			return DDLogLevel.verbose
		}
	}
}

public class LogService: NSObject, LogServiceDelegate {
	
	/// Shared LogService
	public static let shared = LogService()
	
	public var fileLogsPath: String? = nil
	
	static let maximumLogFileSize: UInt64 = 1024 * 1024 * 10
	static let rollingFrequency: TimeInterval = 24.0 * 60.0 * 60.0
	static let maximumNumberOfLogFiles: UInt = 7
	
	public let logFileManager: DDLogFileManager = DDLogFileManagerDefault.init()
	
	private override init() {
		super.init()
		LogServiceManager.shared.delegate = self
	}
	
	/**
	Initializes the LogService based on the Configuration provided
	
	- Parameters:
	- config: Log Config
	*/
	public func initialize(consoleLogLevel: LogLevel, fileLogLevel: LogLevel) {
		configureConsoleLogging(logLevel: consoleLogLevel)
		configureFileLogging(logLevel: fileLogLevel)
		
		LogWrapperKit.log(debug: "Initialized Log Service")
	}
	
	func synced(_ closure: () -> Void) {
		objc_sync_enter(self)
		defer {
			objc_sync_exit(self)
		}
		closure()
	}
	/**
	Configures File Logging
	
	- Parameters:
	- config: Log Config
	*/
	func configureFileLogging(logLevel: LogLevel) {
		// File Logger
		let fileLogger: DDFileLogger = DDFileLogger()
		fileLogger.logFormatter = LogFormatter()
		
		// Set the Log file rolling frequency based on the maximum file size (2MB)
		fileLogger.maximumFileSize = LogService.maximumLogFileSize
		fileLogger.rollingFrequency = LogService.rollingFrequency
		// Maximum number of archived logs to be kept on disk
		fileLogger.logFileManager.maximumNumberOfLogFiles = LogService.maximumNumberOfLogFiles
		
		DDLog.add(fileLogger, with: logLevel.getDDLogLevel())
		fileLogsPath = fileLogger.logFileManager.logsDirectory()
		LogWrapperKit.log(debug: "Configured File Logging \(fileLogger.logFileManager.logsDirectory())")
	}
	
	/**
	Configures Console Logging
	
	- Parameters:
	- config: Log Config
	*/
	func configureConsoleLogging(logLevel: LogLevel) {
		DDTTYLogger.sharedInstance().logFormatter = LogFormatter()
		DDTTYLogger.sharedInstance().colorsEnabled = false
		
		// Log to Xcode console
		DDLog.add(DDTTYLogger.sharedInstance(), with: logLevel.getDDLogLevel())
		LogWrapperKit.log(debug: "Configured Console Logging")
	}
	
	/**
	Logs verbose messages
	- Parameters:
	- message: Message
	*/
	
	public func log(verbose: String, file: StaticString, function: StaticString, line: UInt) {
		synced {
			DDLogVerbose(verbose, file: file, function: function, line: line)
		}
	}
	
	public func log(verbose: CustomStringConvertible, file: StaticString, function: StaticString, line: UInt) {
		log(verbose: verbose.description, file: file, function: function, line: line)
	}
	
	/**
	Logs info messages
	- Parameters:
	- message: Message
	*/
	public func log(info: String, file: StaticString, function: StaticString, line: UInt) {
		synced {
			DDLogInfo(info, file: file, function: function, line: line)
		}
	}
	
	public func log(info: CustomStringConvertible, file: StaticString, function: StaticString, line: UInt) {
		log(info: info.description, file: file, function: function, line: line)
	}
	
	/**
	Logs warning messages
	- Parameters:
	- message: Message
	*/
	public func log(warning: String, file: StaticString, function: StaticString, line: UInt) {
		synced {
			DDLogWarn(warning, file: file, function: function, line: line)
		}
	}
	
	public func log(warning: Error, file: StaticString, function: StaticString, line: UInt) {
		log(warning: "\(warning)", file: file, function: function, line: line)
	}
	
	public func log(warning: CustomStringConvertible, file: StaticString, function: StaticString, line: UInt) {
		log(warning: warning.description, file: file, function: function, line: line)
	}
	
	/**
	Logs Error Messages
	- Parameters:
	- message: Message
	*/
	public func log(error: String, file: StaticString, function: StaticString, line: UInt) {
		synced {
			DDLogError(error, file: file, function: function, line: line)
		}
	}
	
	public func log(error: Error, file: StaticString, function: StaticString, line: UInt) {
		log(warning: "\(error)", file: file, function: function, line: line)
	}
	
	public func log(error: CustomStringConvertible, file: StaticString, function: StaticString, line: UInt) {
		log(error: error.description, file: file, function: function, line: line)
	}
	
	/**
	Logs debug Messages
	- Parameters:
	- message: Message
	*/
	
	public func log(debug: String, file: StaticString, function: StaticString, line: UInt) {
		synced {
			DDLogDebug(debug, file: file, function: function, line: line)
		}
	}
	
	public func log(debug: CustomStringConvertible, file: StaticString, function: StaticString, line: UInt) {
		log(debug: debug.description, file: file, function: function, line: line)
	}
}

class LogFormatter: NSObject, DDLogFormatter {
	
	lazy var dateTimeFormatter: DateFormatter = {
		let df = DateFormatter()
		df.dateFormat = "yyyy-MM-dd HH:mm:ssZ"
		return df
	}()
	
	func formatLogMessage(_ logMessage: DDLogMessage) -> String {
		var logLevel: String
		let logFlag = logMessage.flag
		if logFlag.contains(.error) {
			logLevel = "⛔️"
		} else if logFlag.contains(.warning) {
			logLevel = "⚠️"
		} else if logFlag.contains(.info) {
			logLevel = "💡"
		} else if logFlag.contains(.debug) {
			logLevel = "🐞"
		} else if logFlag.contains(.verbose) {
			logLevel = "💬"
		} else {
			logLevel = "?"
		}
		
		var dateText = "Unknown"
		if let timestamp = logMessage.timestamp {
			dateText = dateTimeFormatter.string(from: timestamp)
		}
		
		return "\(logLevel) [\(dateText)] [\(logMessage.fileName) \(logMessage.function)] #\(logMessage.line): \(logMessage.message)"
	}
}


