#include <Arduino.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <NimBLEDevice.h>
#include <ESP32Ping.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <WebServer.h>
#include <WiFi.h>

namespace {

constexpr char kSetupSsid[] = "WiFi-Survey-Setup";
constexpr char kPreferencesNamespace[] = "wifi-survey";
constexpr uint32_t kConnectTimeoutMs = 15000;
constexpr uint8_t kIdentifyLedPin = 2;
constexpr char kBleServiceUuid[] = "7a1f0001-8d79-4f25-bc40-5c7d17f62a11";
constexpr char kBleCommandUuid[] = "7a1f0002-8d79-4f25-bc40-5c7d17f62a11";
constexpr char kBleEventUuid[] = "7a1f0003-8d79-4f25-bc40-5c7d17f62a11";

WebServer server(80);
Preferences preferences;
String savedSsid;
String savedPassword;
String nodeId;
uint32_t bootMillis;
uint32_t connectStartedAt;
bool connectionPending = false;
bool bleScanRequested = false;
bool blePairRequested = false;
bool bleStatusRequested = false;
bool bleConnectRequested = false;
bool bleDiagnosticsRequested = false;
uint32_t identifyUntil = 0;
uint32_t lastIdentifyToggle = 0;
bool identifyLedOn = false;
bool planningCoordinator = false;
bool planningJoinPending = false;
bool planningReportPending = false;
String planningSsid;
String planningCoordinatorIp;
uint32_t planningJoinStartedAt = 0;
struct PlanningResult {
  String node;
  int rssi = -127;
  float pingMs = 0;
  float lossPercent = 100;
};
PlanningResult planningResults[8];
size_t planningResultCount = 0;
uint32_t lastPingTestAt = 0;
int pingPacketsSent = 0;
int pingPacketsReceived = 0;
float packetLossPercent = 100;
float averagePingMs = 0;
float minPingMs = 0;
float maxPingMs = 0;
String bleRequestedSsid;
String bleRequestedPassword;
NimBLECharacteristic *bleEventCharacteristic = nullptr;

String qualityLabel(int32_t rssi) {
  if (rssi >= -55) return "Excellent";
  if (rssi >= -67) return "Good";
  if (rssi >= -75) return "Fair";
  if (rssi >= -85) return "Weak";
  return "Very Weak";
}

void runPacketLossTest(int attempts = 5) {
  pingPacketsSent = 0;
  pingPacketsReceived = 0;
  averagePingMs = 0;
  minPingMs = 0;
  maxPingMs = 0;
  if (WiFi.status() != WL_CONNECTED) {
    packetLossPercent = 100;
    return;
  }
  float total = 0;
  for (int i = 0; i < attempts; ++i) {
    ++pingPacketsSent;
    if (Ping.ping(WiFi.gatewayIP(), 1)) {
      const float latency = Ping.averageTime();
      ++pingPacketsReceived;
      total += latency;
      if (pingPacketsReceived == 1 || latency < minPingMs) minPingMs = latency;
      if (latency > maxPingMs) maxPingMs = latency;
    }
    delay(35);
  }
  packetLossPercent = pingPacketsSent ? 100.0f * (pingPacketsSent - pingPacketsReceived) / pingPacketsSent : 100;
  averagePingMs = pingPacketsReceived ? total / pingPacketsReceived : 0;
  lastPingTestAt = millis();
}

template <typename T>
void addNetworkMetrics(T &doc) {
  doc["packetLossPercent"] = packetLossPercent;
  doc["pingPacketsSent"] = pingPacketsSent;
  doc["pingPacketsReceived"] = pingPacketsReceived;
  doc["averagePingMs"] = averagePingMs;
  doc["minPingMs"] = minPingMs;
  doc["maxPingMs"] = maxPingMs;
}

String contentTypeFor(const String &path) {
  if (path.endsWith(".html")) return "text/html";
  if (path.endsWith(".css")) return "text/css";
  if (path.endsWith(".js")) return "application/javascript";
  if (path.endsWith(".json")) return "application/json";
  if (path.endsWith(".png")) return "image/png";
  if (path.endsWith(".jpg") || path.endsWith(".jpeg")) return "image/jpeg";
  if (path.endsWith(".svg")) return "image/svg+xml";
  return "text/plain";
}

void sendJson(const JsonDocument &doc, int status = 200) {
  String body;
  serializeJson(doc, body);
  server.send(status, "application/json", body);
}

template <typename T>
void addStatus(T &doc) {
  const bool connected = WiFi.status() == WL_CONNECTED;
  const int32_t rssi = connected ? WiFi.RSSI() : -127;

  doc["node_id"] = nodeId;
  doc["connected"] = connected;
  doc["connection_status"] = connected ? "connected" : (connectionPending ? "connecting" : "disconnected");
  doc["ssid"] = connected ? WiFi.SSID() : savedSsid;
  doc["bssid"] = connected ? WiFi.BSSIDstr() : "";
  if (connected) {
    doc["rssi"] = rssi;
  } else {
    doc["rssi"] = nullptr;
  }
  doc["quality_label"] = connected ? qualityLabel(rssi) : "Unavailable";
  doc["channel"] = connected ? WiFi.channel() : 0;
  doc["local_ip"] = connected ? WiFi.localIP().toString() : "";
  doc["setup_ip"] = WiFi.softAPIP().toString();
  doc["uptime_seconds"] = (millis() - bootMillis) / 1000;
  doc["ap_ssid"] = kSetupSsid;
  doc["ap_clients"] = WiFi.softAPgetStationNum();
  addNetworkMetrics(doc);
}

void beginConnection(const String &ssid, const String &password) {
  savedSsid = ssid;
  savedPassword = password;
  connectionPending = true;
  connectStartedAt = millis();
  WiFi.disconnect();
  delay(100);
  WiFi.begin(savedSsid.c_str(), savedPassword.c_str());
}

void notifyBle(const JsonDocument &doc) {
  if (!bleEventCharacteristic) return;
  String body;
  serializeJson(doc, body);
  Serial.printf("BLE -> %s\n", body.c_str());
  body += '\n';

  constexpr size_t kBleChunkSize = 18;
  for (size_t offset = 0; offset < body.length(); offset += kBleChunkSize) {
    const size_t length = min(kBleChunkSize, body.length() - offset);
    const std::string chunk(body.c_str() + offset, length);
    bleEventCharacteristic->setValue(chunk);
    bleEventCharacteristic->notify();
    delay(18);
  }
}

void notifyBleState(const char *type) {
  JsonDocument doc;
  doc["type"] = type;
  const bool connected = WiFi.status() == WL_CONNECTED;
  doc["node"] = nodeId;
  doc["connected"] = connected;
  doc["state"] = connected ? "connected" : (connectionPending ? "connecting" : "disconnected");
  doc["ssid"] = connected ? WiFi.SSID() : savedSsid;
  doc["ip"] = connected ? WiFi.localIP().toString() : "";
  notifyBle(doc);

  JsonDocument radio;
  radio["type"] = "radio_status";
  radio["bssid"] = connected ? WiFi.BSSIDstr() : "";
  if (connected) radio["rssi"] = WiFi.RSSI();
  radio["quality"] = connected ? qualityLabel(WiFi.RSSI()) : "Unavailable";
  radio["channel"] = connected ? WiFi.channel() : 0;
  radio["uptime"] = (millis() - bootMillis) / 1000;
  notifyBle(radio);

  JsonDocument accessPoint;
  accessPoint["type"] = "ap_status";
  accessPoint["ap_ssid"] = kSetupSsid;
  accessPoint["ap_ip"] = WiFi.softAPIP().toString();
  accessPoint["ap_clients"] = WiFi.softAPgetStationNum();
  notifyBle(accessPoint);
}

void notifyDiagnostics(const char *type = "diagnostics") {
  JsonDocument diagnostics;
  diagnostics["type"] = type;
  const bool connected = WiFi.status() == WL_CONNECTED;
  diagnostics["connected"] = connected;
  diagnostics["gateway_ip"] = connected ? WiFi.gatewayIP().toString() : "";
  diagnostics["dns_ip"] = connected ? WiFi.dnsIP().toString() : "";
  if (connected) {
    runPacketLossTest();
    diagnostics["gateway_latency_ms"] = static_cast<int>(round(averagePingMs));
  } else {
    diagnostics["gateway_latency_ms"] = nullptr;
  }
  addNetworkMetrics(diagnostics);
  notifyBle(diagnostics);
}

void scanNetworksForBle() {
  JsonDocument started;
  started["type"] = "scan_started";
  notifyBle(started);

  const int count = WiFi.scanNetworks(false, true);
  for (int i = 0; i < count; ++i) {
    JsonDocument doc;
    doc["type"] = "network";
    doc["ssid"] = WiFi.SSID(i);
    doc["bssid"] = WiFi.BSSIDstr(i);
    doc["rssi"] = WiFi.RSSI(i);
    doc["channel"] = WiFi.channel(i);
    doc["secure"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
    notifyBle(doc);
  }
  WiFi.scanDelete();

  JsonDocument finished;
  finished["type"] = "scan_complete";
  notifyBle(finished);
}

class BleCommandCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *characteristic) override {
    const std::string value = characteristic->getValue();
    JsonDocument request;
    if (deserializeJson(request, value) != DeserializationError::Ok) {
      Serial.println("BLE command JSON was invalid");
      return;
    }

