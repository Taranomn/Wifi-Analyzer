# Smart AV Field Operations + Wi-Fi Analyzer

Smart AV is a native iOS field-operations app plus ESP firmware for smart home, AV, security, network, and automation installation teams.

The product started as a Wi-Fi survey tool, but the current direction is broader:

**Projects -> Areas -> Tasks**

The app should help installers and managers quickly understand:

- Which job sites exist.
- Which areas of a house still need work.
- Which tasks are open, in progress, done, or blocked.
- Who is responsible for each job.
- What equipment, files, credentials, security checks, shifts, and technical utilities belong to the project.
- Whether Wi-Fi and network quality are good enough for installation decisions.

The app is intentionally not a heavy enterprise project-management system. It should feel fast, premium, visual, and practical for technicians on site.

## Current Status

This repository contains:

- A native SwiftUI iOS app in `ios/WiFiSurvey`.
- Arduino / PlatformIO firmware in `src/main.cpp`.
- An offline ESP-hosted web dashboard in `data/`.
- Smart AV brand assets in `ios/WiFiSurvey/Resources/Brand`.
- Custom fonts in `ios/WiFiSurvey/Resources/Fonts`.

The app currently supports project management, area management, task tracking, demo users, shifts, files, secure credential storage, security final checks, Wi-Fi utilities, ESP device diagnostics, iPhone-only network testing, AR area/task features, and ESP firmware for ESP32 plus ESP-01S / ESP8266.

## Repository Layout

```text
.
├── ios/WiFiSurvey.xcodeproj
├── ios/WiFiSurvey/
│   ├── WiFiSurveyApp.swift
│   ├── ContentView.swift
│   ├── SurveyStore.swift
│   ├── Models.swift
│   ├── ESPService.swift
│   ├── BLEProvisioningService.swift
│   ├── AreaLandmarkCaptureView.swift
│   ├── AreaLandmarkMapView.swift
│   ├── ARWallScannerView.swift
│   ├── RoomScannerView.swift
│   ├── WalkTraceView.swift
│   ├── FloorPlanView.swift
│   ├── SiteTasksView.swift
│   └── Resources/
│       ├── Brand/
│       └── Fonts/
├── src/main.cpp
├── data/index.html
├── data/app.js
├── data/styles.css
└── platformio.ini
```

## Product Direction

The main product is a Smart AV installation workflow app.

Primary flow:

1. Open the app.
2. Sign in as a demo user.
3. See projects/job sites.
4. Open a project.
5. See areas immediately.
6. Open an area.
7. Add, complete, edit, assign, and review tasks.

Secondary tools live under Utilities:

- iPhone Wi-Fi / internet test.
- Signal Analyzer for ESP boards and mapped area points.
- ESP device setup and diagnostics.
- Speed / ping testing.
- Central vacuum planning helper.
- Reports and experimental AR tools.

AR and Wi-Fi heatmap features are kept in the codebase, but they should not dominate the main project workflow.

## Visual Direction

The UI has been redesigned away from an Apple Reminders-style plain list.

Design target:

- Premium dark interface.
- Smart AV orange branding.
- Deep blue / black backgrounds.
- Glass-style cards.
- Rounded corners.
- Fast, linear navigation.
- Minimal forms.
- Large, readable status cards.
- Utilities separate from project execution.

Brand assets:

- `ios/WiFiSurvey/Resources/Brand/smartav-logo.png`
- `ios/WiFiSurvey/Resources/Brand/smartav-wordmark.png`
- `ios/WiFiSurvey/Resources/Brand/smartav-icon.png`

Fonts:

- Satoshi
- Tomato Grotesk

## Demo Users and Access Levels

The app has a simple demo sign-in system. It is not a real backend login yet.

Seeded users:

| Name | Role |
| --- | --- |
| Reza | Admin |
| Hamed | Supervisor |
| Hosein | Supervisor |
| Sasan | Supervisor |
| Pouya | Technician |
| Saman | Technician |
| Behnam | Technician |

Current permission model:

- Admin, Manager, and Supervisor can manage projects, shifts, deletion, and permanent suggestions.
- Technicians can use the workflow but should not have full management permissions.
- Real authentication, team sync, and server-backed roles are future work.

Relevant code:

- `SurveyStore.currentUserId`
- `SurveyStore.canManageProjects`
- `SurveyStore.canManageShifts`
- `SurveyStore.canDeleteRecords`
- `SurveyStore.canManagePermanentSuggestions`
- `SignInView` and `UserSwitcherView` in `ContentView.swift`

