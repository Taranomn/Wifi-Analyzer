import Foundation
import RoomPlan
import simd

struct WiFiStatus: Codable {
    let nodeId: String
    let connected: Bool
    let connectionStatus: String
    let ssid: String
    let bssid: String
    let rssi: Int?
    let qualityLabel: String
    let channel: Int
    let localIp: String
    let setupIp: String
    let uptimeSeconds: Int
    let apSsid: String?
    let apClients: Int?
    let packetLossPercent: Double?
    let pingPacketsSent: Int?
    let pingPacketsReceived: Int?
    let averagePingMs: Double?
    let minPingMs: Double?
    let maxPingMs: Double?

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case connected
        case connectionStatus = "connection_status"
        case ssid, bssid, rssi
        case qualityLabel = "quality_label"
        case channel
        case localIp = "local_ip"
        case setupIp = "setup_ip"
        case uptimeSeconds = "uptime_seconds"
        case apSsid = "ap_ssid"
        case apClients = "ap_clients"
        case packetLossPercent, pingPacketsSent, pingPacketsReceived, averagePingMs, minPingMs, maxPingMs
    }
}

struct BLEDeviceStatus {
    var nodeId = "ESP32-01"
    var connectionStatus = "disconnected"
    var connected = false
    var ssid = ""
    var bssid = ""
    var rssi: Int?
    var qualityLabel = "Unavailable"
    var channel = 0
    var localIp = ""
    var accessPointSsid = "WiFi-Survey-Setup"
    var accessPointIp = "192.168.4.1"
    var accessPointClients = 0
    var uptimeSeconds = 0
    var gatewayIp = ""
    var gatewayLatencyMs: Int?
    var dnsIp = ""
}

struct NetworkDiagnostics: Codable {
    let connected: Bool
    let gatewayIp: String
    let gatewayLatencyMs: Int?
    let dnsIp: String
    let packetLossPercent: Double?
    let pingPacketsSent: Int?
    let pingPacketsReceived: Int?
    let averagePingMs: Double?
    let minPingMs: Double?
    let maxPingMs: Double?

    enum CodingKeys: String, CodingKey {
        case connected
        case gatewayIp = "gateway_ip"
        case gatewayLatencyMs = "gateway_latency_ms"
        case dnsIp = "dns_ip"
        case packetLossPercent, pingPacketsSent, pingPacketsReceived, averagePingMs, minPingMs, maxPingMs
    }
}

struct SurveyDevice: Codable, Identifiable {
    var id: String { nodeId }
    let nodeId: String
    var host: String
    var connected: Bool
    var ssid: String
    var rssi: Int?
    var qualityLabel: String
    var channel: Int
    var lastSeen: Date
    var packetLossPercent: Double?
    var averagePingMs: Double?
    var minPingMs: Double?
    var maxPingMs: Double?
    var localSpeedMbps: Double?
    var channelCongestion: String?
}

struct PhoneTesterStatus {
    var connected = false
    var latencyMs: Int?
    var localSpeedMbps: Double?
    var lastUpdated: Date?
}

struct ChannelAnalysis: Codable {
    let currentChannel: Int
    let currentChannelCongestion: String
    let recommended2GHzChannels: [Int]
    let allChannels: [ChannelMetric]
}

struct ChannelMetric: Codable, Identifiable {
    var id: Int { channel }
    let channel: Int
    let visibleNetworks: Int
    let strongestInterferingRssi: Int?
    let congestionLevel: String
}

struct HardwareProfile: Codable {
    var boardModel = "ESP32-WROOM-32"
    var antennaType = "Unknown"
    var antennaGainDbi = 0.0
    var calibrationOffsetDbm = 0.0
    var notes = ""
}

struct CalibrationProfile: Codable, Identifiable {
    let id: UUID
    let areaId: UUID
    let nodeId: String
    var calibrationOffsetDbm: Double
    var deviceModel: String
    var notes: String
    let createdAt: Date
    let phoneLatencyMs: Int?
    let phoneThroughputMbps: Double?
}

struct SurveyRecommendation: Codable, Identifiable {
    let id: UUID
    let areaId: UUID
    let severity: String
    let title: String
    let description: String
    let suggestedAction: String
}

struct BuildingFloor: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var order: Int
}

struct APPlacementSuggestion: Identifiable {
    let id = UUID()
    let floorId: UUID
    let candidateAreaId: UUID
    let title: String
    let reason: String
    let coveredAreaNames: [String]
    let estimatedRealDeviceRssi: Int?
}

struct PlanningStatus: Codable {
    let role: String
    let ssid: String
    let ip: String
    let results: [PlanningResult]?
}

struct PlanningResult: Codable, Identifiable {
    var id: String { nodeId }
    let nodeId: String
    let rssi: Int
    let averagePingMs: Double
    let packetLossPercent: Double

