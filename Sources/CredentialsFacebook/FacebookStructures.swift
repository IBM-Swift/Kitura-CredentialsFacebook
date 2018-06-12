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

/// The subject's age range.
public struct FacebookAgeRange: Codable {
    let min: Int?
    let max: Int?
}

/// Information on the subject's friends. Note that only friends of this user that
/// have also granted this permission to the same OAuth application will be detailed.
public struct FacebookFriends: Codable {
    struct FriendSummary: Codable {
        let total_count: Int
    }
    let data: [String]
    let summary: FacebookFriends.FriendSummary
}

/// Information about the subject's home town.
public struct FacebookHometown: Codable {
    let id: String
    let name: String
}

/// The subject's location (current city) as specified on their profile.
public struct FacebookLocation: Codable {
    let id: String
    let name: String
}

/// Information about items the subject has 'liked'.
public struct FacebookLikes: Codable {
    struct FacebookLike: Codable {
        let name: String
        let id: String
        let created_time: String
    }
    let data: [FacebookLikes.FacebookLike]
    let paging: FacebookPaging?
}

/// Metadata about the subject's photos, which can be used to access the photos via the User API:
/// https://developers.facebook.com/docs/graph-api/reference/user/photos
public struct FacebookPhotos: Codable {
    struct FacebookPhoto: Codable {
        let created_time: String
        let id: String
        let name: String?
    }
    let data: [FacebookPhotos.FacebookPhoto]
    let paging: FacebookPaging?
}

/// Data from the subject's timeline, including posts they have created and been tagged in.
public struct FacebookPosts: Codable {
    struct FacebookPost: Codable {
        let message: String?
        let created_time: String?
        let id: String?
    }
    let data: [FacebookPosts.FacebookPost]
    let paging: FacebookPostsPaging?
}

/// A list of places that the subject has been tagged at.
public struct FacebookTaggedPlaces: Codable {
    struct FacebookLocation: Codable {
        let city: String?
        let country: String?
        let latitude: Double?
        let longitude: Double?
        let state: String?
        let street: String?
        let zip: String?
    }
    struct FacebookPlace: Codable {
        let id: String
        let name: String?
        let location: FacebookTaggedPlaces.FacebookLocation?
    }
    struct FacebookTaggedPlace: Codable {
        let id: String
        let created_time: String?
        let place: FacebookTaggedPlaces.FacebookPlace?
    }
    let data: [FacebookTaggedPlaces.FacebookTaggedPlace]
    let paging: FacebookPaging
}

/// Data allowing further retrieval of paginated data.
public struct FacebookPaging: Codable {
    struct Cursors: Codable {
        let before: String
        let after: String
    }
    let cursors: FacebookPaging.Cursors
    let next: String
}

/// Data allowing further retrieval of paginated timeline data.
public struct FacebookPostsPaging: Codable {
    let previous: String?
    let next: String?
}
