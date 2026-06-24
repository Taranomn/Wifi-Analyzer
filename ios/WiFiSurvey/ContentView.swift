import Network
import NetworkExtension
import RoomPlan
import CryptoKit
import Security
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService

    var body: some View {
        MainWorkspaceView()
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

private enum MainSection {
    case projects
    case shifts
    case utilities
}

private enum SmartTheme {
    static let background = Color(red: 0.010, green: 0.010, blue: 0.011)
    static let surface = Color(red: 0.078, green: 0.078, blue: 0.078)
    static let graphite = Color(red: 0.173, green: 0.173, blue: 0.173)
    static let panel = Color.white.opacity(0.070)
    static let panelStrong = Color.white.opacity(0.120)
    static let border = Color.white.opacity(0.115)
    static let primary = Color(red: 1.0, green: 0.412, blue: 0.141)
    static let cyan = Color(red: 0.431, green: 0.757, blue: 0.894)
    static let success = Color(red: 0.20, green: 0.86, blue: 0.48)
    static let warning = Color(red: 1.0, green: 0.525, blue: 0.180)
    static let danger = Color(red: 0.95, green: 0.085, blue: 0.012)
    static let text = Color.white
    static let muted = Color(red: 0.725, green: 0.725, blue: 0.725)
    static let displayFont = "TomatoGrotesk-Bold"
    static let displayMediumFont = "TomatoGrotesk-Medium"
    static let bodyFont = "Satoshi-Regular"
    static let bodyMediumFont = "Satoshi-Medium"
    static let bodyBoldFont = "Satoshi-Bold"

    static func display(_ size: CGFloat) -> Font {
        .custom(displayFont, size: size, relativeTo: .title)
    }

    static func displayMedium(_ size: CGFloat) -> Font {
        .custom(displayMediumFont, size: size, relativeTo: .title)
    }

    static func body(_ size: CGFloat) -> Font {
        .custom(bodyFont, size: size, relativeTo: .body)
    }

    static func bodyMedium(_ size: CGFloat) -> Font {
        .custom(bodyMediumFont, size: size, relativeTo: .body)
    }

    static func bodyBold(_ size: CGFloat) -> Font {
        .custom(bodyBoldFont, size: size, relativeTo: .body)
    }
}

private struct SmartAVBrandMark: View {
    var body: some View {
        if let image = SmartAVImageLoader.image(named: "smartav-logo", extension: "png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .accessibilityLabel("Smart AV")
        } else {
            Image(systemName: "hexagon.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(SmartTheme.primary)
                .accessibilityLabel("Smart AV")
        }
    }
}

private struct SmartAVWordmark: View {
    var maxWidth: CGFloat = 132

    var body: some View {
        if let image = SmartAVImageLoader.image(named: "smartav-logo", extension: "png") {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: maxWidth)
                .accessibilityLabel("Smart AV")
        } else {
            Text("SMART AV")
                .font(SmartTheme.bodyBold(15))
                .foregroundStyle(.white)
                .accessibilityLabel("Smart AV")
        }
    }
}

private enum SmartAVImageLoader {
    static func image(named name: String, extension ext: String) -> UIImage? {
        if let image = UIImage(named: name) {
            return image
        }
        guard let path = Bundle.main.path(forResource: name, ofType: ext) else {
            return nil
        }
        return UIImage(contentsOfFile: path)
    }
}

private struct SmartAVLogoLockup: View {
    var wordmarkWidth: CGFloat = 138
    var iconSize: CGFloat = 34

    var body: some View {
        SmartAVWordmark(maxWidth: wordmarkWidth)
            .frame(height: iconSize)
    }
}

private func roleRank(_ role: String) -> Int {
    switch role {
    case "Admin": return 0
    case "Manager": return 1
    case "Project Manager": return 2
    case "Supervisor": return 3
    default: return 4
    }
}

private func roleColor(_ role: String) -> Color {
    switch role {
    case "Admin", "Manager": return SmartTheme.success
    case "Project Manager", "Supervisor": return SmartTheme.cyan
    default: return SmartTheme.warning
    }
}

private struct MainWorkspaceView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var selectedSection: MainSection = .projects

    var body: some View {
        ZStack(alignment: .bottom) {
            SmartBackground()
            if store.isSignedIn {
                Group {
                    switch selectedSection {
                    case .projects:
                        ProjectsDashboardView()
                    case .shifts:
                        ShiftsView()
                    case .utilities:
                        UtilitiesDashboardView()
                    }
                }
                .padding(.bottom, 78)

                SmartBottomBar(selectedSection: $selectedSection)
            } else {
                SignInView()
            }
        }
        .preferredColorScheme(.dark)
        .environment(\.font, SmartTheme.body(15))
    }
}

