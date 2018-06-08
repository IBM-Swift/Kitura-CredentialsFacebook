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
import XCTest

import Kitura
import KituraNet

@testable import CredentialsFacebook

class TestTypeSafeToken : XCTestCase {

    static var allTests : [(String, (TestTypeSafeToken) -> () throws -> Void)] {
        return [
            ("testCache", testCache),
            ("testTwoInCache", testTwoInCache),
            ("testCachedToken", testCachedToken),
            ("testMissingTokenType", testMissingTokenType),
            ("testMissingAccessToken", testMissingAccessToken),
        ]
    }

    override func tearDown() {
        doTearDown()
    }
    
    let token = "testToken"
    let token2 = "testToken2"
    let testTokenProfile = FacebookTokenProfile(id: "123", name: "test", picture: FacebookPicture(data: FacebookPicture.Properties(url: "https://www.kitura.io/", height: 50, width: 50)), first_name: "Joe", last_name: "Bloggs", name_format: "{first}{last}", short_name: "Jo", middle_name: nil, email: "Joe.Bloggs@gmail.com", age_range: FacebookAgeRange(min: 21, max: nil), birthday: nil, friends: FacebookFriends(data: [""], summary: FacebookFriends.FriendSummary(total_count: 100)), gender: "male", hometown: nil, likes: nil, link: nil, location: nil, photos: nil, posts: nil, tagged_places: nil)
    
    let router = TestTypeSafeToken.setupCodableRouter()

    func testCache() {
        guard let body = try? JSONEncoder().encode(testTokenProfile) else {
            return XCTFail("Failed to encode example profile")
        }
        guard let profileInstance = TestFacebookToken.constructSelf(body: body) else {
            return XCTFail("Failed to create example profile")
        }
        TestFacebookToken.saveInCache(profile: profileInstance, token: token)
        guard let cacheProfile = TestFacebookToken.getFromCache(token: token) else {
            return XCTFail("Failed to get from cache")
        }
        XCTAssertEqual(cacheProfile, profileInstance, "retrieved different profile from cache")
    }

    func testTwoInCache() {
        guard let body = try? JSONEncoder().encode(testTokenProfile) else {
            return XCTFail("Failed to encode example profile")
        }
        guard let profileInstance1 = TestFacebookToken.constructSelf(body: body) else {
            return XCTFail("Failed to create example profile")
        }
        guard let profileInstance2 = FacebookTokenProfile.constructSelf(body: body) else {
            return XCTFail("Failed to create example profile")
        }
        TestFacebookToken.saveInCache(profile: profileInstance1, token: token)
        FacebookTokenProfile.saveInCache(profile: profileInstance2, token: token2)
        guard let cacheProfile1 = TestFacebookToken.getFromCache(token: token) else {
            return XCTFail("Failed to get from cache")
        }
        guard let cacheProfile2 = FacebookTokenProfile.getFromCache(token: token2) else {
            return XCTFail("Failed to get from cache")
        }
        XCTAssertEqual(cacheProfile1, profileInstance1, "retrieved different profile from cache1")
        XCTAssertEqual(cacheProfile2, profileInstance2, "retrieved different profile from cache2")
    }
    
    func testCachedToken() {
        guard let body = try? JSONEncoder().encode(testTokenProfile) else {
            return XCTFail("Failed to encode example profile")
        }
        guard let profileInstance = TestFacebookToken.constructSelf(body: body) else {
            return XCTFail("Failed to create example profile")
        }
        TestFacebookToken.saveInCache(profile: profileInstance, token: token)
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path:"typeSafeToken", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
                do {
                    guard let body = try response?.readString(), let tokenData = body.data(using: .utf8) else {
                        XCTFail("No response body")
                        return
                    }
                    let decoder = JSONDecoder()
                    let profile = try decoder.decode(TestFacebookToken.self, from: tokenData)
                    XCTAssertEqual(profile, profileInstance, "Body \(profile) is not equal to \(profileInstance)")
                } catch {
                    XCTFail("No response body")
                }
                expectation.fulfill()
            }, headers: ["X-token-type" : "FacebookToken", "access_token" : self.token])
        }
    }
    
    func testMissingTokenType() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path:"multiTypeSafeToken", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
                do {
                    guard let body = try response?.readString(), let userData = body.data(using: .utf8) else {
                        XCTFail("No response body")
                        return
                    }
                    let decoder = JSONDecoder()
                    let profile = try decoder.decode(User.self, from: userData)
                    XCTAssertEqual(profile.id, "123", "Body \(profile.id) is not equal to 123")
                } catch {
                    XCTFail("No response body")
                }
                expectation.fulfill()
            }, headers: ["access_token" : self.token])
        }
    }
    
    func testMissingAccessToken() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path:"multiTypeSafeToken", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.unauthorized, "HTTP Status code was \(String(describing: response?.statusCode))")
                expectation.fulfill()
            }, headers: ["X-token-type" : "FacebookToken"])
        }
    }

    struct TestFacebookToken: TypeSafeFacebookToken, Equatable {
        var id: String
        
        var name: String
        
        static var appID: String = "123"
        
        static func == (lhs: TestFacebookToken, rhs: TestFacebookToken) -> Bool {
            return lhs.id == rhs.id && lhs.name == rhs.name && lhs.provider == rhs.provider
        }
        
    }
   
    static func setupCodableRouter() -> Router {
        let router = Router()
        
        router.get("/typeSafeToken") { (profile: TestFacebookToken, respondWith: (TestFacebookToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }
        
        router.get("/multiTypeSafeToken") { (profile: TestFacebookToken, respondWith: (TestFacebookToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }
        router.get("/multiTypeSafeToken") { (respondWith: (User?, RequestError?) -> Void) in
            respondWith(User(id: "123"), nil)
        }
        
        return router
    }
    
    struct User: Codable {
        let id: String
    }
}

extension FacebookTokenProfile: Equatable {
    public static func == (lhs: FacebookTokenProfile, rhs: FacebookTokenProfile) -> Bool {
        return lhs.id == rhs.id && lhs.name == rhs.name && lhs.provider == rhs.provider
    }
}
