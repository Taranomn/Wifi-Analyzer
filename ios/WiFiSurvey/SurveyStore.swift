import Combine
import Foundation
import RoomPlan

@MainActor
final class SurveyStore: ObservableObject {
    @Published var espHost: String
    @Published var status: WiFiStatus?
    @Published var homeMap: HomeMap
    @Published var buildingFloors: [BuildingFloor]
    @Published var areaLandmarks: [AreaLandmark]
    @Published var devices: [SurveyDevice]
    @Published var phoneTester = PhoneTesterStatus()
    @Published var hardwareProfiles: [String: HardwareProfile]
    @Published var calibrations: [CalibrationProfile]
    @Published var projectName: String
    @Published var points: [SurveyPoint]
    @Published var selectedRoomId: UUID?
    @Published var selectedAreaId: UUID?
    @Published var selectedLocation: CGPoint?
    @Published var pendingRoomName = "Room"
    @Published var message: String?
    @Published var isLoading = false
    @Published var networks: [WiFiNetwork] = []

    private let defaults = UserDefaults.standard
    private var pollTask: Task<Void, Never>?

    init() {
        espHost = UserDefaults.standard.string(forKey: "espHost") ?? "192.168.4.1"
        if let saved = Self.load(HomeMap.self, key: "homeMap") {
            homeMap = saved
        } else if let legacy = Self.load(FloorPlan.self, key: "floorPlan"), !legacy.walls.isEmpty {
            homeMap = HomeMap(rooms: [HomeRoom(id: UUID(), name: "Room 1", plan: legacy, offsetX: 0, offsetY: 0, assignedNodeIds: ["ESP32-01"])])
        } else {
            homeMap = .empty
        }
        points = Self.load([SurveyPoint].self, key: "surveyPoints") ?? []
        let savedLandmarks = Self.load([AreaLandmark].self, key: "areaLandmarks") ?? []
        var savedFloors = Self.load([BuildingFloor].self, key: "buildingFloors") ?? []
        if savedFloors.isEmpty {
            savedFloors = [BuildingFloor(id: UUID(), name: "Floor 1", order: 0)]
        }
        buildingFloors = savedFloors.sorted { $0.order < $1.order }
        let defaultFloorId = savedFloors[0].id
        areaLandmarks = savedLandmarks.map {
            var landmark = $0
            landmark.floorId = landmark.floorId ?? defaultFloorId
            return landmark
        }
        devices = Self.load([SurveyDevice].self, key: "surveyDevices") ?? []
        hardwareProfiles = Self.load([String: HardwareProfile].self, key: "hardwareProfiles") ?? [:]
        calibrations = Self.load([CalibrationProfile].self, key: "calibrations") ?? []
        projectName = UserDefaults.standard.string(forKey: "projectName") ?? "Wi-Fi Survey"
        selectedRoomId = homeMap.rooms.first?.id
        selectedAreaId = areaLandmarks.first?.id
        Self.save(buildingFloors, key: "buildingFloors")
        Self.save(areaLandmarks, key: "areaLandmarks")
    }

    var hasFloorPlan: Bool { !homeMap.rooms.isEmpty }
    var selectedRoom: HomeRoom? { homeMap.rooms.first { $0.id == selectedRoomId } }
    var selectedArea: AreaLandmark? { areaLandmarks.first { $0.id == selectedAreaId } }

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                await refreshAllDevices()
                await refreshPhoneTester()
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func saveHost() {
        espHost = espHost
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "https://", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        defaults.set(espHost, forKey: "espHost")
        Task { await refreshStatus(showErrors: true) }
    }

    func useDiscoveredHost(_ host: String) {
        espHost = host
        defaults.set(host, forKey: "espHost")
        Task { await refreshStatus(showErrors: false) }
    }

    func register(status: BLEDeviceStatus) {
        guard !status.nodeId.isEmpty, !status.localIp.isEmpty else { return }
        upsertDevice(
            nodeId: status.nodeId, host: status.localIp, connected: status.connected,
            ssid: status.ssid, rssi: status.rssi, quality: status.qualityLabel, channel: status.channel
        )
    }

    func refreshStatus(showErrors: Bool = true) async {
        do {
            status = try await ESPService(host: espHost).status()
        } catch {
            status = nil
            if showErrors { message = "Could not reach the ESP32 at \(espHost)." }
        }
    }

