//
//  Paging.swift
//  MPModelKit
//
//  Created by Martin Prot on 11/05/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

public struct Paging {
	
	static let firstPage = 1
	static let defaultPageSize = 20
	
	public let page: Int
	
	public let limit: Int
	
	public var offset: Int {
		return page * limit
	}
	
	public init() {
		self.init(page: Paging.firstPage, limit: Paging.defaultPageSize)
	}
	
	public init(page: Int) {
		self.init(page: page, limit: Paging.defaultPageSize)
	}
	
	public init(page: Int, limit: Int) {
		self.page = page
		self.limit = limit
	}
	
	public var isFirst: Bool {
		return page == Paging.firstPage
	}
	
	public func next() -> Paging {
		return Paging(page: page+1, limit: self.limit)
	}
	
	public func first() -> Paging {
		return Paging(page: Paging.firstPage, limit: self.limit)
	}
}
