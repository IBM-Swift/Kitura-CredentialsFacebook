/**
 * Copyright IBM Corporation 2016
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

import Credentials

func createUserProfile(from facebookData: [String:Any], for provider: String) -> UserProfile? {
    if let id = facebookData["id"] as? String,
        let name = facebookData["name"] as? String {
        
        var userEmails: [UserProfile.UserProfileEmail]? = nil
        if let email = facebookData["email"] as? String {
            let userEmail = UserProfile.UserProfileEmail(value: email, type: "")
            userEmails = [userEmail]
        }
        
        var userName: UserProfile.UserProfileName? = nil
        if let familyName = facebookData["last_name"] as? String,
            let givenName = facebookData["first_name"] as? String {
            let middleName = (facebookData["middle_name"] as? String) ?? ""
            userName = UserProfile.UserProfileName(familyName: familyName, givenName: givenName, middleName: middleName)
        }
        
        var userPhotos: [UserProfile.UserProfilePhoto]? = nil
        if let photos = facebookData["picture"] as? [String:Any],
            let data = photos["data"] as? [String:Any],
            let photo = data["url"] as? String {
            let userPhoto = UserProfile.UserProfilePhoto(photo)
            userPhotos = [userPhoto]
        }
        return UserProfile(id: id, displayName: name, provider: provider, name: userName, emails: userEmails, photos: userPhotos)
    }
    return nil
}

