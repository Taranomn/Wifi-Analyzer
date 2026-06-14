import RoomPlan
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService

    var body: some View {
        TabView {
            ScanView()
                .tabItem { Label("Home Map", systemImage: "map") }
            SurveyView()
                .tabItem { Label("Survey", systemImage: "wifi") }
            InstallerSurveyView()
                .tabItem { Label("Installer", systemImage: "wrench.and.screwdriver") }
            ReportView()
                .tabItem { Label("Report", systemImage: "doc.text") }
            SettingsView()
                .tabItem { Label("Devices", systemImage: "memorychip") }
        }
        .task { store.startPolling() }
        .sheet(item: $bluetooth.nearbyESP) { device in
            PairESPView(device: device)
                .environmentObject(bluetooth)
                .presentationDetents([.height(300)])
        }
        .sheet(isPresented: $bluetooth.showingWiFiSetup) {
            WiFiNetworkPickerView()
                .environmentObject(bluetooth)
        }
        .alert("Wi-Fi Survey", isPresented: Binding(
            get: { store.message != nil || bluetooth.message != nil },
            set: {
                if !$0 {
                    store.message = nil
                    bluetooth.message = nil
                }
            }
        )) {
            Button("OK") {
                store.message = nil
                bluetooth.message = nil
            }
        } message: {
            Text(store.message ?? bluetooth.message ?? "")
        }
    }
}

