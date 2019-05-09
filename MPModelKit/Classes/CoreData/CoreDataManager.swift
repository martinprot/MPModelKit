//
//  CoreDataManager.swift
//  MPModelKit
//
//  Created by Martin Prot on 04/04/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation
import CoreData

public enum CoreDataError: Error {
	case notInitialized
	case cannotCreateModel
}

public class CoreDataManager {
	static let dbPath = "database.sqlite"
	
	public static let dataStore = CoreDataManager()
	
	private var mainQueueContext: NSManagedObjectContext?
	private var privateQueueContext: NSManagedObjectContext?
	
	private var managedObjectModel: NSManagedObjectModel?
	private var storeCoordinator: NSPersistentStoreCoordinator?
	
	internal init() {}
	
	/// Initializer for instance usage (vs. singleton usage)
	///
	/// - Parameters:
	/// - Parameter modelName: the xcdatamodeld file, without the ".xcdatamodeld")
	/// - 			atPath: the local path of the database, from the Documents directory
	public init(modelName: String, atPath path: String? = .none) throws {
		try self.setupDatabase(modelName: modelName, atPath: path)
	}

	/// Initializes the core data stack, then call the given callback
	/// The core data stack is:
	/// [Main queue context] -> [Global queue context] -> [PSC] -> [DataBase]
	///
	/// - Parameter modelName: the xcdatamodeld file, without the ".xcdatamodeld")
	/// - 			atPath: the local path of the database, from the Documents directory
	public func setupDatabase(modelName: String, atPath path: String? = .none) throws {
		let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
		let dbURL = URL(fileURLWithPath: documentsPath.appendingFormat("/%@", path ?? CoreDataManager.dbPath))
		
		if mainQueueContext != nil {
			return
		}
		guard let url = Bundle.main.url(forResource: modelName, withExtension: "momd"),
			  let managedObjectModel = NSManagedObjectModel(contentsOf: url)
		else {
			throw CoreDataError.cannotCreateModel
		}
		self.managedObjectModel = managedObjectModel
		self.storeCoordinator = NSPersistentStoreCoordinator(managedObjectModel: managedObjectModel)
		
		self.mainQueueContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
		self.privateQueueContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		self.privateQueueContext?.persistentStoreCoordinator = storeCoordinator
		self.mainQueueContext?.parent = privateQueueContext
		
		let options: [String: Any] = [NSMigratePersistentStoresAutomaticallyOption	: true,
									  NSInferMappingModelAutomaticallyOption : true,
									  NSSQLitePragmasOption : ["journal_mode": "DELETE"]]
		let directoryURL = dbURL.deletingLastPathComponent()
		if !FileManager.default.fileExists(atPath: directoryURL.path) {
			try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: .none)
		}
		if FileManager.default.fileExists(atPath: dbURL.path) {
			print("[CoreDataManager] reading database from", dbURL.path)
		}
		else {
			print("[CoreDataManager] created database at", dbURL.path)
		}
			
