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
import TypeDecoder

/**
 A protocol that a user's type can conform to representing a user authenticated using a
 Facebook OAuth token.
 ### Usage Example: ###
 ```swift
 public struct ExampleProfile: TypeSafeFacebookToken {
    static var appID: String? = "yourAppID"     // The id of your Facebook App
    let id: String                              // Protocol requirement
    let name: String                            // Protocol requirement: subject's display name
    let email: String?                          // Optional Facebook field: may not be granted
 }
 router.get("/facebookProfile") { (user: ExampleProfile, respondWith: (ExampleProfile?, RequestError?) -> Void) in
    respondWith(user, nil)
 }
 ```
 A pre-defined `FacebookTokenProfile` type has been provided for use if you do not wish to
 define your own type, and provides an example of how to access the various structured data
 types (such as profile picture information) provided by the Facebook API.
 */
public protocol TypeSafeFacebookToken: TypeSafeFacebook {

    // MARK: Instance fields

    /// The application-scoped ID field. Note that this field uniquely identifies a user
    /// wihin the context of the application represented by the token.
    var id: String { get }

    /// The subject's display name.
    var name: String { get }

    // MARK: Static fields

    /// The maximum size of the in-memory token cache for this type. If not specified, then
    /// the cache has an unlimited size.
    static var cacheSize: Int { get }

}

/// The cache element for keeping facebook profile information.
private class FacebookCacheElement {
    /// The user profile information stored as `TypeSafeFacebookToken`.
    internal var userProfile: TypeSafeFacebookToken

    /// Initialize a `FacebookCacheElement`.
    ///
    /// - Parameter profile: the `TypeSafeFacebookToken` to store.
    internal init (profile: TypeSafeFacebookToken) {
        userProfile = profile
    }
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

    /// A default value for the cache size of `0`, which means that there is no limit on how
    /// many profiles the token cache can store.
    public static var cacheSize: Int {
        return 0
    }

    // Associates a profile cache with the user's type. This relieves the user from having to
    // declare a usersCache property on their conforming type.
    private static var usersCache: NSCache<NSString, FacebookCacheElement> {
        let key = String(reflecting: Self.self)
        if let usersCache = TypeSafeFacebookTokenCache.cacheForType[key] {
            return usersCache
        } else {
            let usersCache = NSCache<NSString, FacebookCacheElement>()
            Log.debug("Token cache size for \(key): \(cacheSize == 0 ? "unlimited" : String(describing: cacheSize))")
            usersCache.countLimit = cacheSize
            TypeSafeFacebookTokenCache.cacheForType[key] = usersCache
            return usersCache
        }
    }

    /// Authenticate an incoming request using a Facebook OAuth token. This type of
    /// authentication handles requests with a header of 'X-token-type: FacebookToken' and
    /// an appropriate OAuth token supplied via the 'access_token' header.
    ///
    /// _Note: this function has been implemented for you._
    ///
    /// - Parameter request: The `RouterRequest` object used to get information about the
    ///                      request.
    /// - Parameter response: The `RouterResponse` object used to respond to the request.
    /// - Parameter onSuccess: The closure to invoke in the case of successful authentication.
    /// - Parameter onFailure: The closure to invoke in the case of an authentication failure.
    /// - Parameter onSkip: The closure to invoke when the plugin doesn't recognize
    ///                     the authentication token in the request.
    public static func authenticate(request: RouterRequest, response: RouterResponse,
                                    onSuccess: @escaping (Self) -> Void,
                                    onFailure: @escaping (HTTPStatusCode?, [String : String]?) -> Void,
                                    onSkip: @escaping (HTTPStatusCode?, [String : String]?) -> Void) {
        // Check whether this request declares that a Facebook token is being supplied
        guard let type = request.headers["X-token-type"], type == "FacebookToken" else {
            return onSkip(nil, nil)
        }
        // Check whether a token has been supplied
        guard let token = request.headers["access_token"] else {
            return onFailure(nil, nil)
        }
        // Return a cached profile from the cache associated with our type, if one is found
        // (ie. if we have successfully authenticated this token before)
        if let cacheProfile = getFromCache(token: token) {
            return onSuccess(cacheProfile)
        }
        // Attempt to validate the supplied token. First check that the token was issued by
        // the expected OAuth application: this is recommended because the ID returned by
        // facebook is application-scoped. However, the user can choose to skip this and
        // accept any token by not specifying an appID on their type.
        validateAppID(token: token) { (validID) in
            guard validID else {
                // Reject any tokens that have not been issued by our OAuth application id (appID).
                Log.error("Failed to match Facebook recieved app ID to user defined app ID")
                return onFailure(nil, nil)
            }
            // Attempt to retrieve the subject's profile from Facebook.
            getFacebookProfile(token: token, callback: { (tokenProfile) in
                guard let tokenProfile = tokenProfile else {
                    Log.error("Failed to retrieve Facebook profile for token")
                    return onFailure(nil, nil)
                }
                saveInCache(profile: tokenProfile, token: token)
                return onSuccess(tokenProfile)
            })
        }
    }

    static func getFromCache(token: String) -> Self? {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        let cacheElement = Self.usersCache.object(forKey: key)
        return cacheElement?.userProfile as? Self
    }

    static func saveInCache(profile: Self, token: String) {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        Self.usersCache.setObject(FacebookCacheElement(profile: profile), forKey: key)
    }

}
