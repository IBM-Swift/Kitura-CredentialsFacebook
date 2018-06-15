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

// A redundant import to separate comment blocks, allowing Jazzy to document the struct below.
import Foundation


/// A structure representing the metadata provided by the Facebook API corresponding
/// to a subject's profile picture. This includes the URL of the image and its width and height.
/// If you wish to retrieve this information, include `let picture: FacebookPicture` in your
/// user profile.
public struct FacebookPicture: Codable {
    /// Properties of a Facebook profile picture.
    public struct Properties: Codable {
        /// The URL from which the profile picture can be retrieved.
        public var url: String
        /// The height of the profile image, in pixels.
        public var height: Int
        /// The width of the profile image, in pixels.
        public var width: Int
    }
    /// Properties of the picture.
    public let data: FacebookPicture.Properties
}

/// Information about the subject's age range.
/// See: https://developers.facebook.com/docs/graph-api/reference/user/
public struct FacebookAgeRange: Codable {
    /// The subject's age range minimum bound. Their age will be greater than or equal to
    /// this value.
    public let min: Int?
    /// The subject's age range maximum bound. Their age will be less than or equal to
    /// this value.
    public let max: Int?
}

/// Information on the subject's friends. Note that only friends of this user that
/// have also granted this permission to the same OAuth application will be detailed.
public struct FacebookFriends: Codable {
    /// A summary of a subject's Facebook friends.
    public struct FriendSummary: Codable {
        /// The subject's total number of Facebook friends.
        let total_count: Int
    }
    /// A list of the subject's friends. Note that only friends of this user that
    /// have also granted this permission to the same OAuth application will be listed.
    public let data: [String]
    /// A summary of the subject's friends list.
    public let summary: FacebookFriends.FriendSummary
}

/// Information about a Facebook Page, which can represent (for example) a subject's
/// Hometown or selected Location.
/// See: https://developers.facebook.com/docs/graph-api/reference/page/
public struct FacebookPage: Codable {
    /// The unique identifier for the Facebook Page.
    public let id: String
    /// The name of the Page.
    public let name: String
}

/// Information about items the subject has 'liked'.
/// See: https://developers.facebook.com/docs/graph-api/reference/user/likes/
public struct FacebookLikes: Codable {
    /// A `FacebookPage`, but with an additional field indicating when a subject
    /// liked the Page.
    public struct FacebookLike: Codable {
        /// The name of the Page.
        public let name: String
        /// The unique identifier for the Facebook Page.
        public let id: String
        /// The time that the subject liked the Page.
        public let created_time: String?
    }
    /// A list of items that the subject has 'liked'.
    public let data: [FacebookLikes.FacebookLike]
    /// Enables access to paginated data.
    public let paging: CursorBasedPagination?
}

/// Metadata about the subject's photos, which can be used to access the photos via the User API.
/// See: https://developers.facebook.com/docs/graph-api/reference/user/photos/
public struct FacebookPhotos: Codable {
    /// Metadata relating to a Photo on Facebook.
    /// See: https://developers.facebook.com/docs/graph-api/reference/photo/
    public struct FacebookPhoto: Codable {
        /// The time this photo was published.
        public let created_time: String
        /// The unique id.
        public let id: String
        /// The caption that the subject provided for this photo (if any).
        public let name: String?
    }
    /// A list of Facebook Photo metadata.
    public let data: [FacebookPhotos.FacebookPhoto]
    /// Enables access to paginated data.
    public let paging: CursorBasedPagination?
}

/// Data from the subject's timeline, including posts they have created and been tagged in.
/// See: https://developers.facebook.com/docs/graph-api/reference/v3.0/user/feed
public struct FacebookPosts: Codable {
    /// Represents a post on Facebook.
    /// See: https://developers.facebook.com/docs/graph-api/reference/post/
    public struct FacebookPost: Codable {
        /// The status message in the post.
        public let message: String?
        /// The time the post was initially published.
        public let created_time: String?
        /// The unique id.
        public let id: String?
    }
    /// A list of Facebook Post metadata.
    public let data: [FacebookPosts.FacebookPost]
    /// Enables access to paginated data.
    public let paging: OffsetBasedPagination?
}

/// A list of places that the subject has been tagged at.
public struct FacebookTaggedPlaces: Codable {
    /// Information describing the Location of a Place.
    public struct FacebookLocation: Codable {
        /// The City within which this Location resides.
        public let city: String?
        /// The Country within which this Location resides.
        public let country: String?
        /// The latitude of this Location.
        public let latitude: Double?
        /// The longitude of this Location.
        public let longitude: Double?
        /// The State (or localized equivalent) within which this Location resides.
        public let state: String?
        /// The Street address of this Location.
        public let street: String?
        /// The Zip code (or localized equivalent) corresponding to this Location.
        public let zip: String?
    }
    /// A Facebook Page, representing a place with a location.
    /// See: https://developers.facebook.com/docs/graph-api/reference/page/
    public struct FacebookPlace: Codable {
        /// The unique identifier for the Facebook Page.
        public let id: String
        /// The name of the Place represented by this Facebook Page.
        public let name: String?
        /// The Location of the Place represented by this Facebook Page.
        public let location: FacebookTaggedPlaces.FacebookLocation?
    }
    /// Information associating the tagging of a Facebook Page that represents a Place.
    public struct FacebookTaggedPlace: Codable {
        /// The unique id.
        public let id: String
        /// The time at which the subject was tagged at this Place.
        public let created_time: String?
        /// The place at which the subject was tagged.
        public let place: FacebookTaggedPlaces.FacebookPlace?
    }
    /// A list of Tagged Places, representing places the subject has been tagged at.
    public let data: [FacebookTaggedPlaces.FacebookTaggedPlace]
    /// Enables access to paginated data.
    public let paging: CursorBasedPagination
}

/// Allows further retrieval of paginated data.
/// See: https://developers.facebook.com/docs/graph-api/using-graph-api/#paging
public struct CursorBasedPagination: Codable {
    /// A pair of Cursors that allow traversal through paginated data.
    public struct Cursors: Codable {
        /// The Cursor that points to the start of the page of data that has been returned.
        public let before: String
        /// The Cursor that points to the end of the page of data that has been returned.
        public let after: String
    }
    /// Cursors that allow traversal through the paginated data.
    public let cursors: CursorBasedPagination.Cursors
    /// The Graph API endpoint that will return the next page of data. If not set, then
    /// the current data represents the last page.
    public let next: String?
}

/// Allows further retrieval of paginated data.
/// See: https://developers.facebook.com/docs/graph-api/using-graph-api/#paging
public struct OffsetBasedPagination: Codable {
    /// The Graph API endpoint that will return the previous page of data. If not set,
    /// then the current data represents the first page.
    public let previous: String?
    /// The Graph API endpoint that will return the next page of data. If not set, then
    /// the current data represents the last page.
    public let next: String?
}
