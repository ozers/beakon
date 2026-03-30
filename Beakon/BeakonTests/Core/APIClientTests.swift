//
//  APIClientTests.swift
//  BeakonTests
//
//  Created by Ozer on 30.03.2026.
//

import Testing
import Foundation
@testable import Beakon

struct APIClientTests {

    @Test func buildURLWithQueryParams() async throws {
        // Verify URL construction by testing with a mock server would be ideal,
        // but we can at least verify the error types exist and are correct
        let client = APIClient()

        // Invalid URL should throw
        await #expect(throws: APIError.self) {
            let _: EmptyResponse = try await client.get(url: "not a url ://invalid")
        }
    }

    @Test func apiErrorDescriptions() {
        #expect(APIError.unauthorized.errorDescription?.contains("API key") == true)
        #expect(APIError.rateLimited(retryAfter: 30).errorDescription?.contains("30") == true)
        #expect(APIError.rateLimited(retryAfter: nil).errorDescription == "Rate limited")
        #expect(APIError.invalidURL.errorDescription == "Invalid URL")
    }
}

private struct EmptyResponse: Decodable {}