private struct SignInView: View {
    @EnvironmentObject private var store: SurveyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            SmartAVLogoLockup(wordmarkWidth: 128, iconSize: 34)
            Text("Choose your demo user")
                .font(SmartTheme.display(34))
                .foregroundStyle(.white)
            Text("Roles control who can delete records, manage shifts, and save permanent task, area, and equipment suggestions.")
                .font(.subheadline)
                .foregroundStyle(SmartTheme.muted)
            VStack(spacing: 10) {
                ForEach(store.employees.sorted { roleRank($0.role) < roleRank($1.role) }) { employee in
                    Button {
                        store.signIn(as: employee)
                    } label: {
                        SmartGlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(roleColor(employee.role))
                                    .frame(width: 12, height: 12)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(employee.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text(employee.role)
                                        .font(.caption.bold())
                                        .foregroundStyle(SmartTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer()
        }
        .padding(20)
    }
}

private struct UserSwitcherView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Signed in as")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.primary)
                        Text(store.currentUser?.name ?? "No user")
                            .font(SmartTheme.display(34))
                            .foregroundStyle(.white)
                        ForEach(store.employees.sorted { roleRank($0.role) < roleRank($1.role) }) { employee in
                            Button {
                                store.signIn(as: employee)
                                dismiss()
                            } label: {
                                SmartGlassCard(padding: 14) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(roleColor(employee.role))
                                            .frame(width: 12, height: 12)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(employee.name)
                                                .font(.headline)
                                                .foregroundStyle(.white)
                                            Text(employee.role)
                                                .font(.caption.bold())
                                                .foregroundStyle(SmartTheme.muted)
                                        }
                                        Spacer()
                                        if store.currentUserId == employee.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(SmartTheme.success)
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        Button(role: .destructive) {
                            store.signOut()
                            dismiss()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SmartTheme.danger)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("User")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct SmartBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                SmartTheme.background,
                SmartTheme.surface
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            LinearGradient(
                colors: [
                    SmartTheme.primary.opacity(0.18),
                    Color.clear,
                    SmartTheme.cyan.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
}

private struct SmartBottomBar: View {
    @Binding var selectedSection: MainSection

    var body: some View {
        HStack(spacing: 18) {
            bottomButton(.projects, title: "Projects", icon: "house.fill")
            bottomButton(.shifts, title: "Shifts", icon: "calendar.badge.clock")
            bottomButton(.utilities, title: "Utilities", icon: "wrench.and.screwdriver.fill")
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(SmartTheme.border, lineWidth: 1)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private func bottomButton(_ section: MainSection, title: String, icon: String) -> some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                selectedSection = section
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
                    .font(.caption.bold())
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundStyle(selectedSection == section ? .white : SmartTheme.muted)
            .background(selectedSection == section ? SmartTheme.primary : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

private struct SmartGlassCard<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(padding)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(SmartTheme.border, lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.32), radius: 20, x: 0, y: 12)
    }
}

private struct ProjectsDashboardView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var showingNewProject = false
    @State private var showingUserSwitcher = false
    @State private var searchText = ""

    private var filteredLocations: [SurveyLocation] {
        let sorted = store.locations.sorted { $0.updatedAt > $1.updatedAt }
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return sorted }
        return sorted.filter { $0.name.lowercased().contains(query) || $0.address.lowercased().contains(query) }
    }

    private var totals: ProjectTotals {
        ProjectTotals(locations: store.locations)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    overview
                    searchField

                    VStack(spacing: 12) {
                        if filteredLocations.isEmpty {
                            SmartEmptyState(title: store.locations.isEmpty ? "No Projects" : "No Results", subtitle: store.locations.isEmpty ? "Create your first Smart AV installation project." : "Try another name or address.")
                        } else {
                            ForEach(filteredLocations) { location in
                                NavigationLink {
                                    ProjectAreasView(projectId: location.id)
                                        .environmentObject(store)
                                } label: {
                                    ProjectCard(location: location)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingNewProject) {
                NewProjectView()
                    .environmentObject(store)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 5) {
                SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                Text("Projects")
                    .font(SmartTheme.display(38))
                    .foregroundStyle(SmartTheme.text)
            }
            Spacer()
            Button {
                showingUserSwitcher = true
            } label: {
                VStack(spacing: 2) {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                    Text(store.currentUser?.name ?? "User")
                        .font(.caption2.bold())
                }
                .frame(width: 58, height: 46)
                .background(SmartTheme.panelStrong, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            if store.canManageProjects {
                Button {
                    showingNewProject = true
                } label: {
                    Image(systemName: "plus")
                        .font(.headline)
                        .frame(width: 46, height: 46)
                        .background(LinearGradient(colors: [SmartTheme.primary, SmartTheme.warning], startPoint: .topLeading, endPoint: .bottomTrailing), in: Circle())
                        .foregroundStyle(.white)
                }
            }
        }
        .sheet(isPresented: $showingUserSwitcher) {
            UserSwitcherView()
                .environmentObject(store)
        }
    }

    private var overview: some View {
        SmartGlassCard {
            HStack(spacing: 18) {
                ProgressRing(progress: totals.completion)
                    .frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 10) {
                    MetricLine(title: "Projects", value: "\(store.locations.count)", color: SmartTheme.cyan)
                    MetricLine(title: "Areas", value: "\(totals.totalAreas)", color: SmartTheme.primary)
                    MetricLine(title: "Open Tasks", value: "\(totals.openTasks)", color: totals.openTasks == 0 ? SmartTheme.success : SmartTheme.warning)
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(SmartTheme.muted)
            TextField("Search projects", text: $searchText)
                .textInputAutocapitalization(.words)
                .foregroundStyle(.white)
        }
        .padding(14)
        .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(SmartTheme.border, lineWidth: 1)
        }
    }
}

private struct ProjectTotals {
    let totalAreas: Int
    let readyAreas: Int
    let openTasks: Int
    let completion: Double

    init(locations: [SurveyLocation]) {
        totalAreas = locations.reduce(0) { $0 + $1.snapshot.areaLandmarks.count }
        readyAreas = locations.reduce(0) { partial, location in
            partial + location.snapshot.areaLandmarks.filter { area in
                location.snapshot.siteTasks.filter { $0.areaId == area.id && $0.status != "Done" }.isEmpty
            }.count
        }
        openTasks = locations.reduce(0) { $0 + $1.snapshot.siteTasks.filter { $0.status != "Done" }.count }
        let totalTasks = locations.reduce(0) { $0 + $1.snapshot.siteTasks.count }
        let doneTasks = locations.reduce(0) { $0 + $1.snapshot.siteTasks.filter { $0.status == "Done" }.count }
        completion = totalTasks == 0 ? (totalAreas == 0 ? 0 : Double(readyAreas) / Double(totalAreas)) : Double(doneTasks) / Double(totalTasks)
    }
}

private struct ProjectCard: View {
    let location: SurveyLocation

    private var metrics: ProjectMetrics {
        ProjectMetrics(location: location)
    }

    var body: some View {
        SmartGlassCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(metrics.accent.opacity(0.18))
                        .frame(width: 46, height: 46)
                    Image(systemName: "house.lodge.fill")
                        .foregroundStyle(metrics.accent)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(location.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Spacer()
                        MiniProgressRing(progress: metrics.completion, color: metrics.accent)
                            .frame(width: 42, height: 42)
                    }
                    if !location.address.isEmpty {
                        Text(location.address)
                            .font(.caption)
                            .foregroundStyle(SmartTheme.muted)
                            .lineLimit(1)
                    }
                    Text("\(Int(metrics.completion * 100))% Complete · \(metrics.openTasks) Open Tasks · \(metrics.readyAreas) / \(metrics.totalAreas) Areas Ready")
                        .font(.caption.bold())
                        .foregroundStyle(metrics.accent)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
            }
        }
    }
}

private struct ProjectMetrics {
    let totalAreas: Int
    let readyAreas: Int
    let openTasks: Int
    let completion: Double
    let accent: Color

    init(location: SurveyLocation) {
        totalAreas = location.snapshot.areaLandmarks.count
        openTasks = location.snapshot.siteTasks.filter { $0.status != "Done" }.count
        readyAreas = location.snapshot.areaLandmarks.filter { area in
            location.snapshot.siteTasks.filter { $0.areaId == area.id && $0.status != "Done" }.isEmpty
        }.count
        let totalTasks = location.snapshot.siteTasks.count
        let doneTasks = location.snapshot.siteTasks.filter { $0.status == "Done" }.count
        completion = totalTasks == 0 ? (totalAreas == 0 ? 0 : Double(readyAreas) / Double(totalAreas)) : Double(doneTasks) / Double(totalTasks)
        accent = openTasks == 0 ? SmartTheme.success : completion < 0.35 ? SmartTheme.danger : SmartTheme.warning
    }
}

private struct ProjectAreasView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @Environment(\.dismiss) private var dismiss
    let projectId: UUID
    @State private var showingAddArea = false
    @State private var showingDeleteProjectConfirmation = false
    @State private var selectedProjectSection = "Areas"

    private var areas: [AreaLandmark] {
        store.areaLandmarks.sorted { left, right in
            let leftRank = areaSortRank(left)
            let rightRank = areaSortRank(right)
            if leftRank != rightRank { return leftRank < rightRank }
            return left.name.localizedCaseInsensitiveCompare(right.name) == .orderedAscending
        }
    }

    private var projectTitle: String {
        store.currentLocation?.name ?? store.projectName
    }

    private var projectAddress: String {
        store.currentLocation?.address ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    SmartIconButton(systemName: "chevron.left") { dismiss() }
                    Spacer()
                    if store.canManageProjects {
                        SmartIconButton(systemName: "trash") {
                            showingDeleteProjectConfirmation = true
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 5) {
                    Text(projectTitle)
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                    if !projectAddress.isEmpty {
                        Text(projectAddress)
                            .font(.caption)
                            .foregroundStyle(SmartTheme.muted)
                    }
                }
                HStack(spacing: 12) {
                    ProjectSummaryPill(title: "Areas", value: "\(areas.count)", color: SmartTheme.cyan)
                    ProjectSummaryPill(title: "Open Tasks", value: "\(store.siteTasks.filter { $0.status != "Done" }.count)", color: SmartTheme.warning)
                    ProjectSummaryPill(title: "Equipment", value: "\(projectEquipmentCount)", color: SmartTheme.success)
                }
                projectSectionPicker
                Group {
                    switch selectedProjectSection {
                    case "Equipment":
                        ProjectEquipmentSummaryView()
                            .environmentObject(store)
                    case "Passwords":
                        ProjectVaultView(projectId: projectId, projectName: projectTitle)
                    case "Files":
                        ProjectFilesView()
                            .environmentObject(store)
                    case "Final Check":
                        SecurityFinalCheckView()
                            .environmentObject(store)
                    case "All Tasks":
                        ProjectTaskListView(title: "All Tasks", tasks: store.siteTasks)
                            .environmentObject(store)
                    case "Wi-Fi Analyzer":
                        SignalAnalyzerUtilityView()
                            .environmentObject(store)
                            .environmentObject(bluetooth)
                    default:
                        VStack(spacing: 12) {
                            if !store.siteTasks.filter({ $0.areaId == nil }).isEmpty {
                                NavigationLink {
                                    ProjectTaskListView(title: "Whole House", tasks: store.siteTasks.filter { $0.areaId == nil })
                                        .environmentObject(store)
                                } label: {
                                    WholeHouseAreaCard()
                                        .environmentObject(store)
                                }
                                .buttonStyle(.plain)
                            }
                            if areas.isEmpty {
                                SmartEmptyState(title: "No Areas", subtitle: "Add rooms and work zones for this project.")
                            } else {
                                ForEach(areas) { area in
                                    NavigationLink {
                                        AreaTasksView(area: area)
                                            .environmentObject(store)
                                    } label: {
                                        AreaCard(area: area)
                                            .environmentObject(store)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }
                if selectedProjectSection == "Areas" {
                    Button {
                        showingAddArea = true
                    } label: {
                        Label("Add Area", systemImage: "plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LinearGradient(colors: [SmartTheme.primary, SmartTheme.cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 4)
                    projectMapActions
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 120)
        }
        .background(SmartBackground())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingAddArea) {
            AreaSuggestionPickerView(title: "Add Area") { names in
                for name in names {
                    store.addUnmappedArea(name: name, floorId: store.buildingFloors.first?.id)
                }
            }
            .environmentObject(store)
        }
        .onAppear {
            store.switchLocation(to: projectId, showsMessage: false)
        }
        .confirmationDialog("Delete this project?", isPresented: $showingDeleteProjectConfirmation, titleVisibility: .visible) {
            Button("Delete Project", role: .destructive) {
                store.deleteCurrentLocation()
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the selected house, areas, tasks, shifts, files, passwords, and project data from this phone.")
        }
    }

    private var projectSectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["Areas", "All Tasks", "Wi-Fi Analyzer", "Equipment", "Files", "Final Check", "Passwords"], id: \.self) { section in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.86)) {
                            selectedProjectSection = section
                        }
                    } label: {
                        Text(section)
                            .font(.caption.bold())
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(selectedProjectSection == section ? SmartTheme.primary : SmartTheme.panel, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(5)
        .background(SmartTheme.panel, in: Capsule())
    }

    private var projectMapActions: some View {
        HStack(spacing: 10) {
            NavigationLink {
                AreaManagementView()
            } label: {
                Label("Project Map", systemImage: "map.fill")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(SmartTheme.cyan)
            }
            NavigationLink {
                AreaLandmarkCaptureView()
            } label: {
                Label("AR Mapping", systemImage: "arkit")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .foregroundStyle(SmartTheme.muted)
            }
        }
        .buttonStyle(.plain)
    }

    private var projectEquipmentCount: Int {
        let legacy = store.locationEquipment.reduce(0) { $0 + max($1.quantity, 1) }
        let taskLinked = store.siteTasks.reduce(0) { partial, task in
            partial + ProjectEquipmentSummaryView.equipmentItems(from: task.note).count
        }
        return legacy + taskLinked
    }

    private func areaSortRank(_ area: AreaLandmark) -> Int {
        let tasks = store.tasks(in: area)
        if tasks.contains(where: { $0.status == "Blocked" || $0.category == "Blocked Path" }) { return 0 }
        if tasks.contains(where: { $0.status != "Done" }) { return 1 }
        return 2
    }
}

private struct ProjectEquipmentSummaryItem: Identifiable {
    let id: String
    let name: String
    let source: String
    let areaName: String
    let status: String
    let statusColor: Color
}

private struct ProjectEquipmentSummaryView: View {
    @EnvironmentObject private var store: SurveyStore

    private var items: [ProjectEquipmentSummaryItem] {
        var result: [ProjectEquipmentSummaryItem] = []

        for item in store.locationEquipment {
            let areaName = item.areaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name } ?? "Project"
            result.append(ProjectEquipmentSummaryItem(
                id: "legacy-\(item.id.uuidString)",
                name: item.quantity > 1 ? "\(item.quantity)x \(item.name)" : item.name,
                source: item.category,
                areaName: areaName,
                status: item.isPacked ? "Ready" : "Needs Work",
                statusColor: item.isPacked ? SmartTheme.success : SmartTheme.warning
            ))
        }

        for task in store.siteTasks {
            let taskEquipment = Self.equipmentItems(from: task.note)
            guard !taskEquipment.isEmpty else { continue }
            let areaName = task.areaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name } ?? "Project"
            for (index, name) in taskEquipment.enumerated() {
                result.append(ProjectEquipmentSummaryItem(
                    id: "task-\(task.id.uuidString)-\(index)",
                    name: name,
                    source: task.title,
                    areaName: areaName,
                    status: task.status == "Done" ? "Installed" : task.status,
                    statusColor: task.status == "Done" ? SmartTheme.success : task.status == "Blocked" ? SmartTheme.danger : SmartTheme.warning
                ))
            }
        }

        return result.sorted {
            if $0.status == $1.status { return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            return $0.status != "Installed" && $0.status != "Ready"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmartGlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("House Equipment")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("\(items.count) items linked to this project")
                            .font(.caption)
                            .foregroundStyle(SmartTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "shippingbox.fill")
                        .font(.title2)
                        .foregroundStyle(SmartTheme.cyan)
                }
            }
            if items.isEmpty {
                SmartEmptyState(title: "No Equipment", subtitle: "Open a task, tap Add Equipment, and selected items will appear here.")
            } else {
                ForEach(items) { item in
                    SmartGlassCard(padding: 14) {
                        HStack(alignment: .top, spacing: 12) {
                            Circle()
                                .fill(item.statusColor)
                                .frame(width: 10, height: 10)
                                .padding(.top, 6)
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Text(item.status)
                                        .font(.caption.bold())
                                        .foregroundStyle(item.statusColor)
                                }
                                Text("\(item.areaName) · \(item.source)")
                                    .font(.caption)
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }
                    }
                }
            }
        }
    }

    static func equipmentItems(from note: String) -> [String] {
        let normalized = note.replacingOccurrences(of: "\n\nInstallation Details:\n", with: "\n\nEquipment:\n")
        let parts = normalized.components(separatedBy: "\n\nEquipment:\n")
        guard parts.count > 1 else { return [] }
        return parts.dropFirst().joined(separator: "\n")
            .split(separator: "\n")
            .map { line in
                line.replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
    }
}

private struct ProjectFilesView: View {
    @EnvironmentObject private var store: SurveyStore
    @Environment(\.openURL) private var openURL
    @State private var showingImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmartGlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Project Files")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Photos, PDFs, invoices, drawings, and project notes attached to this house.")
                            .font(.caption)
                            .foregroundStyle(SmartTheme.muted)
                    }
                    Spacer()
                    Button {
                        showingImporter = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(SmartTheme.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            if store.projectFiles.isEmpty {
                SmartEmptyState(title: "No Files", subtitle: "Attach project photos, plans, handover files, or device documents.")
            } else {
                ForEach(store.projectFiles.sorted { $0.createdAt > $1.createdAt }) { file in
                    SmartGlassCard(padding: 14) {
                        HStack(spacing: 12) {
                            Image(systemName: fileIcon(file))
                                .font(.title3)
                                .foregroundStyle(SmartTheme.cyan)
                                .frame(width: 30)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(file.name)
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("\(file.originalFilename) · \(file.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundStyle(SmartTheme.muted)
                            }
                            Spacer()
                            Menu {
                                if let url = store.localFileURL(for: file) {
                                    Button("Open") { openURL(url) }
                                }
                                if store.canDeleteRecords {
                                    Button("Delete", role: .destructive) {
                                        store.delete(projectFile: file)
                                    }
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.item], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                for url in urls {
                    store.importProjectFile(from: url)
                }
            }
        }
    }

    private func fileIcon(_ file: ProjectFileAttachment) -> String {
        if file.contentType.contains("image") { return "photo.fill" }
        if file.contentType.contains("pdf") { return "doc.richtext.fill" }
        return "doc.fill"
    }
}

private struct SecurityFinalCheckView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var newTitle = ""

    private var doneCount: Int {
        store.securityCheckItems.filter(\.isDone).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmartGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Final Security Check")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(doneCount) / \(store.securityCheckItems.count) checked")
                                .font(.caption.bold())
                                .foregroundStyle(SmartTheme.cyan)
                        }
                        Spacer()
                        Button {
                            store.generateSecurityChecklistFromProject()
                        } label: {
                            Label("Build List", systemImage: "wand.and.stars")
                                .font(.caption.bold())
                                .foregroundStyle(SmartTheme.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    HStack {
                        TextField("Add manual check item", text: $newTitle)
                            .foregroundStyle(.white)
                        Button {
                            addManualItem()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SmartTheme.muted : SmartTheme.cyan)
                        }
                        .buttonStyle(.plain)
                        .disabled(newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            if store.securityCheckItems.isEmpty {
                SmartEmptyState(title: "No Checklist Yet", subtitle: "Tap Build List to create final tests from security tasks and common alarm components.")
            } else {
                ForEach(groupedKeys, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(category.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.muted)
                            .padding(.leading, 4)
                        ForEach(items(in: category)) { item in
                            SmartGlassCard(padding: 14) {
                                HStack(alignment: .top, spacing: 12) {
                                    Button {
                                        store.toggle(securityCheckItem: item)
                                    } label: {
                                        Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                                            .font(.title3)
                                            .foregroundStyle(item.isDone ? SmartTheme.success : SmartTheme.warning)
                                    }
                                    .buttonStyle(.plain)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                            .strikethrough(item.isDone)
                                        Text(areaName(item.areaId))
                                            .font(.caption)
                                            .foregroundStyle(SmartTheme.muted)
                                    }
                                    Spacer()
                                    if store.canDeleteRecords {
                                        Button(role: .destructive) {
                                            store.delete(securityCheckItem: item)
                                        } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(SmartTheme.danger)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupedKeys: [String] {
        Array(Set(store.securityCheckItems.map(\.category))).sorted()
    }

    private func items(in category: String) -> [SecurityCheckItem] {
        store.securityCheckItems
            .filter { $0.category == category }
            .sorted {
                if $0.isDone != $1.isDone { return !$0.isDone }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
    }

    private func areaName(_ id: UUID?) -> String {
        id.flatMap { areaId in store.areaLandmarks.first { $0.id == areaId }?.name } ?? "Whole project"
    }

    private func addManualItem() {
        let clean = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        store.save(securityCheckItem: SecurityCheckItem(id: UUID(), title: clean, category: "Manual", areaId: nil, taskId: nil, isDone: false, note: "", updatedAt: Date()))
        newTitle = ""
    }
}

private struct SecureCredential: Codable, Identifiable {
    let id: UUID
    var projectId: UUID
    var title: String
    var username: String
    var password: String
    var category: String
    var notes: String
    var updatedAt: Date
}

private struct EncryptedCredentialRecord: Codable, Identifiable {
    let id: UUID
    let projectId: UUID
    let nonce: String
    let ciphertext: String
    let tag: String
    let updatedAt: Date
}

private enum SmartVault {
    private static let recordsKey = "smartAVEncryptedCredentialRecords"
    private static let keychainService = "com.smartav.project-vault"
    private static let keychainAccount = "vault-key-v1"

    static func load(projectId: UUID) -> [SecureCredential] {
        loadRecords()
            .filter { $0.projectId == projectId }
            .compactMap(decrypt)
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ credential: SecureCredential) {
        var records = loadRecords()
        records.removeAll { $0.id == credential.id }
        if let encrypted = encrypt(credential) {
            records.append(encrypted)
            saveRecords(records)
        }
    }

    static func delete(_ credential: SecureCredential) {
        var records = loadRecords()
        records.removeAll { $0.id == credential.id }
        saveRecords(records)
    }

    private static func loadRecords() -> [EncryptedCredentialRecord] {
        guard let data = UserDefaults.standard.data(forKey: recordsKey),
              let records = try? JSONDecoder().decode([EncryptedCredentialRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func saveRecords(_ records: [EncryptedCredentialRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: recordsKey)
        }
    }

    private static func encrypt(_ credential: SecureCredential) -> EncryptedCredentialRecord? {
        guard let key = vaultKey(),
              let data = try? JSONEncoder().encode(credential),
              let sealed = try? AES.GCM.seal(data, using: key) else {
            return nil
        }
        return EncryptedCredentialRecord(
            id: credential.id,
            projectId: credential.projectId,
            nonce: Data(sealed.nonce).base64EncodedString(),
            ciphertext: sealed.ciphertext.base64EncodedString(),
            tag: sealed.tag.base64EncodedString(),
            updatedAt: credential.updatedAt
        )
    }

    private static func decrypt(_ record: EncryptedCredentialRecord) -> SecureCredential? {
        guard let key = vaultKey(),
              let nonceData = Data(base64Encoded: record.nonce),
              let ciphertext = Data(base64Encoded: record.ciphertext),
              let tag = Data(base64Encoded: record.tag),
              let nonce = try? AES.GCM.Nonce(data: nonceData),
              let data = try? AES.GCM.open(AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag), using: key) else {
            return nil
        }
        return try? JSONDecoder().decode(SecureCredential.self, from: data)
    }

    private static func vaultKey() -> SymmetricKey? {
        if let data = keychainData() {
            return SymmetricKey(data: data)
        }
        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        return saveKeychainData(data) ? key : nil
    }

    private static func keychainData() -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
        return item as? Data
    }

    private static func saveKeychainData(_ data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        SecItemDelete(query as CFDictionary)
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }
}

private struct ProjectVaultView: View {
    let projectId: UUID
    let projectName: String
    @State private var credentials: [SecureCredential] = []
    @State private var showingEditor = false
    @State private var editingCredential: SecureCredential?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SmartGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Secure Password Vault")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Encrypted locally with a Keychain-protected key.")
                                .font(.caption)
                                .foregroundStyle(SmartTheme.muted)
                        }
                        Spacer()
                        Button {
                            editingCredential = nil
                            showingEditor = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(SmartTheme.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    Text("Share only with trusted team members. Full team sync and permissions should be added after login/accounts are implemented.")
                        .font(.caption2)
                        .foregroundStyle(SmartTheme.warning)
                }
            }
            if credentials.isEmpty {
                SmartEmptyState(title: "No Passwords", subtitle: "Save Wi-Fi, NVR, alarm, controller, router, and device credentials for this project.")
            } else {
                ForEach(credentials) { credential in
                    Button {
                        editingCredential = credential
                        showingEditor = true
                    } label: {
                        SmartGlassCard(padding: 14) {
                            HStack(spacing: 12) {
                                Image(systemName: icon(for: credential.category))
                                    .foregroundStyle(SmartTheme.cyan)
                                    .frame(width: 28)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(credential.title)
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                    Text("\(credential.category) · \(credential.username.isEmpty ? "No username" : credential.username)")
                                        .font(.caption)
                                        .foregroundStyle(SmartTheme.muted)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { reload() }
        .sheet(isPresented: $showingEditor, onDismiss: reload) {
            CredentialEditorView(projectId: projectId, credential: editingCredential)
        }
    }

    private func reload() {
        credentials = SmartVault.load(projectId: projectId)
    }

    private func icon(for category: String) -> String {
        switch category {
        case "Wi-Fi": return "wifi"
        case "NVR", "Camera": return "camera.fill"
        case "Alarm": return "shield.lefthalf.filled"
        case "Router", "Network": return "network"
        default: return "key.fill"
        }
    }
}

private struct CredentialEditorView: View {
    @Environment(\.dismiss) private var dismiss
    let projectId: UUID
    var credential: SecureCredential?
    @State private var title = ""
    @State private var username = ""
    @State private var password = ""
    @State private var category = "Wi-Fi"
    @State private var notes = ""
    @State private var revealPassword = false

    private let categories = ["Wi-Fi", "NVR", "Camera", "Alarm", "Router", "Network", "Controller", "Other"]

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        SmartField(title: "Title", text: $title, prompt: "Main Wi-Fi / NVR / Router")
                        SmartGlassCard {
                            Picker("Type", selection: $category) {
                                ForEach(categories, id: \.self) { Text($0) }
                            }
                            .pickerStyle(.menu)
                            .tint(.white)
                        }
                        SmartField(title: "Username", text: $username, prompt: "admin / email / SSID")
                        SmartGlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Password")
                                    .font(.caption.bold())
                                    .foregroundStyle(SmartTheme.muted)
                                HStack {
                                    if revealPassword {
                                        TextField("Password", text: $password)
                                            .foregroundStyle(.white)
                                    } else {
                                        SecureField("Password", text: $password)
                                            .foregroundStyle(.white)
                                    }
                                    Button {
                                        revealPassword.toggle()
                                    } label: {
                                        Image(systemName: revealPassword ? "eye.slash" : "eye")
                                            .foregroundStyle(SmartTheme.cyan)
                                    }
                                }
                            }
                        }
                        SmartField(title: "Notes", text: $notes, prompt: "Optional device notes", axis: .vertical)
                        if credential != nil {
                            Button(role: .destructive) {
                                if let credential {
                                    SmartVault.delete(credential)
                                }
                                dismiss()
                            } label: {
                                Label("Delete Credential", systemImage: "trash")
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(SmartTheme.danger)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(credential == nil ? "Add Password" : "Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        SmartVault.save(SecureCredential(
                            id: credential?.id ?? UUID(),
                            projectId: projectId,
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                            password: password,
                            category: category,
                            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
                            updatedAt: Date()
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard let credential else { return }
            title = credential.title
            username = credential.username
            password = credential.password
            category = credential.category
            notes = credential.notes
        }
    }
}

private struct AreaCard: View {
    @EnvironmentObject private var store: SurveyStore
    let area: AreaLandmark

    private var tasks: [SiteTask] {
        store.tasks(in: area)
    }

    private var openTasks: [SiteTask] {
        tasks.filter { $0.status != "Done" }
    }

    private var doneCount: Int {
        tasks.filter { $0.status == "Done" }.count
    }

    private var stateColor: Color {
        if openTasks.contains(where: { $0.status == "Blocked" || $0.category == "Blocked Path" }) { return SmartTheme.danger }
        return openTasks.isEmpty ? SmartTheme.success : SmartTheme.warning
    }

    private var stateText: String {
        if openTasks.contains(where: { $0.status == "Blocked" || $0.category == "Blocked Path" }) { return "Blocked" }
        if openTasks.isEmpty { return "Ready" }
        return "\(openTasks.count) Tasks Remaining"
    }

    var body: some View {
        SmartGlassCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(stateColor.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: iconName)
                        .foregroundStyle(stateColor)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(area.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(stateText)
                            .font(.caption.bold())
                            .foregroundStyle(stateColor)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(stateColor.opacity(0.14), in: Capsule())
                    }
                    Text(tasks.isEmpty ? "No tasks yet" : "\(doneCount) / \(tasks.count) Tasks Complete")
                        .font(.caption)
                        .foregroundStyle(SmartTheme.muted)
                }
            }
        }
    }

    private var iconName: String {
        let lower = area.name.lowercased()
        if lower.contains("kitchen") { return "fork.knife" }
        if lower.contains("bed") { return "bed.double.fill" }
        if lower.contains("garage") { return "car.fill" }
        if lower.contains("patio") || lower.contains("pool") { return "sun.max.fill" }
        return "square.grid.2x2.fill"
    }
}

private struct WholeHouseAreaCard: View {
    @EnvironmentObject private var store: SurveyStore

    private var tasks: [SiteTask] {
        store.siteTasks.filter { $0.areaId == nil }
    }

    private var openTasks: [SiteTask] {
        tasks.filter { $0.status != "Done" }
    }

    var body: some View {
        SmartGlassCard {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(SmartTheme.primary.opacity(0.16))
                        .frame(width: 46, height: 46)
                    Image(systemName: "house.fill")
                        .foregroundStyle(openTasks.isEmpty ? SmartTheme.success : SmartTheme.primary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Whole House")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Spacer()
                        Text(openTasks.isEmpty ? "Ready" : "\(openTasks.count) Tasks Remaining")
                            .font(.caption.bold())
                            .foregroundStyle(openTasks.isEmpty ? SmartTheme.success : SmartTheme.warning)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background((openTasks.isEmpty ? SmartTheme.success : SmartTheme.warning).opacity(0.14), in: Capsule())
                    }
                    Text("\(tasks.filter { $0.status == "Done" }.count) / \(tasks.count) Tasks Complete")
                        .font(.caption)
                        .foregroundStyle(SmartTheme.muted)
                }
            }
        }
    }
}

private struct ProjectTaskListView: View {
    @EnvironmentObject private var store: SurveyStore
    let title: String
    let tasks: [SiteTask]
    @State private var editingTask: SiteTask?
    @State private var showingTaskPicker = false

    private var sortedTasks: [SiteTask] {
        tasks.sorted { left, right in
            if (left.status == "Done") != (right.status == "Done") {
                return left.status != "Done"
            }
            let leftRank = priorityRank(left.priority)
            let rightRank = priorityRank(right.priority)
            if leftRank != rightRank { return leftRank < rightRank }
            switch (left.dueDate, right.dueDate) {
            case let (leftDate?, rightDate?):
                if leftDate != rightDate { return leftDate < rightDate }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                break
            }
            return left.updatedAt > right.updatedAt
        }
    }

    var body: some View {
        ZStack {
            SmartBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text(title)
                            .font(SmartTheme.display(36))
                            .foregroundStyle(.white)
                        Spacer()
                        SmartIconButton(systemName: "plus") {
                            showingTaskPicker = true
                        }
                    }
                    if sortedTasks.isEmpty {
                        SmartEmptyState(title: "No Tasks", subtitle: "Add work items from an area or create whole-house tasks.")
                    } else {
                        ForEach(sortedTasks) { task in
                            Button {
                                editingTask = task
                            } label: {
                                VStack(alignment: .leading, spacing: 6) {
                                    TaskCard(task: task)
                                        .environmentObject(store)
                                    Text(task.areaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name } ?? "Whole House")
                                        .font(.caption.bold())
                                        .foregroundStyle(SmartTheme.cyan)
                                        .padding(.leading, 14)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingTask) { task in
            QuickTaskEditorView(task: task, defaultFloorId: task.floorId, defaultAreaId: task.areaId)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingTaskPicker) {
            QuickTaskPickerView(defaultFloorId: store.buildingFloors.first?.id, defaultAreaId: nil)
                .environmentObject(store)
        }
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "Urgent": return 0
        case "High": return 1
        case "Normal": return 2
        default: return 3
        }
    }
}

private struct AreaTasksView: View {
    @EnvironmentObject private var store: SurveyStore
    @Environment(\.dismiss) private var dismiss
    let area: AreaLandmark
    @State private var showingTaskEditor = false
    @State private var editingTask: SiteTask?
    @State private var showingDeleteAreaConfirmation = false

    private var currentArea: AreaLandmark {
        store.areaLandmarks.first { $0.id == area.id } ?? area
    }

    private var areaTasks: [SiteTask] {
        store.tasks(in: currentArea).sorted(by: taskComesBefore)
    }

    private var todo: [SiteTask] {
        areaTasks.filter { $0.status == "To Do" || $0.status == "Blocked" }
    }

    private var inProgress: [SiteTask] {
        areaTasks.filter { $0.status == "In Progress" }
    }

    private var done: [SiteTask] {
        areaTasks.filter { $0.status == "Done" }
    }

    private var completedCount: Int {
        done.count
    }

    private func taskComesBefore(_ left: SiteTask, _ right: SiteTask) -> Bool {
        let leftPriority = priorityRank(left.priority)
        let rightPriority = priorityRank(right.priority)
        if leftPriority != rightPriority { return leftPriority < rightPriority }
        switch (left.dueDate, right.dueDate) {
        case let (leftDate?, rightDate?):
            if leftDate != rightDate { return leftDate < rightDate }
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            break
        }
        return left.updatedAt > right.updatedAt
    }

    private func priorityRank(_ priority: String) -> Int {
        switch priority {
        case "Urgent": return 0
        case "High": return 1
        case "Normal": return 2
        default: return 3
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            List {
                taskSection("To Do", tasks: todo)
                taskSection("In Progress", tasks: inProgress)
                taskSection("Done", tasks: done)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
        }
        .background(SmartBackground())
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showingTaskEditor) {
            QuickTaskPickerView(defaultFloorId: currentArea.floorId, defaultAreaId: currentArea.id)
                .environmentObject(store)
        }
        .sheet(item: $editingTask) { task in
            QuickTaskEditorView(task: task, defaultFloorId: currentArea.floorId, defaultAreaId: currentArea.id)
                .environmentObject(store)
        }
        .confirmationDialog("Delete this area?", isPresented: $showingDeleteAreaConfirmation, titleVisibility: .visible) {
            Button("Delete Area", role: .destructive) {
                store.delete(area: currentArea)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This also removes tasks and equipment linked to this area.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                SmartIconButton(systemName: "chevron.left") { dismiss() }
                Spacer()
                if store.canDeleteRecords {
                    SmartIconButton(systemName: "trash") {
                        showingDeleteAreaConfirmation = true
                    }
                }
                SmartIconButton(systemName: "plus") { showingTaskEditor = true }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text(currentArea.name)
                    .font(SmartTheme.display(36))
                    .foregroundStyle(.white)
                Text("\(completedCount) / \(areaTasks.count) Completed")
                    .font(SmartTheme.bodyBold(15))
                    .foregroundStyle(SmartTheme.primary)
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule()
                            .fill(LinearGradient(colors: [SmartTheme.primary, SmartTheme.cyan], startPoint: .leading, endPoint: .trailing))
                            .frame(width: proxy.size.width * CGFloat(areaTasks.isEmpty ? 0 : Double(completedCount) / Double(areaTasks.count)))
                    }
                }
                .frame(height: 7)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    @ViewBuilder
    private func taskSection(_ title: String, tasks: [SiteTask]) -> some View {
        if !tasks.isEmpty {
            Section {
                ForEach(tasks) { task in
                    TaskCard(task: task)
                        .environmentObject(store)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .onTapGesture { editingTask = task }
                        .swipeActions(edge: .trailing) {
                            Button {
                                store.updateSiteTaskStatus(task, status: "Done")
                            } label: {
                                Label("Complete", systemImage: "checkmark")
                            }
                            .tint(.green)
                            Button {
                                editingTask = task
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                editingTask = task
                            } label: {
                                Label("Reassign", systemImage: "person.crop.circle.badge.plus")
                            }
                            .tint(.orange)
                        }
                }
            } header: {
                Text(title.uppercased())
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                    .padding(.leading, 4)
            }
        }
    }
}

private struct TaskCard: View {
    @EnvironmentObject private var store: SurveyStore
    let task: SiteTask

    private var statusColor: Color {
        switch task.status {
        case "Done": return SmartTheme.success
        case "In Progress": return SmartTheme.cyan
        case "Blocked": return SmartTheme.danger
        default: return SmartTheme.warning
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case "Urgent": return SmartTheme.danger
        case "High": return SmartTheme.warning
        case "Low": return SmartTheme.muted
        default: return SmartTheme.cyan
        }
    }

    var body: some View {
        SmartGlassCard(padding: 14) {
            HStack(alignment: .top, spacing: 12) {
                Button {
                    store.updateSiteTaskStatus(task, status: task.status == "Done" ? "To Do" : "Done")
                } label: {
                    Image(systemName: task.status == "Done" ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(statusColor)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(task.title)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .strikethrough(task.status == "Done")
                        Spacer()
                        Text(task.status)
                            .font(.caption.bold())
                            .foregroundStyle(statusColor)
                    }
                    HStack(spacing: 8) {
                        Label(assignees, systemImage: "person.fill")
                        if let dueDate = task.dueDate {
                            Label(dueDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        }
                        Label(task.priority, systemImage: "flag.fill")
                            .foregroundStyle(priorityColor)
                    }
                    .font(.caption)
                    .foregroundStyle(SmartTheme.muted)
                    if !task.note.isEmpty {
                        Text(task.note)
                            .font(.caption)
                            .foregroundStyle(SmartTheme.muted)
                            .lineLimit(2)
                    }
                    if !task.subtasks.isEmpty {
                        Text("\(task.subtasks.filter { $0.isDone }.count) / \(task.subtasks.count) subtasks done")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.cyan)
                    }
                }
            }
        }
    }

    private var assignees: String {
        let names = store.employees.filter { task.assigneeIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Unassigned" : names.joined(separator: ", ")
    }
}

private struct QuickTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    var task: SiteTask?
    var defaultFloorId: UUID?
    var defaultAreaId: UUID?
    @State private var title = ""
    @State private var status = "To Do"
    @State private var priority = "Normal"
    @State private var selectedAreaId: UUID?
    @State private var assigneeIds = Set<UUID>()
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86_400)
    @State private var notes = ""
    @State private var equipment: [String] = []
    @State private var subtasks: [SiteSubtask] = []
    @State private var newSubtaskTitle = ""
    @State private var showingEquipmentPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SmartField(title: "Title", text: $title, prompt: "Install Living Room TV")
                        SmartPickerCard(title: "Status", selection: $status, options: ["To Do", "In Progress", "Done", "Blocked"])
                        SmartPickerCard(title: "Priority", selection: $priority, options: ["Low", "Normal", "High", "Urgent"])
                        areaPicker
                        assigneePicker
                        SmartGlassCard {
                            Toggle("Due Date", isOn: $hasDueDate)
                                .foregroundStyle(.white)
                            if hasDueDate {
                                DatePicker("Deadline", selection: $dueDate, displayedComponents: .date)
                                    .foregroundStyle(.white)
                            }
                        }
                        SmartField(title: "Notes", text: $notes, prompt: "Optional notes", axis: .vertical)
                        subtasksCard
                        equipmentCard
                        if let task, store.canDeleteRecords {
                            Button(role: .destructive) {
                                store.delete(siteTask: task)
                                dismiss()
                            } label: {
                                Label("Delete Task", systemImage: "trash")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(SmartTheme.danger)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle(task == nil ? "Add Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingEquipmentPicker) {
            EquipmentPickerView(selectedEquipment: $equipment)
                .environmentObject(store)
        }
        .onAppear {
            selectedAreaId = defaultAreaId
            if let task {
                title = task.title
                status = task.status
                priority = task.priority
                selectedAreaId = task.areaId ?? defaultAreaId
                assigneeIds = Set(task.assigneeIds)
                hasDueDate = task.dueDate != nil
                dueDate = task.dueDate ?? dueDate
                let parsed = parseTaskNote(task.note)
                notes = parsed.notes
                equipment = parsed.equipment
                subtasks = task.subtasks
            }
        }
    }

    private var equipmentCard: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Equipment")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.muted)
                        Text(equipment.isEmpty ? "No equipment added" : "\(equipment.count) items")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        showingEquipmentPicker = true
                    } label: {
                        Label("Add Equipment", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.cyan)
                    }
                    .buttonStyle(.plain)
                }
                if !equipment.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(equipment, id: \.self) { item in
                            HStack(spacing: 6) {
                                Text(item)
                                    .font(.caption.bold())
                                Button {
                                    equipment.removeAll { $0 == item }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.10), in: Capsule())
                            .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    private var subtasksCard: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Subtasks")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.muted)
                        Text(subtasks.isEmpty ? "No subtasks" : "\(subtasks.filter { $0.isDone }.count) / \(subtasks.count) done")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                ForEach(subtasks) { subtask in
                    HStack(spacing: 10) {
                        Button {
                            toggleSubtask(subtask)
                        } label: {
                            Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(subtask.isDone ? SmartTheme.success : SmartTheme.warning)
                        }
                        .buttonStyle(.plain)
                        Text(subtask.title)
                            .foregroundStyle(.white)
                            .strikethrough(subtask.isDone)
                        Spacer()
                        Button {
                            subtasks.removeAll { $0.id == subtask.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(SmartTheme.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.subheadline)
                }
                HStack {
                    TextField("Add subtask", text: $newSubtaskTitle)
                        .foregroundStyle(.white)
                    Button {
                        addSubtask()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? SmartTheme.muted : SmartTheme.cyan)
                    }
                    .buttonStyle(.plain)
                    .disabled(newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var areaPicker: some View {
        SmartGlassCard {
            Picker("Area", selection: $selectedAreaId) {
                Text("Whole House").tag(Optional<UUID>.none)
                ForEach(store.areaLandmarks) { area in
                    Text(area.name).tag(Optional(area.id))
                }
            }
            .foregroundStyle(.white)
        }
    }

    private var assigneePicker: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Assigned To")
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                if store.employees.isEmpty {
                    Text("No technicians added yet.")
                        .foregroundStyle(SmartTheme.muted)
                } else {
                    FlowLayout(spacing: 8) {
                        ForEach(store.employees) { employee in
                            Button {
                                if assigneeIds.contains(employee.id) {
                                    assigneeIds.remove(employee.id)
                                } else {
                                    assigneeIds.insert(employee.id)
                                }
                            } label: {
                                Text(employee.name)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 11)
                                    .padding(.vertical, 8)
                                    .background(assigneeIds.contains(employee.id) ? SmartTheme.primary : Color.white.opacity(0.10), in: Capsule())
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func save() {
        let now = Date()
        let cleanNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let equipmentText = equipment.isEmpty ? "" : "Equipment:\n" + equipment.map { "- \($0)" }.joined(separator: "\n")
        let combinedNote = [cleanNotes, equipmentText].filter { !$0.isEmpty }.joined(separator: "\n\n")
        let selectedArea = selectedAreaId.flatMap { id in store.areaLandmarks.first { $0.id == id } }
        store.save(siteTask: SiteTask(
            id: task?.id ?? UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            category: "Installation",
            note: combinedNote,
            status: status,
            floorId: selectedArea?.floorId ?? defaultFloorId,
            areaId: selectedAreaId ?? defaultAreaId,
            assigneeIds: Array(assigneeIds),
            dueDate: hasDueDate ? dueDate : nil,
            priority: priority,
            subtasks: subtasks,
            wantsARPlacement: task?.wantsARPlacement ?? false,
            worldTransform: task?.worldTransform ?? [],
            createdAt: task?.createdAt ?? now,
            updatedAt: now
        ))
        dismiss()
    }

    private func parseTaskNote(_ note: String) -> (notes: String, equipment: [String]) {
        let normalized = note.replacingOccurrences(of: "\n\nInstallation Details:\n", with: "\n\nEquipment:\n")
        let parts = normalized.components(separatedBy: "\n\nEquipment:\n")
        let equipmentItems = parts.dropFirst().joined(separator: "\n")
            .split(separator: "\n")
            .map { line in
                line.replacingOccurrences(of: "^-\\s*", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return (parts.first ?? "", equipmentItems)
    }

    private func addSubtask() {
        let clean = newSubtaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        subtasks.append(SiteSubtask(id: UUID(), title: clean, isDone: false, createdAt: Date()))
        newSubtaskTitle = ""
    }

    private func toggleSubtask(_ subtask: SiteSubtask) {
        guard let index = subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        subtasks[index].isDone.toggle()
    }
}

private struct EquipmentPreset: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
}

private struct EquipmentPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @Binding var selectedEquipment: [String]
    @AppStorage("smartAVReusableEquipmentSuggestions") private var reusableEquipmentData = "[]"
    @State private var search = ""
    @State private var selectedCategory = "All"
    @State private var saveCreatedEquipmentForFuture = true

    private let presets: [EquipmentPreset] = [
        EquipmentPreset(name: "Control4 EA-1 Controller", category: "Control4"),
        EquipmentPreset(name: "Control4 EA-3 Controller", category: "Control4"),
        EquipmentPreset(name: "Control4 Core 1 Controller", category: "Control4"),
        EquipmentPreset(name: "Control4 Core 3 Controller", category: "Control4"),
        EquipmentPreset(name: "Control4 Core 5 Controller", category: "Control4"),
        EquipmentPreset(name: "Control4 Halo Remote", category: "Control4"),
        EquipmentPreset(name: "Control4 Keypad Dimmer", category: "Control4"),
        EquipmentPreset(name: "Control4 Wireless Dimmer", category: "Control4"),
        EquipmentPreset(name: "Control4 8-Zone Amplifier", category: "Control4"),
        EquipmentPreset(name: "Control4 Chime Doorbell", category: "Control4"),

        EquipmentPreset(name: "Crestron CP4 Processor", category: "Crestron"),
        EquipmentPreset(name: "Crestron MC4-R Processor", category: "Crestron"),
        EquipmentPreset(name: "Crestron DIN-AP4 Processor", category: "Crestron"),
        EquipmentPreset(name: "Crestron DM NVX Encoder", category: "Crestron"),
        EquipmentPreset(name: "Crestron DM NVX Decoder", category: "Crestron"),
        EquipmentPreset(name: "Crestron TSW Touch Panel", category: "Crestron"),
        EquipmentPreset(name: "Crestron Horizon Keypad", category: "Crestron"),
        EquipmentPreset(name: "Crestron DIN Rail Dimmer", category: "Crestron"),
        EquipmentPreset(name: "Crestron DM Matrix Switcher", category: "Crestron"),
        EquipmentPreset(name: "Crestron Saros Speaker", category: "Crestron"),

        EquipmentPreset(name: "Lutron RA3 Processor", category: "Lighting"),
        EquipmentPreset(name: "Lutron Sunnata Keypad", category: "Lighting"),
        EquipmentPreset(name: "Lutron Sunnata Dimmer", category: "Lighting"),
        EquipmentPreset(name: "Lutron Palladiom Keypad", category: "Lighting"),
        EquipmentPreset(name: "Lutron Caseta Dimmer", category: "Lighting"),
        EquipmentPreset(name: "Lutron Shade Motor", category: "Shades"),
        EquipmentPreset(name: "Somfy Shade Motor", category: "Shades"),

        EquipmentPreset(name: "Ubiquiti UniFi U6 Pro AP", category: "Network"),
        EquipmentPreset(name: "Ubiquiti UniFi U7 Pro AP", category: "Network"),
        EquipmentPreset(name: "Ubiquiti UniFi Dream Machine Pro", category: "Network"),
        EquipmentPreset(name: "Ubiquiti UniFi 24-Port PoE Switch", category: "Network"),
        EquipmentPreset(name: "Ubiquiti UniFi 48-Port PoE Switch", category: "Network"),
        EquipmentPreset(name: "Araknis Router", category: "Network"),
        EquipmentPreset(name: "Araknis 24-Port PoE Switch", category: "Network"),
        EquipmentPreset(name: "Pakedge Access Point", category: "Network"),
        EquipmentPreset(name: "Luxul Access Point", category: "Network"),
        EquipmentPreset(name: "CAT6 Keystone Jack", category: "Network"),
        EquipmentPreset(name: "Patch Panel", category: "Network"),

        EquipmentPreset(name: "Hikvision Dome Camera", category: "Security"),
        EquipmentPreset(name: "Hikvision Bullet Camera", category: "Security"),
        EquipmentPreset(name: "Hikvision Turret Camera", category: "Security"),
        EquipmentPreset(name: "Hikvision NVR", category: "Security"),
        EquipmentPreset(name: "LTS Dome Camera", category: "Security"),
        EquipmentPreset(name: "LTS NVR", category: "Security"),
        EquipmentPreset(name: "Galaxy Alarm Panel", category: "Security"),
        EquipmentPreset(name: "Galaxy Keypad", category: "Security"),
        EquipmentPreset(name: "DCM Alarm Panel", category: "Security"),
        EquipmentPreset(name: "DCM Security Keypad", category: "Security"),
        EquipmentPreset(name: "DCM Door Contact", category: "Security"),
        EquipmentPreset(name: "DCM Window Contact", category: "Security"),
        EquipmentPreset(name: "DCM Motion Detector", category: "Security"),
        EquipmentPreset(name: "DCM Glass Break Sensor", category: "Security"),
        EquipmentPreset(name: "DCM Smoke Detector", category: "Security"),
        EquipmentPreset(name: "DCM CO Detector", category: "Security"),
        EquipmentPreset(name: "DCM Siren", category: "Security"),
        EquipmentPreset(name: "DCM Expansion Module", category: "Security"),
        EquipmentPreset(name: "Door Contact Sensor", category: "Security"),
        EquipmentPreset(name: "Window Contact Sensor", category: "Security"),
        EquipmentPreset(name: "Motion Detector", category: "Security"),
        EquipmentPreset(name: "Glass Break Sensor", category: "Security"),
        EquipmentPreset(name: "Smoke Detector", category: "Security"),
        EquipmentPreset(name: "CO Detector", category: "Security"),

        EquipmentPreset(name: "Samsung Frame 65 TV", category: "AV"),
        EquipmentPreset(name: "LG OLED TV", category: "AV"),
        EquipmentPreset(name: "Sony Bravia TV", category: "AV"),
        EquipmentPreset(name: "Sonos Arc", category: "AV"),
        EquipmentPreset(name: "Sonos Amp", category: "AV"),
        EquipmentPreset(name: "Sonos Sub", category: "AV"),
        EquipmentPreset(name: "Episode In-Ceiling Speaker", category: "AV"),
        EquipmentPreset(name: "Triad In-Wall Speaker", category: "AV"),
        EquipmentPreset(name: "Denon AV Receiver", category: "AV"),
        EquipmentPreset(name: "Marantz AV Receiver", category: "AV"),
        EquipmentPreset(name: "Binary HDMI Extender", category: "AV"),
        EquipmentPreset(name: "HDBaseT HDMI Extender", category: "AV"),
        EquipmentPreset(name: "Strong TV Mount", category: "AV")
    ]

    private var reusableEquipment: [EquipmentPreset] {
        guard let data = reusableEquipmentData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded.map { EquipmentPreset(name: $0, category: "Custom") }
    }

    private var allEquipment: [EquipmentPreset] {
        var seen = Set<String>()
        return (presets + reusableEquipment).filter { seen.insert($0.name.lowercased()).inserted }
    }

    private var categories: [String] {
        ["All"] + Array(Set(allEquipment.map(\.category))).sorted()
    }

    private var query: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filtered: [EquipmentPreset] {
        let lower = query.lowercased()
        return allEquipment.filter { item in
            (selectedCategory == "All" || item.category == selectedCategory)
            && (lower.isEmpty || item.name.lowercased().contains(lower) || item.category.lowercased().contains(lower))
        }
    }

    private var createCandidate: String? {
        guard !query.isEmpty else { return nil }
        return allEquipment.contains { $0.name.caseInsensitiveCompare(query) == .orderedSame } ? nil : query
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                VStack(spacing: 12) {
                    searchCard.padding(.horizontal, 20)
                    categoryScroller
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filtered) { item in
                                equipmentRow(item)
                            }
                            if filtered.isEmpty && createCandidate == nil {
                                SmartEmptyState(title: "No Equipment Found", subtitle: "Search another model or create one.")
                                    .padding(.top, 30)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Add Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchCard: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(SmartTheme.muted)
                    TextField("Search or create equipment", text: $search)
                        .foregroundStyle(.white)
                    if let createCandidate {
                        Button {
                            add(createCandidate)
                            if store.canManagePermanentSuggestions && saveCreatedEquipmentForFuture { saveReusable(createCandidate) }
                            search = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(SmartTheme.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if createCandidate != nil && store.canManagePermanentSuggestions {
                    Toggle("Save as suggestion for future projects", isOn: $saveCreatedEquipmentForFuture)
                        .font(.caption.bold())
                        .foregroundStyle(SmartTheme.muted)
                        .tint(SmartTheme.primary)
                } else if createCandidate != nil {
                    Text("Only admins, managers, and supervisors can save permanent suggestions.")
                        .font(.caption)
                        .foregroundStyle(SmartTheme.warning)
                }
            }
        }
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        Text(category)
                            .font(.caption.bold())
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selectedCategory == category ? SmartTheme.primary : Color.white.opacity(0.10), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func equipmentRow(_ item: EquipmentPreset) -> some View {
        Button {
            toggle(item.name)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: selectedEquipment.contains(item.name) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(selectedEquipment.contains(item.name) ? SmartTheme.success : SmartTheme.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.category)
                        .font(.caption.bold())
                        .foregroundStyle(SmartTheme.muted)
                }
                Spacer()
            }
            .padding(15)
            .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SmartTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func add(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !selectedEquipment.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else { return }
        selectedEquipment.append(clean)
    }

    private func toggle(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        if let index = selectedEquipment.firstIndex(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) {
            selectedEquipment.remove(at: index)
        } else {
            selectedEquipment.append(clean)
        }
    }

    private func saveReusable(_ name: String) {
        var names = reusableEquipment.map(\.name)
        guard !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        names.append(name)
        names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let data = try? JSONEncoder().encode(names), let encoded = String(data: data, encoding: .utf8) {
            reusableEquipmentData = encoded
        }
    }
}

private struct TaskPreset: Identifiable, Hashable {
    let id = UUID()
    let title: String
    let category: String
}

private struct QuickTaskPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    var defaultFloorId: UUID?
    var defaultAreaId: UUID?
    @AppStorage("smartAVReusableTaskSuggestions") private var reusableTaskSuggestionsData = "[]"
    @State private var search = ""
    @State private var selectedCategory = "All"
    @State private var saveCreatedTaskForFuture = true
    @State private var addedTaskTitles = Set<String>()

    private let presets: [TaskPreset] = [
        TaskPreset(title: "Install TV", category: "AV"),
        TaskPreset(title: "Mount TV bracket", category: "AV"),
        TaskPreset(title: "Install recessed TV box", category: "AV"),
        TaskPreset(title: "Run HDMI cable", category: "AV"),
        TaskPreset(title: "Run optical audio cable", category: "AV"),
        TaskPreset(title: "Install HDMI extender", category: "AV"),
        TaskPreset(title: "Install Sonos soundbar", category: "AV"),
        TaskPreset(title: "Install in-ceiling speakers", category: "AV"),
        TaskPreset(title: "Install in-wall speakers", category: "AV"),
        TaskPreset(title: "Terminate speaker wires", category: "AV"),
        TaskPreset(title: "Label speaker wires", category: "AV"),
        TaskPreset(title: "Install subwoofer outlet", category: "AV"),
        TaskPreset(title: "Configure surround sound", category: "AV"),
        TaskPreset(title: "Program AV receiver", category: "AV"),
        TaskPreset(title: "Test audio zones", category: "AV"),
        TaskPreset(title: "Install projector", category: "AV"),
        TaskPreset(title: "Install projector screen", category: "AV"),
        TaskPreset(title: "Align projector image", category: "AV"),
        TaskPreset(title: "Install media cabinet", category: "AV"),

        TaskPreset(title: "Run CAT6 cable", category: "Network"),
        TaskPreset(title: "Run fiber cable", category: "Network"),
        TaskPreset(title: "Terminate data jack", category: "Network"),
        TaskPreset(title: "Label network cable", category: "Network"),
        TaskPreset(title: "Test network cable", category: "Network"),
        TaskPreset(title: "Install access point", category: "Network"),
        TaskPreset(title: "Mount access point bracket", category: "Network"),
        TaskPreset(title: "Configure access point", category: "Network"),
        TaskPreset(title: "Run Wi-Fi test", category: "Network"),
        TaskPreset(title: "Install network switch", category: "Network"),
        TaskPreset(title: "Configure network switch", category: "Network"),
        TaskPreset(title: "Install router", category: "Network"),
        TaskPreset(title: "Configure VLANs", category: "Network"),
        TaskPreset(title: "Patch network rack", category: "Network"),
        TaskPreset(title: "Clean up rack wiring", category: "Network"),
        TaskPreset(title: "Install PoE injector", category: "Network"),
        TaskPreset(title: "Verify internet speed", category: "Network"),
        TaskPreset(title: "Verify device online", category: "Network"),

        TaskPreset(title: "Replace light switch", category: "Lighting"),
        TaskPreset(title: "Install smart dimmer", category: "Lighting"),
        TaskPreset(title: "Install keypad", category: "Lighting"),
        TaskPreset(title: "Replace keypad", category: "Lighting"),
        TaskPreset(title: "Program keypad buttons", category: "Lighting"),
        TaskPreset(title: "Label keypad buttons", category: "Lighting"),
        TaskPreset(title: "Configure lighting scene", category: "Lighting"),
        TaskPreset(title: "Test lighting scene", category: "Lighting"),
        TaskPreset(title: "Install LED strip", category: "Lighting"),
        TaskPreset(title: "Install LED driver", category: "Lighting"),
        TaskPreset(title: "Test dimming level", category: "Lighting"),
        TaskPreset(title: "Install occupancy sensor", category: "Lighting"),
        TaskPreset(title: "Install motion sensor", category: "Lighting"),

        TaskPreset(title: "Install door contact", category: "Security"),
        TaskPreset(title: "Install window contact", category: "Security"),
        TaskPreset(title: "Install motion detector", category: "Security"),
        TaskPreset(title: "Install glass break sensor", category: "Security"),
        TaskPreset(title: "Install smoke detector", category: "Security"),
        TaskPreset(title: "Install CO detector", category: "Security"),
        TaskPreset(title: "Install security keypad", category: "Security"),
        TaskPreset(title: "Program alarm zone", category: "Security"),
        TaskPreset(title: "Test alarm zone", category: "Security"),
        TaskPreset(title: "Install doorbell camera", category: "Security"),
        TaskPreset(title: "Install security camera", category: "Security"),
        TaskPreset(title: "Aim camera", category: "Security"),
        TaskPreset(title: "Configure camera recording", category: "Security"),
        TaskPreset(title: "Test camera view", category: "Security"),
        TaskPreset(title: "Install NVR", category: "Security"),

        TaskPreset(title: "Install shade motor", category: "Automation"),
        TaskPreset(title: "Program shade limits", category: "Automation"),
        TaskPreset(title: "Pair remote control", category: "Automation"),
        TaskPreset(title: "Install thermostat", category: "Automation"),
        TaskPreset(title: "Configure thermostat", category: "Automation"),
        TaskPreset(title: "Install smart lock", category: "Automation"),
        TaskPreset(title: "Configure smart lock", category: "Automation"),
        TaskPreset(title: "Create automation scene", category: "Automation"),
        TaskPreset(title: "Test automation scene", category: "Automation"),
        TaskPreset(title: "Program control system", category: "Automation"),
        TaskPreset(title: "Update controller firmware", category: "Automation"),
        TaskPreset(title: "Pair device to system", category: "Automation"),

        TaskPreset(title: "Pre-wire location", category: "Rough-In"),
        TaskPreset(title: "Drill cable path", category: "Rough-In"),
        TaskPreset(title: "Pull low-voltage wire", category: "Rough-In"),
        TaskPreset(title: "Install back box", category: "Rough-In"),
        TaskPreset(title: "Install conduit", category: "Rough-In"),
        TaskPreset(title: "Verify power outlet", category: "Rough-In"),
        TaskPreset(title: "Patch drywall opening", category: "Rough-In"),
        TaskPreset(title: "Take completion photos", category: "Finish"),
        TaskPreset(title: "Clean work area", category: "Finish"),
        TaskPreset(title: "Client walkthrough", category: "Finish"),
        TaskPreset(title: "Final functional test", category: "Finish")
    ]

    private var reusableTaskSuggestions: [TaskPreset] {
        guard let data = reusableTaskSuggestionsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded.map { TaskPreset(title: $0, category: "Custom") }
    }

    private var allPresets: [TaskPreset] {
        var seen = Set<String>()
        return (presets + reusableTaskSuggestions).filter { seen.insert($0.title.lowercased()).inserted }
    }

    private var categories: [String] {
        ["All"] + Array(Set(allPresets.map(\.category))).sorted()
    }

    private var searchQuery: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var filteredPresets: [TaskPreset] {
        let query = searchQuery.lowercased()
        return allPresets.filter { preset in
            let categoryMatches = selectedCategory == "All" || preset.category == selectedCategory
            let searchMatches = query.isEmpty || preset.title.lowercased().contains(query) || preset.category.lowercased().contains(query)
            return categoryMatches && searchMatches
        }
    }

    private var createCandidate: String? {
        let name = searchQuery
        guard !name.isEmpty else { return nil }
        let alreadyExists = allPresets.contains { $0.title.caseInsensitiveCompare(name) == .orderedSame }
        return alreadyExists ? nil : name
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                VStack(spacing: 12) {
                    searchCard
                        .padding(.horizontal, 20)
                    categoryScroller
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            ForEach(filteredPresets) { preset in
                                presetRow(preset)
                            }
                            if filteredPresets.isEmpty && createCandidate == nil {
                                SmartEmptyState(title: "No Tasks Found", subtitle: "Try another keyword.")
                                    .padding(.top, 30)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                    }
                }
                .padding(.top, 12)
            }
            .navigationTitle("Add Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var searchCard: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(SmartTheme.muted)
                    TextField("Search or create task", text: $search)
                        .foregroundStyle(.white)
                    if let createCandidate {
                        Button {
                            addTask(title: createCandidate, category: selectedCategory == "All" ? "Custom" : selectedCategory)
                            if store.canManagePermanentSuggestions && saveCreatedTaskForFuture {
                                saveReusableTaskName(createCandidate)
                            }
                            search = ""
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(SmartTheme.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if createCandidate != nil && store.canManagePermanentSuggestions {
                    Toggle("Save as suggestion for future projects", isOn: $saveCreatedTaskForFuture)
                        .font(.caption.bold())
                        .foregroundStyle(SmartTheme.muted)
                        .tint(SmartTheme.primary)
                } else if createCandidate != nil {
                    Text("Only admins, managers, and supervisors can save permanent suggestions.")
                        .font(.caption)
                        .foregroundStyle(SmartTheme.warning)
                }
            }
        }
    }

    private var categoryScroller: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories, id: \.self) { category in
                    Button {
                        withAnimation(.spring(response: 0.24, dampingFraction: 0.85)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.caption.bold())
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background(selectedCategory == category ? SmartTheme.primary : Color.white.opacity(0.10), in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func presetRow(_ preset: TaskPreset) -> some View {
        Button {
            addTask(title: preset.title, category: preset.category)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: addedTaskTitles.contains(preset.title.lowercased()) ? "checkmark.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(addedTaskTitles.contains(preset.title.lowercased()) ? SmartTheme.success : SmartTheme.cyan)
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(preset.category)
                        .font(.caption.bold())
                        .foregroundStyle(SmartTheme.muted)
                }
                Spacer()
            }
            .padding(15)
            .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SmartTheme.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func addTask(title: String, category: String) {
        store.addSiteTask(
            title: title,
            category: category,
            note: "",
            floorId: defaultFloorId,
            areaId: defaultAreaId,
            assigneeIds: []
        )
        addedTaskTitles.insert(title.lowercased())
    }

    private func saveReusableTaskName(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var names = reusableTaskSuggestions.map(\.title)
        guard !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        names.append(name)
        names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let data = try? JSONEncoder().encode(names), let encoded = String(data: data, encoding: .utf8) {
            reusableTaskSuggestionsData = encoded
        }
    }
}

private struct SmartField: View {
    let title: String
    @Binding var text: String
    let prompt: String
    var axis: Axis = .horizontal

    var body: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                TextField(prompt, text: $text, axis: axis)
                    .lineLimit(axis == .vertical ? 3...6 : 1...1)
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct SmartPickerCard: View {
    let title: String
    @Binding var selection: String
    let options: [String]

    var body: some View {
        SmartGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { Text($0) }
                }
                .pickerStyle(.segmented)
            }
        }
    }
}

private struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var projectName = ""
    @State private var address = ""
    @State private var selectedAreaNames: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        SmartField(title: "Project Name", text: $projectName, prompt: "Sunset Villa")
                        SmartField(title: "Address", text: $address, prompt: "123 Ocean Drive", axis: .vertical)
                        AreaSuggestionSelector(selectedAreaNames: $selectedAreaNames)
                            .environmentObject(store)
                    }
                    .padding(20)
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.createNewLocation(named: projectName, address: address, areaNames: selectedAreaNames)
                        dismiss()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AreaSuggestionPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    let title: String
    let onSave: ([String]) -> Void
    @State private var selectedAreaNames: [String] = []

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    AreaSuggestionSelector(selectedAreaNames: $selectedAreaNames)
                        .environmentObject(store)
                        .padding(20)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(selectedAreaNames)
                        dismiss()
                    }
                    .disabled(selectedAreaNames.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct AreaSuggestionSelector: View {
    @EnvironmentObject private var store: SurveyStore
    @Binding var selectedAreaNames: [String]
    @AppStorage("smartAVReusableAreaSuggestions") private var reusableAreaSuggestionsData = "[]"
    @State private var search = ""
    @State private var saveCreatedAreaForFuture = true
    @State private var bedroomCount = 1

    private let commonAreas = [
        "Kitchen", "Living Room", "Family Room", "Dining Room", "Bedroom",
        "Bedroom 1", "Bedroom 2", "Bedroom 3", "Primary Bedroom", "Office",
        "Hallway", "Bathroom", "Garage", "Basement", "Laundry", "Patio",
        "Deck", "Pool", "Golf Room", "Mechanical Room", "Storage", "Theater Room", "AV Rack"
    ]

    private var reusableAreaSuggestions: [String] {
        guard let data = reusableAreaSuggestionsData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private var allAreaNames: [String] {
        let saved = store.locations.flatMap { $0.snapshot.areaLandmarks.map(\.name) } + store.areaLandmarks.map(\.name)
        var seen = Set<String>()
        return (commonAreas + reusableAreaSuggestions + saved).filter { seen.insert($0.lowercased()).inserted }
    }

    private var searchQuery: String {
        search.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var suggestions: [String] {
        let query = searchQuery.lowercased()
        guard !query.isEmpty else { return allAreaNames }
        return allAreaNames.filter { $0.lowercased().contains(query) }
    }

    private var createCandidate: String? {
        let name = searchQuery
        guard !name.isEmpty else { return nil }
        let alreadyExists = allAreaNames.contains { $0.caseInsensitiveCompare(name) == .orderedSame }
        return alreadyExists ? nil : name
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SmartGlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(SmartTheme.muted)
                        TextField("Search or create an area", text: $search)
                            .foregroundStyle(.white)
                        if let createCandidate {
                            Button {
                                addAreaName(createCandidate)
                                if store.canManagePermanentSuggestions && saveCreatedAreaForFuture {
                                    saveReusableAreaName(createCandidate)
                                }
                                search = ""
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(SmartTheme.cyan)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if createCandidate != nil && store.canManagePermanentSuggestions {
                        Toggle("Save as suggestion for future homes", isOn: $saveCreatedAreaForFuture)
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.muted)
                            .tint(SmartTheme.primary)
                    } else if createCandidate != nil {
                        Text("Only admins, managers, and supervisors can save permanent suggestions.")
                            .font(.caption)
                            .foregroundStyle(SmartTheme.warning)
                    }
                }
            }
            SmartGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Stepper("Bedrooms: \(bedroomCount)", value: $bedroomCount, in: 1...12)
                        .foregroundStyle(.white)
                    Button {
                        for index in 1...bedroomCount {
                            addAreaName("Bedroom \(index)")
                        }
                    } label: {
                        Label("Add Bedrooms", systemImage: "bed.double.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(SmartTheme.cyan)
                    }
                }
            }
            VStack(spacing: 10) {
                ForEach(suggestions, id: \.self) { name in
                    Button {
                        toggleAreaName(name)
                    } label: {
                        HStack {
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: selectedAreaNames.contains(name) ? "checkmark.circle.fill" : "plus.circle")
                                .foregroundStyle(selectedAreaNames.contains(name) ? SmartTheme.success : SmartTheme.cyan)
                        }
                        .padding(15)
                        .background(SmartTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(selectedAreaNames.contains(name) ? SmartTheme.success.opacity(0.55) : SmartTheme.border, lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func addAreaName(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !selectedAreaNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        selectedAreaNames.append(name)
    }

    private func saveReusableAreaName(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        var names = reusableAreaSuggestions
        guard !names.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        names.append(name)
        names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let data = try? JSONEncoder().encode(names), let encoded = String(data: data, encoding: .utf8) {
            reusableAreaSuggestionsData = encoded
        }
    }

    private func toggleAreaName(_ rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        if let index = selectedAreaNames.firstIndex(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            selectedAreaNames.remove(at: index)
        } else {
            selectedAreaNames.append(name)
        }
    }
}

private struct UtilitiesDashboardView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                        Text("Utilities")
                            .font(SmartTheme.display(38))
                            .foregroundStyle(.white)
                    }
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        UtilityTile(title: "Wi-Fi Internet Test", icon: "speedometer", color: SmartTheme.cyan) { SimpleInternetTestView() }
                        UtilityTile(title: "Devices", icon: "memorychip.fill", color: SmartTheme.warning) { SettingsView() }
                        UtilityTile(title: "Signal Analyzer", icon: "map.fill", color: SmartTheme.primary) { SignalAnalyzerUtilityView() }
                        UtilityTile(title: "Central Vac Planner", icon: "arrow.triangle.branch", color: SmartTheme.success) { CentralVacPlannerView() }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 110)
            }
            .background(Color.clear)
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct UtilityTile<Destination: View>: View {
    let title: String
    let icon: String
    let color: Color
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            SmartGlassCard {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(color)
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 92)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct SignalAnalyzerUtilityView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var showingRecord = false

    var body: some View {
        ZStack {
            SmartBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                        Text("Signal Analyzer")
                            .font(SmartTheme.display(36))
                            .foregroundStyle(.white)
                    }
                    if store.mappedAreaLandmarks.isEmpty {
                        SmartEmptyState(title: "No Signal Map", subtitle: "Create area points for this project, then place ESP or phone measurements on the map.")
                        NavigationLink {
                            AreaLandmarkCaptureView()
                                .environmentObject(store)
                        } label: {
                            Label("Map Area Points", systemImage: "location.viewfinder")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 15)
                                .background(LinearGradient(colors: [SmartTheme.primary, SmartTheme.cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    } else {
                        SmartGlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Assign ESP Devices")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Text("This project already has mapped area points. Tap or press and hold an area, then place the active ESP or choose a saved device for that area.")
                                    .font(.caption)
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }

                        AreaLandmarkMapView(
                            buildingFloors: store.buildingFloors,
                            landmarks: store.mappedAreaLandmarks,
                            points: store.points,
                            devices: store.devices,
                            phoneTester: store.phoneTester,
                            phoneResults: store.phoneNetworkSamples,
                            onAction: handleAreaMapAction,
                            selectedAreaId: $store.selectedAreaId
                        )
                        .environmentObject(store)

                        if let area = store.selectedArea {
                            AreaResultsView(area: area)
                                .environmentObject(store)
                                .environmentObject(bluetooth)
                        } else {
                            SmartGlassCard {
                                Text("Select an area point to see assigned ESP devices, phone samples, and recommendations.")
                                    .font(.caption)
                                    .foregroundStyle(SmartTheme.muted)
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showingRecord) {
            RecordPointView(isPresented: $showingRecord)
                .environmentObject(store)
                .environmentObject(bluetooth)
        }
    }

    private func handleAreaMapAction(_ area: AreaLandmark, _ action: AreaMapAction) {
        store.selectedAreaId = area.id
        switch action {
        case .viewDetails:
            break
        case .recordESPMeasurement:
            showingRecord = true
        case .analyzeWithIPhone:
            store.message = "Open Wi-Fi Internet Test to collect iPhone-only internet results. ESP area assignment stays here in Signal Analyzer."
        case .assignActiveESP:
            store.assignCurrentNodeToArea(bluetooth.deviceStatus.nodeId)
            store.message = "Assigned \(bluetooth.deviceStatus.nodeId) to \(area.name)."
        }
    }
}

private struct CentralVacPlannerView: View {
    @State private var pipeRunMeters = 12.0
    @State private var inletCount = 1
    @State private var shortNinetyCount = 1
    @State private var longSweepNinetyCount = 2
    @State private var fortyFiveCount = 2
    @State private var stopperDistanceCm = 20.0

    private var equivalentRunMeters: Double {
        pipeRunMeters
        + Double(longSweepNinetyCount) * 1.5
        + Double(shortNinetyCount) * 2.4
        + Double(fortyFiveCount) * 0.75
    }

    private var warnings: [String] {
        var result: [String] = []
        if shortNinetyCount > inletCount {
            result.append("Use short 90 elbows only directly behind inlet valves. For the rest of the run, use long-sweep fittings.")
        }
        if stopperDistanceCm < 10 || stopperDistanceCm > 45 {
            result.append("Recommended stopper/short-90 placement is about 10-45 cm behind the inlet so large debris stops close to the valve.")
        }
        if longSweepNinetyCount + shortNinetyCount > 6 {
            result.append("High 90-degree elbow count. Re-route with sweeping bends where possible to reduce clogs and suction loss.")
        }
        if equivalentRunMeters > 30 {
            result.append("Effective run is long. Verify vacuum unit capacity and consider a shorter route or additional inlet planning.")
        }
        if result.isEmpty {
            result.append("Layout looks reasonable. Keep the short 90 at the inlet only and use long-sweep elbows through the main run.")
        }
        return result
    }

    var body: some View {
        ZStack {
            SmartBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                        Text("Central Vac Planner")
                            .font(SmartTheme.display(36))
                            .foregroundStyle(.white)
                    }
                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Pipe Run")
                                .font(.headline)
                                .foregroundStyle(.white)
                            numberStepper("Straight pipe", value: $pipeRunMeters, range: 0...100, suffix: "m", step: 0.5)
                            intStepper("Inlet valves", value: $inletCount, range: 1...20)
                            numberStepper("Stopper from inlet", value: $stopperDistanceCm, range: 0...100, suffix: "cm", step: 5)
                        }
                    }
                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Fittings")
                                .font(.headline)
                                .foregroundStyle(.white)
                            intStepper("Short 90 elbows", value: $shortNinetyCount, range: 0...20)
                            intStepper("Long-sweep 90 elbows", value: $longSweepNinetyCount, range: 0...40)
                            intStepper("45 elbows", value: $fortyFiveCount, range: 0...40)
                        }
                    }
                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Result")
                                .font(.headline)
                                .foregroundStyle(.white)
                            HStack {
                                Text("Effective run")
                                    .foregroundStyle(SmartTheme.muted)
                                Spacer()
                                Text(String(format: "%.1f m", equivalentRunMeters))
                                    .font(.title3.bold())
                                    .foregroundStyle(SmartTheme.cyan)
                            }
                            ForEach(warnings, id: \.self) { warning in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: warning == warnings.last && warnings.count == 1 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                        .foregroundStyle(warnings.count == 1 ? SmartTheme.success : SmartTheme.warning)
                                    Text(warning)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.82))
                                }
                            }
                        }
                    }
                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Installer rule of thumb")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("Place the tight/short 90 only at the inlet valve as a debris stop. Use long-sweep 90s and 45s everywhere else, keep runs as straight as practical, and avoid back-to-back tight elbows.")
                                .font(.caption)
                                .foregroundStyle(SmartTheme.muted)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func intStepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                Text("\(value.wrappedValue)")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
            Stepper(title, value: value, in: range)
                .labelsHidden()
        }
    }

    private func numberStepper(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, suffix: String, step: Double) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.muted)
                Text(String(format: "%.1f %@", value.wrappedValue, suffix))
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            Spacer()
            Stepper(title, value: value, in: range, step: step)
                .labelsHidden()
        }
    }
}

private struct SimpleInternetTestView: View {
    @StateObject private var analyzer = IPhoneNetworkAnalyzer()
    @State private var latestSample: PhoneNetworkSample?

    var body: some View {
        ZStack {
            SmartBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 5) {
                        SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                        Text("Wi-Fi Internet Test")
                            .font(SmartTheme.display(36))
                            .foregroundStyle(.white)
                        Text("Simple phone-based test. ESP board area mapping is separate.")
                            .font(SmartTheme.bodyMedium(12))
                            .foregroundStyle(SmartTheme.muted)
                    }

                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Network")
                                        .font(.caption.bold())
                                        .foregroundStyle(SmartTheme.muted)
                                    Text(latestSample?.ssid ?? analyzer.pathStatus)
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)
                                }
                                Spacer()
                                if let latestSample {
                                    VStack(alignment: .trailing, spacing: 3) {
                                        Text("\(latestSample.score)")
                                            .font(.system(size: 42, weight: .bold))
                                            .foregroundStyle(scoreColor(latestSample.score))
                                        Text(latestSample.qualityLabel)
                                            .font(.caption.bold())
                                            .foregroundStyle(scoreColor(latestSample.score))
                                    }
                                }
                            }
                            Text("Speed uses Cloudflare's public speed test endpoints for download/upload measurement. Ping and packet loss are measured with repeated internet probes.")
                                .font(.caption)
                                .foregroundStyle(SmartTheme.muted)
                        }
                    }

                    if let latestSample {
                        SmartGlassCard {
                            PhoneResultSummary(sample: latestSample)
                        }
                    } else {
                        SmartEmptyState(title: "No Test Yet", subtitle: "Run a test to measure internet ping, packet loss, download, and upload from this iPhone.")
                    }

                    Button {
                        Task { await runTest() }
                    } label: {
                        Label(analyzer.isAnalyzing ? "Testing..." : "Start Internet Test", systemImage: "play.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(LinearGradient(colors: [SmartTheme.primary, SmartTheme.cyan], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .disabled(analyzer.isAnalyzing)

                    SmartGlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("iPhone limits")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("iOS does not expose real Wi-Fi RSSI in dBm or Wi-Fi channel scan data to normal apps. For room-by-room signal maps and ESP measurements, use the ESP board tools.")
                                .font(.caption)
                                .foregroundStyle(SmartTheme.warning)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 90)
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func runTest() async {
        latestSample = try? await analyzer.analyze(areaId: nil)
    }

    private func scoreColor(_ score: Int) -> Color {
        switch ProfessionalScore.label(score) {
        case "Excellent": return SmartTheme.success
        case "Good": return Color(red: 0.58, green: 0.86, blue: 0.22)
        case "Fair": return .yellow
        case "Weak": return SmartTheme.warning
        default: return SmartTheme.danger
        }
    }
}

private struct UtilityRow<Destination: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let destination: Destination

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(SmartTheme.cyan)
                    .frame(width: 28)
                Text(title)
                    .foregroundStyle(.white)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(SmartTheme.muted)
            }
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }
}

private struct ProjectToolsMenuView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                List {
                    Section("Project") {
                        NavigationLink { AreaManagementView() } label: {
                            Label("Manage Areas and Floors", systemImage: "square.grid.2x2")
                        }
                        NavigationLink { SiteTasksView() } label: {
                            Label("All Tasks", systemImage: "checklist")
                        }
                        NavigationLink { ShiftsView() } label: {
                            Label("Shifts", systemImage: "calendar.badge.clock")
                        }
                    }
                    Section("Experimental") {
                        NavigationLink { AreaLandmarkCaptureView() } label: {
                            Label("Area Mapping", systemImage: "location.viewfinder")
                        }
                        NavigationLink { SiteTasksView() } label: {
                            Label("AR Task Markers", systemImage: "arkit")
                        }
                    }
                    Section("Wi-Fi Tools") {
                        NavigationLink { APWiFiInstallationView() } label: {
                            Label("AP & Wi-Fi Installation", systemImage: "wifi.router")
                        }
                        NavigationLink { IPhoneAnalyzerView() } label: {
                            Label("iPhone Network Test", systemImage: "iphone.radiowaves.left.and.right")
                        }
                        NavigationLink { SettingsView() } label: {
                            Label("ESP Devices", systemImage: "memorychip")
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Tools")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: 10)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(LinearGradient(colors: [SmartTheme.primary, SmartTheme.cyan, SmartTheme.success], startPoint: .topLeading, endPoint: .bottomTrailing), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))%")
                .font(.title3.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct MiniProgressRing: View {
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0, min(progress, 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int(progress * 100))")
                .font(.caption2.bold())
                .foregroundStyle(.white)
        }
    }
}

private struct MetricLine: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(SmartTheme.muted)
            Spacer()
            Text(value)
                .foregroundStyle(color)
                .fontWeight(.bold)
        }
        .font(.subheadline)
    }
}

private struct ProjectSummaryPill: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        SmartGlassCard(padding: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(SmartTheme.muted)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(color)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SmartIconButton: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .frame(width: 42, height: 42)
                .background(SmartTheme.panelStrong, in: Circle())
                .overlay {
                    Circle().stroke(SmartTheme.border, lineWidth: 1)
                }
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }
}

private struct SmartEmptyState: View {
    let title: String
    let subtitle: String

    var body: some View {
        SmartGlassCard {
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(SmartTheme.muted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: spacing)], spacing: spacing) {
            content
        }
    }
}

private struct UtilitiesView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Primary Tools") {
                    NavigationLink {
                        APWiFiInstallationView()
                    } label: {
                        Label("AP & Wi-Fi Installation", systemImage: "wifi.router")
                    }
                    NavigationLink {
                        SiteReadinessView()
                    } label: {
                        Label("Site Readiness", systemImage: "checkmark.seal")
                    }
                }
                Section("Job Setup") {
                    NavigationLink {
                        AreaManagementView()
                    } label: {
                        Label("Areas", systemImage: "square.grid.2x2")
                    }
                    NavigationLink {
                        EquipmentListView()
                    } label: {
                        Label("Devices & Equipment Needed", systemImage: "shippingbox")
                    }
                }
                Section("Reports") {
                    NavigationLink {
                        ReportView()
                    } label: {
                        Label("Final Report", systemImage: "doc.text")
                    }
                    NavigationLink {
                        MeasurementsView()
                    } label: {
                        Label("Measurements", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .navigationTitle("Utilities")
        }
    }
}

private struct APWiFiInstallationView: View {
    var body: some View {
        List {
            Section("Location Setup") {
                NavigationLink {
                    AreaManagementView()
                } label: {
                    Label("Areas", systemImage: "square.grid.2x2")
                }
                NavigationLink {
                    EquipmentListView()
                } label: {
                    Label("Devices & Equipment Needed", systemImage: "shippingbox")
                }
            }
            Section("Planning") {
                NavigationLink {
                    ScanView()
                } label: {
                    Label("Map & Area Measurements", systemImage: "map")
                }
                NavigationLink {
                    InstallerSurveyView()
                } label: {
                    Label("Installer Survey", systemImage: "wrench.and.screwdriver")
                }
                NavigationLink {
                    IPhoneAnalyzerView()
                } label: {
                    Label("iPhone-Only Network Test", systemImage: "iphone.radiowaves.left.and.right")
                }
            }
            Section("Hardware") {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("ESP Devices", systemImage: "memorychip")
                }
            }
            Section("Results") {
                NavigationLink {
                    MeasurementsView()
                } label: {
                    Label("Measurements & Location Data", systemImage: "list.bullet.rectangle")
                }
                NavigationLink {
                    ReportView()
                } label: {
                    Label("Final Report", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("AP & Wi-Fi")
    }
}

private struct SiteReadinessView: View {
    @EnvironmentObject private var store: SurveyStore

    var body: some View {
        List {
            Section("Location") {
                LabeledContent("Areas", value: "\(store.areaLandmarks.count)")
                LabeledContent("Tasks open", value: "\(store.siteTasks.filter { $0.status != "Done" }.count)")
                LabeledContent("Equipment items", value: "\(store.locationEquipment.count)")
                LabeledContent("Upcoming shifts", value: "\(store.shiftsForCurrentLocation.count)")
            }
            Section("Shortcuts") {
                NavigationLink { EquipmentListView() } label: {
                    Label("Check Equipment", systemImage: "shippingbox")
                }
                NavigationLink { AreaManagementView() } label: {
                    Label("Review Areas", systemImage: "square.grid.2x2")
                }
                NavigationLink { ReportView() } label: {
                    Label("Open Report", systemImage: "doc.text")
                }
            }
        }
        .navigationTitle("Site Readiness")
    }
}

private struct AreaManagementView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var showingAddArea = false
    @State private var showingFloorEditor = false

    private var mappedAreas: [AreaLandmark] { store.areaLandmarks.filter(\.isMapped) }
    private var unmappedAreas: [AreaLandmark] { store.areaLandmarks.filter { !$0.isMapped } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AreaLandmarkCaptureView()
                            .environmentObject(store)
                    } label: {
                        Label("Add Areas to Scan Map", systemImage: "location.viewfinder")
                    }
                    Button {
                        showingFloorEditor = true
                    } label: {
                        Label("Floors", systemImage: "square.stack.3d.up")
                    }
                } footer: {
                    Text("Areas can be used for tasks and iPhone tests even if they are never placed on the floor map.")
                }

                if !unmappedAreas.isEmpty {
                    Section("Unmapped Areas") {
                        ForEach(unmappedAreas) { area in
                            NavigationLink {
                                AreaDetailView(area: area)
                            } label: {
                                areaRow(area)
                            }
                        }
                    }
                }

                Section("Mapped Areas") {
                    if mappedAreas.isEmpty {
                        Text("No mapped areas yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mappedAreas) { area in
                            NavigationLink {
                                AreaDetailView(area: area)
                            } label: {
                                areaRow(area)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Areas")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingFloorEditor = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    Button {
                        showingAddArea = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddArea) {
                AreaEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingFloorEditor) {
                FloorManagementView()
                    .environmentObject(store)
            }
        }
    }

    private func areaRow(_ area: AreaLandmark) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(area.name).font(.headline)
                Text("\(area.isMapped ? "Placed on map" : "Not on map") · \(store.areaWorkSummary(area))")
                    .font(.caption)
                    .foregroundStyle(store.isAreaReady(area) ? .green : .orange)
            }
            Spacer()
            Text(store.isAreaReady(area) ? "Ready" : "Needs Work")
                .font(.caption.bold())
                .foregroundStyle(store.isAreaReady(area) ? .green : .orange)
            if let score = store.areaScore(area) {
                Text("\(score)")
                    .font(.headline)
                    .foregroundStyle(scoreColor(score))
            }
        }
    }

    private func scoreColor(_ score: Int) -> Color {
        switch ProfessionalScore.label(score) {
        case "Excellent": return .green
        case "Good": return Color(red: 0.45, green: 0.75, blue: 0.20)
        case "Fair": return .yellow
        case "Weak": return .orange
        default: return .red
        }
    }
}

private struct FloorManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        _ = store.addFloor()
                    } label: {
                        Label("Add Floor", systemImage: "plus")
                    }
                }
                Section("Floors") {
                    ForEach(store.buildingFloors) { floor in
                        FloorRow(floor: floor)
                    }
                }
            }
            .navigationTitle("Floors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct FloorRow: View {
    @EnvironmentObject private var store: SurveyStore
    let floor: BuildingFloor
    @State private var name = ""

    var body: some View {
        TextField("Floor name", text: $name)
            .onSubmit { save() }
            .onAppear { name = floor.name }
            .onChange(of: name) { _, _ in save() }
    }

    private func save() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else { return }
        var updated = floor
        updated.name = cleanName
        store.save(floor: updated)
    }
}

