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

// MARK CredentialsFacebookOptions

/// A list of options for authentication with Facebook.
public struct CredentialsFacebookOptions {
    /// [Facebook permissions](https://developers.facebook.com/docs/facebook-login/permissions)
    public static let scope = "scope"
    /// An implementation of `Credentials.UserProfileDelegate` to update user profile.
    public static let userProfileDelegate = "userProfileDelegate"
    /// A list of [fields](https://developers.facebook.com/docs/graph-api/reference/user) to ask for in authentication.
    public static let fields = "fields"
}
