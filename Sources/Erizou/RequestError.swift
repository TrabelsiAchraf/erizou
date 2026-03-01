//
//  RequestError.swift
//
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

/// Errors that can be thrown by ``HTTPClient`` methods.
public enum RequestError: Error, Equatable {
    /// The response body could not be decoded into the expected type.
    case decode
    /// The URL could not be constructed from the provided ``Endpoint``.
    case invalidURL
    /// The server returned no response, or the response was not an `HTTPURLResponse`.
    case noResponse
    /// The server returned a `401 Unauthorized` status code.
    case unauthorized
    /// The server returned a status code outside the expected range.
    case unexpectedStatusCode
    /// A network-level failure occurred (e.g. no internet connection). Retryable.
    case unknown

    /// A human-readable message suitable for display in the UI.
    public var customMessage: String {
        switch self {
        case .decode:
            return "Decode error"
        case .unauthorized:
            return "Session expired"
        default:
            return "Unknown error"
        }
    }
}
