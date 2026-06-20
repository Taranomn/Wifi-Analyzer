import CoreBluetooth
import Combine
import Foundation

struct NearbyESP: Identifiable, Equatable {
    let id: UUID
    let name: String
    let rssi: Int
}

enum BLELinkState: String {
    case searching = "Searching"
    case connecting = "Connecting"
    case discovering = "Discovering services"
    case ready = "Ready"
    case disconnected = "Disconnected"
    case bluetoothOff = "Bluetooth off"
    case failed = "Connection failed"
}

@MainActor
final class BLEProvisioningService: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "7A1F0001-8D79-4F25-BC40-5C7D17F62A11")
    private static let commandUUID = CBUUID(string: "7A1F0002-8D79-4F25-BC40-5C7D17F62A11")
    private static let eventUUID = CBUUID(string: "7A1F0003-8D79-4F25-BC40-5C7D17F62A11")

    @Published var nearbyESP: NearbyESP?
    @Published var pairedName: String?
    @Published var isConnected = false
    @Published var linkState: BLELinkState = .searching
    @Published var isScanningNetworks = false
    @Published var networks: [WiFiNetwork] = []
    @Published var deviceStatus = BLEDeviceStatus()
    @Published var showingWiFiSetup = false
    @Published var localSpeedMbps: Double?
    @Published var isTestingSpeed = false
    @Published var activeTransport = "Bluetooth fallback"
    @Published var message: String?
    var onIPAddress: ((String) -> Void)?
    var onStatus: ((BLEDeviceStatus) -> Void)?

    private var central: CBCentralManager!
    private var discovered: [UUID: CBPeripheral] = [:]
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var eventCharacteristic: CBCharacteristic?
    private var pendingPair = false
    private var didOfferWiFiSetup = false
    private var statusTask: Task<Void, Never>?
    private var connectionTimeoutTask: Task<Void, Never>?
    private var reconnectTask: Task<Void, Never>?
    private var eventBuffer = Data()
    private var excludedPeripheralId: UUID?
    private let defaults = UserDefaults.standard

    override init() {
        super.init()
        log("service initialized")
        central = CBCentralManager(delegate: self, queue: nil)
    }

    private func log(_ text: String) {
        print("[BLE] \(text)")
    }

    func confirmPairing() {
        guard let device = nearbyESP, let peripheral = discovered[device.id] else { return }
        pendingPair = true
        self.peripheral = peripheral
        defaults.set(peripheral.identifier.uuidString, forKey: "pairedESP")
        pairedName = device.name
        self.nearbyESP = nil
        central.stopScan()
        connect(to: peripheral)
    }

    func dismissPairing() {
        nearbyESP = nil
    }

    func forgetDevice() {
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        defaults.removeObject(forKey: "pairedESP")
        pairedName = nil
        isConnected = false
        linkState = .searching
        reconnectTask?.cancel()
        startScanning()
    }

    func addAnotherDevice() {
        excludedPeripheralId = peripheral?.identifier
        if let peripheral { central.cancelPeripheralConnection(peripheral) }
        defaults.removeObject(forKey: "pairedESP")
        pairedName = nil
        isConnected = false
        linkState = .searching
        commandCharacteristic = nil
        eventCharacteristic = nil
        statusTask?.cancel()
        statusTask = nil
        didOfferWiFiSetup = false
        startScanning(forceDiscovery: true)
    }

    func retryConnection() {
        connectionTimeoutTask?.cancel()
        reconnectTask?.cancel()
        reconnectTask = nil
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        linkState = .searching
        startScanning(forceDiscovery: true)
    }

    func scanWiFi() {
        guard isConnected else {
            message = "Pair with the ESP32 before choosing a Wi-Fi network."
            return
        }
        guard !isScanningNetworks else { return }
        networks = []
        isScanningNetworks = true
        write(["op": "scan"])
    }

    func connectWiFi(ssid: String, password: String) {
        write(["op": "connect", "ssid": ssid, "password": password])
        showingWiFiSetup = false
    }

    func requestStatus() {
        guard isConnected else { return }
        write(["op": "status"])
    }

    func requestDiagnostics() {
        guard isConnected else { return }
        write(["op": "diagnostics"])
    }

    func refreshPreferredStatus() async {
        let host = deviceStatus.localIp
        if !host.isEmpty {
            do {
                async let statusRequest = ESPService(host: host).status()
                async let diagnosticsRequest = ESPService(host: host).diagnostics()
                let (status, diagnostics) = try await (statusRequest, diagnosticsRequest)
                apply(status)
                deviceStatus.gatewayIp = diagnostics.gatewayIp
                deviceStatus.gatewayLatencyMs = diagnostics.gatewayLatencyMs
                deviceStatus.dnsIp = diagnostics.dnsIp
                setActiveTransport("Wi-Fi")
                return
            } catch {
                setActiveTransport("Bluetooth fallback")
            }
        }
        requestStatus()
        requestDiagnostics()
    }

    func runLocalSpeedTest() {
        guard !deviceStatus.localIp.isEmpty else {
            message = "The ESP32 needs a local IP before running the speed test."
            return
        }
        isTestingSpeed = true
        Task {
            defer { isTestingSpeed = false }
            do {
                localSpeedMbps = try await ESPService(host: deviceStatus.localIp).localSpeedTest()
            } catch {
                message = "Could not run the local speed test. Make sure the iPhone is on the same Wi-Fi network."
            }
        }
    }

    private func startScanning(forceDiscovery: Bool = false) {
        guard central.state == .poweredOn else { return }
        guard linkState != .connecting, linkState != .discovering, linkState != .ready else { return }
        let pairedID = defaults.string(forKey: "pairedESP").flatMap(UUID.init(uuidString:))
        if !forceDiscovery, let pairedID, let known = central.retrievePeripherals(withIdentifiers: [pairedID]).first {
            peripheral = known
            pairedName = known.name ?? "WiFi Survey ESP32"
            connect(to: known)
        } else {
            linkState = .searching
            central.stopScan()
            central.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
        }
    }

    private func acceptsDiscoveredPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any]) -> Bool {
        let advertisedServices = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
        if advertisedServices.contains(Self.serviceUUID) {
            return true
        }

        let advertisedName = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        return advertisedName?.hasPrefix("WiFi Survey") == true || peripheral.name?.hasPrefix("WiFi Survey") == true
    }

    private func connect(to peripheral: CBPeripheral) {
        guard linkState != .connecting, linkState != .discovering, linkState != .ready,
              peripheral.state != .connected && peripheral.state != .connecting else { return }
        reconnectTask?.cancel()
        reconnectTask = nil
        central.stopScan()
        log("connecting to \(peripheral.name ?? peripheral.identifier.uuidString)")
        self.peripheral = peripheral
        linkState = .connecting
        central.connect(peripheral)
        connectionTimeoutTask?.cancel()
        connectionTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            guard let self, self.linkState != .ready else { return }
            self.central.cancelPeripheralConnection(peripheral)
            self.scheduleReconnect(forceDiscovery: true)
        }
    }

    private func scheduleReconnect(forceDiscovery: Bool = false) {
        guard reconnectTask == nil else { return }
        reconnectTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.reconnectTask = nil
            self?.startScanning(forceDiscovery: forceDiscovery)
        }
    }

    private func write(_ object: [String: String]) {
        guard let peripheral, let commandCharacteristic,
              let data = try? JSONSerialization.data(withJSONObject: object) else {
            message = "The ESP32 is not connected over Bluetooth."
            return
        }
        log("write \(object["op"] ?? "unknown")")
        peripheral.writeValue(data, for: commandCharacteristic, type: .withResponse)
    }

    private func handleEvent(_ data: Data) {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            log("ignored invalid event: \(String(data: data, encoding: .utf8) ?? "<binary>")")
            return
        }
        log("event \(type)")

        switch type {
        case "paired":
            if let peripheral {
                defaults.set(peripheral.identifier.uuidString, forKey: "pairedESP")
                pairedName = peripheral.name ?? "WiFi Survey ESP32"
            }
            pendingPair = false
            updateDeviceStatus(object)
            updateIPAddress(object)
            showingWiFiSetup = true
            didOfferWiFiSetup = true
            scanWiFi()
        case "status":
            updateDeviceStatus(object)
            updateIPAddress(object)
            if object["connected"] as? Bool == false && !didOfferWiFiSetup {
                didOfferWiFiSetup = true
                showingWiFiSetup = true
                scanWiFi()
            }
        case "scan_started":
            networks = []
            isScanningNetworks = true
        case "network":
            guard let ssid = object["ssid"] as? String,
                  let bssid = object["bssid"] as? String,
                  let rssi = object["rssi"] as? Int,
                  let channel = object["channel"] as? Int,
                  let secure = object["secure"] as? Bool else { return }
            let network = WiFiNetwork(ssid: ssid, bssid: bssid, rssi: rssi, qualityLabel: "", channel: channel, secure: secure)
            if let index = networks.firstIndex(where: { $0.ssid == ssid }) {
                if networks[index].rssi < rssi { networks[index] = network }
            } else {
                networks.append(network)
            }
            networks.sort { $0.rssi > $1.rssi }
        case "scan_complete":
            isScanningNetworks = false
        case "connecting":
            updateDeviceStatus(object)
            message = "ESP32 is connecting to \(object["ssid"] as? String ?? "the selected Wi-Fi")."
        case "connected":
            updateDeviceStatus(object)
            updateIPAddress(object)
            message = "ESP32 connected to \(object["ssid"] as? String ?? "Wi-Fi")."
        case "connection_failed":
            updateDeviceStatus(object)
            message = "The ESP32 could not connect. Check the Wi-Fi password and try again."
        case "diagnostics":
            deviceStatus.gatewayIp = object["gateway_ip"] as? String ?? ""
            deviceStatus.gatewayLatencyMs = object["gateway_latency_ms"] as? Int
            deviceStatus.dnsIp = object["dns_ip"] as? String ?? ""
        default:
            updateDeviceStatus(object)
            updateIPAddress(object)
        }
    }

    private func updateDeviceStatus(_ object: [String: Any]) {
        deviceStatus.nodeId = object["node"] as? String ?? deviceStatus.nodeId
        deviceStatus.connectionStatus = object["state"] as? String ?? deviceStatus.connectionStatus
        deviceStatus.connected = object["connected"] as? Bool ?? deviceStatus.connected
        deviceStatus.ssid = object["ssid"] as? String ?? deviceStatus.ssid
        deviceStatus.bssid = object["bssid"] as? String ?? deviceStatus.bssid
        if object.keys.contains("rssi") { deviceStatus.rssi = object["rssi"] as? Int }
        deviceStatus.qualityLabel = object["quality"] as? String ?? deviceStatus.qualityLabel
        deviceStatus.channel = object["channel"] as? Int ?? deviceStatus.channel
        deviceStatus.localIp = object["ip"] as? String ?? deviceStatus.localIp
        deviceStatus.accessPointSsid = object["ap_ssid"] as? String ?? deviceStatus.accessPointSsid
        deviceStatus.accessPointIp = object["ap_ip"] as? String ?? deviceStatus.accessPointIp
        deviceStatus.accessPointClients = object["ap_clients"] as? Int ?? deviceStatus.accessPointClients
        deviceStatus.uptimeSeconds = object["uptime"] as? Int ?? deviceStatus.uptimeSeconds
        onStatus?(deviceStatus)
    }

    private func updateIPAddress(_ object: [String: Any]) {
        if let ip = object["ip"] as? String, !ip.isEmpty {
            onIPAddress?(ip)
            Task { await refreshPreferredStatus() }
        }
    }

    private func apply(_ status: WiFiStatus) {
        deviceStatus.nodeId = status.nodeId
        deviceStatus.connectionStatus = status.connectionStatus
        deviceStatus.connected = status.connected
        deviceStatus.ssid = status.ssid
        deviceStatus.bssid = status.bssid
        deviceStatus.rssi = status.rssi
        deviceStatus.qualityLabel = status.qualityLabel
        deviceStatus.channel = status.channel
        deviceStatus.localIp = status.localIp
        deviceStatus.accessPointSsid = status.apSsid ?? deviceStatus.accessPointSsid
        deviceStatus.accessPointIp = status.setupIp
        deviceStatus.accessPointClients = status.apClients ?? 0
        deviceStatus.uptimeSeconds = status.uptimeSeconds
        onIPAddress?(status.localIp)
        onStatus?(deviceStatus)
    }

    private func setActiveTransport(_ transport: String) {
        guard activeTransport != transport else { return }
        activeTransport = transport
        log("active transport: \(transport)")
    }
}

