//
//  BackendService+PromiseKit.swift
//  MPModelKit
//
//  Created by Martin Prot on 15/06/2018.
//

import PromiseKit

public enum BackendPromiseError: Error {
	case fetchError(sender: BackendAPIRequest, json: [String: Any]?, error: NetworkServiceError, code: Int)
}

extension BackendService {
	
	public func fetch(request: BackendAPIRequest) -> Promise<Any> {
		return Promise<Any> { [weak self] seal in
			self?.fetch(request: request, success: { result in
				seal.fulfill(result)
			}, failure: { result, error, code in
				seal.reject(BackendPromiseError.fetchError(sender: request, json: result, error: error, code: code))
			})
		}
	}
}
