import Flutter
import Network

final class NetworkTypeEventHandler: NSObject, FlutterPlugin, FlutterStreamHandler {
    private static let name = "\(Bundle.main.serviceIdentifier)/network/events"
    private var channel: FlutterEventChannel?
    private var monitor: NWPathMonitor?
    private var queue: DispatchQueue?
    private var sink: FlutterEventSink?

    static func register(with registrar: FlutterPluginRegistrar) {
        let instance = NetworkTypeEventHandler()
        instance.channel = FlutterEventChannel(name: name, binaryMessenger: registrar.messenger())
        instance.channel?.setStreamHandler(instance)
    }

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.aravpn.app.network-monitor")
        self.monitor = monitor
        self.queue = queue
        monitor.pathUpdateHandler = { [weak self] path in
            let kind: String
            if path.usesInterfaceType(.wifi) || path.usesInterfaceType(.wiredEthernet) {
                kind = "wifi"
            } else if path.usesInterfaceType(.cellular) {
                kind = "mobile"
            } else {
                kind = "unknown"
            }
            DispatchQueue.main.async { self?.sink?(kind) }
        }
        monitor.start(queue: queue)
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        monitor?.cancel()
        monitor = nil
        queue = nil
        sink = nil
        return nil
    }
}
