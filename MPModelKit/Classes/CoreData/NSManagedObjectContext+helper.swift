//
//  NSManagedObjectContext+helper.swift
//  MPModelKit
//
//  Created by Martin Prot on 05/04/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation
import CoreData

enum ManagedObjectError: Error {
	case wrongEntity
}

public protocol Identifiable {
	static var objectIdKeyPath: String { get }
	
	var objectId: Int64 { get set }
}

public extension Identifiable {
	static var objectIdKeyPath: String {
		return "objectId"
	}
}


extension NSManagedObjectContext {
	
	/// Returns a predicate that respects all the properties in parameter
	///
	/// - Parameter respecting: the property/valeu dictionary
	/// - Returns: the resulting predicate that should filter on the given properties
	private func predicate(respecting: [String: Any]) -> NSPredicate {
		let keys: [String] = respecting.keys.map() { $0 as String }
		let values: [Any]  = keys.map() { respecting[$0] as Any }
		let keyValues =  zip(keys, values).flatMap {[$0.0, $0.1]}
		
		let formatList = values.map() { value in
			return value is String ? "%K LIKE %@" : "%K = %@"
		}
		let formatString = formatList.joined(separator: "AND")
		return NSPredicate(format: formatString, argumentArray: keyValues)
	}
	
	/// Just create a new empty object for the given type
	///
	/// - Returns: the new object
	public func newObject<E: NSManagedObject>() throws -> E {
		if let object = NSEntityDescription.insertNewObject(forEntityName: String(describing: E.self), into: self) as? E {
			return object
		}
		else {
			throw ManagedObjectError.wrongEntity
		}
	}
	
	public func newOrExistingObject<E: NSManagedObject>(withValue value: Any, forKey key: String) throws -> E {
		if let object: E = object(withValue: value, forKey: key) {
			return object
		}
		else {
			let object: E = try newObject()
			object.setValue(value, forKey: key)
			return object
		}
	}
	
	public func object<E: NSManagedObject>(withValue value: Any, forKey key: String) -> E? {
		let entityName = String(describing: E.self)
		let request = NSFetchRequest<E>(entityName: entityName)
		request.predicate = predicate(respecting: [key: value])
		request.fetchLimit = 1
		let objects = try? fetch(request)
		return objects?.first
	}
	
	public func allObjects<E: NSManagedObject>(sortOn sortKey: String? = .none, ascending: Bool = true) -> [E] {
		let entityName = String(describing: E.self)
		let request = NSFetchRequest<E>(entityName: entityName)
		if let sortKey = sortKey {
			request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
		}
		return (try? fetch(request)) ?? []
	}
	
	public func allObjects<E: NSManagedObject>(respecting: [String: Any], sortOn sortKey: String? = .none, ascending: Bool = true) -> [E] {
		let entityName = String(describing: E.self)
		let request = NSFetchRequest<E>(entityName: entityName)
		
		request.predicate = predicate(respecting: respecting)
		
		if let sortKey = sortKey {
			request.sortDescriptors = [NSSortDescriptor(key: sortKey, ascending: ascending)]
		}
		return (try? fetch(request)) ?? []
	}
	
	public func removeAll<E: NSManagedObject>(entity: E.Type, respecting: [String: Any]? = .none) throws {
		let objects: [E]
		if let toRespect = respecting {
			objects = allObjects(respecting: toRespect)
		}
		else {
			objects = allObjects()
		}
		objects.forEach { self.delete($0) }
	}
	
	////////////////////////////////////////////////////////////////////////////
	// MARK: Identifiable
	////////////////////////////////////////////////////////////////////////////
	
	public func newOrExistingObject<E: NSManagedObject>(identifiedBy objectId: Int64) throws -> E where E: Identifiable {
		if let object: E = object(identifiedBy: objectId) {
			return object
		}
		else {
			var object: E = try newObject()
			object.objectId = objectId
			return object
		}
	}
	
	public func object<E: NSManagedObject>(identifiedBy objectId: Int64) -> E? where E: Identifiable {
		let entityName = String(describing: E.self)
		let request = NSFetchRequest<E>(entityName: entityName)
		request.predicate = predicate(respecting: [E.objectIdKeyPath: objectId])
		let objects = try? fetch(request)
		return objects?.first
	}
}

extension NSManagedObjectContext {
	
	/// Do the given instructions with the caller, on the main thread
	///
	/// - Parameter block: the instruction to do
	public func doSync(_ block: @escaping (NSManagedObjectContext) -> Void) {
		doSync(block, thenSave: false)
	}
	
	/// Do the given instructions with the caller, on the main thread
	///
	/// - Parameter block: the instruction to do
	/// - Parameter thenSave: true if the modifications should be saved
	public func doSync(_ block: @escaping (NSManagedObjectContext) -> Void, thenSave save: Bool) {
		self.performAndWait {
			block(self)
			if save && self.hasChanges {
				do {
					try self.save()
				}
				catch let error {
					print("failed to save context", error.localizedDescription)
				}
			}
		}
	}
}
