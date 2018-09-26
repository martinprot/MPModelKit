//
//  OAuthManager.swift
//  MPModelKit
//
//  Created by Martin Prot on 14/09/2017.
//  Copyright © 2017 appricot. All rights reserved.
//

import Foundation
import SimpleKeychain

public enum OAuthError: Error {
	case cannotCreateOAuthUrl
	case refreshTokenNotFound
	case unreadableResponse
	case unknown
}

public class OAuthNotification: NSObject {
	@objc public static let authenticationDidChange = "kAuthenticationDidChange"
}

public extension Notification.Name {
	static let authenticationDidChange = Notification.Name(rawValue: OAuthNotification.authenticationDidChange)
}

public enum OAuthResult {
	case authenticated
	case authenticatedAnonymously
	case notAuthenticated(Error)
}

open class OAuthManager: NSObject {
	
	private struct KeychainDefaults {
		static let accessToken = "auth0-user-jwt"
		static let refreshToken = "auth0-user-refresh"
		static let expirationDate = "auth0-jwt-expiration"
		static let anonymousExpirationDate = "anonymous-token-expiration"
	}
	
	internal struct Defaults {
		static let accessToken = "access_token"
		static let refreshToken = "refresh_token"
		static let expirationInterval = "expires_in"
		static let error = "error"
	}
	
	internal let configuration: OAuthConfiguration
	
	public init(configuration: OAuthConfiguration) {
		self.configuration = configuration
	}
	
	@objc public init(clientId: String, clientSecret: String, baseURL: URL, loginPath: String, tokenPath: String, redirectUrl: String) {
		self.configuration = GenericOAuthConfiguration(clientId: clientId, clientSecret: clientSecret, baseURL: baseURL, loginPath: loginPath, tokenPath: tokenPath, redirectUrl: redirectUrl)
	}
	
	////////////////////////////////////////////////////////////////////////////
	// MARK: Computed properties
	////////////////////////////////////////////////////////////////////////////
	
	@objc public private(set) var token: String? {
		didSet {
			let keychain = A0SimpleKeychain()
			if let token = self.token {
				keychain.setString(token, forKey: KeychainDefaults.accessToken)
			}
			else {
				keychain.deleteEntry(forKey: KeychainDefaults.accessToken)
				keychain.deleteEntry(forKey: KeychainDefaults.refreshToken)
			}
		}
	}
	
	@objc public private(set) var anonymousToken: String?
	
	@objc public var isAuthenticated: Bool {
		return self.token != nil
	}
	
	/// Returns the login url to use with a webview
	@objc public var loginURL: URL? {
		let encodedURLString = self.configuration.redirectUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
		
		let loginPath: String
		if self.configuration.loginPath.first == "/" {
			loginPath = self.configuration.loginPath
		}
		else {
			loginPath = "/\(self.configuration.loginPath)"
		}
		
		var components = URLComponents()
		components.scheme = self.configuration.baseURL.scheme
		components.host = self.configuration.baseURL.host
		components.path = loginPath
		let clientId = URLQueryItem(name: "client_id", value: self.configuration.clientId)
		let clientSecret = URLQueryItem(name: "client_secret", value: self.configuration.clientSecret)
		let grantType = URLQueryItem(name: "grant_type", value: "client_credentials")
		let redirectUri = URLQueryItem(name: "redirect_uri", value: encodedURLString)
		let responseType = URLQueryItem(name: "response_type", value: "code")
		components.queryItems = [clientId, clientSecret, grantType, redirectUri, responseType]
		return components.url
	}
	
	////////////////////////////////////////////////////////////////////////////
	// MARK: Methods
	////////////////////////////////////////////////////////////////////////////
	