## Main App Sections

The current app has three major top-level sections:

1. Projects
2. Shifts
3. Utilities

Projects are the main product. Shifts and Utilities are useful but should not visually compete with the project workflow.

## Projects

Projects are stored as `SurveyLocation` records.

Each project contains:

- Name
- Address
- Directions note
- Areas
- Tasks
- Equipment summary
- Files
- Security final check items
- Shifts
- Wi-Fi / ESP survey data
- AR mapping data
- Project-specific snapshot data

The app starts from the last selected project if available. Users can switch projects from the top of the app.

Project creation asks for:

- Project name
- Address
- Areas

The area picker uses a **search or create** pattern:

- If the area exists, the user taps it.
- If it does not exist, the user types it in the same search field.
- A plus button appears in that same field to create the typed area.
- The user can save new suggestions for future projects if they have permission.

## Areas

Areas represent rooms or zones inside a project.

Examples:

- Kitchen
- Living Room
- Family Room
- Dining Room
- Bedroom 1
- Bedroom 2
- Basement
- Patio
- Garage
- Whole House

Areas show status at a glance:

- Ready
- Needs Work
- Blocked

Area readiness is based on open tasks and related work. Areas with remaining tasks or incomplete work should not appear ready.

There is also a Whole House / unassigned area concept for tasks that are not tied to one room.

Area mapping is optional. An area may exist without being placed on a scan or floor plan.

## Tasks

Tasks are the center of the workflow.

Data model: `SiteTask`

Fields:

- Title
- Category
- Notes
- Status
- Floor
- Area
- Assigned employees
- Due date
- Priority
- Subtasks
- Optional AR placement
- Created / updated timestamps

Statuses:

- To Do
- In Progress
- Done
- Blocked

Task creation is designed to be fast:

- Use preset task suggestions.
- Search existing task templates.
- Create a custom task directly from the search field if not found.
- Add details later only if needed.

Tasks support:

- Multiple assignees.
- Bulk assignment.
- Deadlines.
- Priority.
- Subtasks.
- Quick complete by tapping the task checkbox.
- Edit and delete.
- Optional AR placement.

Common Smart AV task categories include:

- TV installation
- AV receiver / processor setup
- Speaker installation
- Ceiling speaker install
- Surround calibration
- HDMI / AV cabling
- Network rack work
- Access point install
- Camera install
- NVR setup
- Alarm keypad install
- Motion sensor install
- Door contact install
- Smoke detector install
- Smart switch install
- Lighting programming
- Shade / curtain programming
- Control4 / Crestron / automation programming
- Final test and handoff

## Equipment

Equipment is not a main navigation section anymore.

Equipment belongs inside project and task context.

Current equipment support includes:

- Project equipment list.
- Equipment status/checklist.
- Equipment attached to tasks through the task detail flow.
- Suggestions for common AV, security, network, Control4, Crestron, camera, NVR, DCM, and smart-home components.

The goal is:

- A project can show all equipment needed for the house.
- An area can show equipment related to that area.
- A task can include equipment details.
- If equipment installation is assigned, it can create or link to a task.

## Files

Each project has a Files tab.

Files can be used for:

- Photos
- Plans
- PDFs
- Notes
- Client-provided documents
- Installation references

Data model: `ProjectFileAttachment`

Files are copied into the app documents directory and referenced by local filename.

## Secure Credential Vault

Each project can store credentials for devices and systems.

Examples:

- Wi-Fi passwords
- NVR passwords
- Router passwords
- Alarm panel passwords
- Automation controller passwords
- Device admin credentials

This is intended for high-security sharing inside the team. The current implementation is local/demo-oriented. A real production version should add proper encryption, access control, audit history, and backend sync before use with real client passwords.

## Security Final Check

Security projects often need final validation.

The app supports checklist-style final checks for components such as:

- Motion sensors
- Contact sensors
- Smoke detectors
- Cameras
- NVR
- Alarm keypads
- Sirens
- Network connectivity

Data model: `SecurityCheckItem`

The purpose is to make final commissioning easier: when a project includes security equipment, the app can show what must be tested and checked off before handoff.

## Shifts

Shifts have a dedicated main section.

Data model: `WorkShift`

Fields:

- Project/location
- Job site name
- Site address
- Shift title
- Start time
- End time
- Assigned employees
- Notes

The shift screen supports:

- Weekly visualization.
- Filtering by employee.
- Showing all employees together.
- Adding new shift titles if not already suggested.
- Selecting an existing project/job site when adding a shift.
- Getting directions after a shift has a defined address.

Shift editing should be limited to Admin, Manager, and Supervisor roles. The current app has role checks in the store; a real login system can harden this later.

## Utilities

Utilities are a toolbox. They should feel separate from project execution.

Current utility concepts:

- iPhone Wi-Fi / internet test.
- Signal Analyzer.
- ESP Devices.
- Central Vacuum Planner.
- Reports and logs.
- Experimental AR tools.

The Utilities UI should use the same Smart AV dark theme as the rest of the app.

## iPhone Wi-Fi / Internet Test

This mode is for times when no ESP board is available.

iOS does not expose true Wi-Fi RSSI to normal apps, so the app does not fake dBm from the phone.

The iPhone can collect:

- SSID where available.
- BSSID where available.
- Network path type.
- Whether the connection is constrained or expensive.
- Internet reachability.
- Average latency.
- Packet loss percentage.
- Download speed.
- Upload speed.
- Probe count.
- A normalized score.

The app supports:

- One-time test.
- Area-based collection where the installer waits at least 5 seconds and can continue collecting more samples.
- Averaging collected samples before saving.
- Live monitor that automatically logs full samples.
- Latest five live results.
- Rolling averages for ping, packet loss, download, upload, and score.

Important:

- iPhone-only testing does not need a mapped area.
- If an area is selected, the result can be saved to that area.
- The live monitor starts immediately when opened.

Relevant code:

- `IPhoneNetworkAnalyzer` in `ContentView.swift`
- `IPhoneAnalyzerView`
- `IPhoneLiveAnalyzerLogView`
- `PhoneNetworkSample`
- `ProfessionalScore.phoneScore`

## ESP Signal Analyzer

This mode is for ESP boards used as Wi-Fi testers.

Current behavior:

- Project screens include a **Wi-Fi Analyzer** section beside areas, tasks, equipment, files, final check, and passwords.
- If the selected project already has mapped area points, the user can assign ESP devices to areas and inspect area results.
- If the project does not have mapped area points, the user can scan/mark locations first.
- If AR marking fails, the typed area name is preserved and an error/status is shown, so the user can retry or choose another location without retyping.
- Existing mapped points can be tapped or long-pressed for area actions.
- Area result cards include an identify/blink button for assigned ESP devices.
- Utilities -> Devices has an add-device flow for Bluetooth ESP32-WROOM pairing or manual IP entry.

The Signal Analyzer is where ESP board measurements connect to project areas.

ESP data includes:

- RSSI
- Quality label
- SSID
- BSSID
- Channel
- Local IP
- Packet loss
- Ping statistics
- Local speed test
- Channel congestion
- Last seen / stale state
- Device score

## Floors and Area Points

The app supports multiple floors through `BuildingFloor`.

Area points store:

- Name
- X/Y/Z position
- Floor ID
- Assigned ESP node IDs
- Whether the point is mapped

The 2D map view can switch floors. Points on each floor should stay aligned by using their saved coordinates and floor IDs.

Area points can exist without a full floor plan. This is useful when the installer only wants rough room markers instead of scanning walls.

## AR and Mapping

AR features are kept in the app but are not the core workflow.

Current AR/mapping files:

- `RoomScannerView.swift`: RoomPlan / LiDAR room capture.
- `ARWallScannerView.swift`: ARKit wall detection fallback.
- `WalkTraceView.swift`: perimeter/corner walking fallback.
- `AreaLandmarkCaptureView.swift`: point-based area marking with AR reticle.
- `SiteTasksView.swift`: AR task marker support.
- `AreaLandmarkMapView.swift`: 2D area point map.

Important limitations:

- Normal web pages cannot access full ARKit/ARCore room scanning.
- RoomPlan requires supported LiDAR devices.
- Non-LiDAR fallback methods are less reliable.
- Area point marking is currently the practical lightweight option.
- AR world-map relocalization can improve accuracy after scanning from multiple angles, but it is not perfect.

For best AR accuracy:

- Scan slowly.
- Capture the site from multiple angles.
- Include textured walls, corners, doors, and fixed objects.
- Avoid changing lighting dramatically between scans.
- Avoid placing markers before tracking has stabilized.
- Reopen and let ARKit relocalize before trusting marker positions.

## Professional Wi-Fi Scoring

The app has a professional score model from 0 to 100.

Labels:

- Excellent
- Good
- Fair
- Weak
- Critical