    const String operation = request["op"] | "";
    Serial.printf("BLE command: %s\n", operation.c_str());
    if (operation == "pair") {
      blePairRequested = true;
    } else if (operation == "status") {
      bleStatusRequested = true;
    } else if (operation == "scan") {
      bleScanRequested = true;
    } else if (operation == "diagnostics") {
      bleDiagnosticsRequested = true;
    } else if (operation == "connect") {
      bleRequestedSsid = request["ssid"] | "";
      bleRequestedPassword = request["password"] | "";
      if (!bleRequestedSsid.isEmpty()) bleConnectRequested = true;
    }
  }
};

class BleServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *server) override {
    Serial.printf("Bluetooth client connected (%d active)\n", server->getConnectedCount());
  }

  void onDisconnect(NimBLEServer *server) override {
    Serial.println("Bluetooth client disconnected; advertising restarted");
    NimBLEDevice::startAdvertising();
  }
};

void configureBle() {
  String deviceName = String("WiFi Survey ") + nodeId;
  NimBLEDevice::init(deviceName.c_str());
  NimBLEDevice::setMTU(185);
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);

  NimBLEServer *bleServer = NimBLEDevice::createServer();
  bleServer->setCallbacks(new BleServerCallbacks());
  NimBLEService *service = bleServer->createService(kBleServiceUuid);
  NimBLECharacteristic *command = service->createCharacteristic(kBleCommandUuid, NIMBLE_PROPERTY::WRITE);
  bleEventCharacteristic = service->createCharacteristic(kBleEventUuid, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  command->setCallbacks(new BleCommandCallbacks());
  service->start();

  NimBLEAdvertising *advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(kBleServiceUuid);
  advertising->setScanResponse(true);
  advertising->start();
  Serial.printf("Bluetooth provisioning: %s\n", deviceName.c_str());
}

