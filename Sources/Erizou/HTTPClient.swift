//
//  HTTPClient.swift
//
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

/// A protocol that defines the interface for making HTTP network requests.
///
/// Conform to `HTTPClient` to add networking capabilities to any type. The protocol
/// provides default implementations for data requests, file uploads, file downloads,
/// and optional automatic retry on network failures.
///
/// ```swift
/// struct APIService: HTTPClient {
///     var retryCount: Int { 2 }
/// }
///
/// let service = APIService()
/// let user: User? = try await service.sendRequest(endpoint: UserEndpoint.profile, responseModel: User.self)
/// ```
public protocol HTTPClient {
    /// The URL session used for network requests. Defaults to `.shared`.
    var urlSession: URLSession { get }

    /// The number of retry attempts made after a network-level failure. Defaults to `0`.
    ///
    /// Only `.unknown` errors (network failures such as no connectivity) trigger a retry.
    /// HTTP errors like `401` or `500` are not retried.
    var retryCount: Int { get }

    /// The base delay in seconds between retry attempts. Exponential backoff is applied.
    /// Defaults to `1.0`.
    var retryDelay: TimeInterval { get }

    /// Sends an HTTP request described by `endpoint` and decodes the response body.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint that describes the request (URL, method, headers, etc.).
    ///   - responseModel: The `Decodable` type to decode the response into, or `nil` to ignore the body.
    /// - Returns: A decoded instance of `responseModel`, or `nil` when `responseModel` is `nil`.
    /// - Throws: A `RequestError` describing what went wrong.
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type?) async throws -> T?

    /// Uploads raw `Data` using the request described by `endpoint`.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint that describes the request.
    ///   - data: The raw data to upload as the HTTP body.
    ///   - responseModel: The `Decodable` type to decode the response into, or `nil` to ignore the body.
    /// - Returns: A decoded instance of `responseModel`, or `nil` when `responseModel` is `nil`.
    /// - Throws: A `RequestError` describing what went wrong.
    func upload<T: Decodable>(endpoint: Endpoint, data: Data, responseModel: T.Type?) async throws -> T?

    /// Uploads a file at `fileURL` using the request described by `endpoint`.
    ///
    /// - Parameters:
    ///   - endpoint: The endpoint that describes the request.
    ///   - fileURL: The local file URL of the file to upload.
    ///   - responseModel: The `Decodable` type to decode the response into, or `nil` to ignore the body.
    /// - Returns: A decoded instance of `responseModel`, or `nil` when `responseModel` is `nil`.
    /// - Throws: A `RequestError` describing what went wrong.
    func upload<T: Decodable>(endpoint: Endpoint, fileURL: URL, responseModel: T.Type?) async throws -> T?

    /// Downloads a file from the endpoint and returns its local cache URL.
    ///
    /// The downloaded file is moved from the temporary download location into
    /// the app's caches directory and its URL is returned.
    ///
    /// - Parameter endpoint: The endpoint that describes the download request.
    /// - Returns: The local `URL` of the downloaded file in the caches directory.
    /// - Throws: A `RequestError` describing what went wrong.
    func download(endpoint: Endpoint) async throws -> URL
}

public extension HTTPClient {

    var urlSession: URLSession { .shared }
    var retryCount: Int { 0 }
    var retryDelay: TimeInterval { 1.0 }

    private static var OK_200: ClosedRange<Int> { 200...299 }
    private static var NOK_401: Int { 401 }