ESP device scoring uses:

- RSSI
- Latency
- Packet loss
- Local throughput
- Channel congestion
- Connection stability
- Last update freshness

iPhone scoring uses:

- Estimated/normalized signal where iOS provides useful path data
- Latency
- Packet loss
- Download speed
- Upload speed
- Internet reachability
- Freshness

Relevant code:

- `ProfessionalScore` in `Models.swift`
- `SurveyDevice`
- `PhoneNetworkSample`
- `SurveyRecommendation`

## Recommendation Engine

The app includes rule-based recommendations for installer decisions.

Typical recommendation logic:

- Weak RSSI and high packet loss -> add AP closer to the area.
- Good RSSI but bad latency/loss -> check interference or AP load.
- High channel congestion -> change AP channel.
- One weak side of the map -> move AP toward weak areas.
- Multiple distant weak areas -> add another AP or mesh node.
- Good scores everywhere -> no action needed.

Recommendations are intended to appear in:

- Installer survey views.
- Area detail popups.
- Final survey reports.

## ESP Firmware

Firmware source: `src/main.cpp`

Framework: Arduino through PlatformIO.

Supported targets:

| Environment | Board Type |
| --- | --- |
| `esp32dev` | ESP-WROOM-32D / common ESP32 dev boards |
| `esp32-s3-devkitc-1` | ESP32-S3 dev boards |
| `esp01s` | ESP-01S / ESP8266 1MB boards |

Common behavior:

- Starts setup AP `WiFi-Survey-Setup`.
- Setup IP is `192.168.4.1`.
- Serves HTTP APIs and the offline dashboard.
- Can connect to a selected router Wi-Fi.
- Reports Wi-Fi status and diagnostics.
- Supports scan, speed test, packet loss, channel analysis, and reset.

ESP32-only behavior:

- BLE provisioning.
- Nearby-device prompt in the iOS app.
- App can send selected router credentials over BLE.
- BLE fallback can be used when Wi-Fi communication is lost.
- ESP32-WROOM acts as the Smart AV hub for ESP-01S satellite testers.
- The hub starts an AP named `SmartAV-Hub-xxxxxx` with password `smartavhub`.
- ESP-01S boards can join this hub AP and periodically register/report status to the ESP32.
- The app can add the ESP32 hub once, then see registered ESP-01S boards through the hub.
- Identify commands for ESP-01S boards can be proxied through the hub.

ESP-01S / ESP8266 behavior:

- No BLE provisioning.
- Uses the setup AP and HTTP dashboard/API flow.
- Can still run the Wi-Fi analyzer/status APIs.
- Device node ID is generated as `ESP01S-xxxxxx`.
- When connected to an ESP32 hub AP, it posts its status to the hub every few seconds.
- If the hub is not available later, the ESP-01S can still be accessed directly by IP when the phone is on the same network or by using its fallback setup AP.

## ESP32 Hub + ESP-01S Satellite Workflow

Target hardware for this mode:

- One ESP32-WROOM as the hub/coordinator.
- One or more ESP-01S boards as small room testers.

High-level flow:

1. Flash the ESP32-WROOM with the `esp32dev` firmware.
2. The ESP32 starts a hub AP named like `SmartAV-Hub-459B58`.
3. Flash each ESP-01S with the `esp01s` firmware from the other laptop.
4. For each ESP-01S, join its setup AP `WiFi-Survey-Setup`.
5. Open `http://192.168.4.1`.
6. Connect the ESP-01S to the ESP32 hub SSID.
7. Password is `smartavhub`.
8. The ESP-01S registers itself with the ESP32 hub automatically.
9. In the app, open Utilities -> Devices -> plus.
10. Add the ESP32-WROOM hub through Bluetooth or manual IP.
11. The app pulls child ESP-01S devices from `/api/hub/devices`.
12. Open a project -> Wi-Fi Analyzer.
13. If there is no signal map, create one by marking the center of each area and choosing the correct floor.
14. If there is already a map, place each ESP device into the correct area.
15. Tap identify beside a device to blink the physical board before assigning/moving it.

Important limitation:

- ESP-01S has no Bluetooth. It cannot pair directly with the iPhone like an ESP32.
- The implemented fallback is saved direct IP/setup AP access, not BLE pairing.
- The phone can reach ESP-01S directly only when it is on the same network as the ESP-01S or connected to that ESP-01S fallback AP.

## ESP API

