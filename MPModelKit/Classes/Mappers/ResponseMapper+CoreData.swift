//
//  ResponseMapper+CoreData.swift
//  MPModelKit
//
//  Created by Martin Prot on 10/04/2017.
//  Copyright © 2017 qosi. All rights reserved.
//

import Foundation
import CoreData

/// Generic parser for arrays, adapted to core data
final public class SetResponseMapper<A: Mappable> where A: Hashable {
	
	/// Processes a json list by calling a mapper for each element. Returns a Set
	/// of managed objects.
	///
	/// - Parameters:
	///   - obj: the json list
	///   - moc: managed object context
	///   - mapper: the mapper that converts json dictionary into managed object.
    ///     A function of CoreDataResponseMapperProtocol
	/// - Returns: a Set of managed objects
	/// - Throws: throws an error if wrong json format or rethrow any subelement
	///		mapping error
	static public func process(obj: Any, objectContext moc: NSManagedObjectContext, mapper: ((Any, Int, NSManagedObjectContext) throws -> A)) throws -> Set<A> {
		guard let json = obj as? [[String: Any]] else {
			throw ResponseMapperError.invalid
		}
		var items = Set<A>()
		for (offset, jsonItem) in json.enumerated() {
			do {
				let item = try mapper(jsonItem, offset, moc)
				items.insert(item)
			}
			catch {
				print("Mapping failed for element \(A.self). \(error)")
			}
		}
		return items
	}
}


/// Protocol to be implemented by concrete mappers
public protocol CoreDataResponseMapperProtocol {
	
	associatedtype Item
	
	/// Processes the json object to create the managed object subclass.
	///
	/// - Parameters:
	///   - jsonObject: the JSON dictionary representing the object
	///   - moc: the managed object context
	/// - Returns: a instance of mnaged object subclass
	/// - Throws: throws an error if missing properties, or database error
	static func process(jsonObject: Any, objectContext moc: NSManagedObjectContext) throws -> Item
	
	/// Processes a json object among others in a json list, to create the managed object subclass.
	/// The list index gives the object position in the list
	///
	/// - Parameters:
	///   - jsonObject: the JSON dictionary representing the object
	///   - offset: the index of the object in the list
	///   - moc: the managed object context
	/// - Returns: a instance of mnaged object subclass
	/// - Throws: throws an error if missing properties, or database error
	static func process(jsonObject: Any, offset: Int, objectContext moc: NSManagedObjectContext) throws -> Item
}

public extension CoreDataResponseMapperProtocol {
	static func process(jsonObject: Any, offset: Int, objectContext moc: NSManagedObjectContext) throws -> Item {
		return try process(jsonObject: jsonObject, objectContext: moc)
	}
}
