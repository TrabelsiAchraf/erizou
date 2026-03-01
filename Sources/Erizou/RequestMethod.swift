//
//  RequestMethod.swift
//
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

/// The HTTP method used in a network request.
public enum RequestMethod: String {
    /// Retrieve a resource without modifying it.
    case get = "GET"
    /// Submit data to create a new resource.
    case post = "POST"
    /// Replace an existing resource entirely.
    case put = "PUT"
    /// Apply a partial update to an existing resource.
    case patch = "PATCH"
    /// Remove a resource.
    case delete = "DELETE"
}
