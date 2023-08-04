//
//  Logger+Infrastructure❤️.swift
//  
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Foundation
import OSLog

struct Log {

    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.oodrive.workDev"
    private static let isJSONResponseEnabled = false

    // MARK: - Public

    static func logNetwork(
        _ response: HTTPURLResponse,
        data: Data,
        responseTime: TimeInterval,
        file: String = #file,
        function: String = #function,
        column: Int = #column,
        line: Int = #line
    ) {
        let statusCode = response.statusCode
        let responseStatus = Log.retrieveResponseStatus(statusCode)
        let strResponse = """
        [🛜] HTTPURLResponse
        [\(responseStatus.emoji)] \(statusCode) \(response.url?.absoluteString ?? "??")"
        [📦] Response Headers :
         ---> \(String(describing: response.allHeaderFields.map { "\($0.key): \($0.value)" }))
        [⏳] Response Time : [\(responseTime / 1e9) seconds]
        """
        let strJSONMessage = "[📖] Response JSON Data :"
            .appending(RETURN)
            .appending(data.mapToJSON)
        let message = SEPARATOR
            .appending(strResponse)
            .appending(RETURN)
            .appending(isJSONResponseEnabled ? strJSONMessage : EMPTY)
            .appending(SEPARATOR)

        if responseStatus.isSuccess {
            Log.debug(message: message, file: file, function: function, column: column, line: line)
        } else {
            Log.error(message: message, file: file, function: function, column: column, line: line)
        }
    }

    static func logNetwork(
        _ request: URLRequest,
        file: String = #file,
        function: String = #function,
        column: Int = #column,
        line: Int = #line
    ) {
        let strResponse = """
        [🛜] URLRequest
        [🚀] \(request.httpMethod ?? "??") \(request.url?.absoluteString ?? "??")"
        [📦] Request Headers :
        \(request.mapHeaderFields)
        """
        let message = SEPARATOR
            .appending(strResponse)
            .appending(SEPARATOR)

        Log.debug(message: message, file: file, function: function, column: column, line: line)
    }

    // MARK: - Private

    private static func retrieveResponseStatus(_ statusCode: Int) -> (emoji: String, isSuccess: Bool) {
        switch statusCode {
        case let status where status >= 200 && status < 300: return (emoji: "💚", isSuccess: true)
        default: return (emoji: "💔", isSuccess: false)
        }
    }

    private static func debug(
        message: String,
        file: String = #file,
        function: String = #function,
        column: Int = #column,
        line: Int = #line
    ) {
        let logger = Logger(subsystem: subsystem, category: "network")
        let message = "\(file): \(function)](\(line): \(column)) \(message)"
        logger.info("\(message)")
    }

    private static func error(
        message: String,
        file: String = #file,
        function: String = #function,
        column: Int = #column,
        line: Int = #line
    ) {
        let logger = Logger(subsystem: subsystem, category: "network")
        let message = "\(file): \(function)](\(line): \(column)) \(message)"
        logger.error("\(message)")
    }
}

// MARK: - Data getJSON

private extension Data {
    var mapToJSON: String {
        do {
            guard let json = try JSONSerialization.jsonObject(with: self) as? [String: AnyObject] else {
                return "Error parsing Data, No JSON"
            }
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            return String(decoding: jsonData, as: UTF8.self)
        } catch {
            return "Error parsing: \(error)"
        }
    }
}

// MARK: - URLRequest mapHeaderFields

extension URLRequest {
    var mapHeaderFields: String {
        var result = ""
        allHTTPHeaderFields?.forEach {
            result = result
                .appending(OPEN_BRACCLET)
                .appending("\($0.key): \($0.value)")
                .appending(CLOSE_BRACCLET)
                .appending(RETURN)
        }
        return result
    }
}

// MARK: - Symbols

private let SEPARATOR = "\n\n=========================================================================================\n\n"
private let EMPTY = ""
private let RETURN = "\n"
private let OPEN_BRACCLET = "["
private let CLOSE_BRACCLET = "]"