private struct ScanView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var showingScanner = false
    @State private var showingARScanner = false
    @State private var showingWalkTrace = false
    @State private var showingLandmarkMapper = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !RoomCaptureSession.isSupported {
                        if store.areaLandmarks.isEmpty {
                            ContentUnavailableView(
                                "No Areas Mapped",
                                systemImage: "mappin.and.ellipse",
                                description: Text("Walk through the home once and mark the center of each area.")
                            )
                            .frame(minHeight: 300)
                        } else {
                            AreaLandmarkMapView(
                                buildingFloors: store.buildingFloors,
                                landmarks: store.areaLandmarks, points: store.points,
                                devices: store.devices, phoneTester: store.phoneTester,
                                selectedAreaId: $store.selectedAreaId
                            )
                            if let area = store.selectedArea {
                                AreaResultsView(area: area)
                                    .environmentObject(store)
                                    .environmentObject(bluetooth)
                            }
                        }

                        Button {
                            showingLandmarkMapper = true
                        } label: {
                            Label(store.areaLandmarks.isEmpty ? "Map Area Centers" : "Remap Area Centers", systemImage: "location.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        Text("Keep this screen open while walking. Aim at the middle of each area's floor, name it, and mark it. Distances are measured by ARKit.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        if !store.areaLandmarks.isEmpty {
                            Button(role: .destructive) { store.clearAreaMap() } label: {
                                Label("Clear Area Map", systemImage: "trash")
                            }
                        }
                    }

                    if RoomCaptureSession.isSupported {
                    if store.hasFloorPlan {
                        HomeMapView(map: store.homeMap, points: store.points, liveStatus: bluetooth.deviceStatus, selectedRoomId: $store.selectedRoomId, selection: $store.selectedLocation)
                            .frame(minHeight: 320)

                        HStack {
                            metric(title: "Home width", value: String(format: "%.1f m", store.homeMap.width))
                            metric(title: "Home length", value: String(format: "%.1f m", store.homeMap.height))
                            metric(title: "Rooms", value: "\(store.homeMap.rooms.count)")
                        }

                        if let room = store.selectedRoom {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Arrange \(room.name)").font(.headline)
                                    Spacer()
                                    Button {
                                        store.assignCurrentNode(bluetooth.deviceStatus.nodeId)
                                    } label: {
                                        Label("Place ESP Here", systemImage: "memorychip")
                                    }
                                    .buttonStyle(.bordered)
                                }
                                HStack {
                                    moveButton("arrow.left", dx: -0.5, dy: 0)
                                    moveButton("arrow.right", dx: 0.5, dy: 0)
                                    moveButton("arrow.up", dx: 0, dy: -0.5)
                                    moveButton("arrow.down", dx: 0, dy: 0.5)
                                    Spacer()
                                    Button(role: .destructive) { store.deleteSelectedRoom() } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                Text("Tap a room to select it. Move it until doors and shared walls line up.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        }

                        Button(role: .destructive) {
                            store.clearPlan()
                        } label: {
                            Label("Clear Home Map and Measurements", systemImage: "trash")
                        }
                    } else {
                        ContentUnavailableView(
                            "No Rooms Mapped",
                            systemImage: "viewfinder",
                            description: Text("Add each room separately, then arrange them into the complete home map.")
                        )
                        .frame(minHeight: 360)
                    }

                    TextField("Room name, for example Kitchen", text: $store.pendingRoomName)
                        .textFieldStyle(.roundedBorder)

                    Button {
                        showingScanner = true
                    } label: {
                        Label("Camera Detect Walls", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button {
                        showingWalkTrace = true
                    } label: {
                        Label("Trace Room Corners", systemImage: "figure.walk")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    }
                }
                .padding()
            }
            .navigationTitle("Home Map")
            .fullScreenCover(isPresented: $showingScanner) {
                RoomScannerView()
                    .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showingWalkTrace) {
                WalkTraceView()
                    .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showingARScanner) {
                ARWallScannerView()
                    .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showingLandmarkMapper) {
                AreaLandmarkCaptureView()
                    .environmentObject(store)
            }
        }
    }

    private func metric(title: String, value: String) -> some View {
        VStack(alignment: .leading) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func moveButton(_ icon: String, dx: Double, dy: Double) -> some View {
        Button { store.moveSelectedRoom(dx: dx, dy: dy) } label: {
            Image(systemName: icon)
        }
        .buttonStyle(.bordered)
    }
}

private struct SurveyView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var showingRecord = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SignalCard(status: bluetooth.deviceStatus)
                    LiveDiagnosticsView()
                        .environmentObject(bluetooth)

                    if !store.areaLandmarks.isEmpty {
                        AreaLandmarkMapView(
                            buildingFloors: store.buildingFloors,
                            landmarks: store.areaLandmarks, points: store.points,
                            devices: store.devices, phoneTester: store.phoneTester,
                            selectedAreaId: $store.selectedAreaId
                        )
                        Text(store.selectedArea == nil ? "Tap the area containing the sensor." : "\(store.selectedArea?.name ?? "Area") selected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            showingRecord = true
                        } label: {
                            Label("Record Area Measurement", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.selectedArea == nil)

                        if let area = store.selectedArea {
                            AreaResultsView(area: area)
                                .environmentObject(store)
                                .environmentObject(bluetooth)
                        }
                    } else if store.hasFloorPlan {
                        HomeMapView(map: store.homeMap, points: store.points, liveStatus: bluetooth.deviceStatus, selectedRoomId: $store.selectedRoomId, selection: $store.selectedLocation)
                            .frame(minHeight: 330)
                        Text(store.selectedLocation == nil ? "Tap the room and current sensor position." : "\(store.selectedRoom?.name ?? "Room") selected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)

                        Button {
                            showingRecord = true
                        } label: {
                            Label("Record Measurement Point", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(store.selectedLocation == nil)
                    } else {
                        ContentUnavailableView("Map Areas First", systemImage: "map", description: Text("Create an area-center map before recording measurements."))
                            .frame(minHeight: 350)
                    }
                }
                .padding()
            }
            .navigationTitle("Live Survey")
            .sheet(isPresented: $showingRecord) {
                RecordPointView(isPresented: $showingRecord)
                    .environmentObject(store)
                    .environmentObject(bluetooth)
            }
        }
    }
}

private struct SignalCard: View {
    let status: BLEDeviceStatus

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text(status.connected ? status.qualityLabel : "Unavailable").font(.title2.bold())
                Text(status.ssid.isEmpty ? "ESP32 offline" : status.ssid).font(.footnote).opacity(0.8)
            }
            Spacer()
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(status.rssi.map(String.init) ?? "--").font(.system(size: 42, weight: .bold))
                Text("dBm").font(.caption)
            }
        }
        .foregroundStyle(.white)
        .padding(20)
        .background(signalColor, in: RoundedRectangle(cornerRadius: 8))
    }

    private var signalColor: Color {
        switch status.qualityLabel {
        case "Excellent": return .green
        case "Good": return Color(red: 0.25, green: 0.58, blue: 0.18)
        case "Fair": return .orange
        case "Weak": return Color(red: 0.85, green: 0.35, blue: 0.08)
        case "Very Weak": return .red
        default: return Color(uiColor: .darkGray)
        }
    }
}

