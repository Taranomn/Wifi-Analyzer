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

struct PhoneNetworkSample: Codable, Identifiable {
    let id: UUID
    let areaId: UUID?
    let timestamp: Date
    let ssid: String?
    let bssid: String?
    let normalizedSignalStrength: Double?
    let interfaceType: String
    let isExpensive: Bool
    let isConstrained: Bool
    let internetReachable: Bool
    let averageLatencyMs: Double?
    let minLatencyMs: Double?
    let maxLatencyMs: Double?
    let jitterMs: Double?
    let packetLossPercent: Double
    let downloadSpeedMbps: Double?
    let uploadSpeedMbps: Double?
    let probesSent: Int
    let probesSucceeded: Int
    let score: Int

    var qualityLabel: String { ProfessionalScore.label(score) }

    func assigned(to areaId: UUID?) -> PhoneNetworkSample {
        PhoneNetworkSample(
            id: UUID(),
            areaId: areaId,
            timestamp: Date(),
            ssid: ssid,
            bssid: bssid,
            normalizedSignalStrength: normalizedSignalStrength,
            interfaceType: interfaceType,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            internetReachable: internetReachable,
            averageLatencyMs: averageLatencyMs,
            minLatencyMs: minLatencyMs,
            maxLatencyMs: maxLatencyMs,
            jitterMs: jitterMs,
            packetLossPercent: packetLossPercent,
            downloadSpeedMbps: downloadSpeedMbps,
            uploadSpeedMbps: uploadSpeedMbps,
            probesSent: probesSent,
            probesSucceeded: probesSucceeded,
            score: score
        )
    }
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

struct SurveyWorkspaceSnapshot: Codable {
    var homeMap: HomeMap
    var buildingFloors: [BuildingFloor]
    var areaLandmarks: [AreaLandmark]
    var locationEquipment: [LocationEquipmentItem]
    var siteTasks: [SiteTask]
    var siteTaskWorldMapData: Data?
    var employees: [Employee]
    var workShifts: [WorkShift]
    var projectFiles: [ProjectFileAttachment]
    var securityCheckItems: [SecurityCheckItem]
    var devices: [SurveyDevice]
    var phoneNetworkSamples: [PhoneNetworkSample]
    var hardwareProfiles: [String: HardwareProfile]
    var calibrations: [CalibrationProfile]
    var projectName: String
    var points: [SurveyPoint]
    var pendingRoomName: String

    enum CodingKeys: String, CodingKey {
        case homeMap, buildingFloors, areaLandmarks, locationEquipment, siteTasks, siteTaskWorldMapData, employees, workShifts, devices
        case projectFiles, securityCheckItems, phoneNetworkSamples, hardwareProfiles, calibrations, projectName, points, pendingRoomName
    }

    init(
        homeMap: HomeMap,
        buildingFloors: [BuildingFloor],
        areaLandmarks: [AreaLandmark],
        locationEquipment: [LocationEquipmentItem] = [],
        siteTasks: [SiteTask] = [],
        siteTaskWorldMapData: Data? = nil,
        employees: [Employee] = [],
        workShifts: [WorkShift] = [],
        projectFiles: [ProjectFileAttachment] = [],
        securityCheckItems: [SecurityCheckItem] = [],
        devices: [SurveyDevice],
        phoneNetworkSamples: [PhoneNetworkSample],
        hardwareProfiles: [String: HardwareProfile],
        calibrations: [CalibrationProfile],
        projectName: String,
        points: [SurveyPoint],
        pendingRoomName: String
    ) {
        self.homeMap = homeMap
        self.buildingFloors = buildingFloors
        self.areaLandmarks = areaLandmarks
        self.locationEquipment = locationEquipment
        self.siteTasks = siteTasks
        self.siteTaskWorldMapData = siteTaskWorldMapData
        self.employees = employees
        self.workShifts = workShifts
        self.projectFiles = projectFiles
        self.securityCheckItems = securityCheckItems
        self.devices = devices
        self.phoneNetworkSamples = phoneNetworkSamples
        self.hardwareProfiles = hardwareProfiles
        self.calibrations = calibrations
        self.projectName = projectName
        self.points = points
        self.pendingRoomName = pendingRoomName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        homeMap = try container.decode(HomeMap.self, forKey: .homeMap)
        buildingFloors = try container.decode([BuildingFloor].self, forKey: .buildingFloors)
        areaLandmarks = try container.decode([AreaLandmark].self, forKey: .areaLandmarks)
        locationEquipment = try container.decodeIfPresent([LocationEquipmentItem].self, forKey: .locationEquipment) ?? []
        siteTasks = try container.decodeIfPresent([SiteTask].self, forKey: .siteTasks) ?? []
        siteTaskWorldMapData = try container.decodeIfPresent(Data.self, forKey: .siteTaskWorldMapData)
        employees = try container.decodeIfPresent([Employee].self, forKey: .employees) ?? []
        workShifts = try container.decodeIfPresent([WorkShift].self, forKey: .workShifts) ?? []
        projectFiles = try container.decodeIfPresent([ProjectFileAttachment].self, forKey: .projectFiles) ?? []
        securityCheckItems = try container.decodeIfPresent([SecurityCheckItem].self, forKey: .securityCheckItems) ?? []
        devices = try container.decode([SurveyDevice].self, forKey: .devices)
        phoneNetworkSamples = try container.decode([PhoneNetworkSample].self, forKey: .phoneNetworkSamples)
        hardwareProfiles = try container.decode([String: HardwareProfile].self, forKey: .hardwareProfiles)
        calibrations = try container.decode([CalibrationProfile].self, forKey: .calibrations)
        projectName = try container.decode(String.self, forKey: .projectName)
        points = try container.decode([SurveyPoint].self, forKey: .points)
        pendingRoomName = try container.decode(String.self, forKey: .pendingRoomName)
    }
}

struct SurveyLocation: Codable, Identifiable {
    let id: UUID
    var name: String
    var address: String
    var directionsNote: String
    var createdAt: Date
    var updatedAt: Date
    var snapshot: SurveyWorkspaceSnapshot

