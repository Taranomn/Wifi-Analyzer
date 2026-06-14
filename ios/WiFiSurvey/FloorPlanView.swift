import SwiftUI

struct HomeMapView: View {
    let map: HomeMap
    let points: [SurveyPoint]
    let liveStatus: BLEDeviceStatus?
    @Binding var selectedRoomId: UUID?
    @Binding var selection: CGPoint?
    var interactive = true

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawGrid(context: context, size: size)
                for room in map.rooms {
                    drawRoom(room, context: context, size: size)
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                guard interactive, let room = room(at: value.location, size: proxy.size) else { return }
                selectedRoomId = room.id
                let frame = drawingFrame(size: proxy.size)
                let worldX = map.minX + Double((value.location.x - frame.minX) / frame.width) * map.width
                let worldY = map.minY + Double((value.location.y - frame.minY) / frame.height) * map.height
                selection = CGPoint(
                    x: min(max((worldX - room.offsetX) / room.plan.width, 0), 1),
                    y: min(max((worldY - room.offsetY) / room.plan.height, 0), 1)
                )
            })
        }
        .aspectRatio(max(map.width / map.height, 0.65), contentMode: .fit)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func drawRoom(_ room: HomeRoom, context: GraphicsContext, size: CGSize) {
        let roomRect = CGRect(
            origin: screenPoint(x: room.minX, y: room.minY, size: size),
            size: CGSize(
                width: CGFloat(room.plan.width / map.width) * drawingFrame(size: size).width,
                height: CGFloat(room.plan.height / map.height) * drawingFrame(size: size).height
            )
        )
        let quality = roomQuality(room)
        context.fill(Path(roomRect), with: .color(qualityColor(quality).opacity(0.18)))
        if room.id == selectedRoomId {
            context.stroke(Path(roomRect.insetBy(dx: -4, dy: -4)), with: .color(.blue), style: StrokeStyle(lineWidth: 2, dash: [7, 5]))
        }

        for wall in room.plan.walls {
            var path = Path()
            path.move(to: wallPoint(room, x: wall.startX, y: wall.startY, size: size))
            path.addLine(to: wallPoint(room, x: wall.endX, y: wall.endY, size: size))
            context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 4, lineCap: .round))
        }

        context.draw(
            Text(room.name).font(.caption.bold()),
            at: CGPoint(x: roomRect.midX, y: roomRect.minY + 14)
        )
        if quality != "Unavailable" {
            context.draw(
                Text(quality).font(.caption2),
                at: CGPoint(x: roomRect.midX, y: roomRect.minY + 30)
            )
        }

        let roomPoints = points.filter { $0.roomId == room.id || ($0.roomId == nil && $0.roomName == room.name) }
        for point in roomPoints {
            drawMarker(room: room, point: CGPoint(x: point.x, y: point.y), color: qualityColor(point.qualityLabel), label: "\(point.rssi)", context: context, size: size)
        }
        if room.id == selectedRoomId, let selection {
            drawMarker(room: room, point: selection, color: .blue, label: "Here", context: context, size: size)
        }
    }

    private func roomQuality(_ room: HomeRoom) -> String {
        if let liveStatus, room.assignedNodeIds.contains(liveStatus.nodeId), liveStatus.connected {
            return liveStatus.qualityLabel
        }
        return points.last(where: { $0.roomId == room.id || ($0.roomId == nil && $0.roomName == room.name) })?.qualityLabel ?? "Unavailable"
    }

    private func drawMarker(room: HomeRoom, point: CGPoint, color: Color, label: String, context: GraphicsContext, size: CGSize) {
        let center = screenPoint(
            x: room.offsetX + Double(point.x) * room.plan.width,
            y: room.offsetY + Double(point.y) * room.plan.height,
            size: size
        )
        let circle = Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14))
        context.fill(circle, with: .color(color))
        context.stroke(circle, with: .color(.white), lineWidth: 2)
        context.draw(Text(label).font(.caption2.bold()), at: CGPoint(x: center.x + 22, y: center.y))
    }

    private func room(at point: CGPoint, size: CGSize) -> HomeRoom? {
        let frame = drawingFrame(size: size)
        let worldX = map.minX + Double((point.x - frame.minX) / frame.width) * map.width
        let worldY = map.minY + Double((point.y - frame.minY) / frame.height) * map.height
        return map.rooms.reversed().first { worldX >= $0.minX && worldX <= $0.maxX && worldY >= $0.minY && worldY <= $0.maxY }
    }

    private func wallPoint(_ room: HomeRoom, x: Double, y: Double, size: CGSize) -> CGPoint {
        screenPoint(x: room.offsetX + x - room.plan.minX, y: room.offsetY + y - room.plan.minY, size: size)
    }

    private func screenPoint(x: Double, y: Double, size: CGSize) -> CGPoint {
        let frame = drawingFrame(size: size)
        return CGPoint(
            x: frame.minX + CGFloat((x - map.minX) / map.width) * frame.width,
            y: frame.minY + CGFloat((y - map.minY) / map.height) * frame.height
        )
    }

    private func drawingFrame(size: CGSize) -> CGRect {
        CGRect(x: 18, y: 18, width: max(size.width - 36, 1), height: max(size.height - 36, 1))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let frame = drawingFrame(size: size)
        for step in 0...10 {
            let fraction = CGFloat(step) / 10
            var vertical = Path()
            vertical.move(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY))
            vertical.addLine(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY))
            context.stroke(vertical, with: .color(.gray.opacity(0.12)), lineWidth: 1)
            var horizontal = Path()
            horizontal.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction))
            horizontal.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction))
            context.stroke(horizontal, with: .color(.gray.opacity(0.12)), lineWidth: 1)
        }
    }

    private func qualityColor(_ label: String) -> Color {
        switch label {
        case "Excellent": return .green
        case "Good": return Color(red: 0.25, green: 0.58, blue: 0.18)
        case "Fair": return .orange
        case "Weak": return Color(red: 0.85, green: 0.35, blue: 0.08)
        case "Very Weak": return .red
        default: return .gray
        }
    }
}

