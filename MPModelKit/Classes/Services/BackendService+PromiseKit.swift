//
//  BackendService+PromiseKit.swift
//  MPModelKit
//
//  Created by Martin Prot on 15/06/2018.
//

import PromiseKit

public enum BackendPromiseError: Error {
	case fetchError(sender: BackendAPIRequest, json: [String: Any]?, error: NetworkServiceError, code: Int)
	
	public var sender: BackendAPIRequest {
		switch self {
		case .fetchError(let sender, _, _, _):
			return sender
		}
	}
	
	public var code: Int {
		switch self {
		case .fetchError(_, _, _, let code):
			return code
		}
	}
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