    enum CodingKeys: String, CodingKey {
        case id, name, address, directionsNote, createdAt, updatedAt, snapshot
    }

    init(id: UUID, name: String, address: String = "", directionsNote: String = "", createdAt: Date, updatedAt: Date, snapshot: SurveyWorkspaceSnapshot) {
        self.id = id
        self.name = name
        self.address = address
        self.directionsNote = directionsNote
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.snapshot = snapshot
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        address = try container.decodeIfPresent(String.self, forKey: .address) ?? ""
        directionsNote = try container.decodeIfPresent(String.self, forKey: .directionsNote) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        snapshot = try container.decode(SurveyWorkspaceSnapshot.self, forKey: .snapshot)
    }
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

struct Employee: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var role: String
    var phone: String
    var email: String
}

struct ProjectFileAttachment: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var originalFilename: String
    var localFilename: String
    var contentType: String
    var note: String
    var uploadedByEmployeeId: UUID?
    var createdAt: Date
}

struct SecurityCheckItem: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var category: String
    var areaId: UUID?
    var taskId: UUID?
    var isDone: Bool
    var note: String
    var updatedAt: Date
}

struct WorkShift: Codable, Identifiable, Hashable {
    let id: UUID
    var locationId: UUID
    var locationName: String
    var siteAddress: String
    var title: String
    var startTime: Date
    var endTime: Date
    var employeeIds: [UUID]
    var notes: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, locationId, locationName, siteAddress, title, startTime, endTime, employeeIds, notes, createdAt
    }

    init(id: UUID, locationId: UUID, locationName: String, siteAddress: String = "", title: String, startTime: Date, endTime: Date, employeeIds: [UUID], notes: String, createdAt: Date) {
        self.id = id
        self.locationId = locationId
        self.locationName = locationName
        self.siteAddress = siteAddress
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.employeeIds = employeeIds
        self.notes = notes
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        locationId = try container.decode(UUID.self, forKey: .locationId)
        locationName = try container.decode(String.self, forKey: .locationName)
        siteAddress = try container.decodeIfPresent(String.self, forKey: .siteAddress) ?? ""
        title = try container.decode(String.self, forKey: .title)
        startTime = try container.decode(Date.self, forKey: .startTime)
        endTime = try container.decode(Date.self, forKey: .endTime)
        employeeIds = try container.decode([UUID].self, forKey: .employeeIds)
        notes = try container.decode(String.self, forKey: .notes)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct LocationEquipmentItem: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var quantity: Int
    var category: String
    var areaId: UUID?
    var assigneeIds: [UUID]
    var installTaskId: UUID?
    var note: String
    var isPacked: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category, areaId, assigneeIds, installTaskId, note, isPacked
    }

    init(id: UUID, name: String, quantity: Int, category: String, areaId: UUID? = nil, assigneeIds: [UUID] = [], installTaskId: UUID? = nil, note: String, isPacked: Bool) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.category = category
        self.areaId = areaId
        self.assigneeIds = assigneeIds
        self.installTaskId = installTaskId
        self.note = note
        self.isPacked = isPacked
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        quantity = try container.decode(Int.self, forKey: .quantity)
        category = try container.decode(String.self, forKey: .category)
        areaId = try container.decodeIfPresent(UUID.self, forKey: .areaId)
        assigneeIds = try container.decodeIfPresent([UUID].self, forKey: .assigneeIds) ?? []
        installTaskId = try container.decodeIfPresent(UUID.self, forKey: .installTaskId)
        note = try container.decode(String.self, forKey: .note)
        isPacked = try container.decode(Bool.self, forKey: .isPacked)
    }
}

