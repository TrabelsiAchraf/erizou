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
    var retryCount: Int = 0
    var retryDelay: TimeInterval = 0
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

    // MARK: - Retry

    func test_retry_succeedsAfterTransientFailure() async throws {
        let expectedUser = User(id: 99, name: "Retry")
        let userData = try JSONEncoder().encode(expectedUser)
        let callCount = CallCounter()

        MockURLProtocol.requestHandler = { _ in
            callCount.increment()
            if callCount.count < 3 {
                throw URLError(.notConnectedToInternet)
            }
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, userData)
        }

        // retryCount: 2 → up to 2 retries (3 total attempts)
        let retryService = MockService(urlSession: .mock, retryCount: 2, retryDelay: 0)
        let result: User? = try await retryService.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)

        XCTAssertEqual(result, expectedUser)
        XCTAssertEqual(callCount.count, 3)
    }

    func test_retry_exhaustedRetries_throwsUnknown() async throws {
        MockURLProtocol.requestHandler = { _ in
            throw URLError(.notConnectedToInternet)
        }

        let retryService = MockService(urlSession: .mock, retryCount: 1, retryDelay: 0)

        do {
            let _: User? = try await retryService.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected unknown error after retries exhausted")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unknown)
        }
    }

    func test_retry_doesNotRetryNonNetworkErrors() async throws {
        let callCount = CallCounter()
        MockURLProtocol.requestHandler = { _ in
            callCount.increment()
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        let retryService = MockService(urlSession: .mock, retryCount: 3, retryDelay: 0)

        do {
            let _: User? = try await retryService.sendRequest(endpoint: MockEndpoint(), responseModel: User.self)
            XCTFail("Expected unauthorized error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unauthorized)
            XCTAssertEqual(callCount.count, 1, "401 errors should not be retried")
        }
    }

    // MARK: - Upload (Data)

    func test_upload_data_200_decodesResponse() async throws {
        let expectedUser = User(id: 2, name: "Upload")
        let responseData = try JSONEncoder().encode(expectedUser)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }

        var endpoint = MockEndpoint()
        endpoint.method = .post
        let payload = try JSONEncoder().encode(expectedUser)
        let result: User? = try await service.upload(endpoint: endpoint, data: payload, responseModel: User.self)
        XCTAssertEqual(result, expectedUser)
    }

    func test_upload_data_401_throwsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        var endpoint = MockEndpoint()
        endpoint.method = .post

        do {
            let _: User? = try await service.upload(endpoint: endpoint, data: Data(), responseModel: User.self)
            XCTFail("Expected unauthorized error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unauthorized)
        }
    }

    // MARK: - Upload (File URL)

    func test_upload_fileURL_200_decodesResponse() async throws {
        let expectedUser = User(id: 3, name: "FileUpload")
        let responseData = try JSONEncoder().encode(expectedUser)

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/users")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, responseData)
        }

        // Write a temporary file to upload
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("upload_test.json")
        let fileData = try JSONEncoder().encode(expectedUser)
        try fileData.write(to: tempFile)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        var endpoint = MockEndpoint()
        endpoint.method = .post
        let result: User? = try await service.upload(endpoint: endpoint, fileURL: tempFile, responseModel: User.self)
        XCTAssertEqual(result, expectedUser)
    }

    // MARK: - Download

    func test_download_200_returnsLocalURL() async throws {
        let content = Data("file content".utf8)

        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/file.txt")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, content)
        }

        var endpoint = MockEndpoint()
        endpoint.path = "/file.txt"
        let localURL = try await service.download(endpoint: endpoint)

        XCTAssertTrue(FileManager.default.fileExists(atPath: localURL.path))
        let downloaded = try Data(contentsOf: localURL)
        XCTAssertEqual(downloaded, content)
        try? FileManager.default.removeItem(at: localURL)
    }

    func test_download_401_throwsUnauthorized() async throws {
        MockURLProtocol.requestHandler = { _ in
            let response = HTTPURLResponse(
                url: URL(string: "https://api.example.com/file.txt")!,
                statusCode: 401,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, nil)
        }

        do {
            _ = try await service.download(endpoint: MockEndpoint())
            XCTFail("Expected unauthorized error")
        } catch let error as RequestError {
            XCTAssertEqual(error, .unauthorized)
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

// MARK: - Helpers

private final class CallCounter {
    private var _count = 0
    private let lock = NSLock()

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return _count
    }

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        _count += 1
    }
}