		_ = try self.storeCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
	}
	
	
	/// Save private context on disk. Until this method is called, the db changes will not be saved on disk
	/// /!\ does not saves main context! If main context has changes, call saveMainContext() before.
	public func saveOnDisk(then: (() -> ())? = .none) {
		guard let context = privateQueueContext,
			context.hasChanges else {
			then?()
			return
		}
		context.perform({ [weak self] in
			do {
				try context.save()
				then?()
			}
			catch let error {
				self?.process(saveError: error)
			}
		})
	}
	
	/// Saves the main context and propagates changes on private context
	public func saveMainContext() {
		guard let context = mainQueueContext,
			context.hasChanges else {
				return
		}
		context.performAndWait { 
			do {
				try context.save()
			}
			catch let error {
				self.process(saveError: error)
			}
		}
	}
	
	/// Perform the given block in the main queue
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	public func doInMain(_ block: (NSManagedObjectContext) -> Void) {
		guard let context = mainQueueContext else {
			print("Data manager not initialized")
			return
		}
		context.performAndWait({
			block(context)
		})
	}
		
	/// Perform the given block in the main queue
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	public func doInMain(_ block: (NSManagedObjectContext) throws -> Void) throws {
		guard let context = mainQueueContext else {
			print("Data manager not initialized")
			return
		}
		var thrownError: Error?
		context.performAndWait({
			do { try block(context) }
			catch { thrownError = error }
		})
		if let error = thrownError {
			throw error
		}
	}
	
	/// Perform the given block in the main queue, then save changes into private context
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	/// - Parameter save: true if the changes should be saved in privateContext
	public func doInMain(_ block: (NSManagedObjectContext) -> Void, thenSave save: Bool) {
		doInMain(block)
		if save {
			saveMainContext()
		}
	}
	
	/// Perform the given block in the main queue, then save changes into private context
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	/// - Parameter save: true if the changes should be saved in privateContext
	public func doInMain(_ block: (NSManagedObjectContext) throws -> Void, thenSave save: Bool) throws {
		try doInMain(block)
		if save {
			saveMainContext()
		}
	}
	
	/// Perform the given block in the main queue, save changes into private context
	/// then save on disk
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	/// - Parameter persist: true if the changes should be saved in private queue, and
	/// on disk.
	public func doInMain(_ block: (NSManagedObjectContext) -> Void, thenPersist persist: Bool) {
		doInMain(block)
		if persist {
			saveMainContext()
			saveOnDisk()
		}
	}
	
	/// Perform the given block in the main queue, save changes into private context
	/// then save on disk
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	/// - Parameter persist: true if the changes should be saved in private queue, and
	/// on disk.
	public func doInMain(_ block: (NSManagedObjectContext) throws -> Void, thenPersist persist: Bool) throws {
		try doInMain(block)
		if persist {
			saveMainContext()
			saveOnDisk()
		}
	}
	
	/// Uses the doInMain pattern to return an object.
	///
	/// - Parameter block: the block which returns something created with context
	/// - Returns: the requested object
	public func getInMain<T>(_ block: (NSManagedObjectContext) -> T) -> T? {
		guard let context = mainQueueContext else {
			print("Data manager not initialized")
			return nil
		}
		var object: T?
		context.performAndWait({
			object = block(context)
		})
		return object
	}	
	
	/// Uses the doInMain pattern to return an object.
	///
	/// - Parameter block: the block which returns something created with context
	/// - Returns: the requested object
	public func getInMain<T>(_ block: (NSManagedObjectContext) throws -> T) throws -> T {
		guard let context = mainQueueContext else {
			print("Data manager not initialized")
			throw CoreDataError.notInitialized
		}
		var object: T?
		var thrownError: Error?
		context.performAndWait({
			do { object = try block(context) }
			catch { thrownError = error }
		})
		if let error = thrownError {
			throw error
		}
		guard let o = object else { throw CoreDataError.cannotCreateModel }
		return o
	}
	
	/// Creates a new async context, executes the bock, saves and deletes the context
	/// The changes are propagated onto main context. saveMainContext should be called
	/// manually
	///
	/// - Parameters:
	/// - Parameter block: the block to be performed, with the main context in parameter
	///   - then: a callback, when everything has been performed
	public func doAsync(_ block: @escaping (NSManagedObjectContext) -> Void, then: (() -> Void)?) {
		guard let mainContext = mainQueueContext else { return }
		
		let asyncContext = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
		asyncContext.parent = mainContext
		asyncContext.perform({ [weak self] in
			block(asyncContext)
			do {
				try asyncContext.save()
			}
			catch let error {
				self?.process(saveError: error)
			}
			then?()
		})
	}
	
	public func revertUnsaved() {
		guard let mainContext = mainQueueContext else { return }
		mainContext.rollback()
	}
	
	/// very basic error handling :)
	///
	/// - Parameter error: the error to handle
	private func process(saveError error: Error) {
		print("failed to save context", error.localizedDescription)
	}
}
