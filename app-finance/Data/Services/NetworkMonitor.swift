import Foundation
import Network
import Combine

// MARK: - Network Monitor

@MainActor
final class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var connectionType: ConnectionType = .unknown

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case unknown
    }

    private init() {
        print("📶 [Network] NetworkMonitor inicializado")
        startMonitoring()
    }

    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            let isConnected = path.status == .satisfied
            let connectionType = self?.getConnectionType(path) ?? .unknown

            Task { @MainActor [weak self] in
                self?.isConnected = isConnected
                self?.connectionType = connectionType

                if isConnected {
                    print("📶 [Network] Conectado - \(connectionType)")
                    // Trigger sync quando conectar
                    NotificationCenter.default.post(name: .networkBecameAvailable, object: nil)
                } else {
                    print("📶 [Network] Desconectado")
                }
            }
        }
        monitor.start(queue: queue)
    }

    func stopMonitoring() {
        monitor.cancel()
    }

    nonisolated private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        }
        return .unknown
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let networkBecameAvailable = Notification.Name("networkBecameAvailable")
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncFailed = Notification.Name("syncFailed")
    static let dataUpdatedFromServer = Notification.Name("dataUpdatedFromServer")
    static let categoriesUpdated = Notification.Name("categoriesUpdated")
    static let transactionsUpdated = Notification.Name("transactionsUpdated")
    static let creditCardsUpdated = Notification.Name("creditCardsUpdated")
    static let fixedBillsUpdated = Notification.Name("fixedBillsUpdated")
}
