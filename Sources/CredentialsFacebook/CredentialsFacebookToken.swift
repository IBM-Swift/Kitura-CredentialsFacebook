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

public class CredentialsFacebookToken : CredentialsPluginProtocol {

    public var name : String {
        return "FacebookToken"
    }

    public var redirecting : Bool {
        return false
    }

    public init () {}

#if os(OSX)
    public var usersCache : NSCache<NSString, BaseCacheElement>?
#else
    public var usersCache : Cache?
#endif

    public func authenticate (request: RouterRequest, response: RouterResponse, options: [String:OptionValue], onSuccess: (UserProfile) -> Void, onFailure: (HTTPStatusCode?, [String:String]?) -> Void, onPass: (HTTPStatusCode?, [String:String]?) -> Void, inProgress: () -> Void) {
        if let type = request.headers["X-token-type"], type == name {
            if let token = request.headers["access_token"] {
                let cacheElement = usersCache!.object(forKey: token.bridge())
                #if os(Linux)
                    if let cached = cacheElement as? BaseCacheElement {
                        onSuccess(cached.userProfile)
                        return
                    }
                #else
                    if let cached = cacheElement {
                        onSuccess(cached.userProfile)
                        return
                    }
                #endif

                var requestOptions: [ClientRequest.Options] = []
                requestOptions.append(.schema("https://"))
                requestOptions.append(.hostname("graph.facebook.com"))
                requestOptions.append(.method("GET"))
                requestOptions.append(.path("/me?access_token=\(token)"))
                var headers = [String:String]()
                headers["Accept"] = "application/json"
                requestOptions.append(.headers(headers))

                let req = HTTP.request(requestOptions) { response in
                    if let response = response, response.statusCode == HTTPStatusCode.OK {
                        do {
                            var body = Data()
                            try response.readAllData(into: &body)
                            let jsonBody = JSON(data: body)
                            if let id = jsonBody["id"].string,
                                let name = jsonBody["name"].string {
                                let userProfile = UserProfile(id: id, displayName: name, provider: self.name)
                                let newCacheElement = BaseCacheElement(profile: userProfile)
                                self.usersCache!.setObject(newCacheElement, forKey: token.bridge())
                                onSuccess(userProfile)
                                return
                            }
                        } catch {
                            Log.error("Failed to read Facebook response")
                        }
                    }
                    onFailure(nil, nil)
                }
                req.end()
            }
            else {
                onFailure(nil, nil)
            }
        }
        else {
            onPass(nil, nil)
        }
    }
}
