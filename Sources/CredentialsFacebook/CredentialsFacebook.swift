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

public class CredentialsFacebook : CredentialsPluginProtocol {
    
    private var clientId : String
    
    private var clientSecret : String
    
    public var callbackUrl : String
    
    public var name : String {
        return "Facebook"
    }
    
    public var redirecting : Bool {
        return true
    }
    
    public init (clientId: String, clientSecret : String, callbackUrl : String) {
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.callbackUrl = callbackUrl
    }
    
#if os(OSX)
    public var usersCache : NSCache<NSString, BaseCacheElement>?
#else
    public var usersCache : Cache?
#endif
    
    
    /// https://developers.facebook.com/docs/facebook-login/manually-build-a-login-flow
    public func authenticate (request: RouterRequest, response: RouterResponse, options: [String:OptionValue], onSuccess: (UserProfile) -> Void, onFailure: (HTTPStatusCode?, [String:String]?) -> Void, onPass: (HTTPStatusCode?, [String:String]?) -> Void, inProgress: () -> Void) {
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
                            requestOptions.append(.path("/me?access_token=\(token)"))
                            headers = [String:String]()
                            headers["Accept"] = "application/json"
                            requestOptions.append(.headers(headers))
                            
                            let requestForProfile = HTTP.request(requestOptions) { profileResponse in
                                if let profileResponse = profileResponse, profileResponse.statusCode == HTTPStatusCode.OK {
                                    do {
                                        body = Data()
                                        try profileResponse.readAllData(into: &body)
                                        jsonBody = JSON(data: body)
                                        if let id = jsonBody["id"].string,
                                            let name = jsonBody["name"].string {
                                            let userProfile = UserProfile(id: id, displayName: name, provider: self.name)
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
            do {
                try response.redirect("https://www.facebook.com/dialog/oauth?client_id=\(clientId)&redirect_uri=\(callbackUrl)&response_type=code")
                inProgress()
            }
            catch {
                Log.error("Failed to redirect to Facebook login page")
            }
        }
    }
}