    enum CodingKeys: String, CodingKey {
        case nodeId = "node_id"
        case rssi, averagePingMs, packetLossPercent
    }
}

enum ProfessionalScore {
    static func device(_ device: SurveyDevice) -> Int {
        let rssi = rssiScore(device.rssi)
        let latency = latencyScore(device.averagePingMs)
        let loss = lossScore(device.packetLossPercent)
        let speed = speedScore(device.localSpeedMbps)
        let congestion = congestionScore(device.channelCongestion)
        let stability = device.connected ? 100.0 : 0
        let freshness = max(0, 100 - Date().timeIntervalSince(device.lastSeen) * 2)
        return Int((rssi * 0.30 + latency * 0.15 + loss * 0.20 + speed * 0.10 + congestion * 0.10 + stability * 0.10 + freshness * 0.05).rounded())
    }

    static func label(_ score: Int) -> String {
        switch score {
        case 85...100: return "Excellent"
        case 70..<85: return "Good"
        case 50..<70: return "Fair"
        case 30..<50: return "Weak"
        default: return "Critical"
        }
    }

    private static func rssiScore(_ value: Int?) -> Double {
        guard let value else { return 0 }
        if value >= -50 { return 100 }
        if value >= -60 { return 90 }
        if value >= -67 { return 78 }
        if value >= -70 { return 65 }
        if value >= -80 { return 35 }
        if value >= -85 { return 15 }
        return 0
    }
    private static func latencyScore(_ value: Double?) -> Double {
        guard let value else { return 30 }
        if value < 10 { return 100 }
        if value <= 30 { return 80 }
        if value <= 80 { return 50 }
        return 10
    }
    private static func lossScore(_ value: Double?) -> Double {
        guard let value else { return 30 }
        if value == 0 { return 100 }
        if value <= 2 { return 80 }
        if value <= 5 { return 45 }
        return 5
    }
    private static func speedScore(_ value: Double?) -> Double {
        guard let value else { return 40 }
        if value >= 50 { return 100 }
        if value >= 25 { return 80 }
        if value >= 10 { return 55 }
        return 20
    }
    private static func congestionScore(_ value: String?) -> Double {
        ["Low": 100, "Medium": 70, "High": 35, "Severe": 5][value ?? ""] ?? 40
    }
}

struct WiFiScanResponse: Codable {
    let networks: [WiFiNetwork]
}

struct WiFiNetwork: Codable, Identifiable {
    var id: String { bssid }
    let ssid: String
    let bssid: String
    let rssi: Int
    let qualityLabel: String
    let channel: Int
    let secure: Bool

    enum CodingKeys: String, CodingKey {
        case ssid, bssid, rssi, channel, secure
        case qualityLabel = "quality_label"
    }
}

struct SurveyPoint: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let nodeId: String
    let roomId: UUID?
    let roomName: String
    let note: String
    let x: Double
    let y: Double
    let rssi: Int
    let qualityLabel: String
    let ssid: String
    let bssid: String
    let channel: Int
}

struct AreaLandmark: Codable, Identifiable {
    let id: UUID
    var name: String
    let x: Double
    let y: Double
    let z: Double
    var floorId: UUID?
    var assignedNodeIds: [String]

    func distance(to other: AreaLandmark) -> Double {
        sqrt(pow(x - other.x, 2) + pow(y - other.y, 2) + pow(z - other.z, 2))
    }
}

struct WallSegment: Codable, Identifiable {
    let id: UUID
    let startX: Double
    let startY: Double
    let endX: Double
    let endY: Double
}

struct FloorPlan: Codable {
    var walls: [WallSegment]
    var minX: Double
    var minY: Double
    var maxX: Double
    var maxY: Double

    static let empty = FloorPlan(walls: [], minX: 0, minY: 0, maxX: 1, maxY: 1)

    var width: Double { max(maxX - minX, 0.1) }
    var height: Double { max(maxY - minY, 0.1) }

    static func from(room: CapturedRoom) -> FloorPlan {
        let segments = room.walls.map { wall -> WallSegment in
            let transform = wall.transform
            let centerX = Double(transform.columns.3.x)
            let centerY = Double(transform.columns.3.z)
            let length = Double(wall.dimensions.x)
            let directionX = Double(transform.columns.0.x)
            let directionY = Double(transform.columns.0.z)
            let magnitude = max(hypot(directionX, directionY), 0.0001)
            let dx = directionX / magnitude * length / 2
            let dy = directionY / magnitude * length / 2
            return WallSegment(
                id: UUID(),
                startX: centerX - dx,
                startY: centerY - dy,
                endX: centerX + dx,
                endY: centerY + dy
            )
        }

        guard !segments.isEmpty else { return .empty }
        let xs = segments.flatMap { [$0.startX, $0.endX] }
        let ys = segments.flatMap { [$0.startY, $0.endY] }
        return FloorPlan(
            walls: segments,
            minX: xs.min() ?? 0,
            minY: ys.min() ?? 0,
            maxX: xs.max() ?? 1,
            maxY: ys.max() ?? 1
        )
    }

