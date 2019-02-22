//
//  OAuthConfiguration.swift
//  MPModelKit
//
//  Created by Martin Prot on 20/06/2018.
//

import Foundation

public protocol OAuthConfiguration {
	var clientId: String { get }
	var clientSecret: String { get }
	var baseURL: URL { get }
	var loginPath: String { get }
	var tokenPath: String { get }
	var redirectUrl: String { get }
	var method: NetworkService.Method { get }
}

extension OAuthConfiguration {
	var loginUrl: URL {
		return self.baseURL.appendingPathComponent(self.loginPath)
	}
	var tokenUrl: URL {
		return self.baseURL.appendingPathComponent(self.tokenPath)
	}
	var method: NetworkService.Method {
		return .POST
	}
}

public struct GenericOAuthConfiguration: OAuthConfiguration {
	public let clientId: String
	public let clientSecret: String
	public let baseURL: URL
	public let loginPath: String
	public let tokenPath: String
	public let redirectUrl: String
	public let method: NetworkService.Method
}
