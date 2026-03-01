//
//  ErizouTests.swift
//
//
//  Created for ErizouTests
//

import XCTest
@testable import Erizou

// MARK: - Test Doubles

private struct MockEndpoint: Endpoint {
    var scheme: String = "https"
    var host: String = "api.example.com"
    var path: String = "/users"
    var subPath: String? = nil
    var method: RequestMethod = .get
    var header: [String: String]? = ["Content-Type": "application/json"]
    var token: String? = nil
    var body: [String: String]? = nil
    var queryItems: [(name: String, value: String)]? = nil
}

private struct MockService: HTTPClient {
    let urlSession: URLSession
}

private struct User: Codable, Equatable {
    let id: Int
    let name: String
}

// MARK: - Tests

final class ErizouTests: XCTestCase {

    private var service: MockService!

    override func setUp() {
        super.setUp()
        service = MockService(urlSession: .mock)
    }

    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    // MARK: - sendRequest

    func test_sendRequest_200_decodesResponse() async throws {
        let expectedUser = User(id: 1, name: "Achraf")
        let data = try JSONEncoder().encode(expectedUser)
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, data)
        }

        let result: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
        XCTAssertEqual(result, expectedUser)
    }

    func test_sendRequest_200_nilModel_returnsNil() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }

        let result: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: nil)
        XCTAssertNil(result)
    }

    func test_sendRequest_200_invalidJSON_throwsDecode() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data("invalid json".utf8))
        }

        do {
            let _: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected decode error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .decode)
        }
    }

    func test_sendRequest_401_throwsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        do {
            let _: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected unauthorized error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    func test_sendRequest_500_throwsUnexpectedStatusCode() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        do {
            let _: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected unexpectedStatusCode error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unexpectedStatusCode)
        }
    }

    func test_sendRequest_networkFailure_throwsUnknown() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        do {
            let _: User? = try await service.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected unknown error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unknown)
        }
    }

    func test_sendRequest_invalidURL_throwsInvalidURL() async throws {
        var endpoint = MockEndpoint()
        // A scheme with spaces is invalid and causes URLComponents.url to return nil
        endpoint.scheme = "not valid"

        do {
            let _: User? = try await service.sendRequest(endpoint: endpoint, responseModel: User.self)
            XCTFail("Expected invalidURL error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .invalidURL)
        }
    }

    // MARK: - RequestError.customMessage

    func test_requestError_decodeMessage() {
        XCTAssertEqual(RequestError.decode.customMessage, "Decode error")
    }

    func test_requestError_unauthorizedMessage() {
        XCTAssertEqual(RequestError.unauthorized.customMessage, "Session expired")
    }

    func test_requestError_unknownMessage() {
        XCTAssertEqual(RequestError.unknown.customMessage, "Unknown error")
    }

    // MARK: - RequestMethod

    func test_requestMethod_rawValues() {
        XCTAssertEqual(RequestMethod.get.rawValue, "GET")
        XCTAssertEqual(RequestMethod.post.rawValue, "POST")
        XCTAssertEqual(RequestMethod.put.rawValue, "PUT")
        XCTAssertEqual(RequestMethod.patch.rawValue, "PATCH")
        XCTAssertEqual(RequestMethod.delete.rawValue, "DELETE")
    }
}

// MARK: - Equatable conformance for testing

extension RequestError: Equatable {
    public static func == (lhs: RequestError, rhs: RequestError) -> Bool {
        switch (lhs, rhs) {
        case (.decode, .decode),
             (.invalidURL, .invalidURL),
             (.noResponse, .noResponse),
             (.unauthorized, .unauthorized),
             (.unexpectedStatusCode, .unexpectedStatusCode),
             (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}
