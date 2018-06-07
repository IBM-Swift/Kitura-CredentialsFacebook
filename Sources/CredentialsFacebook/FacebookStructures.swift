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

public struct FacebookAgeRange: Codable {
    let min: Int?
    let max: Int?
}

public struct FacebookFriends: Codable {
    struct FriendSummary: Codable {
        let total_count: Int
    }
    let data: [String]
    let summary: FacebookFriends.FriendSummary
}

public struct FacebookHometown: Codable {
    let id: String
    let name: String
}

public struct FacebookLocation: Codable {
    let id: String
    let name: String
}

public struct FacebookLikes: Codable {
    struct FacebookLike: Codable {
        let name: String
        let id: String
        let created_time: String
    }
    let data: [FacebookLikes.FacebookLike]
    let paging: FacebookPaging?
}

public struct FacebookPhotos: Codable {
    struct FacebookPhoto: Codable {
        let created_time: String
        let id: String
        let name: String?
    }
    let data: [FacebookPhotos.FacebookPhoto]
    let paging: FacebookPaging?
}

public struct FacebookPosts: Codable {
    struct FacebookPost: Codable {
        let message: String?
        let created_time: String?
        let id: String?
    }
    let data: [FacebookPosts.FacebookPost]
    let paging: FacebookPostsPaging?
}

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

public struct FacebookPaging: Codable {
    struct Cursors: Codable {
        let before: String
        let after: String
    }
    let cursors: FacebookPaging.Cursors
    let next: String
}

public struct FacebookPostsPaging: Codable {
    let previous: String?
    let next: String?
}
