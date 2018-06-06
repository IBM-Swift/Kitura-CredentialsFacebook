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

public protocol TypeSafeFacebookToken: TypeSafeCredentials {
    
    var id: String { get }
    
    var name: String { get }
        
}

// MARK FacebookCacheElement

/// The cache element for keeping facebook profile information.
public class FacebookCacheElement {
    /// The user profile information stored as `UserFacebookToken`.
    public var userProfile: TypeSafeFacebookToken
    
    /// Initialize a `FacebookCacheElement`.
    ///
    /// - Parameter profile: the `UserFacebookToken` to store.
    public init (profile: TypeSafeFacebookToken) {
        userProfile = profile
    }
}

// MARK FacebookPicture

/// A structure representing the metadata provided by the Facebook API corresponding
/// to a user's profile picture. This includes the URL of the image and its width and height.
/// If you wish to retrieve this information, include `let picture: FacebookPicture` in your
/// user profile.
public struct FacebookPicture: Codable {
    public struct Properties: Codable {
        public var url: String
        public var height: Int
        public var width: Int
    }
    public let data: FacebookPicture.Properties
}

// An internal type to hold the mapping from a user's type to an appropriate token cache.
//
// It is a workaround for the inability to define stored properties in a protocol extension.
//
// We use the `debugDescription` of the user's type (via `String(reflecting:)`) as the
// dictionary key.
private struct TypeSafeFacebookTokenCache {
    internal static var cacheForType: [String: NSCache<NSString, FacebookCacheElement>] = [:]
}

extension TypeSafeFacebookToken {

    // Associates a token cache with the user's type. This relieves the user from having to
    // declare a usersCache property on their conforming type.
    private static var usersCache: NSCache<NSString, FacebookCacheElement> {
        let key = String(reflecting: Self.self)
        if let usersCache = TypeSafeFacebookTokenCache.cacheForType[key] {
            return usersCache
        } else {
            let usersCache = NSCache<NSString, FacebookCacheElement>()
            TypeSafeFacebookTokenCache.cacheForType[key] = usersCache
            return usersCache
        }
    }

    /// Provides a default provider name of `Facebook`.
    public var provider: String {
        return "Facebook"
    }
    
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
    public static func authenticate(request: RouterRequest, response: RouterResponse, onSuccess: @escaping (Self) -> Void, onFailure: @escaping (HTTPStatusCode?, [String : String]?) -> Void, onSkip: @escaping (HTTPStatusCode?, [String : String]?) -> Void) {
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
                    if let response = response, response.statusCode == HTTPStatusCode.OK {
                        do {
                            print("facebook response ok: \(response.statusCode)")
                            var body = Data()
                            try response.readAllData(into: &body)
                            let decoder = JSONDecoder()
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
            onSkip(nil, nil)
        }
    }
    
    // Defines the list of valid fields that can be requested from Facebook.
    // Source: https://developers.facebook.com/docs/facebook-login/permissions/v3.0#reference-extended-profile
    private static var validFieldNames: Set<String> {
        return [
            // Default fields representing parts of a person's public profile. These can always be requested.
            "id", "first_name", "last_name", "middle_name", "name", "name_format", "picture", "short_name", "email",
            // The following permissions require approval prior to use in an app.
            // If you request these without approval, Facebook will send 400 "Bad Request"
            "groups_access_member_info", "user_age_range", "user_birthday", "user_events", "user_friends", "user_gender", "user_hometown", "user_likes", "user_link", "user_location", "user_photos", "user_posts", "user_tagged_places", "user_videos", "read_insights", "read_audience_network_insights"
            //
        ]
    }
    
    // Decodes the user's type using the TypeDecoder, in order to find the fields that we
    // should request from Facebook on behalf of the user.
    //
    // After finding a shortlist of fields, we filter on the fields Facebook can provide,
    // which is crucial because Facebook will return Bad Request if asked for anything
    // other than the documented field names.
    private static func decodeFields() -> String {
        var decodedString = [String]()
        if let fieldsInfo = try? TypeDecoder.decode(Self.self) {
            if case .keyed(_, let dict) = fieldsInfo {
                for (key, _) in dict {
                    decodedString.append(key)
                }
            }
        }
        return decodedString.filter(validFieldNames.contains).joined(separator: ",")
    }
}