private struct AreaResultsView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    let area: AreaLandmark

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(area.name).font(.headline)
                Spacer()
                Text("\(area.assignedNodeIds.count) testers")
                    .font(.caption).foregroundStyle(.secondary)
            }

            ForEach(store.deviceResults(in: area)) { device in
                HStack {
                    Image(systemName: "memorychip")
                    VStack(alignment: .leading) {
                        Text(device.nodeId).font(.subheadline.bold())
                        Text(device.connected ? "\(device.host) · Channel \(device.channel)" : "Offline")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(ProfessionalScore.device(device))").font(.headline)
                        Text(device.rssi.map { "\($0) dBm" } ?? "--").font(.caption)
                    }
                }
            }

            if area.assignedNodeIds.contains("IPHONE") {
                HStack {
                    Image(systemName: "iphone")
                    VStack(alignment: .leading) {
                        Text("This iPhone").font(.subheadline.bold())
                        Text("iOS does not expose phone Wi-Fi RSSI")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.phoneTester.latencyMs.map { "\($0) ms" } ?? "--")
                        .font(.headline)
                }
            }

            let recommendation = store.recommendation(for: area)
            VStack(alignment: .leading, spacing: 4) {
                Text(recommendation.title).font(.subheadline.bold())
                Text(recommendation.description).font(.caption).foregroundStyle(.secondary)
                Text(recommendation.suggestedAction).font(.caption.weight(.semibold))
            }

            HStack {
                Menu {
                    ForEach(store.devices) { device in
                        Button(device.nodeId) { store.assignCurrentNodeToArea(device.nodeId) }
                    }
                } label: {
                    Label("Place ESP", systemImage: "memorychip")
                }
                .buttonStyle(.bordered)

                Button {
                    store.assignPhoneToSelectedArea()
                } label: {
                    Label("Place iPhone", systemImage: "iphone")
                }
                .buttonStyle(.bordered)
            }

            if area.assignedNodeIds.contains("IPHONE") {
                Button {
                    Task { await store.runPhoneSpeedTest() }
                } label: {
                    Label(
                        store.phoneTester.localSpeedMbps.map { String(format: "Phone Local Speed %.1f Mbps", $0) } ?? "Test Phone Local Speed",
                        systemImage: "speedometer"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct LiveDiagnosticsView: View {
    @EnvironmentObject private var bluetooth: BLEProvisioningService

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Live Network Details", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Text(bluetooth.activeTransport)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                diagnostic("Gateway ping", bluetooth.deviceStatus.gatewayLatencyMs.map { "\($0) ms" } ?? "--")
                diagnostic("Channel", bluetooth.deviceStatus.channel == 0 ? "--" : "\(bluetooth.deviceStatus.channel)")
                diagnostic("Local speed", bluetooth.localSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
            }

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("BSSID").font(.caption).foregroundStyle(.secondary)
                    Text(bluetooth.deviceStatus.bssid.isEmpty ? "--" : bluetooth.deviceStatus.bssid)
                        .font(.caption.monospaced())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Text("Gateway / DNS").font(.caption).foregroundStyle(.secondary)
                    Text("\(bluetooth.deviceStatus.gatewayIp.isEmpty ? "--" : bluetooth.deviceStatus.gatewayIp) / \(bluetooth.deviceStatus.dnsIp.isEmpty ? "--" : bluetooth.deviceStatus.dnsIp)")
                        .font(.caption.monospaced())
                }
            }

            Button {
                bluetooth.runLocalSpeedTest()
            } label: {
                Label(bluetooth.isTestingSpeed ? "Testing Local Wi-Fi..." : "Run Local Speed Test", systemImage: "speedometer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(bluetooth.isTestingSpeed || !bluetooth.deviceStatus.connected)

            Text("Local speed measures throughput between this iPhone and the ESP32, not internet-provider speed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func diagnostic(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RecordPointView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @Binding var isPresented: Bool
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                if let area = store.selectedArea {
                    LabeledContent("Area", value: area.name)
                } else {
                    LabeledContent("Room", value: store.selectedRoom?.name ?? "Not selected")
                }
                LabeledContent("Sensor", value: bluetooth.deviceStatus.nodeId)
                TextField("Optional note", text: $note, axis: .vertical)
            }
            .navigationTitle("Record Point")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { isPresented = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let saved = store.areaLandmarks.isEmpty
                            ? store.record(status: bluetooth.deviceStatus, note: note)
                            : store.recordArea(status: bluetooth.deviceStatus, note: note)
                        if saved { isPresented = false }
                    }
                    .disabled(store.isLoading)
                }
            }
        }
    }
}

