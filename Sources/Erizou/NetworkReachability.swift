//
//  NetworkReachability.swift
//
//
//  Created by Achraf Trabelsi on 31/07/2023.
//

import Combine
import Foundation
import Network

/// Monitors the device's network reachability in real time.
///
/// Create an instance of `NetworkReachability` and observe the `status` or `isConnected`
/// properties to react to changes in network availability. Both properties are published so
/// they can be bound directly in SwiftUI or observed via Combine.
///
/// ```swift
/// let reachability = NetworkReachability()
///
/// // SwiftUI
/// Text(reachability.isConnected ? "Online" : "Offline")
///
/// // Combine
/// reachability.$isConnected
///     .sink { print("Connected:", $0) }
///     .store(in: &cancellables)
/// ```
public final class NetworkReachability: ObservableObject {

    /// The current network connection status.
    public enum Status {
        /// The path is available and can be used to connect.
        case satisfied
        /// The path is not available.
        case unsatisfied
        /// The path is not available but may become available upon a connection attempt.
        case requiresConnection
        /// The status has not been determined yet.
        case unknown
    }

    /// The current network status. Updates are always delivered on the main queue.
    @Published public private(set) var status: Status = .unknown

    /// A convenience property that returns `true` when the network path is satisfied.
    @Published public private(set) var isConnected: Bool = false

    private let monitor: NWPathMonitor
    private let queue: DispatchQueue

    /// Creates a new `NetworkReachability` instance and starts monitoring immediately.
    ///
    /// - Parameter queue: The dispatch queue on which path updates are received internally.
    ///   Status and `isConnected` are always published on the main queue regardless of this value.
    ///   Defaults to a dedicated serial background queue.
    public init(queue: DispatchQueue = DispatchQueue(label: "com.erizou.NetworkReachability", qos: .utility)) {
        self.monitor = NWPathMonitor()
        self.queue = queue
        startMonitoring()
    }

    deinit {
        monitor.cancel()
    }

    // MARK: - Private

    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let newStatus: Status
            switch path.status {
            case .satisfied:           newStatus = .satisfied
            case .unsatisfied:         newStatus = .unsatisfied
            case .requiresConnection:  newStatus = .requiresConnection
            @unknown default:          newStatus = .unknown
            }
            DispatchQueue.main.async {
                self?.status = newStatus
                self?.isConnected = (newStatus == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }
}
