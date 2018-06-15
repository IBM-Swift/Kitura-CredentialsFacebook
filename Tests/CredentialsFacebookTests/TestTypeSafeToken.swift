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
import LoggerAPI

@testable import CredentialsFacebook

class TestTypeSafeToken : XCTestCase {

    static var allTests : [(String, (TestTypeSafeToken) -> () throws -> Void)] {
        return [
            ("testDefaultTokenProfile", testDefaultTokenProfile),
            ("testMinimalTokenProfile", testMinimalTokenProfile),
            ("testFieldNameFilter", testFieldNameFilter),
            ("testOverrideFieldNameFilter", testOverrideFieldNameFilter),
            ("testCache", testCache),
            ("testTwoInCache", testTwoInCache),
            ("testCachedProfile", testCachedProfile),
            ("testMissingTokenType", testMissingTokenType),
            ("testMissingAccessToken", testMissingAccessToken),
        ]
    }

    override func tearDown() {
        doTearDown()
    }
    
    // An example of a user-defined FacebookToken profile.
    struct TestFacebookToken: TypeSafeFacebookToken, Equatable {
        // Fields that should be retrieved from Facebook
        var id: String
        var name: String
        var email: String?
        
        // Fields that should be ignored (not part of the Facebook API)
        var favouriteArtist: String?
        var favouriteNumber: Int?
        
        // Static configuration for this type
        static var appID: String = "123"

        // Testing requirement: Equatable
        static func == (lhs: TestFacebookToken, rhs: TestFacebookToken) -> Bool {
            return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.provider == rhs.provider
                && lhs.email == rhs.email
                && lhs.favouriteArtist == rhs.favouriteArtist
                && lhs.favouriteNumber == rhs.favouriteNumber
        }
    }
    
    struct TestFacebookTokenCustomFilter: TypeSafeFacebookToken, Equatable {
        // Fields that should be retrieved from Facebook
        var id: String
        var name: String
        var email: String?
        
        // Fields that should be ignored (not part of the Facebook API)
        var favouriteArtist: String?
        var favouriteNumber: Int?

        // Static configuration for this type
        static var appID: String = "123"
        
        // Override the field names for the Facebook response, specifically, omitting the
        // 'email' field that would be included by the default filter.
        static var validFieldNames: Set<String> = ["id", "name"]
        
        // Testing requirement: Equatable
        static func == (lhs: TestFacebookTokenCustomFilter, rhs: TestFacebookTokenCustomFilter) -> Bool {
            return lhs.id == rhs.id
                && lhs.name == rhs.name
                && lhs.provider == rhs.provider
                && lhs.email == rhs.email
                && lhs.favouriteArtist == rhs.favouriteArtist
                && lhs.favouriteNumber == rhs.favouriteNumber
        }
    }

    let token = "Test token"
    let token2 = "Test token 2"

    // A Facebook response JSON fragment. Some optional fields are present (email, age_range,
    // birthday, hometown). Other optional fields (gender, location, etc) are not provided.
    //
    // This data will be decoded into two types during these tests:
    // - an instance of FacebookTokenProfile, which is capable of representing all fields (plus some that are absent from this fragment)
    // - an instance of TestFacebookToken, which defines only 'id' and 'name'.
    let testFacebookResponse = """
    {\"name_format\":\"{first} {last}\",\"id\":\"12345678901234567\",\"age_range\":{\"min\":21},\"last_name\":\"Doe\",\"picture\":{\"data\":{\"url\":\"https://platform-lookaside.fbsbx.com/platform/profilepic/?asid=12345678901234567&height=50&width=50&ext=1234567890&hash=AaBbCcDdEeFfGgHh\",\"width\":50,\"height\":50}},\"email\":\"john_doe@invalid.com\",\"short_name\":\"John\",\"birthday\":\"01/01/1970\",\"hometown\":{\"id\":\"123456789012345\",\"name\":\"Chicago\"},\"name\":\"John Doe\",\"first_name\":\"John\"}
    """.data(using: .utf8)!

    let router = TestTypeSafeToken.setupCodableRouter()

    // Tests that the pre-constructed FacebookTokenProfile type maps correctly to the
    // JSON response retrieved from the Facebook user profile API.
    func testDefaultTokenProfile() {
        guard let profileInstance = FacebookTokenProfile.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to FacebookTokenProfile")
        }
        // An equivalent test profile, constructed directly.
        let testTokenProfile = FacebookTokenProfile(id: "12345678901234567", name: "John Doe", picture: FacebookPicture(data: FacebookPicture.Properties(url: "https://platform-lookaside.fbsbx.com/platform/profilepic/?asid=12345678901234567&height=50&width=50&ext=1234567890&hash=AaBbCcDdEeFfGgHh", height: 50, width: 50)), first_name: "John", last_name: "Doe", name_format: "{first} {last}", short_name: "John", middle_name: nil, email: "john_doe@invalid.com", age_range: FacebookAgeRange(min: 21, max: nil), birthday: "01/01/1970", friends: nil, gender: nil, hometown: FacebookPage(id: "123456789012345", name: "Chicago"), likes: nil, link: nil, location: nil, photos: nil, posts: nil, tagged_places: nil)

