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

@testable import CredentialsFacebook

extension FacebookPage: Equatable {
    public static func == (lhs: FacebookPage, rhs: FacebookPage) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name
    }
}

extension FacebookAgeRange: Equatable {
    public static func == (lhs: FacebookAgeRange, rhs: FacebookAgeRange) -> Bool {
        return lhs.min == rhs.min && lhs.max == rhs.max
    }
}

extension FacebookPicture.Properties: Equatable {
    public static func == (lhs: FacebookPicture.Properties, rhs: FacebookPicture.Properties) -> Bool {
        return lhs.width == rhs.width && lhs.height == rhs.height && lhs.url == rhs.url
    }
}

extension FacebookPicture: Equatable {
    public static func == (lhs: FacebookPicture, rhs: FacebookPicture) -> Bool {
        return lhs.data == rhs.data
    }
}

extension FacebookTokenProfile: Equatable {
    public static func == (lhs: FacebookTokenProfile, rhs: FacebookTokenProfile) -> Bool {
        return lhs.id == rhs.id
            && lhs.name == rhs.name
            && lhs.provider == rhs.provider
            && lhs.age_range == rhs.age_range
            && lhs.birthday == rhs.birthday
            && lhs.first_name == rhs.first_name
            && lhs.gender == rhs.gender
            && lhs.hometown == rhs.hometown
            && lhs.last_name == rhs.last_name
            && lhs.link == rhs.link
            && lhs.middle_name == rhs.middle_name
            && lhs.name_format == rhs.name_format
            && lhs.picture == rhs.picture
            && lhs.short_name == rhs.short_name
            && lhs.provider == rhs.provider
        //&& lhs.location == rhs.location
        //&& lhs.friends == rhs.friends
        //&& lhs.likes == rhs.likes
        //&& lhs.photos == rhs.photos
        //&& lhs.posts == rhs.posts
        //&& lhs.tagged_places == rhs.tagged_places
    }
}

