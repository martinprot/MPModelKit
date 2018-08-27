//
//  ServiceKey.swift
//  MPModelKit
//
//  Created by Martin Prot on 06/02/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

/// Every webservice keys
public protocol ServiceKey {
	var keyName: String { get }
}

public extension ServiceKey where Self: RawRepresentable {
	public var keyName: RawValue { return rawValue }
}

extension Dictionary {
	private struct TempServiceKey: ServiceKey, RawRepresentable {
		typealias RawValue = String
		let rawValue: RawValue
	}
	
	public func key<Value>(_ key: ServiceKey) -> Value? {
		let keys = key.keyName.components(separatedBy: ".")
		if keys.count == 1 {
			if let k = keys[0] as? Key {
				return self[k] as? Value
			}
			else {
				return .none
			}
		}
		else if keys.count > 1 {
			guard let k = keys[0] as? Key,
				  let subdic = self[k] as? [String: Any]
			else {
				return .none
			}
			let subkeys = keys.dropFirst().joined(separator: ".")
			let serviceKey = TempServiceKey(rawValue: subkeys)
			return subdic.key(serviceKey)
		}
		else {
			return .none
		}
	}
	public func key<Value>(_ firstKey: ServiceKey, fallback: ServiceKey) -> Value? {
		return key(firstKey) ?? key(fallback)
	}
}

extension DateFormatter {
	static public var standardFormatter: DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
		return dateFormatter
	}
}