extension BLEProvisioningService: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            log("central state \(central.state.rawValue)")
            if central.state == .poweredOn {
                startScanning()
            } else if central.state == .poweredOff {
                linkState = .bluetoothOff
                message = "Turn on Bluetooth to find the ESP32."
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        Task { @MainActor in
            guard peripheral.identifier != excludedPeripheralId else { return }
            guard acceptsDiscoveredPeripheral(peripheral, advertisementData: advertisementData) else { return }
            log("discovered \(peripheral.name ?? peripheral.identifier.uuidString), RSSI \(RSSI)")
            discovered[peripheral.identifier] = peripheral
            if defaults.string(forKey: "pairedESP") != nil {
                defaults.set(peripheral.identifier.uuidString, forKey: "pairedESP")
                pairedName = peripheral.name ?? "WiFi Survey ESP32"
                connect(to: peripheral)
            } else if nearbyESP == nil {
                nearbyESP = NearbyESP(id: peripheral.identifier, name: peripheral.name ?? "WiFi Survey ESP32", rssi: RSSI.intValue)
            }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            log("link connected; discovering services")
            self.peripheral = peripheral
            peripheral.delegate = self
            connectionTimeoutTask?.cancel()
            reconnectTask?.cancel()
            reconnectTask = nil
            linkState = .discovering
            if defaults.string(forKey: "pairedESP") != nil {
                pairedName = peripheral.name ?? "WiFi Survey ESP32"
            }
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            log("disconnected: \(error?.localizedDescription ?? "no error")")
            isConnected = false
            linkState = .disconnected
            deviceStatus.connectionStatus = "Bluetooth disconnected"
            statusTask?.cancel()
            statusTask = nil
            commandCharacteristic = nil
            eventCharacteristic = nil
            eventBuffer.removeAll(keepingCapacity: true)
            scheduleReconnect(forceDiscovery: error != nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            log("failed to connect: \(error?.localizedDescription ?? "unknown error")")
            isConnected = false
            linkState = .failed
            scheduleReconnect(forceDiscovery: true)
        }
    }
}

