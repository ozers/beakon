//
//  APIClient.swift
//  Beakon
//
//  Created by Ozer on 30.03.2026.
//

import Foundation
import os

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case rateLimited(retryAfter: Int?)
    case networkError(Error)
    case decodingError(Error)
    case httpError(statusCode: Int, body: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .unauthorized:
            return "Unauthorized — check your API key"
        case .rateLimited(let retryAfter):
            if let seconds = retryAfter {
                return "Rate limited — retry after \(seconds)s"
            }
            return "Rate limited"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Decoding error: \(error.localizedDescription)"
        case .httpError(let code, _):
            return "HTTP \(code)"
        }
    }
}

struct APIClient: Sendable {
    private let session: URLSession
    private let logger = Logger(subsystem: "com.beakon", category: "APIClient")

    init(session: URLSession = .shared) {
        self.session = session
    }

    func get<T: Decodable>(
        url: String,
        headers: [String: String] = [:],
        queryParams: [String: String] = [:],
        decoder: JSONDecoder = JSONDecoder()
    ) async throws -> T {
        guard var components = URLComponents(string: url) else {
            throw APIError.invalidURL
        }

        if !queryParams.isEmpty {
            components.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        guard let requestURL = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        #if DEBUG
        logger.debug("GET \(requestURL.absoluteString)")
        #endif

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.networkError(URLError(.badServerResponse))
        }

        #if DEBUG
        logger.debug("Response \(httpResponse.statusCode) — \(data.count) bytes")
        #endif

        switch httpResponse.statusCode {
        case 200..<300:
            break
        case 401:
            throw APIError.unauthorized
        case 429:
            let retryAfter = httpResponse.value(forHTTPHeaderField: "retry-after")
                .flatMap(Int.init)
            throw APIError.rateLimited(retryAfter: retryAfter)
        default:
            let body = String(data: data, encoding: .utf8)
            throw APIError.httpError(statusCode: httpResponse.statusCode, body: body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