private struct AreaDetailView: View {
    @EnvironmentObject private var store: SurveyStore
    let area: AreaLandmark
    @State private var showingTaskEditor = false

    private var currentArea: AreaLandmark {
        store.areaLandmarks.first { $0.id == area.id } ?? area
    }

    private var tasks: [SiteTask] {
        store.siteTasks.filter { $0.areaId == area.id }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var equipment: [LocationEquipmentItem] {
        store.locationEquipment.filter { $0.areaId == area.id }
    }

    var body: some View {
        List {
            Section("Tasks") {
                if tasks.isEmpty {
                    Text("No tasks assigned to this area.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tasks) { task in
                        NavigationLink {
                            SiteTaskEditorView(task: task)
                                .environmentObject(store)
                        } label: {
                            SiteTaskRow(task: task)
                        }
                    }
                }
            }
        }
        .navigationTitle(currentArea.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingTaskEditor = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            SiteTaskEditorView(defaultFloorId: currentArea.floorId, defaultAreaId: currentArea.id)
                .environmentObject(store)
        }
    }

    private func floorName(_ id: UUID?) -> String {
        id.flatMap { floorId in store.buildingFloors.first { $0.id == floorId }?.name } ?? "No floor"
    }
}

private struct AreaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var name = ""
    @State private var floorId: UUID?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Area name, for example Kitchen", text: $name)
                Picker("Floor", selection: $floorId) {
                    Text("Default floor").tag(Optional<UUID>.none)
                    ForEach(store.buildingFloors) { floor in
                        Text(floor.name).tag(Optional(floor.id))
                    }
                }
            }
            .navigationTitle("New Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.addUnmappedArea(name: name, floorId: floorId)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear { floorId = store.buildingFloors.first?.id }
    }
}