extension BLEProvisioningService: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            log("services discovered: \(peripheral.services?.count ?? 0), error: \(error?.localizedDescription ?? "none")")
            peripheral.services?.forEach { peripheral.discoverCharacteristics([Self.commandUUID, Self.eventUUID], for: $0) }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            log("characteristics discovered: \(service.characteristics?.count ?? 0), error: \(error?.localizedDescription ?? "none")")
            service.characteristics?.forEach { characteristic in
                if characteristic.uuid == Self.commandUUID { commandCharacteristic = characteristic }
                if characteristic.uuid == Self.eventUUID {
                    eventCharacteristic = characteristic
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            log("notifications \(characteristic.isNotifying ? "ready" : "not ready"), error: \(error?.localizedDescription ?? "none")")
            guard characteristic.uuid == Self.eventUUID, characteristic.isNotifying else {
                if let error { message = "Could not subscribe to ESP32 updates: \(error.localizedDescription)" }
                return
            }

            isConnected = true
            linkState = .ready
            if pendingPair {
                write(["op": "pair"])
            } else {
                write(["op": "status"])
            }

            if statusTask == nil {
                statusTask = Task { @MainActor [weak self] in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(2))
                        guard !Task.isCancelled else { return }
                        await self?.refreshPreferredStatus()
                    }
                }
            }
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard let data = characteristic.value else { return }
        Task { @MainActor in
            eventBuffer.append(data)

            while let newline = eventBuffer.firstIndex(of: 0x0A) {
                let message = Data(eventBuffer[..<newline])
                eventBuffer.removeSubrange(...newline)
                handleEvent(message)
            }

            if eventBuffer.count > 4096 {
                log("discarding oversized incomplete event")
                eventBuffer.removeAll(keepingCapacity: true)
            }
        }
    }
}