struct FloorPlanView: View {
    let plan: FloorPlan
    let points: [SurveyPoint]
    @Binding var selection: CGPoint?
    var interactive = true

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                drawGrid(context: context, size: size)
                for wall in plan.walls {
                    var path = Path()
                    path.move(to: screenPoint(x: wall.startX, y: wall.startY, size: size))
                    path.addLine(to: screenPoint(x: wall.endX, y: wall.endY, size: size))
                    context.stroke(path, with: .color(.primary), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                }
                for (index, point) in points.enumerated() {
                    drawPoint(context: context, size: size, point: CGPoint(x: point.x, y: point.y), color: qualityColor(point.qualityLabel), label: "\(index + 1)")
                }
                if let selection {
                    drawPoint(context: context, size: size, point: selection, color: .blue, label: "Here")
                }
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onEnded { value in
                guard interactive else { return }
                let frame = drawingFrame(size: proxy.size)
                selection = CGPoint(
                    x: min(max((value.location.x - frame.minX) / frame.width, 0), 1),
                    y: min(max((value.location.y - frame.minY) / frame.height, 0), 1)
                )
            })
        }
        .aspectRatio(max(plan.width / plan.height, 0.65), contentMode: .fit)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.quaternary))
    }

    private func drawingFrame(size: CGSize) -> CGRect {
        CGRect(x: 18, y: 18, width: max(size.width - 36, 1), height: max(size.height - 36, 1))
    }

    private func screenPoint(x: Double, y: Double, size: CGSize) -> CGPoint {
        let frame = drawingFrame(size: size)
        return CGPoint(
            x: frame.minX + ((x - plan.minX) / plan.width) * frame.width,
            y: frame.minY + ((y - plan.minY) / plan.height) * frame.height
        )
    }

    private func drawPoint(context: GraphicsContext, size: CGSize, point: CGPoint, color: Color, label: String) {
        let frame = drawingFrame(size: size)
        let center = CGPoint(x: frame.minX + point.x * frame.width, y: frame.minY + point.y * frame.height)
        let circle = Path(ellipseIn: CGRect(x: center.x - 8, y: center.y - 8, width: 16, height: 16))
        context.fill(circle, with: .color(color))
        context.stroke(circle, with: .color(.white), lineWidth: 2)
        context.draw(Text(label).font(.caption2.bold()), at: CGPoint(x: center.x + 20, y: center.y))
    }

    private func drawGrid(context: GraphicsContext, size: CGSize) {
        let frame = drawingFrame(size: size)
        for step in 0...10 {
            let fraction = CGFloat(step) / 10
            var vertical = Path()
            vertical.move(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.minY))
            vertical.addLine(to: CGPoint(x: frame.minX + frame.width * fraction, y: frame.maxY))
            context.stroke(vertical, with: .color(.gray.opacity(0.12)), lineWidth: 1)

            var horizontal = Path()
            horizontal.move(to: CGPoint(x: frame.minX, y: frame.minY + frame.height * fraction))
            horizontal.addLine(to: CGPoint(x: frame.maxX, y: frame.minY + frame.height * fraction))
            context.stroke(horizontal, with: .color(.gray.opacity(0.12)), lineWidth: 1)
        }
    }

    private func qualityColor(_ label: String) -> Color {
        switch label {
        case "Excellent": return .green
        case "Good": return Color(red: 0.25, green: 0.58, blue: 0.18)
        case "Fair": return .orange
        case "Weak": return Color(red: 0.85, green: 0.35, blue: 0.08)
        default: return .red
        }
    }
}
