import ARKit
import SwiftUI

struct WalkTraceView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var markToken = 0
    @State private var finishToken = 0
    @State private var undoToken = 0
    @State private var pointCount = 0
    @State private var status = "Move the phone slowly until tracking is ready."

    var body: some View {
        ZStack(alignment: .bottom) {
            ARTraceContainer(markToken: markToken, undoToken: undoToken, finishToken: finishToken) { count, text in
                pointCount = count
                status = text
            } onComplete: { points in
                store.accept(tracePoints: points)
                dismiss()
            }
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text(pointCount == 0
                     ? "Stand at the first corner and mark it. Walk around the perimeter in order."
                     : "\(pointCount) corners marked. Move to the next corner.")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)

                HStack {
                    Button {
                        undoToken += 1
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(pointCount == 0)

                    Button {
                        markToken += 1
                    } label: {
                        Label("Mark Corner", systemImage: "mappin.and.ellipse")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    finishToken += 1
                } label: {
                    Label("Finish Perimeter", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .controlSize(.large)
                Button("Cancel", role: .destructive) { dismiss() }
            }
            .padding()
        }
    }
}

private struct ARTraceContainer: UIViewRepresentable {
    let markToken: Int
    let undoToken: Int
    let finishToken: Int
    let onUpdate: (Int, String) -> Void
    let onComplete: ([CGPoint]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onUpdate: onUpdate, onComplete: onComplete)
    }

    func makeUIView(context: Context) -> ARSCNView {
        let view = ARSCNView(frame: .zero)
        view.session.delegate = context.coordinator
        view.automaticallyUpdatesLighting = true
        view.debugOptions = [.showFeaturePoints]
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        view.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        context.coordinator.view = view
        return view
    }

    func updateUIView(_ view: ARSCNView, context: Context) {
        if context.coordinator.lastMarkToken != markToken {
            context.coordinator.lastMarkToken = markToken
            if markToken > 0 { context.coordinator.markCorner() }
        }
        if context.coordinator.lastUndoToken != undoToken {
            context.coordinator.lastUndoToken = undoToken
            if undoToken > 0 { context.coordinator.undo() }
        }
        if context.coordinator.lastFinishToken != finishToken {
            context.coordinator.lastFinishToken = finishToken
            if finishToken > 0 { context.coordinator.finish() }
        }
    }

    final class Coordinator: NSObject, ARSessionDelegate {
        weak var view: ARSCNView?
        var points: [CGPoint] = []
        var lastMarkToken = 0
        var lastUndoToken = 0
        var lastFinishToken = 0
        let onUpdate: (Int, String) -> Void
        let onComplete: ([CGPoint]) -> Void

        init(onUpdate: @escaping (Int, String) -> Void, onComplete: @escaping ([CGPoint]) -> Void) {
            self.onUpdate = onUpdate
            self.onComplete = onComplete
        }

        func markCorner() {
            guard let frame = view?.session.currentFrame else {
                onUpdate(points.count, "Camera tracking is starting. Try again in a moment.")
                return
            }
            let position = frame.camera.transform.columns.3
            points.append(CGPoint(x: CGFloat(position.x), y: CGFloat(position.z)))
            addMarker(at: SIMD3<Float>(position.x, position.y - 0.5, position.z))
            onUpdate(points.count, points.count >= 3 ? "Ready to finish, or mark more corners." : "Corner saved. Walk to the next corner.")
        }

        func undo() {
            guard !points.isEmpty else { return }
            points.removeLast()
            view?.scene.rootNode.childNodes.last?.removeFromParentNode()
            onUpdate(points.count, "Last corner removed.")
        }

        func finish() {
            guard points.count >= 3 else {
                onUpdate(points.count, "Mark at least three corners before finishing.")
                return
            }
            view?.session.pause()
            onComplete(points)
        }

        func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
            let text: String
            switch camera.trackingState {
            case .normal: text = "Tracking ready. Mark the corner when you are standing at it."
            case .limited: text = "Tracking is limited, but you can still mark corners. Move slowly."
            case .notAvailable: text = "Camera tracking is unavailable."
            }
            DispatchQueue.main.async { self.onUpdate(self.points.count, text) }
        }

        private func addMarker(at position: SIMD3<Float>) {
            let sphere = SCNSphere(radius: 0.06)
            sphere.firstMaterial?.diffuse.contents = UIColor.systemBlue
            let node = SCNNode(geometry: sphere)
            node.simdPosition = position
            view?.scene.rootNode.addChildNode(node)
        }
    }
}
