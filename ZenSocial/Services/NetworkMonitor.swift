import Network
import Observation

@Observable
@MainActor
class NetworkMonitor {
    var isConnected = true

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.zensocial.networkmonitor")

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isConnected = (path.status == .satisfied)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