private struct EquipmentListView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var showingEditor = false

    var body: some View {
        List {
            Section {
                Button {
                    showingEditor = true
                } label: {
                    Label("Add Equipment", systemImage: "plus.circle")
                }
            } footer: {
                Text("This is the required equipment list for the selected location.")
            }

            Section("Needed") {
                if store.locationEquipment.isEmpty {
                    ContentUnavailableView("No Equipment", systemImage: "shippingbox", description: Text("Add keypads, wires, smoke detectors, motion sensors, APs, and other job-site material."))
                } else {
                    ForEach(store.locationEquipment) { item in
                        NavigationLink {
                            EquipmentEditorView(item: item)
                                .environmentObject(store)
                        } label: {
                            EquipmentRow(item: item)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                store.delete(equipment: item)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                store.toggleEquipmentPacked(item)
                            } label: {
                                Label(item.isPacked ? "Needs Work" : "Done", systemImage: item.isPacked ? "arrow.uturn.backward" : "checkmark")
                            }
                            .tint(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Equipment")
        .sheet(isPresented: $showingEditor) {
            EquipmentEditorView()
                .environmentObject(store)
        }
    }
}

private struct EquipmentRow: View {
    @EnvironmentObject private var store: SurveyStore
    let item: LocationEquipmentItem

    private var areaName: String? {
        item.areaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.isPacked ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(item.isPacked ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text("\(item.quantity)x \(item.name)")
                    .font(.headline)
                Text(item.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let areaName {
                    Text(areaName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.assigneeIds.isEmpty {
                    Text("Assigned to \(assignees)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !item.note.isEmpty {
                    Text(item.note)
                        .font(.footnote)
                }
            }
        }
    }

    private var assignees: String {
        let names = store.employees.filter { item.assigneeIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "installer" : names.joined(separator: ", ")
    }
}

private struct EquipmentEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    var item: LocationEquipmentItem?
    @State private var name = ""
    @State private var quantity = 1
    @State private var category = "Device"
    @State private var areaId: UUID?
    @State private var assigneeIds = Set<UUID>()
    @State private var createInstallTask = false
    @State private var isDone = false
    @State private var note = ""

    private let categories = ["Device", "Cable", "Sensor", "Mounting", "Power", "Tool", "Other"]

    private var suggestions: [LocationEquipmentItem] {
        let query = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        var seen = Set<String>()
        return store.locationEquipment.filter { existing in
            existing.id != item?.id &&
            existing.name.lowercased().contains(query) &&
            seen.insert(existing.name.lowercased()).inserted
        }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Equipment") {
                    TextField("Item name", text: $name)
                    if !suggestions.isEmpty {
                        ForEach(suggestions) { suggestion in
                            Button {
                                name = suggestion.name
                                category = suggestion.category
                                note = suggestion.note
                            } label: {
                                Label(suggestion.name, systemImage: "text.badge.plus")
                            }
                        }
                    }
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999)
                    Picker("Category", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Toggle("Done / Ready", isOn: $isDone)
                }
                Section("Location") {
                    Picker("Area", selection: $areaId) {
                        Text("No area").tag(Optional<UUID>.none)
                        ForEach(store.areaLandmarks) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                }
                Section("Installation") {
                    Toggle("Create install task", isOn: $createInstallTask)
                    if !store.employees.isEmpty {
                        ForEach(store.employees) { employee in
                            Button {
                                if assigneeIds.contains(employee.id) {
                                    assigneeIds.remove(employee.id)
                                } else {
                                    assigneeIds.insert(employee.id)
                                }
                            } label: {
                                HStack {
                                    Text(employee.name)
                                    Spacer()
                                    if assigneeIds.contains(employee.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Add employees in Shifts before assigning installation.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Notes") {
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
                if item != nil {
                    Section {
                        Button(role: .destructive) {
                            if let item {
                                store.delete(equipment: item)
                            }
                            dismiss()
                        } label: {
                            Label("Delete Equipment", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(item == nil ? "Add Equipment" : "Equipment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let equipment = LocationEquipmentItem(
                            id: item?.id ?? UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity: quantity,
                            category: category,
                            areaId: areaId,
                            assigneeIds: Array(assigneeIds),
                            installTaskId: item?.installTaskId,
                            note: note,
                            isPacked: isDone
                        )
                        store.save(equipment: equipment, createsInstallTask: createInstallTask)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            guard let item else { return }
            name = item.name
            quantity = item.quantity
            category = item.category
            areaId = item.areaId
            assigneeIds = Set(item.assigneeIds)
            createInstallTask = item.installTaskId != nil || !item.assigneeIds.isEmpty
            isDone = item.isPacked
            note = item.note
        }
    }
}

private struct ShiftsView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var showingEmployeeEditor = false
    @State private var showingShiftEditor = false
    @State private var selectedEmployeeId: UUID?

    private var weekDays: [Date] {
        let calendar = Calendar.current
        let start = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        return (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: start) }
    }

    private var filteredShifts: [WorkShift] {
        store.workShifts.filter { shift in
            guard let selectedEmployeeId else { return true }
            return shift.employeeIds.contains(selectedEmployeeId)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                SmartBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 5) {
                            SmartAVLogoLockup(wordmarkWidth: 118, iconSize: 30)
                            Text("Weekly Shifts")
                                .font(SmartTheme.display(36))
                                .foregroundStyle(.white)
                            Text("All job sites")
                                .font(SmartTheme.bodyMedium(12))
                                .foregroundStyle(SmartTheme.muted)
                        }
                        employeeFilter
                        if filteredShifts.isEmpty {
                            SmartEmptyState(title: "No Shifts", subtitle: "Assign employees to this project with start and end times.")
                        }
                        ForEach(weekDays, id: \.self) { day in
                            let shifts = shifts(on: day)
                            SmartGlassCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(day.formatted(.dateTime.weekday(.wide)))
                                            .font(.headline)
                                            .foregroundStyle(.white)
                                        Spacer()
                                        Text(day.formatted(date: .abbreviated, time: .omitted))
                                            .font(.caption.bold())
                                            .foregroundStyle(SmartTheme.muted)
                                    }
                                    if shifts.isEmpty {
                                        Text("No scheduled work")
                                            .font(.caption)
                                            .foregroundStyle(SmartTheme.muted)
                                    } else {
                                        ForEach(shifts) { shift in
                                            if store.canManageShifts {
                                                NavigationLink {
                                                    ShiftEditorView(shift: shift)
                                                        .environmentObject(store)
                                                } label: {
                                                    WeeklyShiftCard(shift: shift)
                                                        .environmentObject(store)
                                                }
                                                .buttonStyle(.plain)
                                            } else {
                                                WeeklyShiftCard(shift: shift)
                                                    .environmentObject(store)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
            }
            .navigationTitle("Shifts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if store.canManageShifts {
                        Button {
                            showingEmployeeEditor = true
                        } label: {
                            Image(systemName: "person.badge.plus")
                        }
                        Button {
                            showingShiftEditor = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showingEmployeeEditor) {
                EmployeeEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingShiftEditor) {
                ShiftEditorView()
                    .environmentObject(store)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var employeeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", id: nil)
                ForEach(store.employees) { employee in
                    filterChip(title: employee.name, id: employee.id)
                }
            }
        }
    }

    private func filterChip(title: String, id: UUID?) -> some View {
        Button {
            selectedEmployeeId = id
        } label: {
            Text(title)
                .font(.caption.bold())
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(selectedEmployeeId == id ? SmartTheme.primary : Color.white.opacity(0.10), in: Capsule())
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    private func shifts(on day: Date) -> [WorkShift] {
        filteredShifts
            .filter { Calendar.current.isDate($0.startTime, inSameDayAs: day) }
            .sorted { $0.startTime < $1.startTime }
    }
}

private struct WeeklyShiftCard: View {
    @EnvironmentObject private var store: SurveyStore
    let shift: WorkShift

    private var names: String {
        let names = store.employees.filter { shift.employeeIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "No employees selected" : names.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 4)
                .fill(SmartTheme.cyan)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(shift.title.isEmpty ? "Scheduled Work" : shift.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    Spacer()
                    Text("\(shift.startTime.formatted(date: .omitted, time: .shortened))-\(shift.endTime.formatted(date: .omitted, time: .shortened))")
                        .font(.caption.bold())
                        .foregroundStyle(SmartTheme.cyan)
                }
                Text(names)
                    .font(.caption)
                    .foregroundStyle(SmartTheme.muted)
                Text(shift.locationName)
                    .font(.caption.bold())
                    .foregroundStyle(SmartTheme.warning)
                if !shift.siteAddress.isEmpty {
                    Text(shift.siteAddress)
                        .font(.caption2)
                        .foregroundStyle(SmartTheme.muted)
                        .lineLimit(1)
                    Link(destination: mapsURL(for: shift.siteAddress) ?? URL(string: "http://maps.apple.com")!) {
                        Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                            .font(.caption.bold())
                            .foregroundStyle(SmartTheme.cyan)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func mapsURL(for address: String) -> URL? {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        return URL(string: "http://maps.apple.com/?daddr=\(encoded)")
    }
}

private struct ShiftRow: View {
    @EnvironmentObject private var store: SurveyStore
    let shift: WorkShift

    private var names: String {
        let names = store.employees.filter { shift.employeeIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "No employees selected" : names.joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(shift.title.isEmpty ? "Scheduled Work" : shift.title)
                    .font(.headline)
                Spacer()
                Text(shift.startTime, style: .time)
                    .font(.subheadline.bold())
            }
            Text(names)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\(shift.startTime.formatted(date: .abbreviated, time: .shortened)) - \(shift.endTime.formatted(date: .omitted, time: .shortened))")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !shift.siteAddress.isEmpty {
                Link(destination: mapsURL(for: shift.siteAddress) ?? URL(string: "http://maps.apple.com")!) {
                    Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                        .font(.caption)
                }
            }
            if !shift.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(shift.notes)
                    .font(.footnote)
            }
        }
        .padding(.vertical, 4)
    }

    private func mapsURL(for address: String) -> URL? {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        return URL(string: "http://maps.apple.com/?daddr=\(encoded)")
    }
}

private struct LocationDetailsEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var address = ""
    @State private var directionsNote = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Address") {
                    TextField("Street address", text: $address, axis: .vertical)
                        .lineLimit(2...4)
                    TextField("Access notes, parking, lockbox, unit", text: $directionsNote, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.updateCurrentLocationAddress(address: address, directionsNote: directionsNote)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            address = store.currentLocation?.address ?? ""
            directionsNote = store.currentLocation?.directionsNote ?? ""
        }
    }
}

private struct EmployeeEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var name = ""
    @State private var role = ""
    @State private var phone = ""
    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Role", text: $role)
                TextField("Phone", text: $phone)
                    .keyboardType(.phonePad)
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
            .navigationTitle("Employee")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.save(employee: Employee(
                            id: UUID(),
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            role: role,
                            phone: phone,
                            email: email
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct ShiftEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    var shift: WorkShift?
    @AppStorage("smartAVReusableShiftTitles") private var reusableShiftTitleData = "[]"
    @State private var title = "Site Work"
    @State private var jobSiteSearch = ""
    @State private var selectedLocationId: UUID?
    @State private var siteAddress = ""
    @State private var startTime = Date().addingTimeInterval(3600)
    @State private var endTime = Date().addingTimeInterval(7200)
    @State private var notes = ""
    @State private var employeeIds = Set<UUID>()

    private let defaultShiftTitles = [
        "Site Work", "Rough-In", "Pre-Wire", "Installation", "Final Installation",
        "Security Final Check", "Network Setup", "AV Rack Work", "Client Walkthrough", "Service Call"
    ]

    private var reusableShiftTitles: [String] {
        guard let data = reusableShiftTitleData.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return decoded
    }

    private var shiftTitleSuggestions: [String] {
        let query = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var seen = Set<String>()
        let all = (defaultShiftTitles + reusableShiftTitles).filter { seen.insert($0.lowercased()).inserted }
        guard !query.isEmpty else { return all }
        return all.filter { $0.lowercased().contains(query) && $0.caseInsensitiveCompare(title) != .orderedSame }
    }

    private var projectSuggestions: [SurveyLocation] {
        let query = jobSiteSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return store.locations.sorted { $0.updatedAt > $1.updatedAt } }
        return store.locations
            .filter { $0.name.lowercased().contains(query) || $0.address.lowercased().contains(query) }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    private var cleanJobSiteName: String {
        jobSiteSearch.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Shift") {
                    TextField("Title", text: $title)
                    if !shiftTitleSuggestions.isEmpty {
                        ForEach(shiftTitleSuggestions.prefix(5), id: \.self) { suggestion in
                            Button {
                                title = suggestion
                            } label: {
                                Label(suggestion, systemImage: "text.badge.plus")
                            }
                        }
                    }
                    DatePicker("Start", selection: $startTime)
                    DatePicker("End", selection: $endTime)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Job Site") {
                    TextField("Search or create project name", text: $jobSiteSearch)
                    if !projectSuggestions.isEmpty {
                        ForEach(projectSuggestions.prefix(6)) { location in
                            Button {
                                selectedLocationId = location.id
                                jobSiteSearch = location.name
                                siteAddress = location.address
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(location.name)
                                        if !location.address.isEmpty {
                                            Text(location.address)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if selectedLocationId == location.id {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                    TextField("Address / directions", text: $siteAddress, axis: .vertical)
                        .lineLimit(2...4)
                    if shift != nil && !siteAddress.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Link(destination: mapsURL(for: siteAddress) ?? URL(string: "http://maps.apple.com")!) {
                            Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond")
                        }
                    }
                }
                Section("Employees") {
                    if store.employees.isEmpty {
                        Text("Add employees before assigning a shift.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(store.employees) { employee in
                            Button {
                                if employeeIds.contains(employee.id) {
                                    employeeIds.remove(employee.id)
                                } else {
                                    employeeIds.insert(employee.id)
                                }
                            } label: {
                                HStack {
                                    Text(employee.name)
                                    Spacer()
                                    if employeeIds.contains(employee.id) {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
                if shift != nil {
                    Section {
                        Button(role: .destructive) {
                            if let shift {
                                store.delete(workShift: shift)
                            }
                            dismiss()
                        } label: {
                            Label("Delete Shift", systemImage: "trash")
                        }
                    } footer: {
                        Text("Editing is available here for now. Later, when login is added, this screen can be limited to managers and admins.")
                    }
                }
            }
            .navigationTitle(shift == nil ? "Assign Shift" : "Shift Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveShiftTitleSuggestion()
                        let locationName = cleanJobSiteName.isEmpty ? (store.currentLocation?.name ?? store.projectName) : cleanJobSiteName
                        let matchedLocation = selectedLocationId.flatMap { id in
                            store.locations.first { $0.id == id && $0.name.caseInsensitiveCompare(locationName) == .orderedSame }
                        }
                        let locationId = matchedLocation?.id ?? shift?.locationId ?? UUID()
                        store.save(workShift: WorkShift(
                            id: shift?.id ?? UUID(),
                            locationId: locationId,
                            locationName: locationName,
                            siteAddress: siteAddress.trimmingCharacters(in: .whitespacesAndNewlines),
                            title: title,
                            startTime: startTime,
                            endTime: max(endTime, startTime.addingTimeInterval(1800)),
                            employeeIds: Array(employeeIds),
                            notes: notes,
                            createdAt: shift?.createdAt ?? Date()
                        ))
                        dismiss()
                    }
                    .disabled(cleanJobSiteName.isEmpty || employeeIds.isEmpty)
                }
            }
        }
        .onAppear {
            if let shift {
                title = shift.title
                jobSiteSearch = shift.locationName
                selectedLocationId = store.locations.first { $0.id == shift.locationId }?.id
                siteAddress = shift.siteAddress
                startTime = shift.startTime
                endTime = shift.endTime
                notes = shift.notes
                employeeIds = Set(shift.employeeIds)
            } else {
                jobSiteSearch = store.currentLocation?.name ?? store.projectName
                selectedLocationId = store.currentLocationId
                siteAddress = store.currentLocation?.address ?? ""
            }
        }
    }

    private func mapsURL(for address: String) -> URL? {
        let encoded = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        return URL(string: "http://maps.apple.com/?daddr=\(encoded)")
    }

    private func saveShiftTitleSuggestion() {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        var names = reusableShiftTitles
        guard !defaultShiftTitles.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }),
              !names.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else { return }
        names.append(clean)
        names.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if let data = try? JSONEncoder().encode(names), let encoded = String(data: data, encoding: .utf8) {
            reusableShiftTitleData = encoded
        }
    }
}

@MainActor
private final class IPhoneNetworkAnalyzer: ObservableObject {
    @Published var currentSample: PhoneNetworkSample?
    @Published var liveSamples: [PhoneNetworkSample] = []
    @Published var isAnalyzing = false
    @Published var isLive = false
    @Published var pathStatus = "Checking"

    private let monitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "wifi-survey.iphone-network-monitor")
    private var liveTask: Task<Void, Never>?

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.pathStatus = path.status == .satisfied ? (path.usesInterfaceType(.wifi) ? "Wi-Fi" : "Online") : "Offline"
            }
        }
        monitor.start(queue: monitorQueue)
    }

    deinit {
        monitor.cancel()
        liveTask?.cancel()
    }

    func analyze(areaId: UUID?) async throws -> PhoneNetworkSample {
        try await analyze(areaId: areaId, probeCount: 8, storesLiveSample: false, includesSpeedTest: true)
    }

    static func averagedSample(from samples: [PhoneNetworkSample], areaId: UUID?) -> PhoneNetworkSample? {
        guard !samples.isEmpty else { return nil }
        let sent = samples.map(\.probesSent).reduce(0, +)
        let succeeded = samples.map(\.probesSucceeded).reduce(0, +)
        let packetLoss = sent > 0 ? Double(sent - succeeded) / Double(sent) * 100 : 100
        let latency = average(samples.compactMap(\.averageLatencyMs))
        let jitter = average(samples.compactMap(\.jitterMs))
        let download = average(samples.compactMap(\.downloadSpeedMbps))
        let upload = average(samples.compactMap(\.uploadSpeedMbps))
        let signal = average(samples.compactMap(\.normalizedSignalStrength))
        let latest = samples.max { $0.timestamp < $1.timestamp } ?? samples[0]
        let reachable = samples.contains { $0.internetReachable }
        let score = ProfessionalScore.phoneScore(
            normalizedSignalStrength: signal,
            averageLatencyMs: latency,
            packetLossPercent: packetLoss,
            jitterMs: jitter,
            downloadSpeedMbps: download,
            uploadSpeedMbps: upload,
            internetReachable: reachable
        )
        return PhoneNetworkSample(
            id: UUID(),
            areaId: areaId,
            timestamp: Date(),
            ssid: latest.ssid,
            bssid: latest.bssid,
            normalizedSignalStrength: signal,
            interfaceType: latest.interfaceType,
            isExpensive: latest.isExpensive,
            isConstrained: latest.isConstrained,
            internetReachable: reachable,
            averageLatencyMs: latency,
            minLatencyMs: samples.compactMap(\.minLatencyMs).min(),
            maxLatencyMs: samples.compactMap(\.maxLatencyMs).max(),
            jitterMs: jitter,
            packetLossPercent: packetLoss,
            downloadSpeedMbps: download,
            uploadSpeedMbps: upload,
            probesSent: sent,
            probesSucceeded: succeeded,
            score: score
        )
    }

    private func analyze(areaId: UUID?, probeCount: Int, storesLiveSample: Bool, includesSpeedTest: Bool) async throws -> PhoneNetworkSample {
        isAnalyzing = true
        defer { isAnalyzing = false }

        let wifi = await currentWiFi()
        let path = monitor.currentPath
        let latencies = await runProbes(count: probeCount)
        let downloadSpeed = includesSpeedTest ? await runDownloadSpeedTest() : nil
        let uploadSpeed = includesSpeedTest ? await runUploadSpeedTest() : nil
        let successes = latencies.compactMap { $0 }
        let packetLoss = latencies.isEmpty ? 100 : Double(latencies.count - successes.count) / Double(latencies.count) * 100
        let average = successes.isEmpty ? nil : successes.reduce(0, +) / Double(successes.count)
        let jitter = Self.jitter(successes)
        let reachable = path.status == .satisfied && !successes.isEmpty
        let score = ProfessionalScore.phoneScore(
            normalizedSignalStrength: wifi.signalStrength,
            averageLatencyMs: average,
            packetLossPercent: packetLoss,
            jitterMs: jitter,
            downloadSpeedMbps: downloadSpeed,
            uploadSpeedMbps: uploadSpeed,
            internetReachable: reachable
        )
        let sample = PhoneNetworkSample(
            id: UUID(),
            areaId: areaId,
            timestamp: Date(),
            ssid: wifi.ssid,
            bssid: wifi.bssid,
            normalizedSignalStrength: wifi.signalStrength,
            interfaceType: path.usesInterfaceType(.wifi) ? "Wi-Fi" : "Other",
            isExpensive: path.isExpensive,
            isConstrained: path.isConstrained,
            internetReachable: reachable,
            averageLatencyMs: average,
            minLatencyMs: successes.min(),
            maxLatencyMs: successes.max(),
            jitterMs: jitter,
            packetLossPercent: packetLoss,
            downloadSpeedMbps: downloadSpeed,
            uploadSpeedMbps: uploadSpeed,
            probesSent: latencies.count,
            probesSucceeded: successes.count,
            score: score
        )
        currentSample = sample
        if storesLiveSample {
            liveSamples.insert(sample, at: 0)
            if liveSamples.count > 120 {
                liveSamples.removeLast(liveSamples.count - 120)
            }
        }
        return sample
    }

    func setLive(_ enabled: Bool) {
        isLive = enabled
        liveTask?.cancel()
        if enabled {
            liveSamples = []
        }
        guard enabled else {
            liveTask = nil
            return
        }
        liveTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                _ = try? await self?.analyze(areaId: nil, probeCount: 5, storesLiveSample: true, includesSpeedTest: true)
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func currentWiFi() async -> (ssid: String?, bssid: String?, signalStrength: Double?) {
        await withCheckedContinuation { continuation in
            NEHotspotNetwork.fetchCurrent { network in
                continuation.resume(returning: (network?.ssid, network?.bssid, network?.signalStrength))
            }
        }
    }

    private func runProbes(count: Int) async -> [Double?] {
        var results: [Double?] = []
        for _ in 0..<count {
            results.append(await probeLatency())
            try? await Task.sleep(for: .milliseconds(180))
        }
        return results
    }

    private func probeLatency() async -> Double? {
        guard let url = URL(string: "https://captive.apple.com/hotspot-detect.html") else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4)
        request.httpMethod = "GET"
        let start = ContinuousClock.now
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode else { return nil }
            let elapsed = start.duration(to: .now)
            return Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15
        } catch {
            return nil
        }
    }

    private func runDownloadSpeedTest() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__down?bytes=750000") else { return nil }
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "GET"
        let start = ContinuousClock.now
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode, !data.isEmpty else { return nil }
            let elapsed = start.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            guard seconds > 0 else { return nil }
            return Double(data.count * 8) / seconds / 1_000_000
        } catch {
            return nil
        }
    }

    private func runUploadSpeedTest() async -> Double? {
        guard let url = URL(string: "https://speed.cloudflare.com/__up") else { return nil }
        let body = Data(repeating: 0x5A, count: 500_000)
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
        request.httpMethod = "POST"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        let start = ContinuousClock.now
        do {
            let (_, response) = try await URLSession.shared.upload(for: request, from: body)
            guard let http = response as? HTTPURLResponse, 200..<400 ~= http.statusCode else { return nil }
            let elapsed = start.duration(to: .now)
            let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
            guard seconds > 0 else { return nil }
            return Double(body.count * 8) / seconds / 1_000_000
        } catch {
            return nil
        }
    }

    private static func jitter(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let deltas = zip(values.dropFirst(), values).map { abs($0 - $1) }
        return deltas.reduce(0, +) / Double(deltas.count)
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

private struct ScanView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var showingScanner = false
    @State private var showingARScanner = false
    @State private var showingWalkTrace = false
    @State private var showingLandmarkMapper = false
    @State private var showingRecord = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    mapPanel
                    mappingPanel

                    if let area = store.selectedArea {
                        AreaResultsView(area: area)
                            .environmentObject(store)
                            .environmentObject(bluetooth)
                    } else if !store.mappedAreaLandmarks.isEmpty {
                        Text("Tap an area to select it. Press and hold an area node to choose actions like iPhone analysis, ESP recording, or device assignment.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    reportsPanel
                    legacyRoomScanPanel
                }
                .padding()
            }
            .navigationTitle("Map")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        ReportView().environmentObject(store)
                    } label: {
                        Image(systemName: "doc.text")
                    }
                }
            }
            .sheet(isPresented: $showingRecord) {
                RecordPointView(isPresented: $showingRecord)
                    .environmentObject(store)
                    .environmentObject(bluetooth)
            }
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

    private var mapPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            if store.mappedAreaLandmarks.isEmpty {
                ContentUnavailableView(
                    "No Areas Mapped",
                    systemImage: "mappin.and.ellipse",
                    description: Text("Create areas first, then map only the areas that need a floor-plan position.")
                )
                .frame(minHeight: 300)
            } else {
                AreaLandmarkMapView(
                    buildingFloors: store.buildingFloors,
                    landmarks: store.mappedAreaLandmarks,
                    points: store.points,
                    devices: store.devices,
                    phoneTester: store.phoneTester,
                    phoneResults: store.phoneNetworkSamples,
                    onAction: handleAreaMapAction,
                    selectedAreaId: $store.selectedAreaId
                )
            }
        }
    }

    private var mappingPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                showingLandmarkMapper = true
            } label: {
                Label(store.mappedAreaLandmarks.isEmpty ? "Map Area Centers" : "Edit Area Centers", systemImage: "location.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text("Mark each room or area once. Floors stay aligned because every floor uses the same building coordinate system.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            if !store.mappedAreaLandmarks.isEmpty {
                Button(role: .destructive) { store.clearAreaMap() } label: {
                    Label("Clear Area Map", systemImage: "trash")
                }
            }
        }
    }

    private var reportsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Results", systemImage: "chart.bar.doc.horizontal")
                .font(.headline)
            HStack {
                NavigationLink {
                    MeasurementsView().environmentObject(store)
                } label: {
                    Label("Measurements", systemImage: "list.bullet.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                NavigationLink {
                    ReportView().environmentObject(store)
                } label: {
                    Label("Report", systemImage: "doc.text")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var legacyRoomScanPanel: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 12) {
                if store.hasFloorPlan {
                    HomeMapView(map: store.homeMap, points: store.points, liveStatus: bluetooth.deviceStatus, selectedRoomId: $store.selectedRoomId, selection: $store.selectedLocation)
                        .frame(minHeight: 260)

                    HStack {
                        metric(title: "Width", value: String(format: "%.1f m", store.homeMap.width))
                        metric(title: "Length", value: String(format: "%.1f m", store.homeMap.height))
                        metric(title: "Rooms", value: "\(store.homeMap.rooms.count)")
                    }

                    if let room = store.selectedRoom {
                        Text("Arrange \(room.name)").font(.subheadline.bold())
                        HStack {
                            moveButton("arrow.left", dx: -0.5, dy: 0)
                            moveButton("arrow.right", dx: 0.5, dy: 0)
                            moveButton("arrow.up", dx: 0, dy: -0.5)
                            moveButton("arrow.down", dx: 0, dy: 0.5)
                            Spacer()
                            Button { store.assignCurrentNode(bluetooth.deviceStatus.nodeId) } label: {
                                Image(systemName: "memorychip")
                            }
                            .buttonStyle(.bordered)
                            Button(role: .destructive) { store.deleteSelectedRoom() } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }
                    }

                    Button(role: .destructive) {
                        store.clearPlan()
                    } label: {
                        Label("Clear Legacy Room Map", systemImage: "trash")
                    }
                }

                TextField("Room name, for example Kitchen", text: $store.pendingRoomName)
                    .textFieldStyle(.roundedBorder)

                Button {
                    showingScanner = true
                } label: {
                    Label("Camera Detect Walls", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    showingWalkTrace = true
                } label: {
                    Label("Trace Room Corners", systemImage: "figure.walk")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        } label: {
            Label("Optional Room Scan Tools", systemImage: "viewfinder")
                .font(.headline)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func handleAreaMapAction(_ area: AreaLandmark, _ action: AreaMapAction) {
        store.selectedAreaId = area.id
        switch action {
        case .viewDetails:
            break
        case .recordESPMeasurement:
            showingRecord = true
        case .analyzeWithIPhone:
            store.message = "Open the iPhone Test tab to collect samples for \(area.name). The selected area is already set."
        case .assignActiveESP:
            store.assignCurrentNodeToArea(bluetooth.deviceStatus.nodeId)
            store.message = "Assigned \(bluetooth.deviceStatus.nodeId) to \(area.name)."
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

private struct IPhoneAnalyzerView: View {
    @EnvironmentObject private var store: SurveyStore
    @StateObject private var analyzer = IPhoneNetworkAnalyzer()
    @State private var areaCollectionSamples: [PhoneNetworkSample] = []
    @State private var isCollectingAreaData = false
    @State private var canFinishAreaCollection = false
    @State private var areaCollectionTask: Task<Void, Never>?
    @State private var finishGateTask: Task<Void, Never>?
    @State private var standaloneSample: PhoneNetworkSample?

    private var areaCollectionAverage: PhoneNetworkSample? {
        IPhoneNetworkAnalyzer.averagedSample(from: areaCollectionSamples, areaId: store.selectedAreaId)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if !store.mappedAreaLandmarks.isEmpty {
                        AreaLandmarkMapView(
                            buildingFloors: store.buildingFloors,
                            landmarks: store.mappedAreaLandmarks,
                            points: store.points,
                            devices: [],
                            phoneTester: store.phoneTester,
                            phoneResults: store.phoneNetworkSamples,
                            selectedAreaId: $store.selectedAreaId
                        )

                    }

                    selectedAreaPanel
                    livePanel

                    if store.areaLandmarks.isEmpty {
                        Text("You can run iPhone-only tests without creating an area or floor map. Add areas only when you want to save results or link tasks to rooms.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
            }
            .navigationTitle("iPhone Analyzer")
        }
    }

    private var selectedAreaPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(store.selectedArea?.name ?? "No area selected").font(.headline)
                    Text(isCollectingAreaData ? "Collecting data. Keep the phone at this place." : "Area is optional. Select one only if you want to save the result to that room or task area.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let result = areaCollectionAverage ?? store.selectedArea.flatMap(store.phoneResult) ?? standaloneSample {
                    Text("\(result.score)")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundStyle(scoreColor(result.score))
                }
            }

            if !store.areaLandmarks.isEmpty {
                Picker("Save to area", selection: $store.selectedAreaId) {
                    Text("No area").tag(Optional<UUID>.none)
                    ForEach(store.areaLandmarks) { area in
                        Text(area.name).tag(Optional(area.id))
                    }
                }
                .pickerStyle(.menu)
            }

            if isCollectingAreaData {
                LabeledContent("Status", value: canFinishAreaCollection ? "Ready to finish" : "Collecting first 5 seconds")
                LabeledContent("Samples collected", value: "\(areaCollectionSamples.count)")
            }

            if let result = areaCollectionAverage ?? store.selectedArea.flatMap(store.phoneResult) ?? standaloneSample {
                PhoneResultSummary(sample: result)
            }

            if isCollectingAreaData {
                Button {
                    finishAreaCollection()
                } label: {
                    Label(canFinishAreaCollection ? "Finish and Save Average" : "Wait 5 Seconds", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canFinishAreaCollection || areaCollectionSamples.isEmpty)
            } else {
                Button {
                    Task { await runStandaloneTest() }
                } label: {
                    Label("Run iPhone Test Here", systemImage: "waveform.path.ecg")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(analyzer.isAnalyzing)

                Button {
                    startAreaCollection()
                } label: {
                    Label(store.selectedArea == nil ? "Collect Average Without Area" : "Analyze Selected Area", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(analyzer.isAnalyzing)
            }

            if !store.areaLandmarks.isEmpty {
                HStack {
                    Button {
                        selectPreviousArea()
                    } label: {
                        Label("Previous", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCollectingAreaData)

                    Spacer()

                    Button {
                        selectNextArea()
                    } label: {
                        Label("Next", systemImage: "chevron.right")
                    }
                    .buttonStyle(.bordered)
                    .disabled(isCollectingAreaData)
                }
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private var livePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Network path", value: analyzer.pathStatus)
            NavigationLink {
                IPhoneLiveAnalyzerLogView(analyzer: analyzer)
                    .environmentObject(store)
            } label: {
                Label("Open Live Monitor", systemImage: "list.bullet.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text("Open the live monitor to start automatic full-result logging with rolling averages and the latest five samples.")
                .font(.footnote).foregroundStyle(.secondary)

            Text("iOS does not expose installer-grade RSSI in dBm or full Wi-Fi scan data. Signal strength is normalized when Apple makes it available.")
                .font(.footnote)
                .foregroundStyle(.orange)
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
    }

    private func startAreaCollection() {
        let selectedAreaId = store.selectedAreaId
        areaCollectionSamples = []
        isCollectingAreaData = true
        canFinishAreaCollection = false
        areaCollectionTask?.cancel()
        finishGateTask?.cancel()
        finishGateTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            canFinishAreaCollection = true
        }
        areaCollectionTask = Task { @MainActor in
            while !Task.isCancelled {
                do {
                    let result = try await analyzer.analyze(areaId: selectedAreaId)
                    areaCollectionSamples.append(result)
                } catch {
                    store.message = "The iPhone analyzer could not complete the last sample."
                    try? await Task.sleep(for: .seconds(1))
                }
            }
        }
    }

    private func finishAreaCollection() {
        areaCollectionTask?.cancel()
        finishGateTask?.cancel()
        areaCollectionTask = nil
        finishGateTask = nil
        isCollectingAreaData = false
        canFinishAreaCollection = false
        guard let average = IPhoneNetworkAnalyzer.averagedSample(from: areaCollectionSamples, areaId: store.selectedAreaId) else {
            store.message = "No iPhone samples were collected for this area."
            return
        }
        let sampleCount = areaCollectionSamples.count
        if store.selectedAreaId == nil {
            standaloneSample = average
            store.message = "Averaged iPhone result is ready. Select an area if you want to save it to a room."
        } else {
            store.savePhoneNetworkSample(average)
            store.message = "Saved averaged iPhone result from \(sampleCount) samples."
        }
        areaCollectionSamples = []
        if store.selectedAreaId != nil { selectNextArea() }
    }

    private func runStandaloneTest() async {
        do {
            let sample = try await analyzer.analyze(areaId: store.selectedAreaId)
            standaloneSample = sample
            if store.selectedAreaId != nil {
                store.savePhoneNetworkSample(sample)
                store.message = "Saved iPhone result to \(store.selectedArea?.name ?? "selected area")."
            }
        } catch {
            store.message = "The iPhone analyzer could not complete the test."
        }
    }

    private func selectNextArea() {
        moveSelection(by: 1)
    }

    private func selectPreviousArea() {
        moveSelection(by: -1)
    }

    private func moveSelection(by offset: Int) {
        guard !store.areaLandmarks.isEmpty else { return }
        areaCollectionSamples = []
        let currentIndex = store.selectedAreaId.flatMap { id in store.areaLandmarks.firstIndex { $0.id == id } } ?? 0
        let nextIndex = min(max(currentIndex + offset, 0), store.areaLandmarks.count - 1)
        store.selectedAreaId = store.areaLandmarks[nextIndex].id
    }

    private func scoreColor(_ score: Int) -> Color {
        switch ProfessionalScore.label(score) {
        case "Excellent": return .green
        case "Good": return Color(red: 0.45, green: 0.75, blue: 0.20)
        case "Fair": return .yellow
        case "Weak": return .orange
        default: return .red
        }
    }
}

private struct IPhoneLiveAnalyzerLogView: View {
    @EnvironmentObject private var store: SurveyStore
    @ObservedObject var analyzer: IPhoneNetworkAnalyzer

    private var averages: PhoneLiveAverages {
        PhoneLiveAverages(samples: analyzer.liveSamples)
    }

    var body: some View {
        List {
            Section {
                Label(analyzer.isLive ? "Live monitor is running" : "Live monitor is stopped", systemImage: analyzer.isLive ? "dot.radiowaves.left.and.right" : "pause.circle")
                LabeledContent("Network path", value: analyzer.pathStatus)
                LabeledContent("Samples", value: "\(analyzer.liveSamples.count)")
            }

            Section("Rolling Averages") {
                averageRow("Score", averages.score.map { String(format: "%.0f/100", $0) } ?? "--")
                averageRow("Ping", averages.latency.map { String(format: "%.0f ms", $0) } ?? "--")
                averageRow("Packet loss", averages.packetLoss.map { String(format: "%.1f%%", $0) } ?? "--")
                averageRow("Download", averages.downloadSpeed.map { String(format: "%.1f Mbps", $0) } ?? "--")
                averageRow("Upload", averages.uploadSpeed.map { String(format: "%.1f Mbps", $0) } ?? "--")
                averageRow("Signal", averages.signal.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
                averageRow("Success", averages.successRate.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
            }

            Section("Latest 5 Results") {
                if analyzer.liveSamples.isEmpty {
                    Text("Waiting for the first live sample.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Array(analyzer.liveSamples.prefix(5).enumerated()), id: \.element.id) { index, sample in
                    PhoneLiveSampleRow(sample: sample, index: index)
                        .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                        .listRowBackground(index.isMultiple(of: 2) ? Color(uiColor: .secondarySystemGroupedBackground) : Color(uiColor: .tertiarySystemGroupedBackground))
                }
            }

            Section {
                Button {
                    guard let selectedAreaId = store.selectedAreaId, let latest = analyzer.liveSamples.first ?? analyzer.currentSample else { return }
                    store.savePhoneNetworkSample(latest.assigned(to: selectedAreaId))
                    store.message = "Live iPhone result saved to \(store.selectedArea?.name ?? "selected area")."
                } label: {
                    Label("Save Latest Result to Selected Area", systemImage: "square.and.arrow.down")
                }
                .disabled(store.selectedAreaId == nil || (analyzer.liveSamples.first ?? analyzer.currentSample) == nil)
            } footer: {
                Text(store.selectedArea.map { "Selected area: \($0.name)" } ?? "Select an area on the map before saving a live result.")
            }
        }
        .navigationTitle("Live iPhone Log")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { analyzer.setLive(true) }
        .onDisappear { analyzer.setLive(false) }
    }

    private func averageRow(_ title: String, _ value: String) -> some View {
        LabeledContent(title, value: value)
    }
}

private struct PhoneLiveAverages {
    let samples: [PhoneNetworkSample]

    var latency: Double? { average(samples.compactMap(\.averageLatencyMs)) }
    var packetLoss: Double? { samples.isEmpty ? nil : average(samples.map(\.packetLossPercent)) }
    var downloadSpeed: Double? { average(samples.compactMap(\.downloadSpeedMbps)) }
    var uploadSpeed: Double? { average(samples.compactMap(\.uploadSpeedMbps)) }
    var signal: Double? { average(samples.compactMap(\.normalizedSignalStrength)) }
    var score: Double? { samples.isEmpty ? nil : average(samples.map { Double($0.score) }) }
    var successRate: Double? {
        let sent = samples.map(\.probesSent).reduce(0, +)
        guard sent > 0 else { return nil }
        return Double(samples.map(\.probesSucceeded).reduce(0, +)) / Double(sent)
    }

    private func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}

private struct PhoneLiveSampleRow: View {
    let sample: PhoneNetworkSample
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("#\(index + 1)  \(sample.timestamp.formatted(date: .omitted, time: .standard))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(sample.score)")
                    .font(.headline)
                Text(sample.qualityLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                metric("Ping", sample.averageLatencyMs.map { String(format: "%.0f ms", $0) } ?? "--")
                metric("Loss", String(format: "%.0f%%", sample.packetLossPercent))
                metric("Down", sample.downloadSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
            }
            HStack(spacing: 14) {
                metric("Up", sample.uploadSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
                metric("Signal", sample.normalizedSignalStrength.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
                metric("Path", sample.interfaceType)
            }
            Text("\(sample.probesSucceeded)/\(sample.probesSent) probes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct PhoneResultSummary: View {
    let sample: PhoneNetworkSample

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(sample.qualityLabel, systemImage: "iphone")
                    .font(.headline)
                Spacer()
                Text("\(sample.score)/100")
                    .font(.headline)
            }
            HStack(spacing: 16) {
                metric("Latency", sample.averageLatencyMs.map { String(format: "%.0f ms", $0) } ?? "--")
                metric("Loss", String(format: "%.0f%%", sample.packetLossPercent))
                metric("Signal", sample.normalizedSignalStrength.map { String(format: "%.0f%%", $0 * 100) } ?? "--")
            }
            HStack(spacing: 16) {
                metric("Download", sample.downloadSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
                metric("Upload", sample.uploadSpeedMbps.map { String(format: "%.1f Mbps", $0) } ?? "--")
                metric("Path", sample.interfaceType)
            }
            HStack(spacing: 16) {
                metric("Probes", "\(sample.probesSucceeded)/\(sample.probesSent)")
            }
            if let ssid = sample.ssid {
                Text("\(ssid)\(sample.bssid.map { " · \($0)" } ?? "")")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                        Text(device.connected ? "\(device.source == "hub" ? "Hub" : "Direct") · \(device.host) · Channel \(device.channel)" : "Offline")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("\(ProfessionalScore.device(device))").font(.headline)
                        Text(device.rssi.map { "\($0) dBm" } ?? "--").font(.caption)
                    }
                    Button {
                        Task {
                            do {
                                if device.source == "hub", let hubHost = device.hubHost {
                                    try await ESPService(host: hubHost).identifyHubChild(nodeId: device.nodeId)
                                } else {
                                    try await ESPService(host: device.host).identify()
                                }
                            } catch {
                                store.message = "Could not identify \(device.nodeId)."
                            }
                        }
                    } label: {
                        Image(systemName: "light.beacon.max")
                    }
                    .buttonStyle(.borderless)
                }
            }

            if area.assignedNodeIds.contains("IPHONE") || store.phoneResult(in: area) != nil {
                HStack {
                    Image(systemName: "iphone")
                    VStack(alignment: .leading) {
                        Text("This iPhone").font(.subheadline.bold())
                        Text(store.phoneResult(in: area).map { "\($0.qualityLabel) · \($0.score)/100" } ?? "No phone result saved")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(store.phoneResult(in: area)?.averageLatencyMs.map { String(format: "%.0f ms", $0) } ?? "--")
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
    @State private var showingNewLocation = false
    @State private var newLocationName = ""

    var body: some View {
        List {
            Section {
                Menu {
                    ForEach(store.locations) { location in
                        Button(location.name) { store.switchLocation(to: location.id) }
                    }
                } label: {
                    Label(store.currentLocation?.name ?? "Choose Current Location", systemImage: "mappin.and.ellipse")
                }

                TextField("Location name", text: $store.projectName)

                Button {
                    store.saveCurrentLocation(name: store.projectName)
                } label: {
                    Label("Save Current Location", systemImage: "tray.and.arrow.down")
                }

                Button {
                    newLocationName = ""
                    showingNewLocation = true
                } label: {
                    Label("New Location / Fresh Survey", systemImage: "plus")
                }
            } header: {
                Text("Location")
            } footer: {
                Text("The app does not infer indoor position from ping tests. Select an area first, then the saved scan belongs to that selected area.")
            }

            Section("Results") {
                NavigationLink {
                    ReportView().environmentObject(store)
                } label: {
                    Label("Final Report", systemImage: "doc.text")
                }
            }

            Section("ESP Measurements") {
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
        .alert("New Location", isPresented: $showingNewLocation) {
            TextField("Home or site name", text: $newLocationName)
            Button("Create") {
                store.createNewLocation(named: newLocationName)
                newLocationName = ""
            }
            Button("Cancel", role: .cancel) { newLocationName = "" }
        } message: {
            Text("This saves the current home and starts a clean survey workspace.")
        }
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var showingAddDevice = false

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
                                Text(device.source == "hub" ? "Via hub \(device.hubHost ?? "") · \(device.childIp ?? device.host)" : device.host)
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
                        showingAddDevice = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddDevice) {
                AddESPDeviceView()
                    .environmentObject(store)
                    .environmentObject(bluetooth)
            }
            .task { await bluetooth.refreshPreferredStatus() }
        }
    }
}

private struct AddESPDeviceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @EnvironmentObject private var bluetooth: BLEProvisioningService
    @State private var host = "192.168.4.1"
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            Form {
                Section("ESP32-WROOM Hub") {
                    Text("Use Bluetooth for the ESP32-WROOM hub. After it is added, ESP-01S boards connected to its SmartAV hub network appear automatically.")
                    Button {
                        bluetooth.addAnotherDevice()
                        dismiss()
                    } label: {
                        Label("Find ESP32-WROOM by Bluetooth", systemImage: "dot.radiowaves.left.and.right")
                    }
                }

                Section("Manual IP") {
                    TextField("192.168.4.1 or local IP", text: $host)
                        .keyboardType(.numbersAndPunctuation)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await addByIP() }
                    } label: {
                        Label(isAdding ? "Adding..." : "Add Device or Hub by IP", systemImage: "network")
                    }
                    .disabled(isAdding)
                    Text("Use this for an ESP32 hub, an ESP-01S setup AP, or a board that is already on the same Wi-Fi as the phone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add ESP Device")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func addByIP() async {
        isAdding = true
        defer { isAdding = false }
        await store.addDevice(host: host)
        if store.message?.contains("added") == true {
            dismiss()
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
                            do {
                                if device.source == "hub", let hubHost = device.hubHost {
                                    try await ESPService(host: hubHost).identifyHubChild(nodeId: device.nodeId)
                                } else {
                                    try await ESPService(host: device.host).identify()
                                }
                            }
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
