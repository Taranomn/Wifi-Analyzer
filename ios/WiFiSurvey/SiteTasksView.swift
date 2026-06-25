import ARKit
import SceneKit
import SwiftUI

struct SiteTasksView: View {
    @EnvironmentObject private var store: SurveyStore
    @State private var showingAR = false
    @State private var showingTaskEditor = false
    @State private var showingBulkAssign = false
    @State private var isSelecting = false
    @State private var selectedTaskIds = Set<UUID>()

    private var openTasks: [SiteTask] {
        store.siteTasks.filter { $0.status != "Done" }.sorted { $0.createdAt > $1.createdAt }
    }

    private var doneTasks: [SiteTask] {
        store.siteTasks.filter { $0.status == "Done" }.sorted { $0.updatedAt > $1.updatedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("To Do") {
                    if store.siteTasks.isEmpty {
                        ContentUnavailableView("No Site Tasks", systemImage: "checklist", description: Text("Use the camera to mark install work, cable runs, access issues, and construction notes."))
                    } else if openTasks.isEmpty {
                        Text("All site tasks are done.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(openTasks) { task in
                            taskListRow(task)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.delete(siteTask: task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    store.updateSiteTaskStatus(task, status: task.status == "Done" ? "To Do" : "Done")
                                } label: {
                                    Label(task.status == "Done" ? "Reopen" : "Done", systemImage: "checkmark.circle")
                                }
                                .tint(.green)
                            }
                        }
                    }
                }

                if !doneTasks.isEmpty {
                    Section("Done") {
                        ForEach(doneTasks) { task in
                            taskListRow(task)
                            .swipeActions {
                                Button(role: .destructive) {
                                    store.delete(siteTask: task)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    store.updateSiteTaskStatus(task, status: "To Do")
                                } label: {
                                    Label("Reopen", systemImage: "arrow.uturn.backward")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Site Tasks")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button(isSelecting ? "Done" : "Select") {
                        isSelecting.toggle()
                        if !isSelecting { selectedTaskIds = [] }
                    }
                    if isSelecting {
                        Button("Assign") {
                            showingBulkAssign = true
                        }
                        .disabled(selectedTaskIds.isEmpty)
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showingAR = true
                    } label: {
                        Image(systemName: "arkit")
                    }
                    Button {
                        showingTaskEditor = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingTaskEditor) {
                SiteTaskEditorView()
                    .environmentObject(store)
            }
            .sheet(isPresented: $showingBulkAssign) {
                BulkTaskAssignmentView(taskIds: selectedTaskIds) {
                    selectedTaskIds = []
                    isSelecting = false
                }
                .environmentObject(store)
            }
            .fullScreenCover(isPresented: $showingAR) {
                SiteTaskARView()
                    .environmentObject(store)
            }
        }
    }

    @ViewBuilder
    private func taskListRow(_ task: SiteTask) -> some View {
        if isSelecting {
            Button {
                if selectedTaskIds.contains(task.id) {
                    selectedTaskIds.remove(task.id)
                } else {
                    selectedTaskIds.insert(task.id)
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: selectedTaskIds.contains(task.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedTaskIds.contains(task.id) ? .blue : .secondary)
                    SiteTaskRow(task: task)
                }
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                SiteTaskEditorView(task: task)
                    .environmentObject(store)
            } label: {
                SiteTaskRow(task: task)
            }
        }
    }
}

struct SiteTaskEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    var task: SiteTask?
    var defaultFloorId: UUID?
    var defaultAreaId: UUID?
    @State private var title = ""
    @State private var note = ""
    @State private var category = "Install AP"
    @State private var status = "To Do"
    @State private var selectedFloorId: UUID?
    @State private var selectedAreaId: UUID?
    @State private var assigneeIds = Set<UUID>()
    @State private var hasDueDate = false
    @State private var dueDate = Date().addingTimeInterval(86_400)
    @State private var wantsARPlacement = false

    private let categories = ["Install AP", "Run Cable", "Add Power", "Ceiling Access", "Mount Bracket", "Blocked Path", "Check Later", "Custom"]

    private var titleSuggestions: [SiteTask] {
        let query = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        var seen = Set<String>()
        return store.siteTasks.filter { existing in
            existing.id != task?.id &&
            existing.title.lowercased().contains(query) &&
            seen.insert(existing.title.lowercased()).inserted
        }
        .prefix(5)
        .map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Task title", text: $title)
                    if !titleSuggestions.isEmpty {
                        ForEach(titleSuggestions) { suggestion in
                            Button {
                                applySuggestion(suggestion)
                            } label: {
                                Label(suggestion.title, systemImage: "text.badge.plus")
                            }
                        }
                    }
                    TextField("Note", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                    Picker("Type", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    Picker("Status", selection: $status) {
                        ForEach(["To Do", "In Progress", "Done"], id: \.self) { Text($0) }
                    }
                    Toggle("Deadline", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate)
                    }
                    Toggle("Add to AR", isOn: $wantsARPlacement)
                }
                Section("Location") {
                    Picker("Floor", selection: $selectedFloorId) {
                        Text("No Floor").tag(Optional<UUID>.none)
                        ForEach(store.buildingFloors) { floor in
                            Text(floor.name).tag(Optional(floor.id))
                        }
                    }
                    Picker("Area", selection: $selectedAreaId) {
                        Text("No Area").tag(Optional<UUID>.none)
                        ForEach(store.areaLandmarks.filter { selectedFloorId == nil || $0.floorId == selectedFloorId }) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                }
                if !store.employees.isEmpty {
                    Section("Assignees") {
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
                    }
                }
                Section("AR") {
                    if task?.worldTransform.count == 16 {
                        Text("This task already has an AR marker.")
                            .foregroundStyle(.secondary)
                    } else {
                        Button {
                            let now = Date()
                            let updated = SiteTask(
                                id: task?.id ?? UUID(),
                                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                                category: category,
                                note: note,
                                status: status,
                                floorId: selectedFloorId,
                                areaId: selectedAreaId,
                                assigneeIds: Array(assigneeIds),
                                dueDate: hasDueDate ? dueDate : nil,
                                wantsARPlacement: true,
                                worldTransform: task?.worldTransform ?? [],
                                createdAt: task?.createdAt ?? now,
                                updatedAt: now
                            )
                            store.save(siteTask: updated)
                            store.message = "Task marked for AR placement. Open the AR icon in Tasks to place it at the camera reticle."
                            dismiss()
                        } label: {
                            Label("Mark for AR Placement", systemImage: "arkit")
                        }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                if task != nil {
                    Section {
                        Button(role: .destructive) {
                            if let task {
                                store.delete(siteTask: task)
                            }
                            dismiss()
                        } label: {
                            Label("Delete Task", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle(task == nil ? "Add Task" : "Task Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let now = Date()
                        store.save(siteTask: SiteTask(
                            id: task?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category,
                            note: note,
                            status: status,
                            floorId: selectedFloorId,
                            areaId: selectedAreaId,
                            assigneeIds: Array(assigneeIds),
                            dueDate: hasDueDate ? dueDate : nil,
                            wantsARPlacement: wantsARPlacement,
                            worldTransform: task?.worldTransform ?? [],
                            createdAt: task?.createdAt ?? now,
                            updatedAt: now
                        )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear {
            if let task {
                title = task.title
                note = task.note
                category = task.category
                status = task.status
                selectedFloorId = task.floorId
                selectedAreaId = task.areaId
                assigneeIds = Set(task.assigneeIds)
                hasDueDate = task.dueDate != nil
                dueDate = task.dueDate ?? Date().addingTimeInterval(86_400)
                wantsARPlacement = task.wantsARPlacement
            } else {
                selectedFloorId = selectedFloorId ?? defaultFloorId ?? store.selectedArea?.floorId ?? store.buildingFloors.first?.id
                selectedAreaId = selectedAreaId ?? defaultAreaId ?? store.selectedAreaId
            }
        }
    }

    private func applySuggestion(_ suggestion: SiteTask) {
        title = suggestion.title
        note = suggestion.note
        category = suggestion.category
        selectedFloorId = suggestion.floorId
        selectedAreaId = suggestion.areaId
        hasDueDate = suggestion.dueDate != nil
        dueDate = suggestion.dueDate ?? dueDate
        wantsARPlacement = suggestion.wantsARPlacement
    }
}

struct SiteTaskRow: View {
    @EnvironmentObject private var store: SurveyStore
    let task: SiteTask

    private var floorName: String {
        task.floorId.flatMap { id in store.buildingFloors.first { $0.id == id }?.name } ?? "No floor"
    }

    private var areaName: String {
        task.areaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name } ?? "No area"
    }

    private var assignees: String {
        let names = store.employees.filter { task.assigneeIds.contains($0.id) }.map(\.name)
        return names.isEmpty ? "Unassigned" : names.joined(separator: ", ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: task.status == "Done" ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.status == "Done" ? .green : .secondary)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(task.title)
                        .font(.headline)
                        .strikethrough(task.status == "Done")
                        .foregroundStyle(task.status == "Done" ? .secondary : .primary)
                    Spacer()
                    Menu {
                        ForEach(["To Do", "In Progress", "Done"], id: \.self) { status in
                            Button(status) {
                                store.updateSiteTaskStatus(task, status: status)
                            }
                        }
                    } label: {
                        Text(task.status)
                            .font(.caption.bold())
                            .foregroundStyle(statusColor)
                    }
                }
                Text("\(task.category) · \(floorName) · \(areaName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(assignees)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let dueDate = task.dueDate {
                    Text("Due \(dueDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(dueDate < Date() && task.status != "Done" ? .red : .secondary)
                }
                if task.wantsARPlacement && task.worldTransform.count != 16 {
                    Text("Needs AR placement")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
                if !task.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(task.note)
                        .font(.footnote)
                }
                Text(task.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch task.status {
        case "Done": return .green
        case "In Progress": return .orange
        default: return .secondary
        }
    }
}

private struct BulkTaskAssignmentView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    let taskIds: Set<UUID>
    let onComplete: () -> Void
    @State private var employeeIds = Set<UUID>()

    var body: some View {
        NavigationStack {
            List {
                Section("Tasks") {
                    Text("\(taskIds.count) selected")
                        .foregroundStyle(.secondary)
                }
                Section("Assign To") {
                    if store.employees.isEmpty {
                        Text("Add employees before assigning tasks.")
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
            }
            .navigationTitle("Assign Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        store.assignTasks(taskIds, to: employeeIds)
                        onComplete()
                        dismiss()
                    }
                    .disabled(store.employees.isEmpty)
                }
            }
        }
    }
}

private struct SiteTaskARView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var title = ""
    @State private var note = ""
    @State private var category = "Install AP"
    @State private var status = "Move slowly and scan the same site features."
    @State private var selectedFloorId: UUID?
    @State private var selectedAreaId: UUID?
    @State private var preparedTask: SiteTask?
    @State private var markRequest: SiteTaskMarkRequest?
    @State private var showingTaskEditor = false

    private let categories = ["Install AP", "Run Cable", "Add Power", "Ceiling Access", "Mount Bracket", "Blocked Path", "Check Later", "Custom"]

    var body: some View {
        ZStack {
            SiteTaskARContainer(
                tasks: store.siteTasks,
                worldMapData: store.siteTaskWorldMapData,
                markRequest: markRequest
            ) { task in
                store.save(siteTask: task)
            } onWorldMapUpdated: { data in
                store.saveSiteTaskWorldMap(data)
            } onStatus: { text in
                status = text
            }
            .ignoresSafeArea()

            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .shadow(radius: 3)

            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AR Site Tasks").font(.headline)
                        Text(status)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Done") { dismiss() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                Spacer()

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title.isEmpty ? "No task prepared" : title)
                                .font(.headline)
                                .lineLimit(1)
                            Text("\(category) · \(selectedFloorName) · \(selectedAreaName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Button {
                            showingTaskEditor = true
                        } label: {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.bordered)
                    }
                    Button {
                        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !cleanTitle.isEmpty else { return }
                        markRequest = SiteTaskMarkRequest(
                            requestId: UUID(),
                            taskId: preparedTask?.id,
                            title: cleanTitle,
                            category: category,
                            note: note,
                            status: preparedTask?.status ?? "To Do",
                            floorId: selectedFloorId,
                            areaId: selectedAreaId,
                            assigneeIds: preparedTask?.assigneeIds ?? [],
                            dueDate: preparedTask?.dueDate,
                            createdAt: preparedTask?.createdAt
                        )
                        preparedTask = nil
                        title = ""
                        note = ""
                    } label: {
                        Label("Place Task at Reticle", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
            .padding()
        }
        .sheet(isPresented: $showingTaskEditor) {
            NavigationStack {
                Form {
                    Section("Task") {
                        TextField("Task title", text: $title)
                        TextField("Note", text: $note, axis: .vertical)
                            .lineLimit(2...4)
                        Picker("Type", selection: $category) {
                            ForEach(categories, id: \.self) { Text($0) }
                        }
                    }
                    Section("Location") {
                        Picker("Floor", selection: $selectedFloorId) {
                            Text("No Floor").tag(Optional<UUID>.none)
                            ForEach(store.buildingFloors) { floor in
                                Text(floor.name).tag(Optional(floor.id))
                            }
                        }
                        Picker("Area", selection: $selectedAreaId) {
                            Text("No Area").tag(Optional<UUID>.none)
                            ForEach(store.areaLandmarks.filter { selectedFloorId == nil || $0.floorId == selectedFloorId }) { area in
                                Text(area.name).tag(Optional(area.id))
                            }
                        }
                    }
                }
                .navigationTitle("Prepare Task")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showingTaskEditor = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Ready") { showingTaskEditor = false }
                    }
                }
            }
            .presentationDetents([.height(380), .medium])
        }
        .onAppear {
            selectedFloorId = selectedFloorId ?? store.selectedArea?.floorId ?? store.buildingFloors.first?.id
            selectedAreaId = selectedAreaId ?? store.selectedAreaId
            if title.isEmpty, let pending = store.siteTasks.first(where: { $0.wantsARPlacement && $0.worldTransform.count != 16 }) {
                preparedTask = pending
                title = pending.title
                note = pending.note
                category = pending.category
                selectedFloorId = pending.floorId ?? selectedFloorId
                selectedAreaId = pending.areaId ?? selectedAreaId
            }
            showingTaskEditor = title.isEmpty
        }
    }

    private var selectedFloorName: String {
        selectedFloorId.flatMap { id in store.buildingFloors.first { $0.id == id }?.name } ?? "No floor"
    }

    private var selectedAreaName: String {
        selectedAreaId.flatMap { id in store.areaLandmarks.first { $0.id == id }?.name } ?? "No area"
    }
}

private struct SiteTaskMarkRequest: Equatable {
    let requestId: UUID
    let taskId: UUID?
    let title: String
    let category: String
    let note: String
    let status: String
    let floorId: UUID?
    let areaId: UUID?
    let assigneeIds: [UUID]
    let dueDate: Date?
    let createdAt: Date?
}

private struct SiteTaskARContainer: UIViewRepresentable {
    let tasks: [SiteTask]
    let worldMapData: Data?
    let markRequest: SiteTaskMarkRequest?
    let onTaskAdded: (SiteTask) -> Void
    let onWorldMapUpdated: (Data) -> Void
    let onStatus: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onTaskAdded: onTaskAdded, onWorldMapUpdated: onWorldMapUpdated, onStatus: onStatus)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = context.coordinator
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.debugOptions = [.showFeaturePoints]
        context.coordinator.view = view
        context.coordinator.tasks = Dictionary(uniqueKeysWithValues: tasks.filter { $0.worldTransform.count == 16 }.map { ($0.id.uuidString, $0) })

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal, .vertical]
        if let worldMap = decodeWorldMap(worldMapData) {
            configuration.initialWorldMap = worldMap
            context.coordinator.usesRestoredWorldMap = true
            context.coordinator.publish("Saved AR map loaded. Scan the same area slowly until markers settle.")
        } else {
            context.coordinator.usesRestoredWorldMap = false
            context.coordinator.publish("No saved AR map yet. Scan slowly, then place the first task.")
        }
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])

        if configuration.initialWorldMap == nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                context.coordinator.syncAnchors(for: tasks)
            }
        }
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        context.coordinator.tasks = Dictionary(uniqueKeysWithValues: tasks.filter { $0.worldTransform.count == 16 }.map { ($0.id.uuidString, $0) })
        context.coordinator.syncAnchors(for: tasks)
        if let markRequest, markRequest.requestId != context.coordinator.lastMarkRequestId {
            context.coordinator.lastMarkRequestId = markRequest.requestId
            context.coordinator.mark(request: markRequest)
        }
    }

    private func decodeWorldMap(_ data: Data?) -> ARWorldMap? {
        guard let data else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data)
    }