| Method | Endpoint | Purpose |
| --- | --- | --- |
| `GET` | `/` | Offline dashboard |
| `GET` | `/api/status` | Current Wi-Fi and node status |
| `GET` | `/api/report` | Report wrapper for current node status |
| `GET` | `/api/diagnostics` | Gateway, DNS, latency, packet-loss diagnostics |
| `GET` | `/api/speed-test` | Local payload for iPhone-to-ESP speed measurement |
| `GET` | `/api/channel-analysis` | Per-channel congestion analysis |
| `GET` | `/api/packet-loss` | Repeated gateway ping and packet-loss metrics |
| `POST` | `/api/identify` | Blink identify LED for physical device identification |
| `GET` | `/api/scan` | Nearby Wi-Fi network scan |
| `POST` | `/api/connect` | Save `{ "ssid", "password" }` and connect to router |
| `POST` | `/api/reset-wifi` | Clear saved credentials |
| `POST` | `/api/hub/register` | ESP-01S child posts status to ESP32 hub |
| `GET` | `/api/hub/devices` | App reads ESP-01S devices registered with ESP32 hub |
| `POST` | `/api/hub/identify` | App asks ESP32 hub to blink a child ESP-01S |
| `POST` | `/api/planning/start` | Start AP planning coordinator mode |
| `POST` | `/api/planning/join` | Join planning mode as another ESP |
| `POST` | `/api/planning/result` | Post planning measurement result to coordinator |
| `GET` | `/api/planning/status` | Get AP planning status/results |
| `POST` | `/api/planning/stop` | Stop planning mode |

## BLE Provisioning

BLE service UUIDs must stay stable:

- Service: `7A1F0001-8D79-4F25-BC40-5C7D17F62A11`
- Command: `7A1F0002-8D79-4F25-BC40-5C7D17F62A11`
- Event: `7A1F0003-8D79-4F25-BC40-5C7D17F62A11`

Current discovery behavior:

- The app scans with `withServices: nil`.
- It accepts a peripheral if advertised services contain the custom UUID.
- It also accepts a peripheral if its advertised/local name starts with `WiFi Survey`.

This improves discovery when iOS does not expose service data consistently.

## Flashing Firmware

Install PlatformIO first.

Build default ESP32 firmware:

```sh
pio run
```

Build and upload ESP32:

```sh
pio run -e esp32dev
pio run -e esp32dev --target upload
pio run -e esp32dev --target uploadfs
pio device monitor -b 115200
```

Build and upload ESP32-S3:

```sh
pio run -e esp32-s3-devkitc-1
pio run -e esp32-s3-devkitc-1 --target upload
pio run -e esp32-s3-devkitc-1 --target uploadfs
pio device monitor -b 115200
```

Build and upload ESP-01S:

```sh
pio run -e esp01s
pio run -e esp01s --target upload
pio run -e esp01s --target uploadfs
pio device monitor -b 115200
```

If upload stalls:

- Put the board in boot/upload mode.
- For ESP32, hold BOOT, tap EN/RESET, start upload, then release BOOT when writing begins.
- For ESP-01S, GPIO0 must be pulled low during reset to enter flashing mode.

If an ESP-01S is used:

1. Flash firmware.
2. Power cycle normally.
3. Join `WiFi-Survey-Setup` from phone or computer.
4. Open `http://192.168.4.1`.
5. To use hub mode, connect it to the ESP32 hub SSID, for example `SmartAV-Hub-459B58`.
6. Use password `smartavhub`.
7. After it joins, it registers with the ESP32 hub automatically.
8. In the app, add the ESP32 hub. The ESP-01S boards should appear under Devices after the next refresh.
9. For direct fallback mode, connect the ESP-01S to any normal router Wi-Fi and add it in the app by local IP.

## Installing the iOS App

Requirements:

- Mac with Xcode.
- iPhone with iOS 17 or newer.
- Apple ID added to Xcode.
- USB connection for development install.

Install from Xcode:

1. Open `ios/WiFiSurvey.xcodeproj`.
2. Select the `WiFiSurvey` target.
3. Open Signing & Capabilities.
4. Choose your Apple developer team.
5. Connect the iPhone and tap Trust.
6. Select the iPhone as the run target.
7. Press Run.

Install from terminal after building:

```sh
xcodebuild -project ios/WiFiSurvey.xcodeproj -scheme WiFiSurvey -sdk iphoneos -configuration Debug build
xcrun devicectl device install app --device <DEVICE_ID> ~/Library/Developer/Xcode/DerivedData/WiFiSurvey-*/Build/Products/Debug-iphoneos/WiFiSurvey.app
```

