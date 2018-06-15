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


/**
 A pre-constructed TypeSafeFacebookToken which contains the default fields plus examples
 of optional fields that can be requested from Facebook.
 See: https://developers.facebook.com/docs/facebook-login/permissions/v3.0#reference-default_fields

 Note that the Optional fields will only be initialized if the user's OAuth token grants
 access to the data, and many extended permissions require a Facebook app review prior
 to that app being allowed to request them.

 ### Usage Example: ###
 ```swift
 FacebookTokenProfile.appID = "yourAppID"
 router.get("/facebookProfile") { (user: FacebookTokenProfile, respondWith: (FacebookTokenProfile?, RequestError?) -> Void) in
    respondWith(user, nil)
 }
 ```
 */
public struct FacebookTokenProfile: TypeSafeFacebookToken {
    
    /// The OAuth client id ('AppID') that tokens should correspond to. This value must be
    /// set to match the Facebook OAuth app that was used to issue the token. Tokens that
    /// are received but that do not match this value will be rejected.
    ///
    /// When using the default `FacebookTokenProfile`, your application must set this value
    /// prior to use:
    /// ```swift
    ///     FacebookTokenProfile.appID = "<your OAuth client id>"
    /// ```
    public static var appID: String = ""

    /// The application-scoped ID field. Note that this field uniquely identifies a user
    /// wihin the context of the application represented by the token.
    public let id: String
    
    /// The subject's display name.
    public let name: String
    
    /// Metadata allowing access to the subject's profile picture.
    public let picture: FacebookPicture
    
    /// The subject's first name.
    public let first_name: String
    
    /// The subject's last name.
    public let last_name: String

    /// The subject's chosen name format, e.g.: `"{first} {last}"`.
    public let name_format: String
    
    /// The subject's chosen short name.
    public let short_name: String
    
    // MARK: Optional fields
    
    /// The subject's middle name.
    public let middle_name: String?
    
    /// The subject's e-mail address.
    public let email: String?
    
    // MARK: Protected fields
    
    /// The subject's age range.
    public let age_range: FacebookAgeRange?
    
    /// The subject's birthday, in the format `MM/DD/YYYY`.
    public let birthday: String?
    
    /// Information on the subject's friends. Note that only friends of this user that
    /// have also granted this permission to the same OAuth application will be detailed.
    public let friends: FacebookFriends?
    
    /// The subject's gender.
    public let gender: String?
    
    /// Information about the subject's home town.
    public let hometown: FacebookPage?
    
    /// Information about items the subject has 'liked'.
    public let likes: FacebookLikes?
    
    /// A link to the subject's profile for another user of the app.
    public let link: String?
    
    /// The subject's location (current city) as specified on their profile.
    public let location: FacebookPage?
    
    /// Metadata about the subject's photos, which can be used to access the photos via the User API:
    /// https://developers.facebook.com/docs/graph-api/reference/user/photos
    public let photos: FacebookPhotos?
    
    /// Data from the subject's timeline, including posts they have created and been tagged in.
    public let posts: FacebookPosts?
    
    /// A list of places that the subject has been tagged at.
    public let tagged_places: FacebookTaggedPlaces?

}


