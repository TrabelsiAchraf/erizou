//
//  HTTPClient.swift
//  
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

public protocol HTTPClient {
    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type?) async throws -> T?
}

public extension HTTPClient {

    private static var OK_200: ClosedRange<Int> { 200...299 }
    private static var NOK_401: Int { 401 }

    // MARK: - Public

    func sendRequest<T: Decodable>(endpoint: Endpoint, responseModel: T.Type?) async throws -> T? {
        guard let request = makeRequest(endpoint: endpoint) else {
            throw RequestError.invalidURL
        }

        Log.logNetwork(request)

        do {
            let startTime = DispatchTime.now().uptimeNanoseconds
            let (data, response) = try await URLSession.shared.data(for: request, delegate: nil)
            guard let response = response as? HTTPURLResponse else {
                throw RequestError.noResponse
            }

            let responseTimeNanoseconds = TimeInterval(DispatchTime.now().uptimeNanoseconds - startTime)
            Log.logNetwork(response, data: data, responseTime: responseTimeNanoseconds)

            switch response.statusCode {
            case Self.OK_200:
                guard let responseModel = responseModel else { return nil }
                guard let decodedResponse = try? JSONDecoder().decode(responseModel, from: data) else {
                    throw RequestError.decode
                }
                return decodedResponse
            case Self.NOK_401: throw RequestError.unauthorized
            default: throw RequestError.unexpectedStatusCode
            }
        } catch {
            throw RequestError.unknown
        }
    }

    // MARK: - Private

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
