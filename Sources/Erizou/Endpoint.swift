//
//  Endpoint.swift
//
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

/// Describes a single API endpoint and all the information needed to build its `URLRequest`.
///
/// Implement this protocol to define the endpoints of your API. Each property maps directly
/// to a part of the underlying `URLRequest` constructed by ``HTTPClient``.
///
/// ```swift
/// enum UserEndpoint: Endpoint {
///     case profile(id: Int)
///
///     var scheme: String { "https" }
///     var host: String { "api.example.com" }
///     var path: String { "/users" }
///     var subPath: String? {
///         switch self {
///         case .profile(let id): return "/\(id)"
///         }
///     }
///     var method: RequestMethod { .get }
///     var header: [String: String]? { ["Content-Type": "application/json"] }
///     var token: String? { nil }
///     var body: [String: String]? { nil }
///     var queryItems: [(name: String, value: String)]? { nil }
/// }
/// ```
public protocol Endpoint {
    /// The URL scheme (e.g. `"https"`).
    var scheme: String { get }

    /// The host component of the URL (e.g. `"api.example.com"`).
    var host: String { get }

    /// The base path component of the URL (e.g. `"/users"`).
    var path: String { get }

    /// An optional sub-path appended after `path` (e.g. `"/42"` to form `/users/42`).
    var subPath: String? { get }

    /// The HTTP method used for the request.
    var method: RequestMethod { get }

    /// Optional HTTP header fields merged into the request. The `Authorization` header
    /// is automatically set when `token` is non-nil.
    var header: [String: String]? { get }

    /// An optional bearer token. When non-nil, the `Authorization: Bearer <token>` header
    /// is added to the request automatically.
    var token: String? { get }

    /// An optional dictionary serialised as the JSON body of the request.
    var body: [String: String]? { get }

    /// Optional query items appended to the URL (e.g. `[("page", "1"), ("limit", "20")]`).
    var queryItems: [(name: String, value: String)]? { get }
}
