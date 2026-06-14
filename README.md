# Wi-Fi Survey MVP

Single-node Wi-Fi survey system for an ESP-32D and iPhone. The ESP32 measures the connected network. The native iOS app uses Apple RoomPlan and LiDAR to scan a room, automatically creates a metric top-down floor plan, and records Wi-Fi measurements on it. The offline browser dashboard remains available as a universal fallback.

## MVP behavior

- First boot creates the open setup AP `WiFi-Survey-Setup` at `192.168.4.1`.
- The setup AP stays available while the ESP32 connects to the selected target Wi-Fi.
- The dashboard is available from both `192.168.4.1` and the ESP32 local network IP.
- The iOS app can scan nearby networks through the ESP32 and send the selected router credentials.
- The ESP32 advertises over Bluetooth as soon as it powers on. The app asks before pairing; the iPhone never needs to join the ESP32 setup Wi-Fi.
- The iOS app uses RoomPlan to detect walls and dimensions without manual scale entry.
- On phones without LiDAR, the main room-scan button uses ARKit vertical-wall detection and the perimeter scanner remains available as a controlled fallback.
- The iOS app displays a generated 2D floor plan, reads live ESP status, records points, and exports CSV.
- Wi-Fi credentials are saved in ESP32 Preferences.
- Floor-plan image is saved in browser IndexedDB.
- Plan dimensions, scale, and measurements are saved in browser localStorage.
- Measurement coordinates are normalized from `0.0` to `1.0`, so they remain valid after image resizing.
- Each board exposes a stable hardware-derived node ID so the iOS app can aggregate multiple ESP32 testers.

## Professional diagnostics APIs

- `GET /api/packet-loss`: repeated gateway ping statistics and packet-loss percentage.
- `GET /api/channel-analysis`: per-channel network count, strongest interferer, congestion level, and recommended 2.4 GHz channels.
- `POST /api/identify`: blinks the configured identify LED for 10 seconds.
- `/api/status`, `/api/report`, and `/api/diagnostics` include packet-loss and ping statistics.

## Requirements

- ESP-32D / ESP-WROOM-32D development board and a USB data cable.
- Mac with Xcode installed.
- Any ARKit-capable iPhone for the walk-perimeter scanner.
- An iPhone or iPad with a LiDAR Scanner for fully automatic RoomPlan wall detection. In the app, **Start Room Scan** is disabled when the device does not support RoomPlan.
- iOS 17 or newer.

The current native MVP scans one room or one connected open area at a time. Separate closed rooms require individual scans and structure merging, which is the next expansion.

## Flash the ESP32 from this Mac

### Option 1: VS Code and PlatformIO

1. Install Visual Studio Code.
2. Install the **PlatformIO IDE** extension.
3. Open this repository folder in VS Code.
4. Connect the ESP32-S3 with a USB data cable.
5. In PlatformIO, run **Upload** to flash the firmware.
6. Run **Upload Filesystem Image** to upload the offline dashboard from `data/`.
7. Open the serial monitor at `115200` baud.

### Option 2: Terminal

Install [PlatformIO](https://platformio.org/), connect the ESP-32D board, then run:

```sh
pio run
pio run --target upload
pio run --target uploadfs
pio device monitor
```

The `uploadfs` step uploads the offline dashboard from `data/` into LittleFS.

The project uses PlatformIO's generic `esp32dev` target, which is normally correct for ESP-WROOM-32D and ESP32 DevKit boards. If uploading stalls, hold the board's **BOOT** button, tap **EN/RESET**, start upload, then release **BOOT** when writing begins.

After flashing:

1. Turn on Bluetooth on the iPhone and power on the ESP32.
2. Open the iOS app. A nearby-device prompt appears automatically.
3. Confirm pairing.
4. Open **ESP32**, tap **Choose Wi-Fi Network**, select your router, and enter its password in the immediate password prompt.
5. The ESP reports its router-assigned address back to the app automatically.

The `WiFi-Survey-Setup` access point and browser dashboard remain available only as a fallback; normal iOS setup does not require joining that network.

## Install the iOS app on your iPhone

1. Connect the iPhone to the Mac with a USB cable and tap **Trust** if prompted.
2. Open [ios/WiFiSurvey.xcodeproj](ios/WiFiSurvey.xcodeproj) in Xcode.
3. In Xcode, open **Xcode > Settings > Accounts** and add your Apple ID.
4. Select the blue **WiFiSurvey** project, select the **WiFiSurvey** target, then open **Signing & Capabilities**.
5. Choose your Apple ID's personal team under **Team**. If Xcode reports that the bundle identifier is unavailable, change `com.wifisurvey.app` to something unique.
6. Select your connected iPhone in Xcode's device selector.
7. Press the Run button or `Command-R`.
8. If prompted on the phone, enable **Developer Mode** under **Settings > Privacy & Security > Developer Mode**, restart the phone, and run again.
9. Approve camera and local-network permissions when the app requests them.

A free Apple ID can install the app for development, but Xcode may require reinstalling it periodically. A paid Apple Developer account supports longer-lived development signing and distribution.

## Survey workflow

1. In the iOS app, open **Scan**.
2. On a LiDAR device, tap **Start Room Scan**, walk slowly around the room, and point the camera at every wall and corner.
3. On a phone without LiDAR, tap **Walk Perimeter and Mark Corners**. Stand at each corner and mark it while walking around the room in order.
4. Finish the scan. The app uses RoomPlan or ARKit motion tracking to produce a scaled floor plan automatically, without entering distances.
5. Open **Survey**, tap the ESP32's current position on the floor plan, then tap **Record Measurement Point**.
6. Move the ESP32, tap its new position, and record again.
7. Open **Points** to review or export the survey as CSV.

Keep the ESP32 near you while recording. The phone's selected map position represents the physical location of the ESP32, not the phone.

## API

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/` | Dashboard |
| `GET` | `/api/status` | Current single-node Wi-Fi status |
| `GET` | `/api/scan` | Nearby Wi-Fi networks |
| `POST` | `/api/connect` | Save `{ "ssid", "password" }` and connect |
| `POST` | `/api/reset-wifi` | Clear saved credentials and restart |
| `GET` | `/api/report` | Current node status wrapper |

## Browser fallback floor-plan workflow

1. Open **Plan** and take or choose a photo of a paper floor plan.
2. Rotate or crop it if needed.
3. Enter overall dimensions or select **Set scale**, tap two points, and enter their real distance.
4. Select **Place point** and tap the current ESP32 location.
5. Open **Live** and press **Record Measurement Point**.

Normal browser pages do not receive full ARKit/ARCore room scanning access. This MVP uses reliable camera photo capture and keeps the floor-plan data model separate so a future native scanner can provide the image, dimensions, and coordinates.
