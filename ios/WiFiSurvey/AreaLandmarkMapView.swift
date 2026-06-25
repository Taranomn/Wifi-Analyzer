import SwiftUI

enum AreaMapAction {
    case viewDetails
    case recordESPMeasurement
    case analyzeWithIPhone
    case assignActiveESP
}

struct AreaLandmarkMapView: View {
    let buildingFloors: [BuildingFloor]
    let landmarks: [AreaLandmark]
    let points: [SurveyPoint]
    let devices: [SurveyDevice]
    let phoneTester: PhoneTesterStatus
    var phoneResults: [PhoneNetworkSample] = []
    var onAction: ((AreaLandmark, AreaMapAction) -> Void)? = nil
    @Binding var selectedAreaId: UUID?
    @State private var selectedFloor = 0

    private var floors: [(floor: BuildingFloor, landmarks: [AreaLandmark])] {
        buildingFloors.sorted { $0.order < $1.order }.map { floor in
            (floor, landmarks.filter { $0.floorId == floor.id && $0.isMapped })
        }
    }

    private var activeFloor: [AreaLandmark] {
        guard floors.indices.contains(selectedFloor) else { return floors.first?.landmarks ?? [] }
        return floors[selectedFloor].landmarks
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button {
                    selectedFloor = max(selectedFloor - 1, 0)
                    selectFirstAreaOnFloor()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .disabled(selectedFloor == 0)

                Spacer()
                VStack(spacing: 2) {
                    Text(floors.indices.contains(selectedFloor) ? floors[selectedFloor].floor.name : "Floor")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(floorHeightText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.62))
                }
                Spacer()

                Button {
                    selectedFloor = min(selectedFloor + 1, max(floors.count - 1, 0))
                    selectFirstAreaOnFloor()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .disabled(selectedFloor >= floors.count - 1)
            }
            .padding(.horizontal, 14)
            .frame(height: 48)
            .foregroundStyle(.white)

            GeometryReader { proxy in
                ZStack {
                    Canvas { context, size in
                        drawGrid(context, size)
                        drawAlignmentReferences(context, size)
                        drawConnections(context, size)
                        for landmark in activeFloor {
                            drawLandmark(landmark, context, size)
                        }
                    }
                    .contentShape(Rectangle())
                    .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                        selectedAreaId = activeFloor.min(by: {
                            distance(screenPoint($0, proxy.size), value.location) < distance(screenPoint($1, proxy.size), value.location)
                        })?.id
                    })

                    ForEach(activeFloor) { landmark in
                        let center = screenPoint(landmark, proxy.size)
                        Button {
                            selectedAreaId = landmark.id
                            onAction?(landmark, .viewDetails)
                        } label: {
                            Circle()
                                .fill(.clear)
                                .frame(width: 72, height: 72)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .position(center)
                        .contextMenu {
                            Button {
                                selectedAreaId = landmark.id
                                onAction?(landmark, .viewDetails)
                            } label: {
                                Label("View Area Details", systemImage: "info.circle")
                            }
                            Button {
                                selectedAreaId = landmark.id
                                onAction?(landmark, .analyzeWithIPhone)
                            } label: {
                                Label("Analyze with iPhone", systemImage: "iphone.radiowaves.left.and.right")
                            }
                            Button {
                                selectedAreaId = landmark.id
                                onAction?(landmark, .recordESPMeasurement)
                            } label: {
                                Label("Record ESP Measurement", systemImage: "plus.circle")
                            }
                            Button {
                                selectedAreaId = landmark.id
                                onAction?(landmark, .assignActiveESP)
                            } label: {
                                Label("Assign Active ESP", systemImage: "memorychip")
                            }
                        }
                    }
                }
            }
        }
        .frame(minHeight: 380)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
        }
        .onAppear { selectFloorContainingSelection() }
        .onChange(of: landmarks.map(\.id)) { _, _ in
            selectedFloor = min(selectedFloor, max(floors.count - 1, 0))
        }
    }

    private var floorHeightText: String {
        guard let height = activeFloor.first?.y, let base = floors.first?.landmarks.first?.y else { return "No areas" }
        return String(format: "%+.1f m from lowest floor", height - base)
    }

    private func selectFloorContainingSelection() {
        guard let selectedAreaId,
              let index = floors.firstIndex(where: { floor in floor.landmarks.contains(where: { $0.id == selectedAreaId }) }) else { return }
        selectedFloor = index
    }

    private func selectFirstAreaOnFloor() {
        if let first = activeFloor.first { selectedAreaId = first.id }
    }

    private func drawAlignmentReferences(_ context: GraphicsContext, _ size: CGSize) {
        for (floorIndex, floor) in floors.enumerated() where floorIndex != selectedFloor {
            for landmark in floor.landmarks {
                let center = screenPoint(landmark, size)
                let outline = Path(ellipseIn: CGRect(x: center.x - 13, y: center.y - 13, width: 26, height: 26))
                context.stroke(outline, with: .color(.secondary.opacity(0.25)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                context.draw(
                    Text(floorIndex > selectedFloor ? "↑\(floorIndex + 1)" : "↓\(floorIndex + 1)")
                        .font(.caption2).foregroundStyle(.secondary.opacity(0.55)),
                    at: center
                )
            }
        }
    }

    private func drawConnections(_ context: GraphicsContext, _ size: CGSize) {
        guard activeFloor.count > 1 else { return }
        for index in 1..<activeFloor.count {
            let first = activeFloor[index - 1]
            let second = activeFloor[index]
            let start = screenPoint(first, size)
            let end = screenPoint(second, size)
            var path = Path()
            path.move(to: start)
            path.addLine(to: end)
            context.stroke(path, with: .color(.secondary.opacity(0.5)), style: StrokeStyle(lineWidth: 2, dash: [6, 5]))
            context.draw(
                Text(String(format: "%.1f m", first.distance(to: second))).font(.caption2),
                at: CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 10)
            )
        }
    }

    private func drawLandmark(_ landmark: AreaLandmark, _ context: GraphicsContext, _ size: CGSize) {
        let center = screenPoint(landmark, size)
        let score = areaScore(landmark)
        let quality = score.map(ProfessionalScore.label) ?? "Unavailable"
        let selected = selectedAreaId == landmark.id
        let radius: CGFloat = selected ? 30 : 24
        let circle = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.fill(circle, with: .color(qualityColor(quality).opacity(0.88)))
        context.stroke(circle, with: .color(selected ? .blue : .white), lineWidth: selected ? 4 : 2)
        if let score {
            context.draw(Text("\(score)").font(.title3.bold()).foregroundStyle(.white), at: center)
        }
        context.draw(Text(landmark.name).font(.caption.bold()), at: CGPoint(x: center.x, y: center.y + radius + 14))
        let testerCount = landmark.assignedNodeIds.count + (latestPhoneResult(landmark) == nil ? 0 : 1)
        context.draw(Text("\(testerCount) testers").font(.caption2), at: CGPoint(x: center.x, y: center.y + radius + 29))
    }

    private func areaScore(_ landmark: AreaLandmark) -> Int? {
        let assigned = devices.filter { landmark.assignedNodeIds.contains($0.nodeId) && $0.connected }
        var scores = assigned.map(ProfessionalScore.device)
        if let phone = latestPhoneResult(landmark) {
            scores.append(ProfessionalScore.phone(phone))
        }
        guard !scores.isEmpty else { return nil }
        return scores.reduce(0, +) / scores.count
    }

    private func latestPhoneResult(_ landmark: AreaLandmark) -> PhoneNetworkSample? {
        phoneResults.filter { $0.areaId == landmark.id }.max { $0.timestamp < $1.timestamp }
    }

    private func screenPoint(_ landmark: AreaLandmark, _ size: CGSize) -> CGPoint {
        // All floors use global building bounds so vertically aligned areas never shift between floors.
        let xs = landmarks.map(\.x)
        let zs = landmarks.map(\.z)
        let minX = (xs.min() ?? 0) - 1
        let maxX = (xs.max() ?? 1) + 1
        let minZ = (zs.min() ?? 0) - 1
        let maxZ = (zs.max() ?? 1) + 1
        let frame = CGRect(x: 30, y: 20, width: max(size.width - 60, 1), height: max(size.height - 50, 1))
        return CGPoint(
            x: frame.minX + CGFloat((landmark.x - minX) / max(maxX - minX, 1)) * frame.width,
            y: frame.minY + CGFloat((landmark.z - minZ) / max(maxZ - minZ, 1)) * frame.height
        )
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    private func drawGrid(_ context: GraphicsContext, _ size: CGSize) {
        for step in 0...10 {
            let fraction = CGFloat(step) / 10
            var vertical = Path()
            vertical.move(to: CGPoint(x: size.width * fraction, y: 0))
            vertical.addLine(to: CGPoint(x: size.width * fraction, y: size.height))
            context.stroke(vertical, with: .color(.gray.opacity(0.1)), lineWidth: 1)
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: 0, y: size.height * fraction))
            horizontal.addLine(to: CGPoint(x: size.width, y: size.height * fraction))
            context.stroke(horizontal, with: .color(.gray.opacity(0.1)), lineWidth: 1)
        }
    }

    private func qualityColor(_ label: String) -> Color {
        switch label {
        case "Excellent": return .green
        case "Good": return Color(red: 0.45, green: 0.75, blue: 0.20)
        case "Fair": return .yellow
        case "Weak": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}