private struct MeasurementsView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var exporting = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.points.reversed()) { point in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(point.roomName).font(.headline)
                            Spacer()
                            Text("\(point.rssi) dBm").font(.headline)
                        }
                        Text("\(point.qualityLabel) | Channel \(point.channel) | \(point.timestamp.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .swipeActions {
                        Button(role: .destructive) { store.delete(point: point) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
            .overlay {
                if store.points.isEmpty {
                    ContentUnavailableView("No Measurements", systemImage: "wifi.exclamationmark", description: Text("Recorded survey points appear here."))
                }
            }
            .navigationTitle("Measurements")
            .toolbar {
                Button {
                    exporting = true
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                .disabled(store.points.isEmpty)
            }
            .fileExporter(
                isPresented: $exporting,
                document: CSVDocument(data: store.csvData()),
                contentType: .commaSeparatedText,
                defaultFilename: "wifi-survey"
            ) { result in
                if case .failure(let error) = result { store.message = error.localizedDescription }
            }
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService

    var body: some View {
        NavigationStack {
            List {
                ForEach(store.devices) { device in
                    NavigationLink {
                        DeviceDetailView(nodeId: device.nodeId)
                            .environmentObject(store)
                            .environmentObject(bluetooth)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "memorychip")
                                .foregroundStyle(device.connected ? .green : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(device.nodeId).font(.headline)
                                Text(device.host)
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text(device.rssi.map { "\($0) dBm" } ?? "--")
                                    .font(.headline)
                                Text(device.connected ? (Date().timeIntervalSince(device.lastSeen) > 15 ? "Stale" : device.qualityLabel) : "Offline")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) { store.removeDevice(device.nodeId) } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .overlay {
                if store.devices.isEmpty {
                    ContentUnavailableView("No Paired Devices", systemImage: "memorychip", description: Text("Tap + to add an ESP32."))
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        bluetooth.addAnotherDevice()
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .task { await bluetooth.refreshPreferredStatus() }
        }
    }
}

private struct DeviceDetailView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    let nodeId: String
    @State private var profile = HardwareProfile()

    private var device: SurveyDevice? { store.devices.first { $0.nodeId == nodeId } }
    private var isActiveBluetoothDevice: Bool { bluetooth.deviceStatus.nodeId == nodeId }

    var body: some View {
        Form {
            if let device {
                Section("Connection") {
                    LabeledContent("Status", value: device.connected ? (Date().timeIntervalSince(device.lastSeen) > 15 ? "Stale" : "Online") : "Offline")
                    LabeledContent("IP address", value: device.host)
                    LabeledContent("SSID", value: device.ssid.isEmpty ? "--" : device.ssid)
                    LabeledContent("Signal", value: device.rssi.map { "\($0) dBm · \(device.qualityLabel)" } ?? "--")
                    LabeledContent("Channel", value: device.channel == 0 ? "--" : String(device.channel))
                    LabeledContent("Last seen", value: device.lastSeen.formatted(date: .omitted, time: .standard))
                    LabeledContent("Professional score", value: "\(ProfessionalScore.device(device)) · \(ProfessionalScore.label(ProfessionalScore.device(device)))")
                    LabeledContent("Average ping", value: device.averagePingMs.map { String(format: "%.1f ms", $0) } ?? "--")
                    LabeledContent("Packet loss", value: device.packetLossPercent.map { String(format: "%.1f%%", $0) } ?? "--")
                    LabeledContent("Local throughput", value: device.localSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
                    LabeledContent("Channel congestion", value: device.channelCongestion ?? "--")
                }
                Section("Hardware Profile") {
                    TextField("Board model", text: $profile.boardModel)
                    Picker("Antenna", selection: $profile.antennaType) {
                        ForEach(["Unknown", "PCB", "External"], id: \.self) { Text($0) }
                    }
                    LabeledContent("Antenna gain") {
                        TextField("0", value: $profile.antennaGainDbi, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Calibration offset") {
                        TextField("0", value: $profile.calibrationOffsetDbm, format: .number)
                            .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                    }
                    TextField("Notes", text: $profile.notes, axis: .vertical)
                    Button("Save Hardware Profile") { store.updateHardwareProfile(nodeId: nodeId, profile: profile) }
                    if profile.antennaType != "External" {
                        Text("Measurements may differ from phones and laptops. For professional surveys, use identical ESP32 boards with external antennas.")
                            .font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section {
                    Button {
                        Task {
                            do { try await ESPService(host: device.host).identify() }
                            catch { store.message = "Could not identify this offline device." }
                        }
                    } label: {
                        Label("Identify Device", systemImage: "light.beacon.max")
                    }
                }
            }

            if isActiveBluetoothDevice {
                Section("Bluetooth and Setup") {
                    LabeledContent("Bluetooth", value: bluetooth.linkState.rawValue)
                    LabeledContent("Transport", value: bluetooth.activeTransport)
                    LabeledContent("BSSID", value: bluetooth.deviceStatus.bssid.isEmpty ? "--" : bluetooth.deviceStatus.bssid)
                    LabeledContent("Gateway", value: bluetooth.deviceStatus.gatewayIp.isEmpty ? "--" : bluetooth.deviceStatus.gatewayIp)
                    LabeledContent("Gateway ping", value: bluetooth.deviceStatus.gatewayLatencyMs.map { "\($0) ms" } ?? "--")
                    LabeledContent("DNS", value: bluetooth.deviceStatus.dnsIp.isEmpty ? "--" : bluetooth.deviceStatus.dnsIp)
                    LabeledContent("Setup AP", value: bluetooth.deviceStatus.accessPointSsid)
                    LabeledContent("Setup AP IP", value: bluetooth.deviceStatus.accessPointIp)

                    Button {
                        bluetooth.showingWiFiSetup = true
                    } label: {
                        Label("Change Wi-Fi Network", systemImage: "wifi")
                    }
                    Button {
                        bluetooth.retryConnection()
                    } label: {
                        Label("Retry Bluetooth Connection", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            } else {
                Section {
                    Text("This ESP32 is reporting over Wi-Fi. Bluetooth setup controls appear when it is the active paired device.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(nodeId)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { profile = store.hardwareProfiles[nodeId] ?? HardwareProfile() }
    }
}

private struct ConnectionDetailsView: View {
    let status: BLEDeviceStatus

    var body: some View {
        LabeledContent("Status", value: status.connectionStatus.capitalized)
        LabeledContent("SSID", value: status.ssid.isEmpty ? "Not configured" : status.ssid)
        LabeledContent("BSSID", value: status.bssid.isEmpty ? "--" : status.bssid)
        LabeledContent("Signal", value: status.rssi.map { "\($0) dBm · \(status.qualityLabel)" } ?? "--")
        LabeledContent("Channel", value: status.channel == 0 ? "--" : String(status.channel))
        LabeledContent("Local IP", value: status.localIp.isEmpty ? "--" : status.localIp)
        LabeledContent("Uptime", value: formattedUptime(status.uptimeSeconds))
    }

    private func formattedUptime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

private struct InstallerSurveyView: View {
    @EnvironmentObject private var store: SurveyStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Overall Project Score").font(.headline)
                            Text(ProfessionalScore.label(store.overallScore ?? 0))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(store.overallScore.map(String.init) ?? "--")
                            .font(.system(size: 42, weight: .bold))
                    }
                }
                ForEach(store.areaLandmarks) { area in
                    Section(area.name) {
                        HStack {
                            Text("Area score")
                            Spacer()
                            Text(store.areaScore(area).map { "\($0) · \(ProfessionalScore.label($0))" } ?? "No data")
                                .font(.headline)
                        }
                        ForEach(store.deviceResults(in: area)) { device in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(device.nodeId).font(.headline)
                                    Spacer()
                                    Text("\(ProfessionalScore.device(device))/100").font(.headline)
                                }
                                Text("RSSI \(device.rssi.map { "\($0) dBm" } ?? "--") · Ping \(device.averagePingMs.map { String(format: "%.0f ms", $0) } ?? "--") · Loss \(device.packetLossPercent.map { String(format: "%.1f%%", $0) } ?? "--")")
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("Speed \(device.localSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--") · Congestion \(device.channelCongestion ?? "--")")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        let recommendation = store.recommendation(for: area)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(recommendation.title).font(.headline)
                            Text(recommendation.description).font(.caption).foregroundStyle(.secondary)
                            Text(recommendation.suggestedAction).font(.subheadline.weight(.semibold))
                        }
                    }
                }
            }
            .navigationTitle("Installer Survey")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        APPlanningView().environmentObject(store)
                    } label: {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                    NavigationLink {
                        CalibrationView().environmentObject(store)
                    } label: {
                        Image(systemName: "scope")
                    }
                }
            }
        }
    }
}

private struct APPlanningView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var coordinatorId = ""
    @State private var liveStatus: PlanningStatus?
    @State private var running = false

    var body: some View {
        List {
            Section("Planning Method") {
                Text("The app groups weak areas by floor and recommends candidate AP positions using measured area distances, professional scores, and saved calibration profiles.")
                Text("Estimated real-device RSSI is a calibrated estimate. iPhone latency and throughput are measured directly; iOS does not expose Wi-Fi RSSI.")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }

            ForEach(store.buildingFloors) { floor in
                let suggestions = store.apPlacementSuggestions().filter { $0.floorId == floor.id }
                Section(floor.name) {
                    if suggestions.isEmpty {
                        Label("No additional AP indicated by current measurements", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    ForEach(suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(suggestion.title).font(.headline)
                            Text(suggestion.reason).font(.caption).foregroundStyle(.secondary)
                            LabeledContent("Expected coverage", value: suggestion.coveredAreaNames.joined(separator: ", "))
                            LabeledContent("Calibrated device estimate", value: suggestion.estimatedRealDeviceRssi.map { "\($0) dBm" } ?? "Needs calibration")
                        }
                    }
                }
            }

            Section("Candidate AP Test") {
                Picker("Candidate AP", selection: $coordinatorId) {
                    Text("Select ESP32").tag("")
                    ForEach(store.devices) { Text($0.nodeId).tag($0.nodeId) }
                }
                Button {
                    Task { await runCandidateTest() }
                } label: {
                    Label(running ? "Testing..." : "Test Candidate AP", systemImage: "dot.radiowaves.left.and.right")
                }
                .disabled(coordinatorId.isEmpty || running || store.devices.count < 2)
                Button("Refresh Test Results") {
                    Task { await refreshCandidateResults() }
                }
                .disabled(coordinatorId.isEmpty)
                if let liveStatus {
                    LabeledContent("Candidate hotspot", value: liveStatus.ssid)
                    ForEach(liveStatus.results ?? []) { result in
                        LabeledContent(result.nodeId, value: "\(result.rssi) dBm · \(Int(result.averagePingMs)) ms · \(String(format: "%.0f%%", result.packetLossPercent)) loss")
                    }
                }
                Text("Place each tester ESP in its assigned area first. The selected board temporarily becomes an AP; all other online boards join it and report their measured link quality.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("AP Planning")
        .onAppear { coordinatorId = coordinatorId.isEmpty ? (store.devices.first?.nodeId ?? "") : coordinatorId }
    }

    private func runCandidateTest() async {
        guard let coordinator = store.devices.first(where: { $0.nodeId == coordinatorId }) else { return }
        running = true
        defer { running = false }
        do {
            let started = try await ESPService(host: coordinator.host).startPlanning()
            liveStatus = started
            for tester in store.devices where tester.nodeId != coordinator.nodeId && tester.connected {
                try await ESPService(host: tester.host).joinPlanning(ssid: started.ssid, coordinatorIp: started.ip)
            }
            try? await Task.sleep(for: .seconds(5))
            liveStatus = try await ESPService(host: coordinator.host).planningStatus()
        } catch {
            store.message = "Candidate AP test could not start. Confirm every ESP32 has planning-mode firmware and is online."
        }
    }

    private func refreshCandidateResults() async {
        guard let coordinator = store.devices.first(where: { $0.nodeId == coordinatorId }) else { return }
        do {
            liveStatus = try await ESPService(host: coordinator.host).planningStatus()
        } catch {
            store.message = "Could not reach the candidate AP coordinator."
        }
    }
}

private struct CalibrationView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var areaId: UUID?
    @State private var nodeId = ""
    @State private var offset = 0.0
    @State private var deviceModel = "iPhone"
    @State private var notes = ""

    var body: some View {
        Form {
            Section("Calibration Target") {
                Picker("Area", selection: $areaId) {
                    Text("Select area").tag(UUID?.none)
                    ForEach(store.areaLandmarks) { Text($0.name).tag(Optional($0.id)) }
                }
                Picker("ESP32", selection: $nodeId) {
                    Text("Select device").tag("")
                    ForEach(store.devices) { Text($0.nodeId).tag($0.nodeId) }
                }
            }
            Section("Phone Comparison") {
                LabeledContent("Phone latency", value: store.phoneTester.latencyMs.map { "\($0) ms" } ?? "--")
                LabeledContent("Phone local speed", value: store.phoneTester.localSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
                Button("Run Phone Latency and Speed Test") {
                    Task { await store.runPhoneSpeedTest() }
                }
                Text("iOS does not provide real Wi-Fi RSSI to normal apps. iPhone quality is estimated using local latency and throughput.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            Section("Profile") {
                TextField("Device model", text: $deviceModel)
                LabeledContent("Calibration offset dBm") {
                    TextField("0", value: $offset, format: .number)
                        .keyboardType(.decimalPad).multilineTextAlignment(.trailing)
                }
                TextField("Notes", text: $notes, axis: .vertical)
                Button("Save Calibration Profile") {
                    guard let areaId, !nodeId.isEmpty else { return }
                    store.saveCalibration(CalibrationProfile(
                        id: UUID(), areaId: areaId, nodeId: nodeId, calibrationOffsetDbm: offset,
                        deviceModel: deviceModel, notes: notes, createdAt: Date(),
                        phoneLatencyMs: store.phoneTester.latencyMs,
                        phoneThroughputMbps: store.phoneTester.localSpeedMbps
                    ))
                    store.message = "Calibration profile saved."
                }
                .disabled(areaId == nil || nodeId.isEmpty)
            }
        }
        .navigationTitle("Calibration")
    }
}

private struct ReportView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var exporting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Project") {
                    TextField("Project name", text: $store.projectName)
                        .onSubmit { store.saveProjectName() }
                    LabeledContent("Overall score", value: store.overallScore.map { "\($0) · \(ProfessionalScore.label($0))" } ?? "No data")
                    LabeledContent("Mapped areas", value: "\(store.areaLandmarks.count)")
                    LabeledContent("ESP32 devices", value: "\(store.devices.count)")
                }
                Section("Recommendations") {
                    ForEach(store.areaLandmarks) { area in
                        let recommendation = store.recommendation(for: area)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(area.name): \(recommendation.title)").font(.headline)
                            Text(recommendation.suggestedAction).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                Button {
                    store.saveProjectName()
                    exporting = true
                } label: {
                    Label("Export JSON Report", systemImage: "square.and.arrow.up")
                }
            }
            .navigationTitle("Final Report")
            .fileExporter(
                isPresented: $exporting,
                document: JSONDocument(data: store.reportData()),
                contentType: .json,
                defaultFilename: "wifi-survey-report"
            ) { result in
                if case .failure(let error) = result { store.message = error.localizedDescription }
            }
        }
    }
}

private struct PairESPView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    let device: NearbyESP

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "memorychip")
                .font(.system(size: 42))
                .foregroundStyle(.blue)
            Text("Pair with \(device.name)?")
                .font(.title3.bold())
            Text("This nearby ESP32 will become the measurement device for this phone.")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack {
                Button("Not Now") {
                    bluetooth.dismissPairing()
                    dismiss()
                }
                .buttonStyle(.bordered)
                Button("Pair") {
                    bluetooth.confirmPairing()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
    }
}

private struct WiFiNetworkPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var selectedNetwork: WiFiNetwork?

    var body: some View {
        NavigationStack {
            List(bluetooth.networks) { network in
                Button {
                    selectedNetwork = network
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(network.ssid.isEmpty ? "Hidden network" : network.ssid)
                                .foregroundStyle(.primary)
                            Text("\(network.rssi) dBm  |  Channel \(network.channel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if network.secure { Image(systemName: "lock.fill").font(.caption) }
                        Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
            .overlay {
                if bluetooth.isScanningNetworks {
                    ProgressView("Scanning nearby Wi-Fi...")
                } else if bluetooth.networks.isEmpty {
                    ContentUnavailableView("No Networks Found", systemImage: "wifi.slash")
                }
            }
            .navigationTitle("Choose Wi-Fi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        bluetooth.scanWiFi()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(bluetooth.isScanningNetworks)
                }
            }
            .task { bluetooth.scanWiFi() }
            .sheet(item: $selectedNetwork) { network in
                WiFiPasswordView(network: network)
                    .environmentObject(bluetooth)
                    .presentationDetents([.height(network.secure ? 300 : 240)])
            }
        }
    }
}

private struct WiFiPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    let network: WiFiNetwork
    @State private var password = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(network.ssid)
                .font(.title2.bold())
            Text("Channel \(network.channel)  |  \(network.rssi) dBm")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if network.secure {
                SecureField("Wi-Fi password", text: $password)
                    .textContentType(.password)
                    .textFieldStyle(.roundedBorder)
            } else {
                Text("This network does not require a password.")
                    .font(.footnote)
            }
            Button {
                bluetooth.connectWiFi(ssid: network.ssid, password: password)
                dismiss()
            } label: {
                Label("Connect ESP32", systemImage: "wifi")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(network.secure && password.isEmpty)
        }
        .padding(24)
    }
}

private struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

private struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    let data: Data
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}