void handleStatus() {
  JsonDocument doc;
  addStatus(doc);
  sendJson(doc);
}

void handleReport() {
  JsonDocument doc;
  doc["generated_at_uptime_seconds"] = (millis() - bootMillis) / 1000;
  JsonObject node = doc["node"].to<JsonObject>();
  addStatus(node);
  sendJson(doc);
}

void handleDiagnostics() {
  JsonDocument diagnostics;
  const bool connected = WiFi.status() == WL_CONNECTED;
  diagnostics["connected"] = connected;
  diagnostics["gateway_ip"] = connected ? WiFi.gatewayIP().toString() : "";
  diagnostics["dns_ip"] = connected ? WiFi.dnsIP().toString() : "";
  if (connected) {
    runPacketLossTest();
    diagnostics["gateway_latency_ms"] = static_cast<int>(round(averagePingMs));
  } else {
    diagnostics["gateway_latency_ms"] = nullptr;
  }
  addNetworkMetrics(diagnostics);
  sendJson(diagnostics);
}

String congestionLevel(int count, int strongestRssi) {
  if (count >= 8 || strongestRssi >= -55) return "Severe";
  if (count >= 5 || strongestRssi >= -65) return "High";
  if (count >= 3 || strongestRssi >= -75) return "Medium";
  return "Low";
}