	/// Tells if the token should be refreshed
	///
	/// - Returns: true or false
	@objc public func shouldRefreshToken() -> Bool {
		guard let date = UserDefaults.standard.value(forKey: KeychainDefaults.expirationDate) as? Date
			else { return true }
		
		let tokenWillExpireIn = date.timeIntervalSinceNow
		if tokenWillExpireIn > 0 {
			print("OAuth token will expire in \(tokenWillExpireIn) s.")
			return false
		}
		else { return true }
	}
	
	/// Tells if the anonymous token should be refreshed
	///
	/// - Returns: true or false
	@objc public func shouldRefreshAnonymousToken() -> Bool {
		guard self.anonymousToken != nil,
			let date = UserDefaults.standard.value(forKey: KeychainDefaults.anonymousExpirationDate) as? Date
			else { return true }
		let tokenExpirationInterval = date.timeIntervalSinceNow
		if tokenExpirationInterval > 0 {
			print("Anonymous token will expire in \(tokenExpirationInterval) s.")
			return false
		}
		else {
			return true
		}
	}
	
	/// Loads the token from the keychain and return true if succeed
	///
	/// - Returns: true of false, weither it suceeded
	@objc public func recoverTokenFromKeychain() -> Bool {
		guard let token = A0SimpleKeychain().string(forKey: KeychainDefaults.accessToken),
			token.count > 0
			else { return false }
		self.token = token
		return true
	}
	
	/// Stores the token, anonymous token and the token expiration date
	///
	/// - Parameter parameters: a dictionary conaining part of the 3 above objects
	internal func storeToken(with parameters: [String: Any]) {
		guard let token = parameters[Defaults.accessToken] as? String else { return }
		self.token = token
		let keychain = A0SimpleKeychain()
		if let refreshToken = parameters[Defaults.refreshToken] as? String {
			keychain.setString(refreshToken, forKey: KeychainDefaults.refreshToken)
		}
		// compute expiration date
		if let expiration = parameters[Defaults.expirationInterval] as? TimeInterval {
			let expirationDate = Date(timeIntervalSinceNow: expiration)
			UserDefaults.standard.set(expirationDate, forKey: KeychainDefaults.expirationDate)
			UserDefaults.standard.synchronize()
		}
		NotificationCenter.default.post(name: .authenticationDidChange, object: nil, userInfo: [Defaults.accessToken: token])
	}
	
	/// Log user out by deleting its token
	@objc public func disconnect() {
		self.token = .none
		
		self.getAnonymousToken { _ in
			NotificationCenter.default.post(name: .authenticationDidChange, object: nil)
		}
	}
	
	/// Returns the parameter list in parameter, augmented with the current access token, if any
	///
	/// - Parameter parameters: the parameter list to return with an added token
	/// - Returns: the given parameter list with an added token
	@objc public func authenticatedParameters(_ parameters: [String: Any]? = .none) -> [String: Any] {
		if let parameters = parameters {
			var paramsWithToken = parameters
			if let token = self.token {
				paramsWithToken[Defaults.accessToken] = token
			}
			else if let anonymousToken = self.anonymousToken {
				paramsWithToken[Defaults.accessToken] = anonymousToken
			}
			else {
				print("[OAuth] no token available")
			}
			return paramsWithToken
		}
		else {
			return self.tokenParameter
		}
	}
	
	private var tokenParameter: [String: String] {
		if let token = self.token {
			return [Defaults.accessToken : token]
		}
		else if let anonymousToken = self.anonymousToken {
			return [Defaults.accessToken : anonymousToken]
		}
		else {
			return [:]
		}
	}
	
	////////////////////////////////////////////////////////////////////////////
	// MARK: Endpoints
	////////////////////////////////////////////////////////////////////////////
	
	@objc public func refreshToken(success: @escaping ()->()) {
		self.refreshToken(success: success, failed: nil)
	}
	
