//
//  FetchViewModel.swift
//  MPModelKit
//
//  Created by Martin Prot on 27/01/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import CoreData
import Foundation

open class FetchViewModel<E: NSFetchRequestResult> {
	
	public init() { }
	
	/// The fetch request, to be implemented in subclasses
	open var fetchRequest: NSFetchRequest<E> {
		get {
			return NSFetchRequest<E> ()
		}
	}
	
	/// If the list should contain sections, the object keypath to sort with
	open var sectionKeyPath: String? { return .none }
	
	/// The fetchedResultsController initializer
	private var resultControllerInitializer: NSFetchedResultsController<E>? {
		var resultController: NSFetchedResultsController<E>? = .none
		CoreDataManager.dataStore.doInMain { moc in
			resultController = NSFetchedResultsController<E>(fetchRequest: self.fetchRequest, managedObjectContext: moc, sectionNameKeyPath: self.sectionKeyPath, cacheName: .none)
			do {
				try resultController?.performFetch()
			}
			catch let error {
				print("Fetching error %@", error)
			}
		}
		return resultController
	}
	
	private var _fetchedResultsController: NSFetchedResultsController<E>?
	
	
	/// the result controller, lazy var that can be reset
	public var fetchedResultsController: NSFetchedResultsController<E>? {
		get {
			if _fetchedResultsController == nil {
				_fetchedResultsController = resultControllerInitializer
			}
			return _fetchedResultsController
		}
		set {
			_fetchedResultsController = newValue
		}
	}
	
	/// reset the result controller
	open func resetFetch () {
		self.fetchedResultsController = nil
	}
	
	public var hasResults: Bool {
		get {
			guard let frc = self.fetchedResultsController,
				let objects = frc.fetchedObjects else {
					return false
			}
			return objects.count > 0
		}
	}
	
	public var count: Int {
		return fetchedResultsController?.fetchedObjects?.count ?? 0
	}
	
	/// Number of sections in the list
	public var sectionCount: Int {
		get {
			guard let frc = self.fetchedResultsController,
				let sectionInfos = frc.sections else {
					return 0
			}
			return sectionInfos.count
		}
	}
	
	/// Number of lines
	public func itemCount(atSection section: Int) -> Int {
		guard let frc = self.fetchedResultsController,
			let sectionInfos = frc.sections,
			section < sectionInfos.count else {
				return 0
		}
		return sectionInfos[section].numberOfObjects
	}
	
	/// Returns the object at the given index Path
	///
	/// - Parameter indexPath: the index path of the object
	/// - Returns: the object at the index path
	public func object(at indexPath: IndexPath) -> E? {
		return fetchedResultsController?.object(at: indexPath)
	}
	
	/// Returns the objects indexpath, if any
	///
	/// - Parameter object: the object to search the indexpath
	public func indexPath(forObject object: E) -> IndexPath? {
		return fetchedResultsController?.indexPath(forObject: object)
	}
	
	/// Returns a description of the object at the index path. Used for cell short
	/// displays. Should be overriden in subclasses to return something better than
	/// default description
	///
	/// - Parameter indexPath: the index path to search the object
	/// - Returns: the object description
	open func objectTitle(at indexPath: IndexPath) -> String? {
		return object(at: indexPath)?.description
	}
	
	
	/// Returns the title of the given section
	///
	/// - Parameter section: the section
	/// - Returns: the section displayed title
	open func title(forSection section: Int) -> String? {
		guard let resultsController = self.fetchedResultsController,
			  let _ = sectionKeyPath,
			  let sectionInfos = resultsController.sections
		else { return .none }
		if sectionInfos.count > section {
			return sectionInfos[section].name
		}
		else {
			return .none
		}
	}
}