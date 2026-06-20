import Combine
import Foundation
import RoomPlan
import UniformTypeIdentifiers
import UserNotifications

@MainActor
final class SurveyStore: ObservableObject {
    @Published var espHost: String
    @Published var status: WiFiStatus?
    @Published var homeMap: HomeMap
    @Published var buildingFloors: [BuildingFloor]
    @Published var areaLandmarks: [AreaLandmark]
    @Published var locationEquipment: [LocationEquipmentItem]
    @Published var siteTasks: [SiteTask]
    @Published var siteTaskWorldMapData: Data?
    @Published var employees: [Employee]
    @Published var workShifts: [WorkShift]
    @Published var projectFiles: [ProjectFileAttachment]
    @Published var securityCheckItems: [SecurityCheckItem]
    @Published var devices: [SurveyDevice]
    @Published var phoneTester = PhoneTesterStatus()
    @Published var phoneNetworkSamples: [PhoneNetworkSample]
    @Published var hardwareProfiles: [String: HardwareProfile]
    @Published var calibrations: [CalibrationProfile]
    @Published var projectName: String
    @Published var locations: [SurveyLocation] = []
    @Published var currentLocationId: UUID?
    @Published var hasChosenLocation = false
    @Published var points: [SurveyPoint]
    @Published var selectedRoomId: UUID?
    @Published var selectedAreaId: UUID?
    @Published var selectedLocation: CGPoint?
    @Published var pendingRoomName = "Room"
    @Published var message: String?
    @Published var isLoading = false
    @Published var networks: [WiFiNetwork] = []
    @Published var currentUserId: UUID?

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
        locationEquipment = Self.load([LocationEquipmentItem].self, key: "locationEquipment") ?? []
        siteTasks = Self.load([SiteTask].self, key: "siteTasks") ?? []
        siteTaskWorldMapData = UserDefaults.standard.data(forKey: "siteTaskWorldMapData")
        employees = Self.load([Employee].self, key: "employees") ?? []
        workShifts = Self.load([WorkShift].self, key: "workShifts") ?? []
        projectFiles = Self.load([ProjectFileAttachment].self, key: "projectFiles") ?? []
        securityCheckItems = Self.load([SecurityCheckItem].self, key: "securityCheckItems") ?? []
        devices = Self.load([SurveyDevice].self, key: "surveyDevices") ?? []
        phoneNetworkSamples = Self.load([PhoneNetworkSample].self, key: "phoneNetworkSamples") ?? []
        hardwareProfiles = Self.load([String: HardwareProfile].self, key: "hardwareProfiles") ?? [:]
        calibrations = Self.load([CalibrationProfile].self, key: "calibrations") ?? []
        projectName = UserDefaults.standard.string(forKey: "projectName") ?? "Wi-Fi Survey"
        selectedRoomId = homeMap.rooms.first?.id
        selectedAreaId = areaLandmarks.first?.id
        currentUserId = UserDefaults.standard.string(forKey: "currentUserId").flatMap(UUID.init(uuidString:))
        Self.save(buildingFloors, key: "buildingFloors")
        Self.save(self.areaLandmarks, key: "areaLandmarks")
        seedDemoUsers()
        loadLocations()
    }

    var hasFloorPlan: Bool { !homeMap.rooms.isEmpty }
    var selectedRoom: HomeRoom? { homeMap.rooms.first { $0.id == selectedRoomId } }
    var selectedArea: AreaLandmark? { areaLandmarks.first { $0.id == selectedAreaId } }
    var currentLocation: SurveyLocation? { locations.first { $0.id == currentLocationId } }
    var currentUser: Employee? { employees.first { $0.id == currentUserId } }
    var mappedAreaLandmarks: [AreaLandmark] { areaLandmarks.filter(\.isMapped) }
    var isSignedIn: Bool { currentUser != nil }

    var canManagePermanentSuggestions: Bool {
        hasRoleAccess(["Admin", "Manager", "Supervisor"])
    }

    var canDeleteRecords: Bool {
        hasRoleAccess(["Admin", "Manager", "Supervisor"])
    }

    var canManageShifts: Bool {
        hasRoleAccess(["Admin", "Manager", "Supervisor"])
    }

    var canManageProjects: Bool {
        hasRoleAccess(["Admin", "Manager", "Supervisor"])
    }

    func signIn(as employee: Employee) {
        currentUserId = employee.id
        defaults.set(employee.id.uuidString, forKey: "currentUserId")
    }

    func signOut() {
        currentUserId = nil
        defaults.removeObject(forKey: "currentUserId")
    }

    var shiftsForCurrentLocation: [WorkShift] {
        guard let currentLocationId else { return [] }
        return workShifts.filter { $0.locationId == currentLocationId }.sorted { $0.startTime < $1.startTime }
    }

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
        let mappedNames = Set(areaLandmarks.map { $0.name.lowercased() })
        let unmapped = self.areaLandmarks.filter { !$0.isMapped && !mappedNames.contains($0.name.lowercased()) }
        self.areaLandmarks = areaLandmarks + unmapped
        selectedAreaId = areaLandmarks.first?.id ?? self.areaLandmarks.first?.id
        Self.save(self.areaLandmarks, key: "areaLandmarks")
        updateCurrentLocationSnapshot()
        message = "\(areaLandmarks.count) areas mapped with measured positions."
    }

    func addUnmappedArea(name: String, floorId: UUID?) {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        let area = AreaLandmark(
            id: UUID(),
            name: cleanName,
            x: 0,
            y: 0,
            z: 0,
            floorId: floorId ?? buildingFloors.first?.id,
            assignedNodeIds: [],
            isMapped: false
        )
        areaLandmarks.append(area)
        selectedAreaId = area.id
        Self.save(areaLandmarks, key: "areaLandmarks")
        updateCurrentLocationSnapshot()
    }

    @discardableResult
    func addFloor() -> BuildingFloor {
        let floor = BuildingFloor(id: UUID(), name: "Floor \(buildingFloors.count + 1)", order: buildingFloors.count)
        buildingFloors.append(floor)
        Self.save(buildingFloors, key: "buildingFloors")
        updateCurrentLocationSnapshot()
        return floor
    }

    func save(floor: BuildingFloor) {
        if let index = buildingFloors.firstIndex(where: { $0.id == floor.id }) {
            buildingFloors[index] = floor
        } else {
            buildingFloors.append(floor)
        }
        buildingFloors.sort { $0.order < $1.order }
        Self.save(buildingFloors, key: "buildingFloors")
        updateCurrentLocationSnapshot()
    }

    func clearAreaMap() {
        for index in areaLandmarks.indices {
            areaLandmarks[index].x = 0
            areaLandmarks[index].y = 0
            areaLandmarks[index].z = 0
            areaLandmarks[index].isMapped = false
        }
        Self.save(areaLandmarks, key: "areaLandmarks")
        updateCurrentLocationSnapshot()
        message = "Map positions cleared. Area names are still available for tasks and testing."
    }

    func save(siteTask: SiteTask) {
        if let index = siteTasks.firstIndex(where: { $0.id == siteTask.id }) {
            siteTasks[index] = siteTask
        } else {
            siteTasks.append(siteTask)
        }
        Self.save(siteTasks, key: "siteTasks")
        updateCurrentLocationSnapshot()
    }

    func addSiteTask(title: String, category: String, note: String, floorId: UUID?, areaId: UUID?, assigneeIds: [UUID]) {
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanTitle.isEmpty else { return }
        let now = Date()
        save(siteTask: SiteTask(
            id: UUID(),
            title: cleanTitle,
            category: category,
            note: note,
            status: "To Do",
            floorId: floorId,
            areaId: areaId,
            assigneeIds: assigneeIds,
            worldTransform: [],
            createdAt: now,
            updatedAt: now
        ))
    }

    func updateSiteTaskStatus(_ task: SiteTask, status: String) {
        guard let index = siteTasks.firstIndex(where: { $0.id == task.id }) else { return }
        siteTasks[index].status = status
        siteTasks[index].updatedAt = Date()
        Self.save(siteTasks, key: "siteTasks")
        updateCurrentLocationSnapshot()
    }

    func assignTasks(_ taskIds: Set<UUID>, to employeeIds: Set<UUID>) {
        guard !taskIds.isEmpty else { return }
        for index in siteTasks.indices where taskIds.contains(siteTasks[index].id) {
            siteTasks[index].assigneeIds = Array(employeeIds)
            siteTasks[index].updatedAt = Date()
        }
        Self.save(siteTasks, key: "siteTasks")
        updateCurrentLocationSnapshot()
    }

    func markTaskForAR(_ task: SiteTask) {
        var updated = task
        updated.wantsARPlacement = true
        updated.updatedAt = Date()
        save(siteTask: updated)
    }

    func delete(siteTask: SiteTask) {
        siteTasks.removeAll { $0.id == siteTask.id }
        securityCheckItems.removeAll { $0.taskId == siteTask.id }
        Self.save(siteTasks, key: "siteTasks")
        Self.save(securityCheckItems, key: "securityCheckItems")
        updateCurrentLocationSnapshot()
    }

    func delete(area: AreaLandmark) {
        areaLandmarks.removeAll { $0.id == area.id }
        siteTasks.removeAll { $0.areaId == area.id }
        locationEquipment.removeAll { $0.areaId == area.id }
        securityCheckItems.removeAll { $0.areaId == area.id }
        selectedAreaId = areaLandmarks.first?.id
        Self.save(areaLandmarks, key: "areaLandmarks")
        Self.save(siteTasks, key: "siteTasks")
        Self.save(locationEquipment, key: "locationEquipment")
        Self.save(securityCheckItems, key: "securityCheckItems")
        updateCurrentLocationSnapshot()
    }

    func saveSiteTaskWorldMap(_ data: Data) {
        siteTaskWorldMapData = data
        defaults.set(data, forKey: "siteTaskWorldMapData")
        updateCurrentLocationSnapshot()
    }

    func save(employee: Employee) {
        if let index = employees.firstIndex(where: { $0.id == employee.id }) {
            employees[index] = employee
        } else {
            employees.append(employee)
        }
        Self.save(employees, key: "employees")
        updateCurrentLocationSnapshot()
    }

    func delete(employee: Employee) {
        employees.removeAll { $0.id == employee.id }
        for index in siteTasks.indices {
            siteTasks[index].assigneeIds.removeAll { $0 == employee.id }
        }
        for index in workShifts.indices {
            workShifts[index].employeeIds.removeAll { $0 == employee.id }
        }
        Self.save(employees, key: "employees")
        Self.save(siteTasks, key: "siteTasks")
        Self.save(workShifts, key: "workShifts")
        updateCurrentLocationSnapshot()
    }

    func save(workShift: WorkShift) {
        if let index = workShifts.firstIndex(where: { $0.id == workShift.id }) {
            workShifts[index] = workShift
        } else {
            workShifts.append(workShift)
        }
        Self.save(workShifts, key: "workShifts")
        updateCurrentLocationSnapshot()
        scheduleNotification(for: workShift)
    }

    func save(projectFile: ProjectFileAttachment) {
        if let index = projectFiles.firstIndex(where: { $0.id == projectFile.id }) {
            projectFiles[index] = projectFile
        } else {
            projectFiles.append(projectFile)
        }
        Self.save(projectFiles, key: "projectFiles")
        updateCurrentLocationSnapshot()
    }

    func delete(projectFile: ProjectFileAttachment) {
        projectFiles.removeAll { $0.id == projectFile.id }
        Self.save(projectFiles, key: "projectFiles")
        if let url = localFileURL(for: projectFile) {
            try? FileManager.default.removeItem(at: url)
        }
        updateCurrentLocationSnapshot()
    }

    func importProjectFile(from url: URL) {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart { url.stopAccessingSecurityScopedResource() }
        }
        do {
            let folder = try projectFilesDirectory()
            let destinationName = "\(UUID().uuidString)-\(url.lastPathComponent)"
            let destination = folder.appendingPathComponent(destinationName)
            try FileManager.default.copyItem(at: url, to: destination)
            save(projectFile: ProjectFileAttachment(
                id: UUID(),
                name: url.deletingPathExtension().lastPathComponent,
                originalFilename: url.lastPathComponent,
                localFilename: destinationName,
                contentType: UTType(filenameExtension: url.pathExtension)?.identifier ?? "public.data",
                note: "",
                uploadedByEmployeeId: currentUserId,
                createdAt: Date()
            ))
        } catch {
            message = "Could not add this file to the project."
        }
    }

    func localFileURL(for file: ProjectFileAttachment) -> URL? {
        try? projectFilesDirectory().appendingPathComponent(file.localFilename)
    }

    func save(securityCheckItem item: SecurityCheckItem) {
        if let index = securityCheckItems.firstIndex(where: { $0.id == item.id }) {
            securityCheckItems[index] = item
        } else {
            securityCheckItems.append(item)
        }
        Self.save(securityCheckItems, key: "securityCheckItems")
        updateCurrentLocationSnapshot()
    }

    func toggle(securityCheckItem item: SecurityCheckItem) {
        var updated = item
        updated.isDone.toggle()
        updated.updatedAt = Date()
        save(securityCheckItem: updated)
    }

    func delete(securityCheckItem item: SecurityCheckItem) {
        securityCheckItems.removeAll { $0.id == item.id }
        Self.save(securityCheckItems, key: "securityCheckItems")
        updateCurrentLocationSnapshot()
    }

    func generateSecurityChecklistFromProject() {
        var existing = Set(securityCheckItems.map { $0.title.lowercased() + "|" + ($0.areaId?.uuidString ?? "project") })
        var newItems: [SecurityCheckItem] = []
        for task in siteTasks where task.category == "Security" || isSecurityRelated(task.title) || isSecurityRelated(task.note) {
            let title = "Test \(task.title)"
            let key = title.lowercased() + "|" + (task.areaId?.uuidString ?? "project")
            guard !existing.contains(key) else { continue }
            existing.insert(key)
            newItems.append(SecurityCheckItem(id: UUID(), title: title, category: "Security", areaId: task.areaId, taskId: task.id, isDone: false, note: "", updatedAt: Date()))
        }
        for title in [
            "Test alarm panel communication",
            "Test NVR recording",
            "Test camera live view",
            "Test motion sensors",
            "Test door contacts",
            "Test window contacts",
            "Test smoke detectors",
            "Test glass break sensors",
            "Test siren",
            "Verify zone labels"
        ] {
            let key = title.lowercased() + "|project"
            guard !existing.contains(key) else { continue }
            existing.insert(key)
            newItems.append(SecurityCheckItem(id: UUID(), title: title, category: "Security", areaId: nil, taskId: nil, isDone: false, note: "", updatedAt: Date()))
        }
        securityCheckItems.append(contentsOf: newItems)
        Self.save(securityCheckItems, key: "securityCheckItems")
        updateCurrentLocationSnapshot()
    }

    func save(equipment item: LocationEquipmentItem) {
        if let index = locationEquipment.firstIndex(where: { $0.id == item.id }) {
            locationEquipment[index] = item
        } else {
            locationEquipment.append(item)
        }
        Self.save(locationEquipment, key: "locationEquipment")
        updateCurrentLocationSnapshot()
    }

    func save(equipment item: LocationEquipmentItem, createsInstallTask: Bool) {
        var itemToSave = item
        if createsInstallTask, !item.assigneeIds.isEmpty {
            let now = Date()
            let taskId = item.installTaskId ?? UUID()
            let area = item.areaId.flatMap { id in areaLandmarks.first { $0.id == id } }
            let task = SiteTask(
                id: taskId,
                title: "Install \(item.quantity)x \(item.name)",
                category: "Install Equipment",
                note: item.note,
                status: item.isPacked ? "Done" : "To Do",
                floorId: area?.floorId,
                areaId: item.areaId,
                assigneeIds: item.assigneeIds,
                worldTransform: [],
                createdAt: siteTasks.first(where: { $0.id == taskId })?.createdAt ?? now,
                updatedAt: now
            )
            save(siteTask: task)
            itemToSave.installTaskId = taskId
        }
        save(equipment: itemToSave)
    }

    func delete(equipment item: LocationEquipmentItem) {
        locationEquipment.removeAll { $0.id == item.id }
        Self.save(locationEquipment, key: "locationEquipment")
        updateCurrentLocationSnapshot()
    }

    func deleteCurrentLocation() {
        guard let currentLocationId else { return }
        locations.removeAll { $0.id == currentLocationId }
        if let next = locations.first {
            self.currentLocationId = next.id
            apply(snapshot: next.snapshot)
        } else {
            let id = UUID()
            let now = Date()
            let floor = BuildingFloor(id: UUID(), name: "Floor 1", order: 0)
            self.currentLocationId = id
            projectName = "New Project"
            homeMap = .empty
            buildingFloors = [floor]
            areaLandmarks = []
            locationEquipment = []
            siteTasks = []
            siteTaskWorldMapData = nil
            workShifts = []
            projectFiles = []
            securityCheckItems = []
            devices = []
            phoneNetworkSamples = []
            hardwareProfiles = [:]
            calibrations = []
            points = []
            pendingRoomName = "Room"
            seedDemoUsers()
            locations = [SurveyLocation(id: id, name: projectName, createdAt: now, updatedAt: now, snapshot: makeSnapshot())]
        }
        persistWorkspace()
        saveLocations()
    }

    func toggleEquipmentPacked(_ item: LocationEquipmentItem) {
        guard let index = locationEquipment.firstIndex(where: { $0.id == item.id }) else { return }
        locationEquipment[index].isPacked.toggle()
        if let taskId = locationEquipment[index].installTaskId,
           let taskIndex = siteTasks.firstIndex(where: { $0.id == taskId }) {
            siteTasks[taskIndex].status = locationEquipment[index].isPacked ? "Done" : "To Do"
            siteTasks[taskIndex].updatedAt = Date()
            Self.save(siteTasks, key: "siteTasks")
        }
        Self.save(locationEquipment, key: "locationEquipment")
        updateCurrentLocationSnapshot()
    }

    func tasks(in area: AreaLandmark) -> [SiteTask] {
        siteTasks.filter { $0.areaId == area.id }
    }

    func equipment(in area: AreaLandmark) -> [LocationEquipmentItem] {
        locationEquipment.filter { $0.areaId == area.id }
    }

    func isAreaReady(_ area: AreaLandmark) -> Bool {
        let areaTasks = tasks(in: area)
        let areaEquipment = equipment(in: area)
        let tasksDone = areaTasks.allSatisfy { $0.status == "Done" }
        let equipmentDone = areaEquipment.allSatisfy { item in
            guard item.isPacked else { return false }
            guard let taskId = item.installTaskId else { return true }
            return siteTasks.first { $0.id == taskId }?.status == "Done"
        }
        return tasksDone && equipmentDone
    }

    func areaWorkSummary(_ area: AreaLandmark) -> String {
        let openTasks = tasks(in: area).filter { $0.status != "Done" }.count
        let pendingEquipment = equipment(in: area).filter { !$0.isPacked }.count
        if openTasks == 0 && pendingEquipment == 0 { return "Ready" }
        return "\(openTasks) open tasks · \(pendingEquipment) equipment pending"
    }

    func updateCurrentLocationAddress(address: String, directionsNote: String) {
        guard let currentLocationId,
              let index = locations.firstIndex(where: { $0.id == currentLocationId }) else { return }
        locations[index].address = address
        locations[index].directionsNote = directionsNote
        locations[index].updatedAt = Date()
        saveLocations()
    }

    func delete(workShift: WorkShift) {
        workShifts.removeAll { $0.id == workShift.id }
        Self.save(workShifts, key: "workShifts")
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [workShift.id.uuidString])
        updateCurrentLocationSnapshot()
    }

    func assignCurrentNodeToArea(_ nodeId: String) {
        guard let selectedAreaId, let index = areaLandmarks.firstIndex(where: { $0.id == selectedAreaId }) else { return }
        for areaIndex in areaLandmarks.indices {
            areaLandmarks[areaIndex].assignedNodeIds.removeAll { $0 == nodeId }
        }
        areaLandmarks[index].assignedNodeIds.append(nodeId)
        Self.save(areaLandmarks, key: "areaLandmarks")
        updateCurrentLocationSnapshot()
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

    func phoneResult(in area: AreaLandmark) -> PhoneNetworkSample? {
        phoneNetworkSamples
            .filter { $0.areaId == area.id }
            .max { $0.timestamp < $1.timestamp }
    }

    func areaScore(_ area: AreaLandmark) -> Int? {
        var scores = deviceResults(in: area).map(ProfessionalScore.device)
        if let phone = phoneResult(in: area) {
            scores.append(ProfessionalScore.phone(phone))
        }
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

    func savePhoneNetworkSample(_ sample: PhoneNetworkSample) {
        phoneNetworkSamples.removeAll { existing in
            guard let areaId = sample.areaId else { return false }
            return existing.areaId == areaId
        }
        phoneNetworkSamples.append(sample)
        Self.save(phoneNetworkSamples, key: "phoneNetworkSamples")
        updateCurrentLocationSnapshot()
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
            let areas = areaLandmarks.filter { $0.floorId == floor.id && $0.isMapped }
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
        saveCurrentLocation(name: projectName, showsMessage: false)
    }

    func saveCurrentLocation(name: String? = nil, showsMessage: Bool = true) {
        let fallbackName = currentLocation?.name ?? projectName
        let cleanName = (name ?? fallbackName).trimmingCharacters(in: .whitespacesAndNewlines)
        let locationName = cleanName.isEmpty ? fallbackName : cleanName
        projectName = locationName
        let now = Date()
        if let currentLocationId, let index = locations.firstIndex(where: { $0.id == currentLocationId }) {
            locations[index].name = locationName
            locations[index].updatedAt = now
            locations[index].snapshot = makeSnapshot()
        } else {
            let id = UUID()
            currentLocationId = id
            locations.append(SurveyLocation(id: id, name: locationName, createdAt: now, updatedAt: now, snapshot: makeSnapshot()))
        }
        hasChosenLocation = true
        persistWorkspace()
        saveLocations()
        if showsMessage { message = "\(locationName) saved." }
    }

    func switchLocation(to id: UUID, showsMessage: Bool = true) {
        guard let location = locations.first(where: { $0.id == id }) else { return }
        guard id != currentLocationId else {
            hasChosenLocation = true
            return
        }
        saveCurrentLocation(showsMessage: false)
        currentLocationId = id
        apply(snapshot: location.snapshot)
        hasChosenLocation = true
        defaults.set(id.uuidString, forKey: "currentLocationId")
        if showsMessage {
            message = "\(location.name) loaded."
        }
    }

    func createNewLocation(named name: String, address: String = "") {
        saveCurrentLocation(showsMessage: false)
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let locationName = cleanName.isEmpty ? "New Location" : cleanName
        let floor = BuildingFloor(id: UUID(), name: "Floor 1", order: 0)
        homeMap = .empty
        buildingFloors = [floor]
        areaLandmarks = []
        locationEquipment = []
        siteTasks = []
        siteTaskWorldMapData = nil
        workShifts = []
        projectFiles = []
        securityCheckItems = []
        devices = []
        phoneNetworkSamples = []
        hardwareProfiles = [:]
        calibrations = []
        projectName = locationName
        points = []
        selectedRoomId = nil
        selectedAreaId = nil
        selectedLocation = nil
        pendingRoomName = "Room"
        networks = []
        seedDemoUsers()
        let id = UUID()
        currentLocationId = id
        hasChosenLocation = true
        let now = Date()
        locations.append(SurveyLocation(id: id, name: locationName, address: address, createdAt: now, updatedAt: now, snapshot: makeSnapshot()))
        persistWorkspace()
        saveLocations()
        message = "\(locationName) created. Start mapping this home from a clean workspace."
    }

    func createNewLocation(named name: String, address: String = "", areaNames: [String]) {
        createNewLocation(named: name, address: address)
        let cleanAreaNames = areaNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        for areaName in cleanAreaNames {
            addUnmappedArea(name: areaName, floorId: buildingFloors.first?.id)
        }
    }

    func reportData() -> Data {
        struct Report: Encodable {
            let projectName: String
            let generatedAt: Date
            let overallScore: Int?
            let areas: [AreaReport]
            let devices: [SurveyDevice]
            let phoneNetworkSamples: [PhoneNetworkSample]
            let siteTasks: [SiteTask]
            let locationEquipment: [LocationEquipmentItem]
            let employees: [Employee]
            let workShifts: [WorkShift]
            let hardwareProfiles: [String: HardwareProfile]
            let calibrations: [CalibrationProfile]
        }
        struct AreaReport: Encodable {
            let area: AreaLandmark
            let score: Int?
            let devices: [SurveyDevice]
            let phoneResult: PhoneNetworkSample?
            let recommendation: SurveyRecommendation
        }
        let areas = areaLandmarks.map {
            AreaReport(area: $0, score: areaScore($0), devices: deviceResults(in: $0), phoneResult: phoneResult(in: $0), recommendation: recommendation(for: $0))
        }
        return (try? JSONEncoder.pretty.encode(Report(
            projectName: projectName, generatedAt: Date(), overallScore: overallScore,
            areas: areas, devices: devices, phoneNetworkSamples: phoneNetworkSamples,
            siteTasks: siteTasks,
            locationEquipment: locationEquipment,
            employees: employees, workShifts: workShifts,
            hardwareProfiles: hardwareProfiles, calibrations: calibrations
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
        updateCurrentLocationSnapshot()
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
        updateCurrentLocationSnapshot()
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

    private func loadLocations() {
        locations = Self.load([SurveyLocation].self, key: "surveyLocations") ?? []
        currentLocationId = defaults.string(forKey: "currentLocationId").flatMap(UUID.init(uuidString:))
        if locations.isEmpty {
            let id = UUID()
            let now = Date()
            currentLocationId = id
            locations = [SurveyLocation(id: id, name: projectName, createdAt: now, updatedAt: now, snapshot: makeSnapshot())]
            saveLocations()
            return
        }
        let selectedId = currentLocationId.flatMap { id in locations.contains(where: { $0.id == id }) ? id : nil } ?? locations[0].id
        currentLocationId = selectedId
        if let location = locations.first(where: { $0.id == selectedId }) {
            apply(snapshot: location.snapshot)
        }
        saveLocations()
    }

    private func makeSnapshot() -> SurveyWorkspaceSnapshot {
        SurveyWorkspaceSnapshot(
            homeMap: homeMap,
            buildingFloors: buildingFloors,
            areaLandmarks: areaLandmarks,
            locationEquipment: locationEquipment,
            siteTasks: siteTasks,
            siteTaskWorldMapData: siteTaskWorldMapData,
            employees: employees,
            workShifts: workShifts,
            projectFiles: projectFiles,
            securityCheckItems: securityCheckItems,
            devices: devices,
            phoneNetworkSamples: phoneNetworkSamples,
            hardwareProfiles: hardwareProfiles,
            calibrations: calibrations,
            projectName: projectName,
            points: points,
            pendingRoomName: pendingRoomName
        )
    }

    private func apply(snapshot: SurveyWorkspaceSnapshot) {
        homeMap = snapshot.homeMap
        buildingFloors = snapshot.buildingFloors.isEmpty
            ? [BuildingFloor(id: UUID(), name: "Floor 1", order: 0)]
            : snapshot.buildingFloors.sorted { $0.order < $1.order }
        let defaultFloorId = buildingFloors[0].id
        areaLandmarks = snapshot.areaLandmarks.map {
            var area = $0
            area.floorId = area.floorId ?? defaultFloorId
            return area
        }
        locationEquipment = snapshot.locationEquipment
        siteTasks = snapshot.siteTasks
        siteTaskWorldMapData = snapshot.siteTaskWorldMapData
        employees = snapshot.employees
        seedDemoUsers()
        workShifts = snapshot.workShifts
        projectFiles = snapshot.projectFiles
        securityCheckItems = snapshot.securityCheckItems
        devices = snapshot.devices
        phoneNetworkSamples = snapshot.phoneNetworkSamples
        hardwareProfiles = snapshot.hardwareProfiles
        calibrations = snapshot.calibrations
        projectName = snapshot.projectName
        points = snapshot.points
        pendingRoomName = snapshot.pendingRoomName
        selectedRoomId = homeMap.rooms.first?.id
        selectedAreaId = areaLandmarks.first?.id
        selectedLocation = nil
        networks = []
        persistWorkspace()
    }

    private func persistWorkspace() {
        Self.save(homeMap, key: "homeMap")
        Self.save(buildingFloors, key: "buildingFloors")
        Self.save(areaLandmarks, key: "areaLandmarks")
        Self.save(locationEquipment, key: "locationEquipment")
        Self.save(siteTasks, key: "siteTasks")
        if let siteTaskWorldMapData {
            defaults.set(siteTaskWorldMapData, forKey: "siteTaskWorldMapData")
        } else {
            defaults.removeObject(forKey: "siteTaskWorldMapData")
        }
        Self.save(employees, key: "employees")
        Self.save(workShifts, key: "workShifts")
        Self.save(projectFiles, key: "projectFiles")
        Self.save(securityCheckItems, key: "securityCheckItems")
        Self.save(devices, key: "surveyDevices")
        Self.save(phoneNetworkSamples, key: "phoneNetworkSamples")
        Self.save(hardwareProfiles, key: "hardwareProfiles")
        Self.save(calibrations, key: "calibrations")
        Self.save(points, key: "surveyPoints")
        defaults.set(projectName, forKey: "projectName")
    }

    private func saveLocations() {
        Self.save(locations, key: "surveyLocations")
        defaults.set(currentLocationId?.uuidString, forKey: "currentLocationId")
    }

    private func updateCurrentLocationSnapshot() {
        guard let currentLocationId,
              let index = locations.firstIndex(where: { $0.id == currentLocationId }) else { return }
        locations[index].updatedAt = Date()
        locations[index].snapshot = makeSnapshot()
        saveLocations()
    }

    private func hasRoleAccess(_ allowed: Set<String>) -> Bool {
        guard let role = currentUser?.role else { return false }
        return allowed.contains(role)
    }

    private func seedDemoUsers() {
        var changed = false
        for employee in Self.demoEmployees where !employees.contains(where: { $0.name.caseInsensitiveCompare(employee.name) == .orderedSame }) {
            employees.append(employee)
            changed = true
        }
        if currentUserId == nil || !employees.contains(where: { $0.id == currentUserId }) {
            currentUserId = employees.first(where: { $0.name == "Reza" })?.id ?? employees.first?.id
            if let currentUserId {
                defaults.set(currentUserId.uuidString, forKey: "currentUserId")
            }
        }
        if changed {
            Self.save(employees, key: "employees")
        }
    }

    private static var demoEmployees: [Employee] {
        [
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, name: "Reza", role: "Admin", phone: "", email: "reza@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, name: "Hamed", role: "Supervisor", phone: "", email: "hamed@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, name: "Hosein", role: "Supervisor", phone: "", email: "hosein@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!, name: "Sasan", role: "Supervisor", phone: "", email: "sasan@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!, name: "Pouya", role: "Technician", phone: "", email: "pouya@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000106")!, name: "Saman", role: "Technician", phone: "", email: "saman@smartav.local"),
            Employee(id: UUID(uuidString: "00000000-0000-0000-0000-000000000107")!, name: "Behnam", role: "Technician", phone: "", email: "behnam@smartav.local")
        ]
    }

    private func projectFilesDirectory() throws -> URL {
        let root = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ProjectFiles", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        }
        return root
    }

    private func isSecurityRelated(_ text: String) -> Bool {
        let lower = text.lowercased()
        return ["security", "alarm", "motion", "contact", "smoke", "co detector", "camera", "nvr", "siren", "glass break", "dcm", "hikvision", "galaxy"].contains { lower.contains($0) }
    }

    private func scheduleNotification(for shift: WorkShift) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: shift.startTime)
        guard shift.startTime > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = "Shift: \(shift.locationName)"
        content.body = shift.title.isEmpty ? "Scheduled work starts now." : shift.title
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: shift.id.uuidString,
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
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
