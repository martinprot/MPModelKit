//
//  BackendAPIRequest.swift
//  MPModelKit
//
//  Created by Martin Prot on 12/01/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

public protocol BackendAPIRequest {
	
	/// Defines the api endpoint to use
	var endpoint: String { get }
	
	// Define what method
	var method: NetworkService.Method { get }
	
	// The parameters to pass in
	var parameters: [String: Any]? { get }
	
	// form-data, or raw json
	var bodyType: BodyRequestType { get }
	
	// Some headers
	var headers: [String: String]? { get }
}

public enum BodyRequestType {
	case formData
	case rawJson
}

extension BackendAPIRequest {
	
	/// Default parameter type is form-data
	public var bodyType: BodyRequestType {
		return .formData
	}
	
	public func defaultJSONHeaders() -> [String: String] {
		switch bodyType {
		case .formData: return ["Content-Type": "application/x-www-form-urlencoded"]
		case .rawJson: return ["Content-Type": "application/json"]
		}
	}
	
	/// Default headers are Content-type: application/x-www-form-urlencoded
	public var headers: [String: String]? {
		get {
			return defaultJSONHeaders()
		}
	}
}


/// A request with the data, instead of the JSON response
public protocol BackendAPIDataRequest: BackendAPIRequest {
}

/// A request with a json object at root named with objectKey property
public protocol BackendAPIObjectRequest: BackendAPIRequest {
	// returned object key
	var objectKey: String? { get }
}

/// A request with the data, instead of the JSON response
public protocol BackendAPIHTMLRequest: BackendAPIRequest {
}

extension BackendAPIObjectRequest {
	public var objectKey: String? {
		get {
			return .none
		}
	}

}