    final class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        weak var view: ARSCNView?
        var tasks: [String: SiteTask] = [:]
        var addedAnchorTaskIds = Set<String>()
        var markerNodesByTaskId: [String: SCNNode] = [:]
        var lastMarkRequestId: UUID?
        var lastWorldMapSave = Date.distantPast
        var usesRestoredWorldMap = false
        let onTaskAdded: (SiteTask) -> Void
        let onWorldMapUpdated: (Data) -> Void
        let onStatus: (String) -> Void

        init(onTaskAdded: @escaping (SiteTask) -> Void, onWorldMapUpdated: @escaping (Data) -> Void, onStatus: @escaping (String) -> Void) {
            self.onTaskAdded = onTaskAdded
            self.onWorldMapUpdated = onWorldMapUpdated
            self.onStatus = onStatus
        }

        func syncAnchors(for tasks: [SiteTask]) {
            guard let view else { return }
            guard !usesRestoredWorldMap else { return }
            for task in tasks where task.worldTransform.count == 16 && !addedAnchorTaskIds.contains(task.id.uuidString) {
                view.session.add(anchor: ARAnchor(name: anchorName(for: task.id), transform: matrix(from: task.worldTransform)))
                addedAnchorTaskIds.insert(task.id.uuidString)
            }
        }

