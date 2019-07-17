//
//  CoreDataContextObserver.swift
//  PulseCollect
//
//  Created by Martin Prot on 29/04/2019.
//  Copyright © 2019 Appricot media. All rights reserved.
//

import Foundation
import CoreData

public struct ObserverChangeType: OptionSet {
	public let rawValue: Int
	public init(rawValue: Int) { self.rawValue = rawValue }
	public static let insert    = ObserverChangeType(rawValue: 1 << 0)
	public static let update  = ObserverChangeType(rawValue: 1 << 1)
	public static let delete   = ObserverChangeType(rawValue: 1 << 2)
}

public class ManagedObjectObserver<O> where O: NSManagedObject {
	private let changeType: ObserverChangeType
	private let managedObjectContext: NSManagedObjectContext
	private let onChange: (ObserverChangeType, Set<O>) -> ()
	
	public init(context: NSManagedObjectContext, changeType: ObserverChangeType, onChange: @escaping (ObserverChangeType, Set<O>) -> ()) {
		self.managedObjectContext = context
		self.onChange = onChange
		self.changeType = changeType
		
		// Add Observer
		let notificationCenter = NotificationCenter.default
		notificationCenter.addObserver(self, selector: #selector(didChange(_:)), name: .NSManagedObjectContextObjectsDidChange, object: context)
	}
	
	deinit {
		NotificationCenter.default.removeObserver(self, name: .NSManagedObjectContextObjectsDidChange, object: nil)
	}
	
	@objc private func didChange(_ notification: Notification) {
		guard let userInfo = notification.userInfo else { return }
		
		if self.changeType.contains(.insert) {
			if let inserts = userInfo[NSInsertedObjectsKey] as? Set<O> {
				if inserts.count > 0 {
					self.onChange(.insert, inserts)
				}
			}
		}
		
		if self.changeType.contains(.update) {
			if let updates = userInfo[NSUpdatedObjectsKey] as? Set<O> {
				if updates.count > 0 {
					self.onChange(.update, updates)
				}
			}
		}
		
		if self.changeType.contains(.delete) {
			if let deletes = userInfo[NSDeletedObjectsKey] as? Set<O> {
				if deletes.count > 0 {
					self.onChange(.delete, deletes)
				}
			}
		}
	}
}