void handleChannelAnalysis() {
  int counts[14] = {};
  int strongest[14];
  for (int i = 0; i < 14; ++i) strongest[i] = -127;
  const int found = WiFi.scanNetworks(false, true);
  for (int i = 0; i < found; ++i) {
    if (WiFi.status() == WL_CONNECTED && WiFi.BSSIDstr(i).equalsIgnoreCase(WiFi.BSSIDstr())) continue;
    const int channel = WiFi.channel(i);
    if (channel >= 1 && channel <= 13) {
      counts[channel]++;
      strongest[channel] = max(strongest[channel], static_cast<int>(WiFi.RSSI(i)));
    }
  }
  WiFi.scanDelete();
  JsonDocument doc;
  const int current = WiFi.status() == WL_CONNECTED ? WiFi.channel() : 0;
  doc["currentChannel"] = current;
  doc["currentChannelCongestion"] = current ? congestionLevel(counts[current], strongest[current]) : "Unknown";
  JsonArray recommended = doc["recommended2GHzChannels"].to<JsonArray>();
  int candidates[] = {1, 6, 11};
  int bestScore = 999;
  for (int channel : candidates) bestScore = min(bestScore, counts[channel] * 10 + strongest[channel] + 127);
  for (int channel : candidates) {
    if (counts[channel] * 10 + strongest[channel] + 127 <= bestScore + 10) recommended.add(channel);
  }
  JsonArray all = doc["allChannels"].to<JsonArray>();
  for (int channel = 1; channel <= 13; ++channel) {
    JsonObject item = all.add<JsonObject>();
    item["channel"] = channel;
    item["visibleNetworks"] = counts[channel];
    if (strongest[channel] == -127) {
      item["strongestInterferingRssi"] = nullptr;
    } else {
      item["strongestInterferingRssi"] = strongest[channel];
    }
    item["congestionLevel"] = congestionLevel(counts[channel], strongest[channel]);
  }
  sendJson(doc);
}

void handlePacketLoss() {
  runPacketLossTest(10);
  JsonDocument doc;
  addNetworkMetrics(doc);
  sendJson(doc);
}

void handleIdentify() {
  identifyUntil = millis() + 10000;
  server.send(202, "application/json", R"({"ok":true,"message":"Identification started"})");
}

void handlePlanningStart() {
  planningCoordinator = true;
  planningJoinPending = false;
  planningReportPending = false;
  planningResultCount = 0;
  planningSsid = "Survey-AP-" + nodeId.substring(max(0, static_cast<int>(nodeId.length()) - 6));
  WiFi.softAPdisconnect(true);
  WiFi.softAP(planningSsid.c_str());
  JsonDocument doc;
  doc["ok"] = true;
  doc["role"] = "coordinator";
  doc["ssid"] = planningSsid;
  doc["ip"] = WiFi.softAPIP().toString();
  sendJson(doc);
}

void handlePlanningJoin() {
  JsonDocument request;
  if (!server.hasArg("plain") || deserializeJson(request, server.arg("plain")) ||
      !request["ssid"].is<const char *>()) {
    server.send(400, "application/json", R"({"error":"ssid and coordinatorIp are required"})");
    return;
  }
  planningSsid = request["ssid"].as<String>();
  planningCoordinatorIp = request["coordinatorIp"] | "192.168.4.1";
  planningCoordinator = false;
  planningJoinPending = true;
  planningReportPending = false;
  planningJoinStartedAt = millis();
  server.send(202, "application/json", R"({"ok":true,"message":"Joining candidate AP"})");
}

void handlePlanningResult() {
  JsonDocument request;
  if (!planningCoordinator || !server.hasArg("plain") || deserializeJson(request, server.arg("plain"))) {
    server.send(400, "application/json", R"({"error":"Coordinator mode and valid JSON required"})");
    return;
  }
  const String resultNode = request["node_id"] | "";
  size_t index = planningResultCount;
  for (size_t i = 0; i < planningResultCount; ++i) {
    if (planningResults[i].node == resultNode) index = i;
  }
  if (index == planningResultCount && planningResultCount < 8) ++planningResultCount;
  if (index < 8) {
    planningResults[index].node = resultNode;
    planningResults[index].rssi = request["rssi"] | -127;
    planningResults[index].pingMs = request["averagePingMs"] | 0;
    planningResults[index].lossPercent = request["packetLossPercent"] | 100;
  }
  server.send(200, "application/json", R"({"ok":true})");
}