struct SiteTask: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var category: String
    var note: String
    var status: String
    var floorId: UUID?
    var areaId: UUID?
    var assigneeIds: [UUID]
    var dueDate: Date?
    var priority: String
    var subtasks: [SiteSubtask]
    var wantsARPlacement: Bool
    var worldTransform: [Double]
    var createdAt: Date
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id, title, category, note, status, floorId, areaId, assigneeIds, dueDate, priority, subtasks, wantsARPlacement, worldTransform, createdAt, updatedAt
    }

    init(
        id: UUID,
        title: String,
        category: String,
        note: String,
        status: String,
        floorId: UUID?,
        areaId: UUID?,
        assigneeIds: [UUID] = [],
        dueDate: Date? = nil,
        priority: String = "Normal",
        subtasks: [SiteSubtask] = [],
        wantsARPlacement: Bool = false,
        worldTransform: [Double] = [],
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.note = note
        self.status = status
        self.floorId = floorId
        self.areaId = areaId
        self.assigneeIds = assigneeIds
        self.dueDate = dueDate
        self.priority = priority
        self.subtasks = subtasks
        self.wantsARPlacement = wantsARPlacement
        self.worldTransform = worldTransform
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        category = try container.decode(String.self, forKey: .category)
        note = try container.decode(String.self, forKey: .note)
        status = try container.decode(String.self, forKey: .status)
        floorId = try container.decodeIfPresent(UUID.self, forKey: .floorId)
        areaId = try container.decodeIfPresent(UUID.self, forKey: .areaId)
        assigneeIds = try container.decodeIfPresent([UUID].self, forKey: .assigneeIds) ?? []
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        priority = try container.decodeIfPresent(String.self, forKey: .priority) ?? "Normal"
        subtasks = try container.decodeIfPresent([SiteSubtask].self, forKey: .subtasks) ?? []
        wantsARPlacement = try container.decodeIfPresent(Bool.self, forKey: .wantsARPlacement) ?? false
        worldTransform = try container.decodeIfPresent([Double].self, forKey: .worldTransform) ?? []
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    var x: Double { worldTransform.indices.contains(12) ? worldTransform[12] : 0 }
    var y: Double { worldTransform.indices.contains(13) ? worldTransform[13] : 0 }
    var z: Double { worldTransform.indices.contains(14) ? worldTransform[14] : 0 }
}

struct SiteSubtask: Codable, Identifiable, Hashable {
    let id: UUID
    var title: String
    var isDone: Bool
    var createdAt: Date
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

    static func phone(_ sample: PhoneNetworkSample) -> Int {
        phoneScore(
            normalizedSignalStrength: sample.normalizedSignalStrength,
            averageLatencyMs: sample.averageLatencyMs,
            packetLossPercent: sample.packetLossPercent,
            jitterMs: sample.jitterMs,
            downloadSpeedMbps: sample.downloadSpeedMbps,
            uploadSpeedMbps: sample.uploadSpeedMbps,
            internetReachable: sample.internetReachable,
            timestamp: sample.timestamp
        )
    }

    static func phoneScore(
        normalizedSignalStrength: Double?,
        averageLatencyMs: Double?,
        packetLossPercent: Double,
        jitterMs: Double?,
        downloadSpeedMbps: Double? = nil,
        uploadSpeedMbps: Double? = nil,
        internetReachable: Bool,
        timestamp: Date = Date()
    ) -> Int {
        let signal = phoneSignalScore(normalizedSignalStrength)
        let latency = latencyScore(averageLatencyMs)
        let loss = lossScore(packetLossPercent)
        let jitter = jitterScore(jitterMs)
        let speed = averageScore([downloadSpeedMbps, uploadSpeedMbps].map(speedScore))
        let path = internetReachable ? 100.0 : 0
        let freshness = max(0, 100 - Date().timeIntervalSince(timestamp) * 0.5)
        return Int((signal * 0.15 + latency * 0.22 + loss * 0.22 + jitter * 0.10 + speed * 0.12 + path * 0.14 + freshness * 0.05).rounded())
    }

    private static func phoneSignalScore(_ value: Double?) -> Double {
        guard let value else { return 45 }
        if value >= 0.85 { return 100 }
        if value >= 0.65 { return 80 }
        if value >= 0.45 { return 55 }
        if value >= 0.25 { return 30 }
        return 10
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
    private static func averageScore(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 40 }
        return values.reduce(0, +) / Double(values.count)
    }
    private static func jitterScore(_ value: Double?) -> Double {
        guard let value else { return 40 }
        if value < 10 { return 100 }
        if value <= 25 { return 75 }
        if value <= 50 { return 45 }
        return 15
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
    var x: Double
    var y: Double
    var z: Double
    var floorId: UUID?
    var assignedNodeIds: [String]
    var isMapped: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, x, y, z, floorId, assignedNodeIds, isMapped
    }

    init(id: UUID, name: String, x: Double, y: Double, z: Double, floorId: UUID?, assignedNodeIds: [String], isMapped: Bool = true) {
        self.id = id
        self.name = name
        self.x = x
        self.y = y
        self.z = z
        self.floorId = floorId
        self.assignedNodeIds = assignedNodeIds
        self.isMapped = isMapped
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        x = try container.decode(Double.self, forKey: .x)
        y = try container.decode(Double.self, forKey: .y)
        z = try container.decode(Double.self, forKey: .z)
        floorId = try container.decodeIfPresent(UUID.self, forKey: .floorId)
        assignedNodeIds = try container.decodeIfPresent([String].self, forKey: .assignedNodeIds) ?? []
        isMapped = try container.decodeIfPresent(Bool.self, forKey: .isMapped) ?? true
    }

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
