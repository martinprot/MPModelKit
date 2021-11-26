//
//  BackendService.swift
//  MPModelKit
//
//  Created by Martin Prot on 12/01/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

public final class BackendConfiguration {
	
	public let baseURL: URL?
	
	var apiAuthenticator: BackendAPIAuth?
	
	public init() {
		self.baseURL = .none
	}
	
	public init(baseURL: URL) {
		self.baseURL = baseURL
	}
	
	convenience public init(baseURL: URL, apiAuth: BackendAPIAuth) {
		self.init(baseURL: baseURL)
		self.apiAuthenticator = apiAuth
	}
	
	public func setAsDefault() {
		BackendConfiguration.shared = self
	}
	
	static var shared = BackendConfiguration()
}

public class BackendService {
	
	/// the backend configuration
	private let configuration: BackendConfiguration
	
	/// the service to connect
	private let service: NetworkService = NetworkService()
	
	public init() {
		self.configuration = BackendConfiguration()
	}
	
	public init(configuration: BackendConfiguration) {
		self.configuration = configuration
	}
	
	public func fetch(request: BackendAPIRequest,
	             success: @escaping (Any) -> Void,
	             failure: (([String: Any]?, NetworkServiceError, Int) -> Void)? = nil) {
		// Configure URL
		let serviceURL: URL?
		if request.endpoint.starts(with: "http") {
			serviceURL = URL(string: request.endpoint)
		}
		else if let baseURL = configuration.baseURL {
			serviceURL = baseURL.appendingPathComponent(request.endpoint)
		}
		else {
			serviceURL = URL(string: "http://" + request.endpoint)
		}
		guard let url = serviceURL
			else {
				failure?(.none, .wrongURL, 0)
				return
		}
		let completeUrl: URL
		let body: Data?
		
		// Configure parameters
		if let parameters = request.parameters {
			switch request.bodyType {
			case .formData:
				// creating the query string
				let getParameters = parameters.map() { (key, value) -> String in
					if let array = value as? [Any] {
						// for arrays, the string should be for example:
						// order[]=intl_title&order[]=publication
						let values = array.map() { "\(key)[]=\($0)" }
						return values.joined(separator: "&")
					}
					else {
						return "\(key)=\(value)"
					}
				}
				let queryString = getParameters.joined(separator: "&")
				
				switch request.method {
				case .GET, .DELETE:
					// including GET parameters directly in URL
					var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
					components?.query = queryString
					completeUrl = components?.url ?? url
					body = .none
				
				case .POST, .PUT:
					// including parameters in body, as x-www-form-urlencoded
					completeUrl = url
					body = queryString.data(using: String.Encoding.utf8)
				}
				
			case .rawJson:
				completeUrl = url
				body = try? JSONSerialization.data(withJSONObject: request.parameters ?? [:], options: [])
			}
		}
		else {
			completeUrl = url
			body = .none
		}
		
		// Configure headers
		var headers = request.headers
		if let authHeaders = configuration.apiAuthenticator?.authenticationHeader(withUrl: completeUrl, body: body) {
			// adds auth headers into headers
			authHeaders.forEach { _ = headers?.updateValue($1, forKey: $0) }
		}
		
		service.request(url: completeUrl, method: request.method, body: body, headers: headers, success: { data in
			switch request {
				
			// The request was asking a Data object (such as an image)
			case _ as BackendAPIDataRequest:
				guard let returnedData = data else {
					DispatchQueue.main.async {
						failure?(.none, .unreadableResponse, 0)
					}
					return
				}
				DispatchQueue.main.async {
					success(returnedData)
				}
			// The request was asking a String object (such as HTML string)
			case _ as BackendAPIHTMLRequest:
				guard let returnedData = data,
					let htmlString = String.init(data: returnedData, encoding: .utf8)
					else {
						DispatchQueue.main.async {
							failure?(.none, .unreadableResponse, 0)
						}
						return
				}
				DispatchQueue.main.async {
					success(htmlString)
				}
			// The request was asking a [String: Any] object
			case let objectRequest as BackendAPIObjectRequest:
				var json: Any? = .none
				if let data = data {
					json = try? JSONSerialization.jsonObject(with: data, options: [])
				}
				guard let dic = json as? [String: Any] else {
					DispatchQueue.main.async {
						failure?(.none, .unreadableResponse, 0)
					}
					return
				}
				if let objectKey = objectRequest.objectKey {
                    guard let objectDic: Any = dic.key(objectKey) else {
						DispatchQueue.main.async {
							failure?(.none, .unreadableResponse, 0)
						}
						return
					}
					DispatchQueue.main.async {
						success(objectDic)
					}
				}
				else {
					DispatchQueue.main.async {
						success(dic)
					}
				}
			default:
				DispatchQueue.main.async {
					failure?(.none, .unreadableResponse, 0)
				}
			}
		}, failure: { data, error, statusCode in
			var json: Any? = .none
			if let data = data {
				json = try? JSONSerialization.jsonObject(with: data, options: [])
			}
			DispatchQueue.main.async {
				failure?(json as? [String: Any], error, statusCode)
			}
		})
	}
	
	public func cancel() {
		service.cancel()
	}
}

/// BackendAPIAuth is used to sign the request and send the result of the signature un headers
/// BackendAPIAuth can handle a OAuth bearer
public protocol BackendAPIAuth {
	
	func authenticationHeader(withUrl url: URL) -> [String: String]
	
	func authenticationHeader(withUrl url: URL, body postData: Data?) -> [String: String]
}

public struct OAuthBearerAPIAuth: BackendAPIAuth {
    let token: String
    
    public init(token: String) {
        self.token = token
    }
    
    public func authenticationHeader(withUrl url: URL) -> [String: String] {
        ["Authorization": "Bearer \(token)"]
    }
    
    public func authenticationHeader(withUrl url: URL, body postData: Data?) -> [String: String] {
        authenticationHeader(withUrl: url)
    }
    
}