	/// Refreshes the current saved token and its expiration date
	///
	/// - Parameters:
	///   - success: callback if succeed
	///   - failed: callback if failed, with the error
	@objc public func refreshToken(success: @escaping ()->(), failed: ((Error)->())? = .none) {
		let keychain = A0SimpleKeychain()
		guard let refreshToken = keychain.string(forKey: KeychainDefaults.refreshToken)
			else {
				failed?(OAuthError.refreshTokenNotFound)
				return
		}
		let oauthRequest = OAuthAPIRequest(type: .refreshToken(token: refreshToken, redirectURI: self.configuration.redirectUrl), clientId: self.configuration.clientId, secret: self.configuration.clientSecret, endPoint: self.configuration.tokenUrl)
		let service = BackendService()
		service.fetch(request: oauthRequest, success: { result in
			guard let responseObject = result as? [String: Any]
				else {
					failed?(OAuthError.unreadableResponse)
					return
			}
			self.storeToken(with: responseObject)
			success()
			
		}, failure: { result, error, code in
			self.token = .none
			failed?(error)
		})
	}
	
	/// Refreshes the anonymous token
	///
	/// - Parameter callback: callback when finished, with an error if so.
	@objc public func getAnonymousToken(callback: @escaping (Error?)->()) {
		let oauthRequest = OAuthAPIRequest(type: .credentials, clientId: self.configuration.clientId, secret: self.configuration.clientSecret, endPoint: self.configuration.tokenUrl)
		let service = BackendService()
		service.fetch(request: oauthRequest, success: { result in
			guard let responseObject = result as? [String: Any],
				let anonymousToken = responseObject[Defaults.accessToken] as? String,
				let expirationInterval = responseObject[Defaults.expirationInterval] as? TimeInterval
				else {
					callback(OAuthError.unreadableResponse)
					return
			}
			self.anonymousToken = anonymousToken
			let date = Date(timeIntervalSinceNow: expirationInterval)
			UserDefaults.standard.setValue(date, forKey: KeychainDefaults.anonymousExpirationDate)
			callback(.none)
			
		}, failure: { result, error, code in
			print("Refresh token failure \(error)")
			self.anonymousToken = .none
			callback(error)
		})
	}
	
	/// logs with an email and a password
	///
	/// - Parameter callback: callback when finished, with an error if so.
	@objc public func authenticate(withLogin login: String, password: String, callback: @escaping (Error?)->()) {
		let oauthRequest = OAuthAPIRequest(type: .password(login: login, password: password), clientId: self.configuration.clientId, secret: self.configuration.clientSecret, endPoint: self.configuration.tokenUrl)
		let service = BackendService()
		service.fetch(request: oauthRequest, success: { result in
			guard let responseObject = result as? [String: Any],
				responseObject[Defaults.accessToken] != nil,
				responseObject[Defaults.expirationInterval] != nil,
				responseObject[Defaults.refreshToken] != nil
				else {
					callback(OAuthError.unreadableResponse)
					return
			}
			self.storeToken(with: responseObject)
			callback(.none)
			
		}, failure: { result, error, code in
			print("authentication failure \(error)")
			callback(error)
		})
	}
	
	/// logs with a third party oauth supplier
	///
	/// - Parameter callback: callback when finished, with an error if so.
	@objc public func authenticate(on service: String, parameters: [String: String], callback: @escaping (Error?)->()) {
		let oauthRequest = OAuthAPIRequest(type: .oauthService(service: service, parameters: parameters),
										   clientId: self.configuration.clientId,
										   secret: self.configuration.clientSecret,
										   endPoint: self.configuration.tokenUrl)
		let service = BackendService()
		service.fetch(request: oauthRequest, success: { result in
			guard let responseObject = result as? [String: Any],
				responseObject[Defaults.accessToken] != nil,
				responseObject[Defaults.expirationInterval] != nil,
				responseObject[Defaults.refreshToken] != nil
				else {
					callback(OAuthError.unreadableResponse)
					return
			}
			self.storeToken(with: responseObject)
			callback(.none)
			
		}, failure: { result, error, code in
			print("authentication failure \(error)")
			callback(error)
		})
	}
	
