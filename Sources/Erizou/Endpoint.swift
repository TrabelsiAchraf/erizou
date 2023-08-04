//
//  Endpoint.swift
//  
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation

public protocol Endpoint {
    var scheme: String { get }
    var host: String { get }
    var path: String { get }
    var subPath: String? { get }
    var method: RequestMethod { get }
    var header: [String: String]? { get }
    var token: String? { get }
    var body: [String: String]? { get }
    var queryItems: [(name: String, value: String)]? { get }
}
