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

/// A protocol that a user's type can conform to representing a user authenticated using a
/// Facebook OAuth token.
public protocol TypeSafeFacebookToken: TypeSafeCredentials {

    // MARK: Instance fields
    
    /// The application-scoped ID field. Note that this field uniquely identifies a user
    /// wihin the context of the application represented by the token.
    var id: String { get }
    
    /// The subject's display name.
    var name: String { get }
    
    // MARK: Static configuration for the type
    
    /// The OAuth client id ('AppID') that tokens should correspond to. This value must be
    /// set to match the Facebook OAuth app that was used to issue the token. Tokens that
    /// are received but that do not match this value will be rejected.
    static var appID: String { get }
    
    /// A set of valid field names that can be requested from Facebook. A default set is
    /// implemented for you, however this property can be overridden if needed to customize
    /// or extend the set.
    static var validFieldNames: Set<String> { get }
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
        // the expected OAuth application: this is necessary because the ID returned by
        // facebook is application-scoped, and so in theory, a user could supply a token
        // issued by a different OAuth application that contains an ID that collides with
        // an existing ID issued in the scope of our application.
        validateAppID(token: token) { (validID) in
            guard validID else {
                // Reject any tokens that have not been issued by our OAuth application id (appID).
                Log.error("Failed to match Facebook recieved app ID to user defined app ID")
                return onFailure(nil, nil)
            }
            // Attempt to retrieve the subject's profile from Facebook.
            getTokenProfile(token: token, callback: { (tokenProfile) in
                guard let tokenProfile = tokenProfile else {
                    Log.error("Failed to retrieve Facebook profile for token")
                    return onFailure(nil, nil)
                }
                return onSuccess(tokenProfile)
            })
        }
    }
    
    /// Defines the list of valid fields that can be requested from Facebook.
    /// Source: https://developers.facebook.com/docs/facebook-login/permissions/v3.0#reference-extended-profile
    ///
    /// Note that this is for convenience and not an exhaustive list.
    public static var validFieldNames: Set<String> {
        return [
            // Default fields representing parts of a person's public profile. These can always be requested:
            "id", "first_name", "last_name", "name", "name_format", "picture", "short_name",
            // Optional fields that the user may not have provided within their profile:
            "middle_name", 
            // Optional fields that not need app review, but the user may decline to share the information:
            "email",
            // All other permissions require a facebook app review prior to use:
            "age_range", "birthday", "friends", "gender", "hometown", "likes", "link", "location", "photos", "posts", "tagged_places"
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
    
    private static func validateAppID(token: String, callback: @escaping (Bool) -> Void) {
        // Send the app id request to facebook
        let fbAppReq = HTTP.request("https://graph.facebook.com/app?access_token=\(token)") { response in
            // check you have recieved an app id from facebook which matches the app id you set
            var body = Data()
            guard let response = response,
                response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body),
                let appDictionary = try? JSONSerialization.jsonObject(with: body, options: []) as? [String : Any],
                Self.appID == appDictionary?["id"] as? String
                else {
                    return callback(false)
            }
            return callback(true)
        }
        fbAppReq.end()
    }
    
    private static func getTokenProfile(token: String, callback: @escaping (Self?) -> Void) {
        let fieldsInfo = decodeFields()
        let fbreq = HTTP.request("https://graph.facebook.com/me?access_token=\(token)&fields=\(fieldsInfo)") { response in
            // Check we have recieved an OK response from Facebook
            var body = Data()
            let decoder = JSONDecoder()
            guard let response = response else {
                Log.error("Request to facebook failed: response was nil")
                return callback(nil)
            }
            guard response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body)
            else {
                Log.error("Facebook request failed: statusCode=\(response.statusCode), body=\(String(data: body, encoding: .utf8) ?? "")")
                return callback(nil)
            }
            // Attempt to construct the user's type by decoding the Facebook response. This could
            // fail if the user has defined any additional, non-optional fields on their type.
            do {
                let selfInstance = try decoder.decode(Self.self, from: body)
                #if os(Linux)
                    let key = NSString(string: token)
                #else
                    let key = token as NSString
                #endif
                Self.usersCache.setObject(FacebookCacheElement(profile: selfInstance), forKey: key)
                return callback(selfInstance)
            } catch {
                Log.error("Failed to decode \(Self.self) from Facebook response, error=\(error)")
                Log.debug("Facebook response data: statusCode=\(response.statusCode), body=\(String(data: body, encoding: .utf8) ?? "")")
                return callback(nil)
            }
        }
        fbreq.end()
    }
    
    private static func getFromCache(token: String) -> Self? {
        #if os(Linux)
        let key = NSString(string: token)
        #else
        let key = token as NSString
        #endif
        let cacheElement = Self.usersCache.object(forKey: key)
        return cacheElement?.userProfile as? Self
    }
}
