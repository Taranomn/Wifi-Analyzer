import ARKit
import SwiftUI

struct ARWallScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var finishToken = 0
    @State private var wallCount = 0
    @State private var status = "Move slowly and point the camera at each wall."

    var body: some View {
        ZStack(alignment: .bottom) {
            ARWallCaptureContainer(finishToken: finishToken) { count, text in
                wallCount = count
                status = text
            } onComplete: { walls in
                store.accept(detectedWalls: walls)
                dismiss()
            }
            .ignoresSafeArea()

            VStack(spacing: 12) {
                VStack(spacing: 4) {
                    Text("\(wallCount) walls detected")
                        .font(.headline)
                    Text(status)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                HStack {
                    Button("Cancel") { dismiss() }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    Button {
                        finishToken += 1
                    } label: {
                        Label("Finish Room Scan", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
    }
}

private struct ARWallCaptureContainer: UIViewRepresentable {
    let finishToken: Int
    let onUpdate: (Int, String) -> Void
    let onComplete: ([WallSegment]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUpdate: onUpdate, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = context.coordinator
        view.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.debugOptions = [.showFeaturePoints]
        context.coordinator.view = view

        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        configuration.planeDetection = [.vertical]
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        guard context.coordinator.lastFinishToken != finishToken else { return }
        context.coordinator.lastFinishToken = finishToken
        if finishToken > 0 { context.coordinator.finish() }
    }

    final class Coordinator: NSObject, ARSessionDelegate, ARSCNViewDelegate {
        weak var view: ARSCNView?
        var anchors: [UUID: ARPlaneAnchor] = [:]
        var lastFinishToken = 0
        let onUpdate: (Int, String) -> Void
        let onComplete: ([WallSegment]) -> Void

        init(onUpdate: @escaping (Int, String) -> Void, onComplete: @escaping ([WallSegment]) -> Void) {
            self.onUpdate = onUpdate
            self.onComplete = onComplete
        }

        func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
            update(anchors)
        }

        func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
            update(anchors)
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let text: String
            switch camera.trackingState {
            case .normal: text = "Tracking ready. Sweep each wall from side to side."
            case .limited: text = "Move slowly and keep textured surfaces in view."
            case .notAvailable: text = "Camera tracking is unavailable."
            }
            DispatchQueue.main.async { self.onUpdate(self.anchors.count, text) }
        }

        func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
            guard let plane = anchor as? ARPlaneAnchor, plane.alignment == .vertical else { return }
            let geometry = SCNPlane(width: CGFloat(plane.planeExtent.width), height: CGFloat(plane.planeExtent.height))
            geometry.firstMaterial?.diffuse.contents = UIColor.systemBlue.withAlphaComponent(0.22)
            geometry.firstMaterial?.isDoubleSided = true
            let planeNode = SCNNode(geometry: geometry)
            planeNode.eulerAngles.x = -.pi / 2
            node.addChildNode(planeNode)
        }

        func finish() {
            let walls = anchors.values.compactMap(Self.wallSegment)
            guard walls.count >= 2 else {
                onUpdate(walls.count, "Keep scanning until at least two walls are detected.")
                return
            }
            view?.session.pause()
            onComplete(walls)
        }

        private func update(_ incoming: [ARAnchor]) {
            for case let plane as ARPlaneAnchor in incoming where plane.alignment == .vertical {
                anchors[plane.identifier] = plane
            }
            DispatchQueue.main.async {
                self.onUpdate(self.anchors.count, "Sweep slowly across the next wall.")
            }
        }

        private static func wallSegment(_ plane: ARPlaneAnchor) -> WallSegment? {
            let width = Double(plane.planeExtent.width)
            guard width > 0.25 else { return nil }
            let transform = plane.transform
            let centerX = Double(transform.columns.3.x)
            let centerY = Double(transform.columns.3.z)
            let directionX = Double(transform.columns.0.x)
            let directionY = Double(transform.columns.0.z)
            let magnitude = max(hypot(directionX, directionY), 0.0001)
            let dx = directionX / magnitude * width / 2
            let dy = directionY / magnitude * width / 2
            return WallSegment(id: UUID(), startX: centerX - dx, startY: centerY - dy, endX: centerX + dx, endY: centerY + dy)
        }
    }
}
