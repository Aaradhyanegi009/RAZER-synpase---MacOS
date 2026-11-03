import SwiftUI
import Combine
import CRazer

class RazerState: ObservableObject {
    @Published var isConnected: Bool = false
    @Published var dpi: Int = 1600
    @Published var pollingRate: Int = 1000
    @Published var brightness: Double = 100.0
    @Published var lightingMode: Int = 1 // 0: off, 1: static, 2: breathing, 3: reactive
    @Published var selectedColorHex: String = "#00E676"
    @Published var statusMessage: String = "Synchronized"
    @Published var isApplying: Bool = false
    @Published var showSavedToast: Bool = false
    @Published var toastText: String = "Saved to Onboard Memory"
    @Published var activeTab: Int = 0 // 0: All/Home, 1: DPI, 2: Polling/Gestures, 3: Lighting
    @Published var invertSwipeButtons: Bool = false
    @Published var scrollSpeed: Int = 3 // 1 (Slow) to 10 (Fast), 3 = Default (1.0x)
    @Published var invertScrollWheel: Bool = false
    
    private var timer: AnyCancellable?
    
    init() {
        loadKarabinerState()
        refreshFromHardware()
        
        timer = Timer.publish(every: 3.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkConnection()
            }
    }
    
    func checkConnection() {
        let connected = razer_is_connected()
        if self.isConnected != connected {
            self.isConnected = connected
            if connected {
                refreshFromHardware()
            }
        }
    }
    
    func refreshFromHardware() {
        let connected = razer_is_connected()
        self.isConnected = connected
        if connected {
            let hwDpi = Int(razer_get_dpi())
            if hwDpi >= 100 && hwDpi <= 6400 {
                self.dpi = hwDpi
            }
            let hwPoll = Int(razer_get_polling_rate())
            if [125, 500, 1000].contains(hwPoll) {
                self.pollingRate = hwPoll
            }
            let hwBright = Int(razer_get_led_brightness())
            let pct = round((Double(hwBright) / 255.0) * 100.0 / 5.0) * 5.0
            self.brightness = max(0.0, min(100.0, pct))
            if hwBright == 0 {
                self.lightingMode = 0
            }
        }
    }
    
    func setDPI(_ newDPI: Int) {
        let clamped = max(100, min(6400, (newDPI / 100) * 100))
        self.dpi = clamped
        applyDPI()
        triggerToast("\(clamped) DPI Applied")
    }
    
    func setPollingRate(_ rate: Int) {
        self.pollingRate = rate
        applyPollingRate()
        triggerToast("\(rate) Hz Polling Active")
    }
    
    func setLightingMode(_ mode: Int) {
        self.lightingMode = mode
        if mode != 0 && self.brightness == 0 {
            self.brightness = 100.0
        }
        applyLighting()
        let names = [0: "LED Off", 1: "Static LED", 2: "Breathing LED", 3: "Reactive Click LED"]
        triggerToast(names[mode] ?? "Lighting Updated")
    }
    
    func setBrightness(_ val: Double) {
        self.brightness = max(0, min(100, val))
        if self.brightness == 0 {
            self.lightingMode = 0
        } else if self.lightingMode == 0 {
            self.lightingMode = 1
        }
        applyLighting()
    }
    
    func selectColorPreset(hex: String, targetBrightness: Double) {
        self.selectedColorHex = hex
        if self.lightingMode == 0 {
            self.lightingMode = 1
        }
        self.brightness = targetBrightness
        applyLighting()
        triggerToast("LED Intensity \(Int(targetBrightness))% Applied")
    }
    
    func toggleSwipeDirection() {
        invertSwipeButtons.toggle()
        syncKarabinerConfig()
        triggerToast(invertSwipeButtons ? "Buttons 4/5 Inverted" : "Buttons 4/5 Standard")
    }
    
    func toggleScrollWheelDirection() {
        invertScrollWheel.toggle()
        syncKarabinerConfig()
        triggerToast(invertScrollWheel ? "Scroll Wheel Reversed" : "Scroll Wheel Standard")
    }
    
    func setScrollSpeed(_ speed: Int) {
        let clamped = max(1, min(10, speed))
        guard clamped != self.scrollSpeed else { return }
        self.scrollSpeed = clamped
        applyScrollSpeed()
        triggerToast("Scroll Speed \(clamped)x Applied")
    }
    
    var currentWheelMultiplier: Double {
        let multTable: [Int: Double] = [
            1: 0.5,
            2: 0.75,
            3: 1.0,
            4: 1.35,
            5: 1.75,
            6: 2.2,
            7: 2.7,
            8: 3.3,
            9: 4.0,
            10: 5.0
        ]
        return multTable[self.scrollSpeed] ?? 1.0
    }
    
    func applyScrollSpeed() {
        let accelTable: [Int: Int] = [
            1: 5120,
            2: 12288,
            3: 20480,
            4: 32768,
            5: 45056,
            6: 65536,
            7: 98304,
            8: 131072,
            9: 163840,
            10: 196608
        ]
        let accel = accelTable[self.scrollSpeed] ?? 20480
        let scale = Double(accel) / 65536.0
        
        // 1. Update Karabiner DriverKit hardware wheel multiplier atomically
        syncKarabinerConfig()
        
        // 2. Update macOS HIDMouseScrollAcceleration across all pointing drivers (Karabiner VirtualHIDPointing + Razer)
        DispatchQueue.global(qos: .userInitiated).async {
            let p1 = Process()
            p1.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
            p1.arguments = [
                "property",
                "--set",
                "{\"HIDMouseScrollAcceleration\":\(accel),\"HIDScrollAcceleration\":\(accel)}"
            ]
            try? p1.run()
            p1.waitUntilExit()
            
            let p2 = Process()
            p2.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            p2.arguments = ["write", "-g", "com.apple.scrollwheel.scaling", "-float", String(format: "%.4f", scale)]
            try? p2.run()
            p2.waitUntilExit()
        }
    }
    
