import ARKit
import SwiftUI

struct AreaLandmarkCaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var areaName = ""
    @State private var selectedFloorId: UUID?
    @State private var markRequest: LandmarkMarkRequest?
    @State private var finishToken = 0
    @State private var landmarks: [AreaLandmark] = []
    @State private var pendingMarkName: String?
    @State private var status = "Move slowly until tracking is ready."
    private let accent = Color(red: 0.08, green: 0.82, blue: 0.95)
    private let primary = Color(red: 0.22, green: 0.43, blue: 1.0)
    private let panel = Color.white.opacity(0.10)

    var body: some View {
        ZStack {
            AreaLandmarkCaptureContainer(markRequest: markRequest, finishToken: finishToken) { spots, text in
                if spots.count > landmarks.count, spots.last?.name == pendingMarkName {
                    areaName = ""
                    pendingMarkName = nil
                }
                landmarks = spots
                status = text
            } onComplete: { spots in
                store.accept(areaLandmarks: spots)
                dismiss()
            }
            .ignoresSafeArea()

            Image(systemName: "plus")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white)
                .shadow(radius: 3)

            VStack {
                VStack(spacing: 5) {
                    Text("\(landmarks.count) areas marked")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(status)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.68))
                }
                .frame(maxWidth: .infinity)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .background(panel, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
                Spacer()

                VStack(spacing: 10) {
                    HStack {
                        Picker("Floor", selection: $selectedFloorId) {
                            ForEach(store.buildingFloors) { floor in
                                Text(floor.name).tag(Optional(floor.id))
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(.white)
                        Spacer()
                        Button {
                            selectedFloorId = store.addFloor().id
                        } label: {
                            Image(systemName: "plus")
                        }
                        .accessibilityLabel("Add floor")
                        .foregroundStyle(accent)
                    }
                    TextField("Area name, for example Kitchen", text: $areaName)
                        .padding(13)
                        .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundStyle(.white)
                    Button {
                        let trimmed = areaName.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty else { return }
                        guard let selectedFloorId else { return }
                        pendingMarkName = trimmed
                        markRequest = LandmarkMarkRequest(id: UUID(), name: trimmed, floorId: selectedFloorId)
                    } label: {
                        Label("Mark Area at Reticle", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 14)
                    .background(LinearGradient(colors: [primary, accent], startPoint: .leading, endPoint: .trailing), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .foregroundStyle(.white)
                    .controlSize(.large)
                    .disabled(areaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(areaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                    HStack {
                        Button("Cancel", role: .destructive) { dismiss() }
                            .foregroundStyle(Color(red: 1.0, green: 0.23, blue: 0.32))
                        Spacer()
                        Button {
                            finishToken += 1
                        } label: {
                            Label("Finish Map", systemImage: "checkmark.circle.fill")
                        }
                        .foregroundStyle(landmarks.isEmpty ? .white.opacity(0.35) : Color(red: 0.20, green: 0.86, blue: 0.48))
                        .disabled(landmarks.isEmpty)
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .background(panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                }
            }
            .padding()
        }
        .preferredColorScheme(.dark)
        .onAppear { selectedFloorId = selectedFloorId ?? store.buildingFloors.first?.id }
    }
}

private struct LandmarkMarkRequest: Equatable {
    let id: UUID
    let name: String
    let floorId: UUID
}

private struct AreaLandmarkCaptureContainer: UIViewRepresentable {
    let markRequest: LandmarkMarkRequest?
    let finishToken: Int
    let onUpdate: ([AreaLandmark], String) -> Void
    let onComplete: ([AreaLandmark]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUpdate: onUpdate, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.debugOptions = [.showFeaturePoints]
        context.coordinator.view = view
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.horizontal]
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        if let markRequest, markRequest.id != context.coordinator.lastMarkId {
            context.coordinator.lastMarkId = markRequest.id
            context.coordinator.mark(name: markRequest.name, floorId: markRequest.floorId)
        }
        if finishToken != context.coordinator.lastFinishToken {
            context.coordinator.lastFinishToken = finishToken
            if finishToken > 0 { context.coordinator.finish() }
        }
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var view: ARSCNView?
        var landmarks: [AreaLandmark] = []
        var lastMarkId: UUID?
        var lastFinishToken = 0
        let onUpdate: ([AreaLandmark], String) -> Void
        let onComplete: ([AreaLandmark]) -> Void

        init(onUpdate: @escaping ([AreaLandmark], String) -> Void, onComplete: @escaping ([AreaLandmark]) -> Void) {
            self.onUpdate = onUpdate
            self.onComplete = onComplete
        }

        func mark(name: String, floorId: UUID) {
            guard let view else { return }
            let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
            let query = view.raycastQuery(from: center, allowing: .estimatedPlane, alignment: .horizontal)
            guard let query, let result = view.session.raycast(query).first else {
                publishUpdate("Aim the reticle at a visible section of floor and try again.")
                return
            }
            let position = result.worldTransform.columns.3
            let landmark = AreaLandmark(
                id: UUID(), name: name, x: Double(position.x), y: Double(position.y),
                z: Double(position.z), floorId: floorId, assignedNodeIds: []
            )
            landmarks.append(landmark)
            addMarker(at: SIMD3<Float>(position.x, position.y, position.z))
            let distanceText: String
            if landmarks.count > 1 {
                distanceText = String(format: " %.1f m from %@.", landmarks[landmarks.count - 2].distance(to: landmark), landmarks[landmarks.count - 2].name)
            } else {
                distanceText = ""
            }
            publishUpdate("\(name) saved.\(distanceText) Walk to the next area without closing this screen.")
        }

        func finish() {
            guard !landmarks.isEmpty else { return }
            view?.session.pause()
            let result = landmarks
            DispatchQueue.main.async { self.onComplete(result) }
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let text: String
            switch camera.trackingState {
            case .normal: text = "Tracking ready. Aim the reticle at the middle of the area's floor."
            case .limited: text = "Move slowly and keep the camera pointed at textured surfaces."
            case .notAvailable: text = "Camera tracking is unavailable."
            }
            publishUpdate(text)
        }

        private func publishUpdate(_ text: String) {
            let result = landmarks
            DispatchQueue.main.async { self.onUpdate(result, text) }
        }

        private func addMarker(at position: SIMD3<Float>) {
            let cylinder = SCNCylinder(radius: 0.12, height: 0.02)
            cylinder.firstMaterial?.diffuse.contents = UIColor.systemBlue
            let node = SCNNode(geometry: cylinder)
            node.simdPosition = position
            view?.scene.rootNode.addChildNode(node)
        }
    }
}