    static func fromTrace(points: [CGPoint]) -> FloorPlan {
        guard points.count >= 3 else { return .empty }
        let segments = points.indices.map { index in
            let start = points[index]
            let end = points[(index + 1) % points.count]
            return WallSegment(
                id: UUID(),
                startX: start.x,
                startY: start.y,
                endX: end.x,
                endY: end.y
            )
        }
        let xs = points.map(\.x)
        let ys = points.map(\.y)
        return FloorPlan(
            walls: segments,
            minX: xs.min() ?? 0,
            minY: ys.min() ?? 0,
            maxX: xs.max() ?? 1,
            maxY: ys.max() ?? 1
        )
    }

    static func from(walls: [WallSegment]) -> FloorPlan {
        guard !walls.isEmpty else { return .empty }
        let xs = walls.flatMap { [$0.startX, $0.endX] }
        let ys = walls.flatMap { [$0.startY, $0.endY] }
        return FloorPlan(
            walls: walls,
            minX: xs.min() ?? 0,
            minY: ys.min() ?? 0,
            maxX: xs.max() ?? 1,
            maxY: ys.max() ?? 1
        )
    }

    static func cleanedRoomOutline(from walls: [WallSegment]) -> FloorPlan {
        let points = walls.flatMap {
            [CGPoint(x: $0.startX, y: $0.startY), CGPoint(x: $0.endX, y: $0.endY)]
        }
        guard points.count >= 4 else { return .from(walls: walls) }

        let center = CGPoint(
            x: points.map(\.x).reduce(0, +) / CGFloat(points.count),
            y: points.map(\.y).reduce(0, +) / CGFloat(points.count)
        )
        let xx = points.map { pow($0.x - center.x, 2) }.reduce(0, +)
        let yy = points.map { pow($0.y - center.y, 2) }.reduce(0, +)
        let xy = points.map { ($0.x - center.x) * ($0.y - center.y) }.reduce(0, +)
        let angle = 0.5 * atan2(2 * xy, xx - yy)
        let cosine = cos(angle)
        let sine = sin(angle)
        let rotated = points.map { point in
            CGPoint(
                x: (point.x - center.x) * cosine + (point.y - center.y) * sine,
                y: -(point.x - center.x) * sine + (point.y - center.y) * cosine
            )
        }

        func percentile(_ values: [CGFloat], _ fraction: Double) -> CGFloat {
            let sorted = values.sorted()
            let index = Int((Double(sorted.count - 1) * fraction).rounded())
            return sorted[min(max(index, 0), sorted.count - 1)]
        }

        let minX = percentile(rotated.map(\.x), 0.08)
        let maxX = percentile(rotated.map(\.x), 0.92)
        let minY = percentile(rotated.map(\.y), 0.08)
        let maxY = percentile(rotated.map(\.y), 0.92)
        guard maxX - minX > 0.5, maxY - minY > 0.5 else { return .from(walls: walls) }

        let rotatedCorners: [CGPoint] = [
            CGPoint(x: minX, y: minY), CGPoint(x: maxX, y: minY),
            CGPoint(x: maxX, y: maxY), CGPoint(x: minX, y: maxY)
        ]
        let corners: [CGPoint] = rotatedCorners.map { point in
            let x = center.x + point.x * cosine - point.y * sine
            let y = center.y + point.x * sine + point.y * cosine
            return CGPoint(x: x, y: y)
        }
        return .fromTrace(points: corners)
    }
}

struct HomeRoom: Codable, Identifiable {
    let id: UUID
    var name: String
    var plan: FloorPlan
    var offsetX: Double
    var offsetY: Double
    var assignedNodeIds: [String]

    var minX: Double { offsetX }
    var minY: Double { offsetY }
    var maxX: Double { offsetX + plan.width }
    var maxY: Double { offsetY + plan.height }
}

struct HomeMap: Codable {
    var rooms: [HomeRoom]

    static let empty = HomeMap(rooms: [])

    var minX: Double { rooms.map(\.minX).min() ?? 0 }
    var minY: Double { rooms.map(\.minY).min() ?? 0 }
    var maxX: Double { rooms.map(\.maxX).max() ?? 1 }
    var maxY: Double { rooms.map(\.maxY).max() ?? 1 }
    var width: Double { max(maxX - minX, 1) }
    var height: Double { max(maxY - minY, 1) }
}

enum SignalQuality {
    static func colorName(_ label: String) -> String {
        switch label {
        case "Excellent": return "excellent"
        case "Good": return "good"
        case "Fair": return "fair"
        case "Weak": return "weak"
        default: return "veryWeak"
        }
    }
}
