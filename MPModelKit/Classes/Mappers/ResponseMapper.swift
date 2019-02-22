//
//  ResponseMapper.swift
//  MPModelKit
//
//  Created by Martin Prot on 16/01/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

/// some error relative to parsing
///
/// - invalid: the JSON is not valid
/// - missingAttribute: a mandatory attribute is missing
public enum ResponseMapperError: Error {
	case invalid
	case missingAttribute
	case databaseError
	case resourceNotFound
	case notMappable
}

public protocol Mappable { }


/// Generic parser object
open class ResponseMapper<I: Mappable> {
	
	static public func process(jsonObject obj: Any, do parsing: (_ json: [String: Any]) -> I?) throws -> I {
		guard let json = obj as? [String: Any] else {
			throw ResponseMapperError.invalid
		}
		if let item = parsing (json) {
			return item
		}
		else {
			throw ResponseMapperError.invalid
		}
	}
}


/// Generic parser for arrays
final public class ArrayResponseMapper<A: Mappable> {
	
	@discardableResult static public func process(obj: Any, mapper: ((Any) throws -> A)) throws -> [A] {
		guard let json = obj as? [[String: Any]] else {
			throw ResponseMapperError.invalid
		}
		var items = [A]()
		json.forEach { (jsonItem) in
			if let item = try? mapper(jsonItem) {
				items.append(item)
			}
		}
		return items
	}

}

/// Generic parser for arrays which contains some Dictionaries with only one element each:
/// These elements are the objects we whant to parse.
final public class ArrayFlattenResponseMapper<A: Mappable> {

	
	static public func process(flattenOn: String? = .none, obj: Any, mapper: ((Any) throws -> A)) throws -> [A] {
		guard let json = obj as? [[String: Any]] else {
			throw ResponseMapperError.invalid
		}
		var items = [A]()
		try json.forEach { uniqueElementArray in
			if let flattenOn = flattenOn {
				guard	let jsonItem = uniqueElementArray[flattenOn]
				else {
						throw ResponseMapperError.invalid
				}
				let item = try mapper(jsonItem)
				items.append(item)
			}
			else {
				guard	uniqueElementArray.count == 1,
					let jsonItem = uniqueElementArray.values.first
					else {
						throw ResponseMapperError.invalid
				}
				let item = try mapper(jsonItem)
				items.append(item)
			}
		}
		return items
	}
}



/// Protocol to be implemented by concrete mappers
public protocol ResponseMapperProtocol {
	
	associatedtype Item
	
	@discardableResult static func process(jsonObject: Any) throws -> Item
}

public typealias ClassicResponseMapper<T: Mappable> = ResponseMapper<T> & ResponseMapperProtocol
