/**
 * Copyright IBM Corporation 2016
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 **/

import Kitura
import KituraNet
import LoggerAPI
import Credentials

import SwiftyJSON

import Foundation

// MARK CredentialsFacebookToken

/// Authentication using Facebook web login with OAuth.
/// See [Facebook's manual](https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow)
/// for more information.
public class CredentialsFacebook: CredentialsPluginProtocol {
    
    private var clientId: String
    
    private var clientSecret: String
    
    /// The URL that Facebook redirects back to.
    public var callbackUrl: String
    
    /// The name of the plugin.
    public var name: String {
        return "Facebook"
    }
    
    /// An indication as to whether the plugin is redirecting or not.
    public var redirecting: Bool {
        return true
    }
    
    /// User profile cache.
    public var usersCache: NSCache<NSString, BaseCacheElement>?
    
    private let fields: String?
    
    private let scope: String?
    
    private var delegate: UserProfileDelegate?

    /// A delegate for `UserProfile` manipulation.
    public var userProfileDelegate: UserProfileDelegate? {
        return delegate
    }

    /// Initialize a `CredentialsFacebook` instance.
    ///
    /// - Parameter clientId: The App ID of the app in the Facebook Developer dashboard.
    /// - Parameter clientSecret: The App Secret of the app in the Facebook Developer dashboard.
    /// - Parameter callbackUrl: The URL that Facebook redirects back to.
    /// - Parameter options: A dictionary of plugin specific options.
    public init(clientId: String, clientSecret: String, callbackUrl: String, options: [String:Any]?=nil) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
        if let scope = options?[CredentialsFacebookOptions.scope] as? [String] {
            self.scope = scope.joined(separator: ",")
        }
        else {
           scope = options?[CredentialsFacebookOptions.scope] as? String
        }
        if let fields = options?[CredentialsFacebookOptions.fields] as? [String] {
            self.fields = fields.joined(separator: ",")
        }
        else {
            fields = options?[CredentialsFacebookOptions.fields] as? String
        }
        delegate = options?[CredentialsFacebookOptions.userProfileDelegate] as? UserProfileDelegate
    }
    
    /// Authenticate incoming request using Facebook web login with OAuth.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize the
    ///                     authentication data in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public func authenticate(request: RouterRequest, response: RouterResponse,
                             options: [String:Any], onSuccess: @escaping (UserProfile) -> Void,
                             onFailure: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             onPass: @escaping (HTTPStatusCode?, [String:String]?) -> Void,
                             inProgress: @escaping () -> Void) {
        if let code = request.queryParameters["code"] {
            var requestOptions: [ClientRequest.Options] = []
            requestOptions.append(.schema("https://"))
            requestOptions.append(.hostname("graph.facebook.com"))
            requestOptions.append(.method("GET"))
            requestOptions.append(.path("/v2.3/oauth/access_token?client_id=\(clientId)&redirect_uri=\(callbackUrl)&client_secret=\(clientSecret)&code=\(code)"))
            var headers = [String:String]()
            headers["Accept"] = "application/json"
            requestOptions.append(.headers(headers))
            
            let requestForToken = HTTP.request(requestOptions) { fbResponse in
                if let fbResponse = fbResponse, fbResponse.statusCode == HTTPStatusCode.OK {
                    do {
                        var body = Data()
                        try fbResponse.readAllData(into: &body)
                        var jsonBody = JSON(data: body)
                        if let token = jsonBody["access_token"].string {
                            requestOptions = []
                            requestOptions.append(.schema("https://"))
                            requestOptions.append(.hostname("graph.facebook.com"))
                            requestOptions.append(.method("GET"))
                            var pathFields = ""
                            if let fields = self.fields {
                                pathFields = "&fields=" + fields
                            }
                            requestOptions.append(.path("/me?access_token=\(token)\(pathFields)"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            requestOptions.append(.headers(headers))
                            
                            let requestForProfile = HTTP.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse, profileResponse.statusCode == HTTPStatusCode.OK {
                                    do {
                                        body = Data()
                                        try profileResponse.readAllData(into: &body)
                                        jsonBody = JSON(data: body)
                                        if let dictionary = jsonBody.dictionaryObject,
                                            let userProfile = createUserProfile(from: dictionary, for: self.name) {
                                            if let delegate = self.delegate {
                                                delegate.update(userProfile: userProfile, from: dictionary)
                                            }
                                            onSuccess(userProfile)
                                            return
                                        }
                                    }
                                    catch {
                                        Log.error("Failed to read Facebook response")
                                    }
                                }
                                else {
                                    onFailure(nil, nil)
                                }
                            }
                            requestForProfile.end()
                        }
                    }
                    catch {
                        Log.error("Failed to read Facebook response")
                    }
                }
                else {
                    onFailure(nil, nil)
                }
            }
            requestForToken.end()
        }
        else {
            // Log in
            var scopeParameters = ""
            if let scope = scope {
                scopeParameters = "&scope=" + scope
            }
            do {
                try response.redirect("https://www.facebook.com/dialog/oauth?client_id=\(clientId)&redirect_uri=\(callbackUrl)&response_type=code\(scopeParameters)")
                inProgress()
            }
            catch {
                Log.error("Failed to redirect to Facebook login page")
            }
        }
    }
}
