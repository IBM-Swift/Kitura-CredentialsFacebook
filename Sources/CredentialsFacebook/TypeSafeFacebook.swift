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

import Foundation
import KituraNet
import Credentials
import LoggerAPI
import TypeDecoder

/// A protocol that defines common attributes of Facebook authentication methods.
///
/// It is not intended for a user's type to conform to this protocol directly. Instead,
/// your type should conform to a specific authentication type, such as
/// `TypeSafeFacebookToken`.
public protocol TypeSafeFacebook: TypeSafeCredentials {
    /// The OAuth client id ('AppID') that tokens should correspond to. This value should be
    /// set to match the Facebook OAuth app that was used to issue the token. Tokens that
    /// do not match this value will be rejected.
    /// If you do not specify a value for appID, then the appID will not be verified and all
    /// tokens will be accepted, regardless of which app they are associated with.
    static var appID: String? { get }

    /// A set of valid field names that can be requested from Facebook. A default set is
    /// implemented for you, however this property can be overridden to customize or
    /// extend the set.
    static var validFieldNames: Set<String> { get }
}

extension TypeSafeFacebook {
    /// Provides a default provider name of `Facebook`.
    public var provider: String {
        return "Facebook"
    }

    /// Defines the list of valid fields that can be requested from Facebook.
    /// Source: https://developers.facebook.com/docs/facebook-login/permissions/v3.0#reference-default_fields
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

    /// Decodes the user's type using the TypeDecoder, in order to find the fields that we
    /// should request from Facebook on behalf of the user.
    ///
    /// After finding a shortlist of fields, we filter on the fields Facebook can provide,
    /// which is crucial because Facebook will return Bad Request if asked for anything
    /// other than the documented field names.
    static func decodeValidFields() -> String {
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

    /// Queries the Facebook App API to obtain the AppID used to issue a token, and
    /// verifies whether the AppID of the token matches the AppID associated with our
    /// type.
    /// - Parameter token: a Facebook OAuth token
    /// - Parameter callback: A callback that will be invoked with `true` if the
    ///   token matches our AppID, or false otherwise.
    static func validateAppID(token: String, callback: @escaping (Bool) -> Void) {
        guard let appID = Self.appID else {
            // User has not specified an appID - allow all tokens
            return callback(true)
        }
        // Send the app id request to facebook
        let fbAppReq = HTTP.request("https://graph.facebook.com/app?access_token=\(token)") { response in
            // check you have recieved an app id from facebook which matches the app id you set
            var body = Data()
            guard let response = response,
                response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body),
                let appDictionary = try? JSONSerialization.jsonObject(with: body, options: []) as? [String : Any],
                appID == appDictionary?["id"] as? String
                else {
                    return callback(false)
            }
            return callback(true)
        }
        fbAppReq.end()
    }

    /// Gets a subject's profile information from Facebook using an access token, and
    /// returns an instance of `Self`. The query to Facebook is generated by using the
    /// TypeDecoder to obtain a list of fields on our type, and then filtering out any
    /// that are not valid Facebook field names. The response from Facebook is then
    /// decoded using JSONDecoder.
    ///
    /// Failure could occur for two reasons:
    /// 1. If an invalid field name is sent to Facebook (ie. not filtered out). This could
    ///    occur if the user's type overrides the set of `validFieldNames`.
    /// 2. If the response from Facebook could not be decoded to our type. An example of
    ///    when failure might occur is if the user's type declares a field that the subject
    ///    declines to share as a non-optional type, for example: `let email: String`.
    ///
    /// - Parameter token: a Facebook OAuth token
    /// - Parameter callback: A callback that will be invoked with an instance of `Self`
    ///   on success, or `nil` on failure.
    static func getFacebookProfile(token: String, callback: @escaping (Self?) -> Void) {
        let fieldsInfo = decodeValidFields()
        let fbreq = HTTP.request("https://graph.facebook.com/me?access_token=\(token)&fields=\(fieldsInfo)") { response in
            // Check we have recieved an OK response from Facebook
            guard let response = response else {
                Log.error("Request to facebook failed: response was nil")
                return callback(nil)
            }
            var body = Data()
            guard response.statusCode == HTTPStatusCode.OK,
                let _ = try? response.readAllData(into: &body)
                else {
                    Log.error("Facebook request failed: statusCode=\(response.statusCode), body=\(String(data: body, encoding: .utf8) ?? "")")
                    return callback(nil)
            }
            // Attempt to construct the user's type by decoding the Facebook response
            guard let profile = decodeFacebookResponse(data: body) else {
                Log.debug("Facebook response data: \(String(data: body, encoding: .utf8) ?? "")")
                return callback(nil)
            }
            return callback(profile)
        }
        fbreq.end()
    }

    /// Attempt to decode the JSON response from Facebook into an instance of `Self`.
    static func decodeFacebookResponse(data: Data) -> Self? {
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(Self.self, from: data)
        } catch {
            Log.error("Failed to decode \(Self.self) from Facebook response, error=\(error)")
            return nil
        }
    }

}
