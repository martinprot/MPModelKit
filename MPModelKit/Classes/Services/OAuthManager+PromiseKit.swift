//
//  OAuthManager+PromiseKit.swift
//  mpkit
//
//  Created by Martin Prot on 18/07/2018.
//

import PromiseKit

extension OAuthManager {
	
	public func authenticate() -> Promise<OAuthResult> {
		return Promise<OAuthResult> { [weak self] seal in
			self?.authenticate() { result in
				switch result {
				case .authenticated, .authenticatedAnonymously:
					seal.fulfill(result)
				case .notAuthenticated(let error):
					seal.reject(error)
				}
			}
		}
	}
	
	public func authenticate(withLogin login: String, password: String) -> Promise<Void> {
		return Promise<Void> { [weak self] seal in
			self?.authenticate(withLogin: login, password: password, callback: { error in
				if let error = error {
					seal.reject(error)
				}
				else {
					seal.fulfill(())
				}
			})
		}
	}
	
	public func authenticate(on service: String, parameters: [String: String]) -> Promise<Void> {
		return Promise<Void> { [weak self] seal in
			self?.authenticate(on: service, parameters: parameters, callback: { error in
				if let error = error {
					seal.reject(error)
				}
				else {
					seal.fulfill(())
				}
			})
		}
	}
}