void handlePlanningStatus() {
  JsonDocument doc;
  doc["role"] = planningCoordinator ? "coordinator" : (planningJoinPending || planningReportPending ? "tester" : "inactive");
  doc["ssid"] = planningSsid;
  doc["ip"] = WiFi.softAPIP().toString();
  JsonArray results = doc["results"].to<JsonArray>();
  for (size_t i = 0; i < planningResultCount; ++i) {
    JsonObject item = results.add<JsonObject>();
    item["node_id"] = planningResults[i].node;
    item["rssi"] = planningResults[i].rssi;
    item["averagePingMs"] = planningResults[i].pingMs;
    item["packetLossPercent"] = planningResults[i].lossPercent;
  }
  sendJson(doc);
}

void handlePlanningStop() {
  planningCoordinator = false;
  planningJoinPending = false;
  planningReportPending = false;
  planningResultCount = 0;
  planningSsid = "";
  WiFi.softAPdisconnect(true);
  WiFi.softAP(kSetupSsid);
  if (!savedSsid.isEmpty()) beginConnection(savedSsid, savedPassword);
  server.send(200, "application/json", R"({"ok":true})");
}

void handleSpeedTest() {
  constexpr size_t kPayloadBytes = 128 * 1024;
  String chunk;
  chunk.reserve(1024);
  while (chunk.length() < 1024) chunk += 'W';
  server.setContentLength(kPayloadBytes);
  server.send(200, "application/octet-stream", "");
  for (size_t sent = 0; sent < kPayloadBytes; sent += chunk.length()) {
    server.sendContent(chunk);
  }
}

void handleScan() {
  const int count = WiFi.scanNetworks(false, true);
  JsonDocument doc;
  JsonArray networks = doc["networks"].to<JsonArray>();

  for (int i = 0; i < count; ++i) {
    JsonObject network = networks.add<JsonObject>();
    network["ssid"] = WiFi.SSID(i);
    network["bssid"] = WiFi.BSSIDstr(i);
    network["rssi"] = WiFi.RSSI(i);
    network["quality_label"] = qualityLabel(WiFi.RSSI(i));
    network["channel"] = WiFi.channel(i);
    network["secure"] = WiFi.encryptionType(i) != WIFI_AUTH_OPEN;
  }
  WiFi.scanDelete();
  sendJson(doc);
}

void handleConnect() {
  if (!server.hasArg("plain")) {
    server.send(400, "application/json", R"({"error":"Missing JSON body"})");
    return;
  }

  JsonDocument request;
  const DeserializationError error = deserializeJson(request, server.arg("plain"));
  if (error || !request["ssid"].is<const char *>()) {
    server.send(400, "application/json", R"({"error":"A valid ssid is required"})");
    return;
  }

  const String ssid = request["ssid"].as<String>();
  const String password = request["password"] | "";
  preferences.putString("ssid", ssid);
  preferences.putString("password", password);
  beginConnection(ssid, password);

  JsonDocument response;
  response["ok"] = true;
  response["message"] = "Connection started";
  response["ssid"] = ssid;
  sendJson(response, 202);
}

void handleResetWifi() {
  preferences.clear();
  savedSsid = "";
  savedPassword = "";
  WiFi.disconnect(true);

  JsonDocument response;
  response["ok"] = true;
  response["message"] = "Wi-Fi credentials cleared. Restarting in setup mode.";
  sendJson(response);
  delay(500);
  ESP.restart();
}

bool serveFile(String path) {
  if (path == "/") path = "/index.html";
  if (!LittleFS.exists(path)) return false;

  File file = LittleFS.open(path, "r");
  server.streamFile(file, contentTypeFor(path));
  file.close();
  return true;
}

void configureRoutes() {
  server.on("/api/status", HTTP_GET, handleStatus);
  server.on("/api/report", HTTP_GET, handleReport);
  server.on("/api/diagnostics", HTTP_GET, handleDiagnostics);
  server.on("/api/speed-test", HTTP_GET, handleSpeedTest);
  server.on("/api/channel-analysis", HTTP_GET, handleChannelAnalysis);
  server.on("/api/packet-loss", HTTP_GET, handlePacketLoss);
  server.on("/api/identify", HTTP_POST, handleIdentify);
  server.on("/api/planning/start", HTTP_POST, handlePlanningStart);
  server.on("/api/planning/join", HTTP_POST, handlePlanningJoin);
  server.on("/api/planning/result", HTTP_POST, handlePlanningResult);
  server.on("/api/planning/status", HTTP_GET, handlePlanningStatus);
  server.on("/api/planning/stop", HTTP_POST, handlePlanningStop);
  server.on("/api/scan", HTTP_GET, handleScan);
  server.on("/api/connect", HTTP_POST, handleConnect);
  server.on("/api/reset-wifi", HTTP_POST, handleResetWifi);
  server.onNotFound([]() {
    if (!serveFile(server.uri())) {
      server.send(404, "application/json", R"({"error":"Not found"})");
    }
  });
}

}  // namespace

