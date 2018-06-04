//
//  CoreDataManager.swift
//  MPModelKit
//
//  Created by Martin Prot on 04/04/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation
import CoreData

enum CoreDataError: Error {
	case alreadyInitialized
	case cannotCreateModel
}

class CoreDataManager {
	struct Defaults {
		static let dbPath = "database.sqlite"
	}
	
	static let dataStore = CoreDataManager()
	
	private var mainQueueContext: NSManagedObjectContext?
	private var privateQueueContext: NSManagedObjectContext?
	
	private var managedObjectModel: NSManagedObjectModel?
	private var storeCoordinator: NSPersistentStoreCoordinator?

	/// Initializes the core data stack, then call the given callback
	/// The core data stack is:
	/// [Main queue context] -> [Global queue context] -> [PSC] -> [DataBase]
	///
	/// - Parameter then: the completion callback, or error callback if so
	func setupDatabase(modelName: String, atPath path: String = Defaults.dbPath) throws {
		let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
		let dbURL = URL(fileURLWithPath: documentsPath.appendingFormat("/%@", path))
		print("[CoreDataManager] created database at", dbURL.path)
		
		if mainQueueContext != nil {
			return
		}
		guard let url = Bundle(for: type(of: self)).url(forResource: modelName, withExtension: nil),
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
		_ = try self.storeCoordinator?.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: dbURL, options: options)
	}
	
	
	/// Save private context on disk. Until this method is called, the db changes will not be saved on disk
	/// /!\ does not saves main context! If main context has changes, call saveMainContext() before.
	func saveOnDisk(then: (() -> ())? = .none) {
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
	func saveMainContext() {
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
	func doInMain(_ block: (NSManagedObjectContext) -> Void) {
		guard let context = mainQueueContext else {
			print("Data manager not initialized")
			return
		}
		context.performAndWait({
			block(context)
		})
	}
	
	/// Perform the given block in the main queue, then save changes into private context
	///
	/// - Parameter block: the block to be performed, with the main context in parameter
	/// - Parameter save: true if the changes should be saved in privateContext
	func doInMain(_ block: (NSManagedObjectContext) -> Void, thenSave save: Bool) {
		doInMain(block)
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
	func doInMain(_ block: (NSManagedObjectContext) -> Void, thenPersist persist: Bool) {
		doInMain(block)
		if persist {
			saveMainContext()
			saveOnDisk()
		}
	}
	
	/// Creates a new async context, executes the bock, saves and deletes the context
	/// The changes are propagated onto main context. saveMainContext should be called
	/// manually
	///
	/// - Parameters:
	/// - Parameter block: the block to be performed, with the main context in parameter
	///   - then: a callback, when everything has been performed
	func doAsync(_ block: @escaping (NSManagedObjectContext) -> Void, then: (() -> Void)?) {
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
	
	func revertUnsaved() {
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
