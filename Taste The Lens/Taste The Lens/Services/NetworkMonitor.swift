import Foundation
import Network
import os

private let logger = makeLogger(category: "NetworkMonitor")

extension Notification.Name {
    static let networkStatusChanged = Notification.Name("networkStatusChanged")
}

@Observable @MainActor
final class NetworkMonitor {
    static let shared = NetworkMonitor()

    var isConnected = true  // Optimistic default — avoids flash of offline banner on cold launch
    var wasDisconnected = false

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tastethelens.network-monitor")
    private var reconnectTask: Task<Void, Never>?

    private init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                let connected = path.status == .satisfied
                let wasOffline = !self.isConnected
                self.isConnected = connected

                if wasOffline && connected {
                    logger.info("Network restored")
                    self.wasDisconnected = true
                    self.reconnectTask?.cancel()
                    self.reconnectTask = Task {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        self.wasDisconnected = false
                    }
                    NotificationCenter.default.post(name: .networkStatusChanged, object: nil)
                } else if !connected {
                    logger.info("Network lost")
                    self.reconnectTask?.cancel()
                }
            }
        }
        monitor.start(queue: queue)
        logger.info("NetworkMonitor started")
    }
}