void setup() {
  Serial.begin(115200);
  bootMillis = millis();
  pinMode(kIdentifyLedPin, OUTPUT);
  const uint64_t chipId = ESP.getEfuseMac();
  char nodeBuffer[16];
  snprintf(nodeBuffer, sizeof(nodeBuffer), "ESP32-%06llX", chipId & 0xFFFFFF);
  nodeId = nodeBuffer;
  Serial.printf("Node ID: %s\n", nodeId.c_str());

  if (!LittleFS.begin(true)) {
    Serial.println("LittleFS mount failed");
  }

  preferences.begin(kPreferencesNamespace, false);
  savedSsid = preferences.getString("ssid", "");
  savedPassword = preferences.getString("password", "");

  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(kSetupSsid);
  Serial.printf("Setup AP: %s at %s\n", kSetupSsid, WiFi.softAPIP().toString().c_str());

  if (!savedSsid.isEmpty()) {
    beginConnection(savedSsid, savedPassword);
  }

  configureRoutes();
  server.begin();
  configureBle();
  Serial.println("HTTP server started");
}

void loop() {
  server.handleClient();
  if (identifyUntil && millis() < identifyUntil && millis() - lastIdentifyToggle >= 250) {
    lastIdentifyToggle = millis();
    identifyLedOn = !identifyLedOn;
    digitalWrite(kIdentifyLedPin, identifyLedOn);
  } else if (identifyUntil && millis() >= identifyUntil) {
    identifyUntil = 0;
    identifyLedOn = false;
    digitalWrite(kIdentifyLedPin, LOW);
  }
  if (WiFi.status() == WL_CONNECTED && millis() - lastPingTestAt > 15000) runPacketLossTest();

  if (planningJoinPending && millis() - planningJoinStartedAt > 300) {
    planningJoinPending = false;
    WiFi.disconnect();
    WiFi.begin(planningSsid.c_str());
    planningReportPending = true;
    planningJoinStartedAt = millis();
  }
  if (planningReportPending && WiFi.status() == WL_CONNECTED) {
    runPacketLossTest(10);
    JsonDocument report;
    report["node_id"] = nodeId;
    report["rssi"] = WiFi.RSSI();
    addNetworkMetrics(report);
    String body;
    serializeJson(report, body);
    HTTPClient http;
    http.begin("http://" + planningCoordinatorIp + "/api/planning/result");
    http.addHeader("Content-Type", "application/json");
    const int response = http.POST(body);
    http.end();
    planningReportPending = response < 200 || response >= 300;
    if (planningReportPending) delay(500);
  }

  if (blePairRequested) {
    blePairRequested = false;
    notifyBleState("paired");
  }

  if (bleStatusRequested) {
    bleStatusRequested = false;
    notifyBleState("status");
  }

  if (bleScanRequested) {
    bleScanRequested = false;
    scanNetworksForBle();
  }

  if (bleDiagnosticsRequested) {
    bleDiagnosticsRequested = false;
    notifyDiagnostics();
  }

  if (bleConnectRequested) {
    bleConnectRequested = false;
    preferences.putString("ssid", bleRequestedSsid);
    preferences.putString("password", bleRequestedPassword);
    beginConnection(bleRequestedSsid, bleRequestedPassword);
    notifyBleState("connecting");
  }

  if (connectionPending && WiFi.status() == WL_CONNECTED) {
    connectionPending = false;
    Serial.printf("Connected to %s at %s\n", WiFi.SSID().c_str(), WiFi.localIP().toString().c_str());
    notifyBleState("connected");
  } else if (connectionPending && millis() - connectStartedAt > kConnectTimeoutMs) {
    connectionPending = false;
    WiFi.disconnect();
    Serial.println("Connection timed out; setup AP remains available");
    notifyBleState("connection_failed");
  }
}