        XCTAssertEqual(profileInstance, testTokenProfile, "The reference FacebookTokenProfile instance did not match the instance decoded from the Facebook JSON response")
    }

    // Tests that a minimal TypeSafeFacebookToken can be decoded from the same Facebook
    // JSON response, and that it matches the content that we expect.
    func testMinimalTokenProfile() {
        guard let profileInstance = TestFacebookToken.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to FacebookTokenProfile")
        }
        let expectedProfile = TestFacebookToken(id: "12345678901234567", name: "John Doe", email: "john_doe@invalid.com", favouriteArtist: nil, favouriteNumber: nil)
        XCTAssertEqual(profileInstance, expectedProfile, "The reference TestFacebookToken instance did not match the instance decoded from the Facebook JSON response")
    }
    
    // Tests that we are able to filter out unwanted fields from our Facebook query. In this example
    // we are filtering out the 'favouriteArtist' and 'favouriteNumber' fields.
    func testFieldNameFilter() {
        let validFields = TestFacebookToken.decodeValidFields()
        // Note: Field names appear in declaration order
        XCTAssertEqual(validFields, "id,name,email")
    }

    // Tests that we can override the filter of field names that will be requested from Facebook.
    // In this example, we exclude the 'email' field that would otherwise be included by the default
    // filter.
    func testOverrideFieldNameFilter() {
        let validFields = TestFacebookTokenCustomFilter.decodeValidFields()
        XCTAssertEqual(validFields, "id,name")
    }
    
    // Tests that a profile can be saved and retreived from the cache
    func testCache() {
        guard let profileInstance = TestFacebookToken.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to FacebookTokenProfile")
        }
        TestFacebookToken.saveInCache(profile: profileInstance, token: token)
        guard let cacheProfile = TestFacebookToken.getFromCache(token: token) else {
            return XCTFail("Failed to get from cache")
        }
        XCTAssertEqual(cacheProfile, profileInstance, "retrieved different profile from cache")
    }

    // Tests that two different profiles can be saved and retreived from the cache
    func testTwoInCache() {
        guard let profileInstance1 = TestFacebookToken.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to TestFacebookToken")
        }
        guard let profileInstance2 = FacebookTokenProfile.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to FacebookTokenProfile")
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

    // Tests that a profile stored in the token cache can be retrieved and returned by a Codable
    // route that includes this middleware.
    func testCachedProfile() {
        guard let profileInstance = TestFacebookToken.decodeFacebookResponse(data: testFacebookResponse) else {
            return XCTFail("Facebook JSON response cannot be decoded to FacebookTokenProfile")
        }
        TestFacebookToken.saveInCache(profile: profileInstance, token: token)
        performServerTest(router: router) { expectation in
            // Note that currently, this request to /multipleHandlers will fail, as both handlers
            // are invoked and both write a JSON response body (which is itself invalid JSON).
            // If Codable routing in the future equates the writing of data with ending the
            // response, this would work.
            self.performRequest(method: "get", path: "/singleHandler", callback: {response in
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
                    XCTFail("Could not decode response: \(error)")
                }
                expectation.fulfill()
            }, headers: ["X-token-type" : "FacebookToken", "access_token" : self.token])
        }
    }

    // Tests that when a request to a Codable route that includes this middleware does not
    // contain the matching X-token-type header, the middleware skips authentication and a
    // second handler is instead invoked.
    func testMissingTokenType() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/multipleHandlers", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.OK, "HTTP Status code was \(String(describing: response?.statusCode))")
                do {
                    guard let body = try response?.readString(), let responseData = body.data(using: .utf8) else {
                        XCTFail("No response body")
                        return
                    }
                    let decoder = JSONDecoder()
                    let testResponse = try decoder.decode(TestFacebookToken.self, from: responseData)
                    let expectedResponse = TestFacebookToken(id: "123", name: "abc", email: "def", favouriteArtist: "ghi", favouriteNumber: 123)
                    XCTAssertEqual(testResponse, expectedResponse, "Response from second handler did not contain expected data")
                } catch {
                    XCTFail("Could not decode response: \(error)")
                }
                expectation.fulfill()
            }, headers: ["access_token" : self.token])
        }
    }

    // Tests that when a request to a Codable route that includes this middleware contains
    // the matching X-token-type header, but does not supply an access_token, the middleware
    // fails authentication and returns unauthorized.
    func testMissingAccessToken() {
        performServerTest(router: router) { expectation in
            self.performRequest(method: "get", path: "/multipleHandlers", callback: {response in
                XCTAssertNotNil(response, "ERROR!!! ClientRequest response object was nil")
                XCTAssertEqual(response?.statusCode, HTTPStatusCode.unauthorized, "HTTP Status code was \(String(describing: response?.statusCode))")
                expectation.fulfill()
            }, headers: ["X-token-type" : "FacebookToken"])
        }
    }

    static func setupCodableRouter() -> Router {
        let router = Router()
        PrintLogger.use(colored: true)

        router.get("/singleHandler") { (profile: TestFacebookToken, respondWith: (TestFacebookToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }

        router.get("/multipleHandlers") { (profile: TestFacebookToken, respondWith: (TestFacebookToken?, RequestError?) -> Void) in
            respondWith(profile, nil)
        }

        router.get("/multipleHandlers") { (respondWith: (TestFacebookToken?, RequestError?) -> Void) in
            respondWith(TestFacebookToken(id: "123", name: "abc", email: "def", favouriteArtist: "ghi", favouriteNumber: 123), nil)
        }

        return router
    }
}
