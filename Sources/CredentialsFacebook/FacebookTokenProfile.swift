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


/// A pre-constructed TypeSafeFacebookToken which contains the default fields that can be
/// requested from Facebook.
/// See: https://developers.facebook.com/docs/facebook-login/permissions/v3.0#reference-default_fields
public struct FacebookTokenProfile: TypeSafeFacebookToken {
    
    public static var appID: String = ""

    /// The application-scoped ID field. Note that this field uniquely identifies a user
    /// wihin the context of the application represented by the token.
    public let id: String
    
    public let name: String
    
    public let picture: FacebookPicture
    
    public let email: String?

    public let first_name: String
    
    public let middle_name: String?
    
    public let last_name: String

    public let name_format: String

}
