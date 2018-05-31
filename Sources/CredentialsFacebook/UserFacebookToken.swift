/**
 * Copyright IBM Corporation 2018
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
import Foundation
import KituraContracts
import TypeDecoder

public protocol UserFacebookToken: TypeSafeCredentialsPluginProtocol, Codable {
    
    var id: String { get }
    
    var name: String { get }
    
    static var usersCache: NSCache<NSString, FacebookCacheElement> { get }

}

// MARK FacebookCacheElement

/// The cache element for keeping facebook profile information.
public class FacebookCacheElement {
    /// The user profile information stored as `UserFacebookToken`.
    public var userProfile: UserFacebookToken
    
    /// Initialize a `FacebookCacheElement`.
    ///
    /// - Parameter profile: the `UserFacebookToken` to store.
    public init (profile: UserFacebookToken) {
        userProfile = profile
    }
}

public struct FacebookPicture: Codable {
    public struct facebookData: Codable {
        public var url: String
    }
    public let data: facebookData
}

extension UserFacebookToken {
    
    /// Authenticate incoming request using Facebook OAuth token.
    ///
    /// - Parameter request: The `RouterRequest` object used to get information
    ///                     about the request.
    /// - Parameter response: The `RouterResponse` object used to respond to the
    ///                       request.
    /// - Parameter options: The dictionary of plugin specific options.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onPass: The closure to invoke when the plugin doesn't recognize
    ///                     the authentication token in the request.
    /// - Parameter inProgress: The closure to invoke to cause a redirect to the login page in the
    ///                     case of redirecting authentication.
    public static func authenticate(request: RouterRequest, response: RouterResponse, onSuccess: @escaping (Self) -> Void, onFailure: @escaping (HTTPStatusCode?, [String : String]?) -> Void, onPass: @escaping (HTTPStatusCode?, [String : String]?) -> Void, inProgress: @escaping () -> Void) {
        if let type = request.headers["X-token-type"], type == "FacebookToken" {
            if let token = request.headers["access_token"] {
                print("using facebook token authentication")
                #if os(Linux)
                let key = NSString(string: token)
                #else
                let key = token as NSString
                #endif
                let cacheElement = Self.usersCache.object(forKey: key)
                if let cacheProfile = cacheElement?.userProfile as? Self {
                    print("using cache: \(cacheProfile)")
                    onSuccess(cacheProfile)
                    return
                }
                let fieldsInfo = decodeFields()
                print("fieldsInfo: \(fieldsInfo)")
                var requestOptions: [ClientRequest.Options] = []
                requestOptions.append(.schema("https://"))
                requestOptions.append(.hostname("graph.facebook.com"))
                requestOptions.append(.method("GET"))
                requestOptions.append(.path("/me?access_token=\(token)&fields=\(fieldsInfo)"))
                var headers = [String:String]()
                headers["Accept"] = "application/json"
                requestOptions.append(.headers(headers))
                
                let fbreq = HTTP.request(requestOptions) { response in
                    print("got facebook response: \(String(describing: response)) status code: \(response?.statusCode)")
                    if let response = response, response.statusCode == HTTPStatusCode.OK {
                        do {
                            print("facebook response ok: \(response.statusCode)")
                            var body = Data()
                            try response.readAllData(into: &body)
                            let decoder = JSONDecoder()
                            // TODO: Remove JSONSerialization, only in for testing
                            let userDictionary = try JSONSerialization.jsonObject(with: body, options: []) as? [String : Any]
                            print("facebook response body: \(String(describing: userDictionary))")
                            if let selfInstance = try? decoder.decode(Self.self, from: body) {
                                #if os(Linux)
                                let key = NSString(string: token)
                                #else
                                let key = token as NSString
                                #endif
                                Self.usersCache.setObject(FacebookCacheElement(profile: selfInstance), forKey: key)
                                onSuccess(selfInstance)
                                return
                            }
                        } catch {
                            Log.error("Failed to read Facebook response")
                        }
                    }
                    onFailure(nil, nil)
                }
                fbreq.end()
            }
            else {
                onFailure(nil, nil)
            }
        }
        else {
            onPass(nil, nil)
        }
    }
    
    private static func decodeFields() -> String {
        var decodedString = [String]()
        if let fieldsInfo = try? TypeDecoder.decode(Self.self) {
            if case .keyed(_, let dict) = fieldsInfo {
                for (key, _) in dict {
                    decodedString.append(key)
                }
            }
        }
        return decodedString.joined(separator: ",")
    }
    
}