    func applyDPI() {
        _ = razer_set_dpi(UInt16(self.dpi))
    }
    
    func applyPollingRate() {
        _ = razer_set_polling_rate(UInt16(self.pollingRate))
    }
    
    func applyLighting() {
        let (r, g, b) = hexToRGB(self.selectedColorHex)
        let bVal = UInt8((self.brightness / 100.0) * 255.0)
        _ = razer_set_led(UInt8(self.lightingMode), bVal, r, g, b)
    }
    
    func applyAllSettings() {
        isApplying = true
        applyDPI()
        applyPollingRate()
        applyLighting()
        applyScrollSpeed()
        triggerToast("Saved to Onboard Hardware Memory")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            self.isApplying = false
        }
    }
    
    func triggerToast(_ message: String) {
        self.toastText = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            self.showSavedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeInOut(duration: 0.25)) {
                self.showSavedToast = false
            }
        }
    }
    
    private func loadKarabinerState() {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/karabiner/karabiner.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profiles = json["profiles"] as? [[String: Any]],
              let first = profiles.first,
              let devices = first["devices"] as? [[String: Any]] else { return }
        
        for dev in devices {
            if let ids = dev["identifiers"] as? [String: Any],
               let vid = ids["vendor_id"] as? Int, vid == 5426 {
                if let flip = dev["mouse_flip_vertical_wheel"] as? Bool {
                    self.invertScrollWheel = flip
                }
                if let mult = dev["pointing_motion_wheels_multiplier"] as? Double {
                    let multMap: [(Int, Double)] = [
                        (1, 0.5), (2, 0.75), (3, 1.0), (4, 1.35), (5, 1.75),
                        (6, 2.2), (7, 2.7), (8, 3.3), (9, 4.0), (10, 5.0)
                    ]
                    if let closest = multMap.min(by: { abs($0.1 - mult) < abs($1.1 - mult) }) {
                        self.scrollSpeed = closest.0
                    }
                }
            }
        }
    }

    private func syncKarabinerConfig() {
        let btn4Key = invertSwipeButtons ? "right_arrow" : "left_arrow"
        let btn5Key = invertSwipeButtons ? "left_arrow" : "right_arrow"
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let path = "\(home)/.config/karabiner/karabiner.json"
        
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              var profiles = json["profiles"] as? [[String: Any]],
              !profiles.isEmpty else { return }
        
        let manipulators: [[String: Any]] = [
            [
                "type": "basic",
                "from": [
                    "pointing_button": "button4",
                    "modifiers": ["optional": ["caps_lock"]]
                ],
                "to": [
                    ["key_code": btn4Key, "modifiers": ["left_control"]]
                ]
            ],
            [
                "type": "basic",
                "from": [
                    "pointing_button": "button5",
                    "modifiers": ["optional": ["caps_lock"]]
                ],
                "to": [
                    ["key_code": btn5Key, "modifiers": ["left_control"]]
                ]
            ]
        ]
        
        var complex = (profiles[0]["complex_modifications"] as? [String: Any]) ?? [:]
        complex["rules"] = [[
            "description": "Mouse Button 4/5 Space Switching",
            "manipulators": manipulators
        ]]
        profiles[0]["complex_modifications"] = complex
        
        // Update Razer DeathAdder Essential device entry with wheel multiplier & flip
        var devices = (profiles[0]["devices"] as? [[String: Any]]) ?? []
        var foundRazer = false
        for i in 0..<devices.count {
            if let ids = devices[i]["identifiers"] as? [String: Any],
               let vid = ids["vendor_id"] as? Int, vid == 5426 {
                devices[i]["pointing_motion_wheels_multiplier"] = currentWheelMultiplier
                devices[i]["mouse_flip_vertical_wheel"] = invertScrollWheel
                foundRazer = true
            }
        }
        if !foundRazer {
            devices.append([
                "identifiers": [
                    "is_pointing_device": true,
                    "product_id": 152,
                    "vendor_id": 5426
                ],
                "ignore": false,
                "pointing_motion_wheels_multiplier": currentWheelMultiplier,
                "mouse_flip_vertical_wheel": invertScrollWheel,
                "simple_modifications": []
            ])
        }
        profiles[0]["devices"] = devices
        json["profiles"] = profiles
        
        if let outData = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]) {
            try? outData.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
    }
    
    private func hexToRGB(_ hex: String) -> (UInt8, UInt8, UInt8) {
        var cString: String = hex.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if cString.hasPrefix("#") {
            cString.remove(at: cString.startIndex)
        }
        if cString.count != 6 {
            return (0, 255, 0)
        }
        var rgbValue: UInt64 = 0
        Scanner(string: cString).scanHexInt64(&rgbValue)
        return (
            UInt8((rgbValue & 0xFF0000) >> 16),
            UInt8((rgbValue & 0x00FF00) >> 8),
            UInt8(rgbValue & 0x0000FF)
        )
    }
}