    // MARK: - sendRequest

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type?) async throws -> T? {
        guard let request = makeRequest(endpoint: endpoint) else {
            throw RequestError.invalidURL
        }
        return try await withRetry(retryCount) {
            try await performDataRequest(request: request, responseModel: responseModel)
        }
    }

    // MARK: - upload

    func upload<T: Decodable>(endpoint: Endpoint, data uploadData: Data, responseModel: T.Type?) async throws -> T? {
        guard let request = makeRequest(endpoint: endpoint) else {
            throw RequestError.invalidURL
        }
        return try await withRetry(retryCount) {
            try await performUploadRequest(request: request, uploadData: uploadData, responseModel: responseModel)
        }
    }

    func upload<T: Decodable>(endpoint: Endpoint, fileURL: URL, responseModel: T.Type?) async throws -> T? {
        guard let request = makeRequest(endpoint: endpoint) else {
            throw RequestError.invalidURL
        }
        return try await withRetry(retryCount) {
            try await performUploadRequest(request: request, fileURL: fileURL, responseModel: responseModel)
        }
    }

    // MARK: - download

    func download(endpoint: Endpoint) async throws -> URL {
        guard let request = makeRequest(endpoint: endpoint) else {
            throw RequestError.invalidURL
        }
        return try await withRetry(retryCount) {
            try await performDownloadRequest(request: request)
        }
    }

    // MARK: - Private

    private func withRetry<T>(_ retries: Int, _ operation: () async throws -> T) async throws -> T {
        var attempt = 0
        while true {
            do {
                return try await operation()
            } catch RequestError.unknown where attempt < retries {
                attempt += 1
                let delay = UInt64(pow(2.0, Double(attempt)) * retryDelay * 1_000_000_000)
                try await Task.sleep(nanoseconds: delay)
            }
        }
    }

    private func performDataRequest<T: Decodable>(request: URLRequest, responseModel: T.Type?) async throws -> T? {
        Log.logNetwork(request)
        do {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let (data, response) = try await urlSession.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }
            let responseTime = TimeInterval(DispatchTime.now().uptimeNanoseconds - startTime)
            Log.logNetwork(httpResponse, data: data, responseTime: responseTime)
            return try handleResponse(data: data, response: httpResponse, responseModel: responseModel)
        } catch let error as RequestError {
            throw error
        } catch {
            throw RequestError.unknown
        }
    }

    private func performUploadRequest<T: Decodable>(
        request: URLRequest,
        uploadData: Data,
        responseModel: T.Type?
    ) async throws -> T? {
        Log.logNetwork(request)
        do {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let (data, response) = try await urlSession.upload(for: request, from: uploadData)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }
            let responseTime = TimeInterval(DispatchTime.now().uptimeNanoseconds - startTime)
            Log.logNetwork(httpResponse, data: data, responseTime: responseTime)
            return try handleResponse(data: data, response: httpResponse, responseModel: responseModel)
        } catch let error as RequestError {
            throw error
        } catch {
            throw RequestError.unknown
        }
    }

    private func performUploadRequest<T: Decodable>(
        request: URLRequest,
        fileURL: URL,
        responseModel: T.Type?
    ) async throws -> T? {
        Log.logNetwork(request)
        do {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let (data, response) = try await urlSession.upload(for: request, fromFile: fileURL)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }
            let responseTime = TimeInterval(DispatchTime.now().uptimeNanoseconds - startTime)
            Log.logNetwork(httpResponse, data: data, responseTime: responseTime)
            return try handleResponse(data: data, response: httpResponse, responseModel: responseModel)
        } catch let error as RequestError {
            throw error
        } catch {
            throw RequestError.unknown
        }
    }

    private func performDownloadRequest(request: URLRequest) async throws -> URL {
        Log.logNetwork(request)
        do {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let (tempURL, response) = try await urlSession.download(for: request)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }
            let responseTime = TimeInterval(DispatchTime.now().uptimeNanoseconds - startTime)
            Log.logNetwork(httpResponse, data: Data(), responseTime: responseTime)

            switch httpResponse.statusCode {
            case Self.OK_200:
                let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                let filename = httpResponse.url?.lastPathComponent ?? UUID().uuidString
                let destURL = cacheDir.appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: destURL)
                try FileManager.default.moveItem(at: tempURL, to: destURL)
                return destURL
            case Self.NOK_401:
                throw RequestError.unauthorized
            default:
                throw RequestError.unexpectedStatusCode
            }
        } catch let error as RequestError {
            throw error
        } catch {
            throw RequestError.unknown
        }
    }

    private func handleResponse<T: Decodable>(
        data: Data,
        response: HTTPURLResponse,
        responseModel: T.Type?
    ) throws -> T? {
        switch response.statusCode {
        case Self.OK_200:
            guard let responseModel = responseModel else { return nil }
            guard let decoded = try? JSONDecoder().decode(responseModel, from: data) else {
                throw RequestError.decode
            }
            return decoded
        case Self.NOK_401:
            throw RequestError.unauthorized
        default:
            throw RequestError.unexpectedStatusCode
        }
    }

    private func makeRequest(endpoint: Endpoint) -> URLRequest? {
        var urlComponents = URLComponents()
        urlComponents.scheme = endpoint.scheme
        urlComponents.host = endpoint.host
        urlComponents.path = endpoint.path.appending(endpoint.subPath ?? "")
        urlComponents.queryItems = endpoint.queryItems?.compactMap { URLQueryItem(name: $0.name, value: $0.value) }

        guard let url = urlComponents.url else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.allHTTPHeaderFields = endpoint.header

        if let token = endpoint.token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        }

        return request
    }
}