        func mark(request: SiteTaskMarkRequest) {
            guard let view else { return }
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let query = view.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .any)
            guard let query, let result = view.session.raycast(query).first else {
                publish("Aim the reticle at a visible wall, floor, ceiling, or object and try again.")
                return
            }
            let now = Date()
            let task = SiteTask(
                id: request.taskId ?? UUID(),
                title: request.title,
                category: request.category,
                note: request.note,
                status: request.status,
                floorId: request.floorId,
                areaId: request.areaId,
                assigneeIds: request.assigneeIds,
                dueDate: request.dueDate,
                wantsARPlacement: false,
                worldTransform: array(from: result.worldTransform),
                createdAt: request.createdAt ?? now,
                updatedAt: now
            )
            tasks[task.id.uuidString] = task
            view.session.add(anchor: ARAnchor(name: anchorName(for: task.id), transform: result.worldTransform))
            addedAnchorTaskIds.insert(task.id.uuidString)
            DispatchQueue.main.async { self.onTaskAdded(task) }
            saveWorldMap()
            publish("\(task.title) saved. Keep scanning for a few seconds so iOS can improve the saved AR map.")
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let taskId = taskId(from: anchor.name), let task = tasks[taskId] else { return }
            markerNodesByTaskId[taskId]?.removeFromParentNode()
            let marker = markerNode(for: task)
            marker.name = "marker:\(taskId)"
            markerNodesByTaskId[taskId] = marker
            node.addChildNode(marker)
        }

        func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
            guard let taskId = taskId(from: anchor.name) else { return }
            markerNodesByTaskId[taskId]?.removeFromParentNode()
            markerNodesByTaskId[taskId] = nil
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            switch camera.trackingState {
            case .normal:
                publish("Tracking ready. Saved markers are shown when the site has relocalized.")
            case .limited(let reason):
                publish("Tracking limited: \(reasonText(reason)). Move slowly and scan textured surfaces.")
            case .notAvailable:
                publish("AR tracking is unavailable.")
            }
        }

        func session(_ session: ARSession, didUpdate frame: ARFrame) {
            switch frame.worldMappingStatus {
            case .mapped, .extending:
                guard Date().timeIntervalSince(lastWorldMapSave) > 4 else { return }
                saveWorldMap()
            default:
                break
            }
        }

        func publish(_ text: String) {
            DispatchQueue.main.async { self.onStatus(text) }
        }

        private func saveWorldMap() {
            guard let view else { return }
            lastWorldMapSave = Date()
            view.session.getCurrentWorldMap { worldMap, _ in
                guard let worldMap,
                      let data = try? NSKeyedArchiver.archivedData(withRootObject: worldMap, requiringSecureCoding: true) else { return }
                DispatchQueue.main.async { self.onWorldMapUpdated(data) }
            }
        }

        private func markerNode(for task: SiteTask) -> SCNNode {
            let root = SCNNode()
            let sphere = SCNSphere(radius: 0.07)
            sphere.firstMaterial?.diffuse.contents = color(for: task)
            let sphereNode = SCNNode(geometry: sphere)
            root.addChildNode(sphereNode)

            let text = SCNText(string: task.title, extrusionDepth: 0.5)
            text.font = UIFont.systemFont(ofSize: 5, weight: .bold)
            text.firstMaterial?.diffuse.contents = UIColor.white
            let textNode = SCNNode(geometry: text)
            textNode.scale = SCNVector3(0.008, 0.008, 0.008)
            textNode.position = SCNVector3(0.09, 0.02, 0)
            let constraint = SCNBillboardConstraint()
            constraint.freeAxes = [.Y]
            textNode.constraints = [constraint]
            root.addChildNode(textNode)
            return root
        }

        private func color(for task: SiteTask) -> UIColor {
            switch task.category {
            case "Install AP": return .systemBlue
            case "Run Cable": return .systemOrange
            case "Add Power": return .systemYellow
            case "Blocked Path": return .systemRed
            case "Ceiling Access", "Mount Bracket": return .systemPurple
            default: return .systemGreen
            }
        }

        private func reasonText(_ reason: ARCamera.TrackingState.Reason) -> String {
            switch reason {
            case .excessiveMotion: return "too much motion"
            case .insufficientFeatures: return "not enough visual detail"
            case .initializing: return "initializing"
            case .relocalizing: return "relocalizing"
            @unknown default: return "unknown"
            }
        }

        private func anchorName(for id: UUID) -> String {
            "siteTask:\(id.uuidString)"
        }

        private func taskId(from anchorName: String?) -> String? {
            guard let anchorName, anchorName.hasPrefix("siteTask:") else { return nil }
            return String(anchorName.dropFirst("siteTask:".count))
        }

        private func array(from matrix: simd_float4x4) -> [Double] {
            [matrix.columns.0.x, matrix.columns.0.y, matrix.columns.0.z, matrix.columns.0.w,
             matrix.columns.1.x, matrix.columns.1.y, matrix.columns.1.z, matrix.columns.1.w,
             matrix.columns.2.x, matrix.columns.2.y, matrix.columns.2.z, matrix.columns.2.w,
             matrix.columns.3.x, matrix.columns.3.y, matrix.columns.3.z, matrix.columns.3.w].map(Double.init)
        }

        private func matrix(from values: [Double]) -> simd_float4x4 {
            guard values.count == 16 else { return matrix_identity_float4x4 }
            return simd_float4x4(
                SIMD4<Float>(Float(values[0]), Float(values[1]), Float(values[2]), Float(values[3])),
                SIMD4<Float>(Float(values[4]), Float(values[5]), Float(values[6]), Float(values[7])),
                SIMD4<Float>(Float(values[8]), Float(values[9]), Float(values[10]), Float(values[11])),
                SIMD4<Float>(Float(values[12]), Float(values[13]), Float(values[14]), Float(values[15]))
            )
        }
    }
}