    func scanNetworks() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scanned = try await ESPService(host: espHost).scan()
            networks = Dictionary(grouping: scanned, by: \.ssid)
                .compactMap { $0.value.max(by: { $0.rssi < $1.rssi }) }
                .sorted { $0.rssi > $1.rssi }
        } catch {
            message = "Network scan failed. Connect the iPhone to WiFi-Survey-Setup and use 192.168.4.1."
        }
    }

    func connectESP(ssid: String, password: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            try await ESPService(host: espHost).connect(ssid: ssid, password: password)
            message = "ESP32 is connecting to \(ssid). Its setup network remains available."
            return true
        } catch {
            message = "Could not send Wi-Fi credentials to the ESP32."
            return false
        }
    }

    func accept(room: CapturedRoom) {
        addRoom(plan: .from(room: room))
    }

    func accept(tracePoints: [CGPoint]) {
        addRoom(plan: .fromTrace(points: tracePoints))
    }

    func accept(detectedWalls: [WallSegment]) {
        addRoom(plan: .from(walls: detectedWalls))
    }

    func clearPlan() {
        homeMap = .empty
        selectedRoomId = nil
        selectedLocation = nil
        points = []
        Self.save(homeMap, key: "homeMap")
        Self.save(points, key: "surveyPoints")
    }

    func accept(areaLandmarks: [AreaLandmark]) {
        self.areaLandmarks = areaLandmarks
        selectedAreaId = areaLandmarks.first?.id
        Self.save(areaLandmarks, key: "areaLandmarks")
        message = "\(areaLandmarks.count) areas mapped with measured positions."
    }

    @discardableResult
    func addFloor() -> BuildingFloor {
        let floor = BuildingFloor(id: UUID(), name: "Floor \(buildingFloors.count + 1)", order: buildingFloors.count)
        buildingFloors.append(floor)
        Self.save(buildingFloors, key: "buildingFloors")
        return floor
    }

    func clearAreaMap() {
        areaLandmarks = []
        selectedAreaId = nil
        Self.save(areaLandmarks, key: "areaLandmarks")
    }

    func assignCurrentNodeToArea(_ nodeId: String) {
        guard let selectedAreaId, let index = areaLandmarks.firstIndex(where: { $0.id == selectedAreaId }) else { return }
        for areaIndex in areaLandmarks.indices {
            areaLandmarks[areaIndex].assignedNodeIds.removeAll { $0 == nodeId }
        }
        areaLandmarks[index].assignedNodeIds.append(nodeId)
        Self.save(areaLandmarks, key: "areaLandmarks")
    }

    func assignPhoneToSelectedArea() {
        assignCurrentNodeToArea("IPHONE")
    }

    func removeDevice(_ nodeId: String) {
        devices.removeAll { $0.nodeId == nodeId }
        for index in areaLandmarks.indices {
            areaLandmarks[index].assignedNodeIds.removeAll { $0 == nodeId }
        }
        Self.save(devices, key: "surveyDevices")
        Self.save(areaLandmarks, key: "areaLandmarks")
    }

    func deviceResults(in area: AreaLandmark) -> [SurveyDevice] {
        devices.filter { area.assignedNodeIds.contains($0.nodeId) }
    }

    func areaScore(_ area: AreaLandmark) -> Int? {
        let scores = deviceResults(in: area).map(ProfessionalScore.device)
        guard !scores.isEmpty else { return nil }
        return Int(Double(scores.reduce(0, +)) / Double(scores.count))
    }

    var overallScore: Int? {
        let scores = areaLandmarks.compactMap(areaScore)
        guard !scores.isEmpty else { return nil }
        return Int(Double(scores.reduce(0, +)) / Double(scores.count))
    }

    func recommendation(for area: AreaLandmark) -> SurveyRecommendation {
        let assigned = deviceResults(in: area)
        let score = areaScore(area) ?? 0
        let weakRssi = assigned.contains { ($0.rssi ?? -100) < -70 }
        let badLoss = assigned.contains { ($0.packetLossPercent ?? 0) > 5 }
        let badLatency = assigned.contains { ($0.averagePingMs ?? 0) > 80 }
        let congested = assigned.contains { $0.channelCongestion == "High" || $0.channelCongestion == "Severe" }
        if weakRssi && badLoss {
            return recommendation(area, "critical", "Weak coverage and packet loss", "The area has low signal and unreliable delivery.", "Add an AP closer to this area.")
        }
        if congested {
            return recommendation(area, "warning", "Channel congestion detected", "Nearby networks are competing with the current AP channel.", "Change the AP to a recommended 2.4 GHz channel.")
        }
        if badLoss || badLatency {
            return recommendation(area, "warning", "Good signal but poor network quality", "Latency or packet loss indicates interference or AP load.", "Check interference, cabling, and AP utilization.")
        }
        if score < 50 {
            return recommendation(area, "critical", "Weak coverage", "The professional survey score is below installer target.", "Move the AP toward this area or add another AP.")
        }
        return recommendation(area, "info", "Healthy coverage", "Measured network quality is suitable for normal use.", "No action needed.")
    }

    func updateHardwareProfile(nodeId: String, profile: HardwareProfile) {
        hardwareProfiles[nodeId] = profile
        Self.save(hardwareProfiles, key: "hardwareProfiles")
    }

    func saveCalibration(_ profile: CalibrationProfile) {
        calibrations.append(profile)
        Self.save(calibrations, key: "calibrations")
    }

    func calibratedRealDeviceRssi(for device: SurveyDevice, in area: AreaLandmark) -> Int? {
        guard let rssi = device.rssi else { return nil }
        let hardwareOffset = hardwareProfiles[device.nodeId]?.calibrationOffsetDbm ?? 0
        let comparisonOffset = calibrations
            .filter { $0.nodeId == device.nodeId && $0.areaId == area.id }
            .max(by: { $0.createdAt < $1.createdAt })?.calibrationOffsetDbm ?? 0
        return Int((Double(rssi) + hardwareOffset + comparisonOffset).rounded())
    }

    func apPlacementSuggestions() -> [APPlacementSuggestion] {
        var allSuggestions: [APPlacementSuggestion] = []
        for floor in buildingFloors {
            let areas = areaLandmarks.filter { $0.floorId == floor.id }
            guard !areas.isEmpty else { continue }
            let weak = areas.filter { (areaScore($0) ?? 0) < 70 }
            guard !weak.isEmpty else { continue }

            var remaining = weak
            while !remaining.isEmpty {
                let candidate = areas.min { left, right in
                    remaining.map { left.distance(to: $0) }.reduce(0, +) <
                    remaining.map { right.distance(to: $0) }.reduce(0, +)
                } ?? remaining[0]
                let covered = remaining.filter { candidate.distance(to: $0) <= 9 }
                let effectiveCovered = covered.isEmpty ? [remaining[0]] : covered
                let estimates = deviceResults(in: candidate).compactMap { calibratedRealDeviceRssi(for: $0, in: candidate) }
                allSuggestions.append(APPlacementSuggestion(
                    floorId: floor.id,
                    candidateAreaId: candidate.id,
                    title: "Candidate AP near \(candidate.name)",
                    reason: "Improves the weakest nearby areas while keeping the proposed AP within about 9 m.",
                    coveredAreaNames: effectiveCovered.map(\.name),
                    estimatedRealDeviceRssi: estimates.isEmpty ? nil : estimates.reduce(0, +) / estimates.count
                ))
                let coveredIds = Set(effectiveCovered.map(\.id))
                remaining.removeAll { coveredIds.contains($0.id) }
            }
        }
        return allSuggestions
    }

    func saveProjectName() {
        defaults.set(projectName, forKey: "projectName")
    }

    func reportData() -> Data {
        struct Report: Encodable {
            let projectName: String
            let generatedAt: Date
            let overallScore: Int?
            let areas: [AreaReport]
            let devices: [SurveyDevice]
            let hardwareProfiles: [String: HardwareProfile]
            let calibrations: [CalibrationProfile]
        }
        struct AreaReport: Encodable {
            let area: AreaLandmark
            let score: Int?
            let devices: [SurveyDevice]
            let recommendation: SurveyRecommendation
        }
        let areas = areaLandmarks.map {
            AreaReport(area: $0, score: areaScore($0), devices: deviceResults(in: $0), recommendation: recommendation(for: $0))
        }
        return (try? JSONEncoder.pretty.encode(Report(
            projectName: projectName, generatedAt: Date(), overallScore: overallScore,
            areas: areas, devices: devices, hardwareProfiles: hardwareProfiles, calibrations: calibrations
        ))) ?? Data()
    }

    func recordArea(status: BLEDeviceStatus, note: String) -> Bool {
        guard let area = selectedArea else {
            message = "Select the area containing the ESP32 first."
            return false
        }
        guard status.connected, let rssi = status.rssi else {
            message = "The ESP32 is not connected to the target Wi-Fi."
            return false
        }
        points.append(SurveyPoint(
            id: UUID(), timestamp: Date(), nodeId: status.nodeId, roomId: area.id,
            roomName: area.name, note: note, x: area.x, y: area.z, rssi: rssi,
            qualityLabel: status.qualityLabel, ssid: status.ssid, bssid: status.bssid,
            channel: status.channel
        ))
        Self.save(points, key: "surveyPoints")
        assignCurrentNodeToArea(status.nodeId)
        message = "Measurement recorded in \(area.name)."
        return true
    }

    func record(status: BLEDeviceStatus, note: String) -> Bool {
        guard let room = selectedRoom else {
            message = "Select the room containing the ESP32 first."
            return false
        }
        guard let selectedLocation else {
            message = "Tap your current position on the floor plan first."
            return false
        }

        guard status.connected, let rssi = status.rssi else {
            message = "The ESP32 is not connected to the target Wi-Fi."
            return false
        }

        points.append(SurveyPoint(
            id: UUID(),
            timestamp: Date(),
            nodeId: status.nodeId,
            roomId: room.id,
            roomName: room.name,
            note: note,
            x: selectedLocation.x,
            y: selectedLocation.y,
            rssi: rssi,
            qualityLabel: status.qualityLabel,
            ssid: status.ssid,
            bssid: status.bssid,
            channel: status.channel
        ))
        Self.save(points, key: "surveyPoints")
        message = "Measurement recorded."
        return true
    }

    func assignCurrentNode(_ nodeId: String) {
        guard let selectedRoomId, let index = homeMap.rooms.firstIndex(where: { $0.id == selectedRoomId }) else { return }
        for roomIndex in homeMap.rooms.indices {
            homeMap.rooms[roomIndex].assignedNodeIds.removeAll { $0 == nodeId }
        }
        homeMap.rooms[index].assignedNodeIds.append(nodeId)
        Self.save(homeMap, key: "homeMap")
    }

    func moveSelectedRoom(dx: Double, dy: Double) {
        guard let selectedRoomId, let index = homeMap.rooms.firstIndex(where: { $0.id == selectedRoomId }) else { return }
        homeMap.rooms[index].offsetX += dx
        homeMap.rooms[index].offsetY += dy
        Self.save(homeMap, key: "homeMap")
    }

    func deleteSelectedRoom() {
        guard let selectedRoomId else { return }
        homeMap.rooms.removeAll { $0.id == selectedRoomId }
        points.removeAll { $0.roomId == selectedRoomId }
        self.selectedRoomId = homeMap.rooms.first?.id
        selectedLocation = nil
        Self.save(homeMap, key: "homeMap")
        Self.save(points, key: "surveyPoints")
    }

    func delete(point: SurveyPoint) {
        points.removeAll { $0.id == point.id }
        Self.save(points, key: "surveyPoints")
    }

    func csvData() -> Data {
        let header = "timestamp,node_id,room_name,note,x,y,rssi,quality_label,ssid,bssid,channel\n"
        let rows = points.map { point in
            [
                point.timestamp.ISO8601Format(), point.nodeId, point.roomName, point.note,
                String(point.x), String(point.y), String(point.rssi), point.qualityLabel,
                point.ssid, point.bssid, String(point.channel)
            ].map(Self.csvEscape).joined(separator: ",")
        }.joined(separator: "\n")
        return Data((header + rows).utf8)
    }

    private static func csvEscape(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func addRoom(plan: FloorPlan) {
        guard !plan.walls.isEmpty else {
            message = "No reliable walls were captured. Try scanning again or use Walk Perimeter."
            return
        }
        let offsetX = (homeMap.rooms.map(\.maxX).max() ?? -0.5) + 0.5
        let room = HomeRoom(
            id: UUID(),
            name: pendingRoomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Room \(homeMap.rooms.count + 1)" : pendingRoomName,
            plan: plan,
            offsetX: offsetX,
            offsetY: 0,
            assignedNodeIds: homeMap.rooms.isEmpty ? ["ESP32-01"] : []
        )
        homeMap.rooms.append(room)
        selectedRoomId = room.id
        selectedLocation = nil
        pendingRoomName = "Room"
        Self.save(homeMap, key: "homeMap")
        message = "\(room.name) added. Arrange it beside the connected rooms."
    }

    private func refreshAllDevices() async {
        for device in devices {
            do {
                async let statusRequest = ESPService(host: device.host).status()
                async let diagnosticsRequest = ESPService(host: device.host).diagnostics()
                async let channelRequest = ESPService(host: device.host).channelAnalysis()
                let (status, diagnostics, channel) = try await (statusRequest, diagnosticsRequest, channelRequest)
                var speed = device.localSpeedMbps
                if speed == nil {
                    speed = try? await ESPService(host: device.host).localSpeedTest()
                }
                upsertDevice(
                    nodeId: status.nodeId, host: status.localIp.isEmpty ? device.host : status.localIp,
                    connected: status.connected, ssid: status.ssid, rssi: status.rssi,
                    quality: status.qualityLabel, channel: status.channel,
                    loss: diagnostics.packetLossPercent, ping: diagnostics.averagePingMs,
                    minPing: diagnostics.minPingMs, maxPing: diagnostics.maxPingMs,
                    congestion: channel.currentChannelCongestion, speed: speed
                )
            } catch {
                if let index = devices.firstIndex(where: { $0.nodeId == device.nodeId }) {
                    devices[index].connected = false
                }
            }
        }
        Self.save(devices, key: "surveyDevices")
    }

    private func refreshPhoneTester() async {
        guard let host = devices.first(where: \.connected)?.host else {
            phoneTester.connected = false
            return
        }
        do {
            phoneTester.latencyMs = try await ESPService(host: host).responseLatencyMs()
            phoneTester.connected = true
            phoneTester.lastUpdated = Date()
        } catch {
            phoneTester.connected = false
        }
    }

    func runPhoneSpeedTest() async {
        guard let host = devices.first(where: \.connected)?.host else {
            message = "Connect at least one ESP32 to the same Wi-Fi network first."
            return
        }
        do {
            phoneTester.localSpeedMbps = try await ESPService(host: host).localSpeedTest()
            phoneTester.connected = true
            phoneTester.lastUpdated = Date()
        } catch {
            message = "The phone could not reach an ESP32 over Wi-Fi."
        }
    }

    private func upsertDevice(nodeId: String, host: String, connected: Bool, ssid: String, rssi: Int?, quality: String, channel: Int, loss: Double? = nil, ping: Double? = nil, minPing: Double? = nil, maxPing: Double? = nil, congestion: String? = nil, speed: Double? = nil) {
        let previous = devices.first { $0.nodeId == nodeId }
        let device = SurveyDevice(
            nodeId: nodeId, host: host, connected: connected, ssid: ssid, rssi: rssi,
            qualityLabel: quality, channel: channel, lastSeen: Date(),
            packetLossPercent: loss ?? previous?.packetLossPercent,
            averagePingMs: ping ?? previous?.averagePingMs,
            minPingMs: minPing ?? previous?.minPingMs,
            maxPingMs: maxPing ?? previous?.maxPingMs,
            localSpeedMbps: speed ?? previous?.localSpeedMbps,
            channelCongestion: congestion ?? previous?.channelCongestion
        )
        if let previous = devices.first(where: { $0.host == host && $0.nodeId != nodeId }) {
            for index in areaLandmarks.indices where areaLandmarks[index].assignedNodeIds.contains(previous.nodeId) {
                areaLandmarks[index].assignedNodeIds.removeAll { $0 == previous.nodeId }
                areaLandmarks[index].assignedNodeIds.append(nodeId)
            }
            devices.removeAll { $0.nodeId == previous.nodeId }
            Self.save(areaLandmarks, key: "areaLandmarks")
        }
        if let index = devices.firstIndex(where: { $0.nodeId == nodeId }) {
            devices[index] = device
        } else {
            devices.append(device)
        }
        Self.save(devices, key: "surveyDevices")
    }

    private func recommendation(_ area: AreaLandmark, _ severity: String, _ title: String, _ description: String, _ action: String) -> SurveyRecommendation {
        SurveyRecommendation(id: UUID(), areaId: area.id, severity: severity, title: title, description: description, suggestedAction: action)
    }

    private static func save<T: Encodable>(_ value: T, key: String) {
        UserDefaults.standard.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }
}
