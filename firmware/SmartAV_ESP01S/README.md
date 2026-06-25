# SmartAV ESP-01S Firmware

Use this sketch when uploading ESP-01S satellite boards from Arduino IDE.

## Arduino IDE setup

1. Install the ESP8266 board package.
2. Select board: `Generic ESP8266 Module` or `Generic ESP8266 ESP-01 1M`.
3. Flash size: `1MB`.
4. Upload speed: `115200`.
5. Install libraries from Library Manager:
   - `ArduinoJson`
   - `ESP8266Ping`

## Behavior

On boot, an ESP-01S with no saved Wi-Fi credentials scans for `SmartAV-Hub-*`.
When it finds the ESP32 WROOM hub, it connects with password `smartavhub` and
posts its status to the hub every 5 seconds.

Serial Monitor at `115200` should show:

```text
ESP-01S hub scan: looking for SmartAV-Hub-*
ESP-01S hub scan: joining SmartAV-Hub-34E3EC rssi=-45
Connected to SmartAV-Hub-34E3EC at 192.168.4.x
ESP-01S hub register: gateway=192.168.4.1 response=200
```

If it prints `no SmartAV hub found`, the ESP-01S cannot see the ESP32 WROOM hub.
If it connects but registration response is not `200`, the ESP32 hub or HTTP
registration route needs to be checked.
