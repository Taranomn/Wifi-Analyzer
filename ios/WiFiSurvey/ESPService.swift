import Foundation

struct ESPService {
    let host: String

    func status() async throws -> WiFiStatus {
        let (data, _) = try await request(path: "/api/status")
        return try JSONDecoder().decode(WiFiStatus.self, from: data)
    }

    func scan() async throws -> [WiFiNetwork] {
        let (data, _) = try await request(path: "/api/scan", timeout: 20)
        return try JSONDecoder().decode(WiFiScanResponse.self, from: data).networks
    }

    func connect(ssid: String, password: String) async throws {
        let payload = try JSONEncoder().encode(["ssid": ssid, "password": password])
        _ = try await request(path: "/api/connect", method: "POST", body: payload)
    }

    func localSpeedTest() async throws -> Double {
        let start = ContinuousClock.now
        let (data, _) = try await request(path: "/api/speed-test", timeout: 15)
        let elapsed = start.duration(to: .now)
        let seconds = Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18
        guard seconds > 0 else { return 0 }
        return Double(data.count * 8) / seconds / 1_000_000
    }

    func diagnostics() async throws -> NetworkDiagnostics {
        let (data, _) = try await request(path: "/api/diagnostics", timeout: 5)
        return try JSONDecoder().decode(NetworkDiagnostics.self, from: data)
    }

    func responseLatencyMs() async throws -> Int {
        let start = ContinuousClock.now
        _ = try await status()
        let elapsed = start.duration(to: .now)
        return Int(Double(elapsed.components.seconds) * 1000 + Double(elapsed.components.attoseconds) / 1e15)
    }

    func channelAnalysis() async throws -> ChannelAnalysis {
        let (data, _) = try await request(path: "/api/channel-analysis", timeout: 20)
        return try JSONDecoder().decode(ChannelAnalysis.self, from: data)
    }

    func identify() async throws {
        _ = try await request(path: "/api/identify", method: "POST")
    }

    func startPlanning() async throws -> PlanningStatus {
        let (data, _) = try await request(path: "/api/planning/start", method: "POST")
        return try JSONDecoder().decode(PlanningStatus.self, from: data)
    }

    func joinPlanning(ssid: String, coordinatorIp: String) async throws {
        let payload = try JSONEncoder().encode(["ssid": ssid, "coordinatorIp": coordinatorIp])
        _ = try await request(path: "/api/planning/join", method: "POST", body: payload)
    }

    func planningStatus() async throws -> PlanningStatus {
        let (data, _) = try await request(path: "/api/planning/status")
        return try JSONDecoder().decode(PlanningStatus.self, from: data)
    }

    func stopPlanning() async throws {
        _ = try await request(path: "/api/planning/stop", method: "POST")
    }

    private func request(path: String, method: String = "GET", body: Data? = nil, timeout: TimeInterval = 4) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: "http://\(host)\(path)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = timeout
        request.httpBody = body
        if body != nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
