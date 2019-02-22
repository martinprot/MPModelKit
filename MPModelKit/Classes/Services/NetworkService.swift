//
//  NetworkService.swift
//  MPModelKit
//
//  Created by Martin Prot on 12/01/2017.
//  Copyright © 2017 appricot media. All rights reserved.
//

import Foundation

public enum NetworkServiceError: Error {
	
	case wrongURL
	case unreadableResponse
	
	case timeout
	case badRequest
	case unauthorized
	case forbidden
	case notFound
	case alreadyExists
	case unhandledError(Error)
	case unknownError(Int)
	
	internal init(statusCode: Int) {
		switch statusCode {
		case 0:
			self = .timeout
		case .badRequest:
			self = .badRequest
		case .unauthorized:
			self = .unauthorized
		case .forbidden:
			self = .forbidden
		case .notFound:
			self = .notFound
		case .alreadyExists:
			self = .alreadyExists
		default:
			self = .unknownError(statusCode)
		}
	}
}

/// some http error codes
internal extension Int {
	static let badRequest = 400
	static let unauthorized = 401
	static let forbidden = 403
	static let notFound = 404
	static let alreadyExists = 409
}


public class NetworkService {
	
	private var task: URLSessionDataTask?
	private var successCodes: Range<Int> = 200..<299
	private var failureCodes: Range<Int> = 400..<599
	
	public enum Method: String {
		case GET
		case POST
		case PUT
		case DELETE
	}
	
	
	/// Execute a REST request with the given parameters
	///
	/// - Parameters:
	///   - url: the server url
	///   - method: a method
	///   - params: the parameters to send
	///   - headers: some headers
	///   - success: closure to call on success
	///   - failure: closure to call on failure
	func request(url: URL, method: Method,
	             body: Data? = .none,
	             headers: [String: String]? = .none,
	             success: ((Data?) -> Void)? = .none,
				 failure: ((Data?, NetworkServiceError, Int) -> Void)? = .none) {
		var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 60.0)
		request.allHTTPHeaderFields = headers
		request.httpMethod = method.rawValue
		request.httpBody = body
		
		let session = URLSession.shared
		task = session.dataTask(with: request, completionHandler: { data, response, error in
			if let httpResponse = response as? HTTPURLResponse {
				// Log the serveur response
				if let unwrappedData = data, let responseString = String(data: unwrappedData, encoding: String.Encoding.utf8) {
					if responseString.hasPrefix("<!DOCTYPE html>") {
						print("\n\(httpResponse.statusCode)\nHTML content")
					}
					else {
						print("\n\(httpResponse.statusCode)\n\(responseString)")
					}
				}
				
				if self.successCodes.contains(httpResponse.statusCode) {
					success? (data)
				}
				else if self.failureCodes.contains(httpResponse.statusCode) {
					failure? (data, NetworkServiceError(statusCode: httpResponse.statusCode), httpResponse.statusCode)
				}
				else if let error = error {
					failure? (data, .unhandledError(error), httpResponse.statusCode)
				}
				else {
					failure? (data, .unknownError(0), httpResponse.statusCode)
				}
			}
			else {
				failure? (data, NetworkServiceError(statusCode: 0), 0)
			}
		})
		print("[\(method.rawValue)] \(url.absoluteString)")
		task?.resume()
	}
	
	func cancel() {
		task?.cancel()
	}
}