	/// Authenticates to the API with the token saved in keychain, or anonymously if none
	///
	/// - Parameter then: the callback with the authentication result
	public func authenticate(then: @escaping (OAuthResult)->()) {
		if self.recoverTokenFromKeychain() {
			if self.shouldRefreshToken() {
				print("OAuth token expired! Refreshing...")
				self.refreshToken(success: {
					// authenticated
					then(.authenticated)
					print("OAuth Refresh token success")
				}, failed: { error in
					print("OAuth Refresh token failure: \(error)")
					self.getAnonymousToken(callback: { error in
						if let error = error {
							print("Cannot get anonymous token: \(error)")
							// not authenticated
							then(.notAuthenticated(error))
						}
						else {
							// authenticated anonymously
							then(.authenticatedAnonymously)
						}
					})
				})
			}
			else {
				// (already) authenticated
				print("OAuth token still valid")
				then(.authenticated)
			}
		}
		else {
			// Not authenticated
			print("OAuth: not connected")
			self.getAnonymousToken(callback: { error in
				if let error = error {
					print("Cannot get anonymous token: \(error)")
					// not authenticated
					then(.notAuthenticated(error))
				}
				else {
					// authenticated anonymously
					then(.authenticatedAnonymously)
				}
			})
		}
	}
}

////////////////////////////////////////////////////////////////////////////
// MARK: OAuth API Request
////////////////////////////////////////////////////////////////////////////

internal class OAuthAPIRequest: BackendAPIObjectRequest {
	
	enum RequestType {
		case refreshToken(token: String, redirectURI: String)
		case authCode(code: String, redirectURI: String)
		case credentials
		case password(login: String, password: String)
		case oauthService(service: String, parameters: [String: String])
		
		var grantType: String {
			switch self {
			case .refreshToken:
				return "refresh_token"
			case .authCode:
				return "authorization_code"
			case .credentials:
				return "client_credentials"
			case .password:
				return "password"
			case .oauthService(let service, _):
				return service
			}
		}
	}
	
	let type: RequestType
	let clientId: String
	let clientSecret: String
	let endPoint: URL
	
	init(type: RequestType, clientId: String, secret: String, endPoint: URL) {
		self.type = type
		self.clientId = clientId
		self.clientSecret = secret
		self.endPoint = endPoint
	}
	
	/// Defines the api endpoint to use
	public var endpoint: String {
		get {
			return endPoint.absoluteString
		}
	}
	
	// Define what method
	// note: token endpoint in restful app should be POST, but it happens to find an API
	// that looks for GET request. If so, we would pass the method by dependency injection or something.
	public var method: NetworkService.Method { get { return .POST } }
	
	// The parameters to pass in
	public var parameters: [String: Any]? {
		get {
			switch self.type {
			case .refreshToken(token: let token, redirectURI: let uri):
				return ["client_id" : self.clientId,
						"client_secret" : self.clientSecret,
						"redirect_uri" : uri,
						"grant_type" : self.type.grantType,
						"refresh_token" : token]
			case .authCode(code: let code, redirectURI: let uri):
				return ["client_id" : self.clientId,
						"client_secret" : self.clientSecret,
						"redirect_uri" : uri,
						"grant_type" : self.type.grantType,
						"code" : code]
			case .credentials:
				return ["client_id" : self.clientId,
						"client_secret" : self.clientSecret,
						"grant_type" : self.type.grantType]
			case .password(login: let login, password: let password):
				return ["client_id" : self.clientId,
						"client_secret" : self.clientSecret,
						"grant_type" : self.type.grantType,
						"username" : login,
						"password" : password]
			case .oauthService(_, let parameters):
				return ["client_id" : self.clientId,
						"client_secret" : self.clientSecret,
						"grant_type" : self.type.grantType].merging(parameters) { a, b in return a }
			}
		}
	}
}
