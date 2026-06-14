import RoomPlan
import SwiftUI

struct RoomScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SurveyStore
    @State private var stopToken = 0
    @State private var isFinishing = false

    var body: some View {
        ZStack(alignment: .bottom) {
            RoomCaptureContainer(stopToken: stopToken) { room in
                store.accept(room: room)
                dismiss()
            } onError: { error in
                store.message = error.localizedDescription
                dismiss()
            }
            .ignoresSafeArea()

            VStack(spacing: 10) {
                Text("Slowly point the camera at every wall, doorway, and corner.")
                    .font(.footnote.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(12)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))

                Button {
                    isFinishing = true
                    stopToken += 1
                } label: {
                    Label(isFinishing ? "Building floor plan..." : "Finish Scan", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isFinishing)
            }
            .padding()
        }
    }
}

private struct RoomCaptureContainer: UIViewControllerRepresentable {
    let stopToken: Int
    let onComplete: (CapturedRoom) -> Void
    let onError: (Error) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete, onError: onError)
    }

    func makeUIViewController(context: Context) -> CaptureController {
        let controller = CaptureController()
        controller.coordinator = context.coordinator
        context.coordinator.captureView = controller.captureView
        controller.captureView.captureSession.delegate = context.coordinator
        controller.captureView.delegate = context.coordinator
        controller.start()
        return controller
    }

    func updateUIViewController(_ controller: CaptureController, context: Context) {
        guard context.coordinator.lastStopToken != stopToken else { return }
        context.coordinator.lastStopToken = stopToken
        if stopToken > 0 { controller.stop() }
    }

    @objc(WiFiSurveyRoomCaptureCoordinator)
    final class Coordinator: NSObject, RoomCaptureViewDelegate, RoomCaptureSessionDelegate {
        var captureView: RoomCaptureView?
        var lastStopToken = 0
        let onComplete: (CapturedRoom) -> Void
        let onError: (Error) -> Void

        init(onComplete: @escaping (CapturedRoom) -> Void, onError: @escaping (Error) -> Void) {
            self.onComplete = onComplete
            self.onError = onError
        }

        required init?(coder: NSCoder) {
            return nil
        }

        func encode(with coder: NSCoder) {}

        func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: Error?) -> Bool {
            if let error { onError(error) }
            return error == nil
        }

        func captureView(didPresent processedResult: CapturedRoom, error: Error?) {
            if let error {
                onError(error)
            } else {
                onComplete(processedResult)
            }
        }
    }
}

private final class CaptureController: UIViewController {
    let captureView = RoomCaptureView(frame: .zero)
    weak var coordinator: RoomCaptureContainer.Coordinator?

    override func viewDidLoad() {
        super.viewDidLoad()
        captureView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(captureView)
        NSLayoutConstraint.activate([
            captureView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            captureView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            captureView.topAnchor.constraint(equalTo: view.topAnchor),
            captureView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    func start() {
        captureView.captureSession.run(configuration: RoomCaptureSession.Configuration())
    }

    func stop() {
        captureView.captureSession.stop()
    }
}