If the app installs but does not open:

- On iPhone, go to Settings.
- Open General.
- Open VPN & Device Management.
- Trust the developer profile.
- Launch again.

The app may request:

- Bluetooth permission.
- Local Network permission.
- Camera permission.
- Notifications permission.

Bluetooth must be enabled for ESP32 BLE provisioning.

## Building for Verification

Useful local checks:

```sh
pio run -e esp32dev
pio run -e esp01s
xcodebuild -project ios/WiFiSurvey.xcodeproj -scheme WiFiSurvey -sdk iphonesimulator -configuration Debug build CODE_SIGNING_ALLOWED=NO
```

The current branch has been verified with:

- ESP32 PlatformIO build.
- ESP-01S PlatformIO build.
- iOS simulator build.
- iPhone device build/install/launch.

## Data Storage

The current app is local-first.

Most data is stored in:

- `UserDefaults` for Codable app state.
- App documents directory for imported project files.
- ESP LittleFS for the offline dashboard and, on ESP8266, saved Wi-Fi credentials.
- ESP32 Preferences for saved Wi-Fi credentials.

Important:

- There is no production backend yet.
- There is no real multi-user cloud sync yet.
- Demo users and permissions are local.
- Secure credentials should not be used for real client secrets until encryption and backend access control are implemented.

## Reports

The app can export survey/report data as JSON and related local artifacts.

Report content should include:

- Project name.
- Date/time.
- Areas.
- Devices.
- Hardware profiles.
- RSSI.
- Latency.
- Packet loss.
- Speed test.
- Channel congestion.
- Recommendations.
- Overall network score.

PDF export is optional and should not be overcomplicated unless the project has a clean PDF pipeline.

## Hardware Profiles and Calibration

ESP readings can differ from phones and laptops.

The app supports hardware profile and calibration concepts:

- Board model.
- Antenna type.
- Antenna gain.
- Calibration offset.
- Notes.

Recommended professional hardware:

- ESP32-S3-WROOM-1U with external antenna.
- ESP32-WROOM-32U with external antenna.
- Use identical boards when comparing areas.

iOS does not expose true Wi-Fi RSSI, so calibration compares ESP readings against practical phone performance such as latency and throughput, not fake iPhone dBm.

## Central Vacuum Planner

There is a utility for centralized vacuum installation planning.

Goal:

- Help installers calculate pipe layout constraints.
- Plan where stoppers or supports should be placed.
- Respect 90-degree elbow rules.
- Keep rough installation guidance inside the field app.

This is a utility, not part of the core Projects -> Areas -> Tasks flow.

## Known Limitations

- No production backend or cloud sync yet.
- Demo sign-in is local only.
- Permissions are local UI/store checks, not server-enforced.
- Secure vault needs real encryption and access control before production secret storage.
- ESP-01S does not support BLE provisioning.
- ESP32 firmware flash size is high on `esp32dev`.
- iOS Wi-Fi RSSI is not available to normal apps.
- RoomPlan requires LiDAR hardware.
- AR marker persistence depends on ARKit relocalization quality.
- Non-LiDAR mapping is less reliable than point-based marking.
- The offline web dashboard is older than the native app workflow and is mainly a fallback.

## GitHub Workflow

Current repository:

```text
https://github.com/Taranomn/Wifi-Analyzer.git
```

Current working branch:

```text
codex/smart-av-brand-and-workflow
```

Existing pull request:

```text
https://github.com/Taranomn/Wifi-Analyzer/pull/1
```

To continue work on another computer:

```sh
git clone https://github.com/Taranomn/Wifi-Analyzer.git
cd Wifi-Analyzer
git checkout codex/smart-av-brand-and-workflow
```

Then install Xcode and PlatformIO as needed.

## Suggested Next Steps

Highest-value product work:

1. Clean up the project screen so areas, tasks, files, and equipment are fast to reach.
2. Finish the task preset/category UX for Smart AV installation work.
3. Harden delete/edit permissions.
4. Add real backend sync.
5. Add encrypted credential vault.
6. Improve shift calendar visualization.
7. Improve project files with preview/open/share.
8. Make reports client-ready.
9. Keep AR and ESP Wi-Fi survey tools under Utilities until the core workflow is polished.

The core rule for future work:

**Do not let utilities, AR, or network diagnostics make the main workflow harder. The app should open into projects, show areas immediately, and let technicians add or complete tasks with minimal friction.**
