import SwiftUI
import AppKit

struct ContentView: View {
    @ObservedObject var state: RazerState
    
    // Color & Hardware Intensity Presets
    let colorPresets: [(name: String, hex: String, brightness: Double, color: Color)] = [
        ("Razer Green · 100%", "#00E676", 100.0, Color(hex: "00E676")),
        ("Neon Cyan · 80%", "#00E5FF", 80.0, Color(hex: "00E5FF")),
        ("Ultraviolet · 60%", "#9D4EDD", 60.0, Color(hex: "A855F7")),
        ("Amber Sun · 40%", "#FF9100", 40.0, Color(hex: "FF9100")),
        ("Frost Dim · 20%", "#FFFFFF", 20.0, Color.white)
    ]
    
    let dpiPresets: [Int] = [400, 800, 1600, 3200, 6400]
    let pollingPresets: [Int] = [125, 500, 1000]
    
    var activeThemeColor: Color {
        Color(hex: state.selectedColorHex)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            Color(hex: "0A0D0C")
                .ignoresSafeArea()
            
            // Dynamic Ambient Radial Glow at top matching selected color
            VStack {
                HStack {
                    Spacer()
                    RadialGradient(
                        colors: [activeThemeColor.opacity(0.18), Color.clear],
                        center: .topTrailing,
                        startRadius: 15,
                        endRadius: 290
                    )
                    .frame(width: 340, height: 250)
                }
                Spacer()
            }
            .ignoresSafeArea()
            
            // Pinned Header + Scrollable Cards VStack
            VStack(alignment: .leading, spacing: 0) {
                // --- PINNED HEADER (Never scrolls under traffic lights) ---
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(tabSubtitle)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(Color(hex: "8E9491"))
                        Spacer()
                        
                        // Official Razer 3-Headed Snake Logo Badge
                        ZStack {
                            Circle()
                                .fill(Color(hex: "141A17"))
                                .frame(width: 42, height: 42)
                                .overlay(
                                    Circle()
                                        .stroke(activeThemeColor.opacity(0.45), lineWidth: 1.5)
                                )
                            if let logoPath = Bundle.main.path(forResource: "razer_logo", ofType: "png"),
                               let nsImg = NSImage(contentsOfFile: logoPath) {
                                Image(nsImage: nsImg)
                                    .resizable()
                                    .interpolation(.high)
                                    .scaledToFit()
                                    .frame(width: 28, height: 28)
                            } else {
                                Image(systemName: "bolt.circle.fill")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(activeThemeColor)
                            }
                        }
                    }
                    
                    Text(tabTitle)
                        .font(.system(size: 38, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(-0.6)
                    
                    // Status Pill Badges Row
                    HStack(spacing: 8) {
                        // Pill 1: Connection & Port
                        HStack(spacing: 6) {
                            Circle()
                                .fill(state.isConnected ? Color(hex: "00E676") : Color.red)
                                .frame(width: 7, height: 7)
                            Text(state.isConnected ? "USB Hub · Active" : "Searching...")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "D8DEDC"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "161918"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                        
                        // Pill 2: Current Hardware State
                        HStack(spacing: 6) {
                            Circle()
                                .fill(activeThemeColor)
                                .frame(width: 7, height: 7)
                            Text("\(state.pollingRate)Hz · \(state.dpi) DPI · \(state.lightingMode == 0 ? "LED Off" : "\(Int(state.brightness))%")")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "D8DEDC"))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "161918"))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.06), lineWidth: 1))
                        
                        Spacer()
                        
                        // Sync from Hardware Button
                        Button(action: {
                            state.refreshFromHardware()
                            state.triggerToast("Synced from Mouse Hardware")
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(Color(hex: "A5ACA8"))
                                .padding(8)
                                .background(Color(hex: "161918"))
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.06), lineWidth: 1))
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)
                    }
                    .padding(.top, 2)
                }
                .padding(.horizontal, 20)
                .padding(.top, 30)
                .padding(.bottom, 12)
                
                // Main Content ScrollView
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        
                        // --- TAB-FILTERED CARDS ---
                        if state.activeTab == 0 || state.activeTab == 1 {
                            dpiCard
                        }
                        
                        if state.activeTab == 1 {
                            dpiFineTuneCard
                        }
                        
                        if state.activeTab == 0 || state.activeTab == 2 {
                            pollingCard
                        }
                        
                        if state.activeTab == 0 || state.activeTab == 1 || state.activeTab == 2 {
                            scrollWheelCard
                        }
                        
                        if state.activeTab == 0 || state.activeTab == 3 {
                            lightingCard
                        }
                        
                        if state.activeTab == 0 || state.activeTab == 2 {
                            gestureCard
                        }
                        
                        // Bottom padding so dock never obscures content
                        Spacer().frame(height: 95)
                    }
                    .padding(.top, 2)
                }
            }
            
            // --- FLOATING SQUIRCLE DOCK (All 4 Tab Buttons + FAB Sync Button Active) ---
            HStack(spacing: 12) {
                HStack(spacing: 18) {
                    DockButton(icon: "house.fill", label: "All", isSelected: state.activeTab == 0, accent: activeThemeColor) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            state.activeTab = 0
                        }
                    }
                    DockButton(icon: "bolt.fill", label: "DPI", isSelected: state.activeTab == 1, accent: activeThemeColor) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            state.activeTab = 1
                        }
                    }
                    DockButton(icon: "speedometer", label: "Hz", isSelected: state.activeTab == 2, accent: activeThemeColor) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            state.activeTab = 2
                        }
                    }
                    DockButton(icon: "sun.max.fill", label: "LED", isSelected: state.activeTab == 3, accent: activeThemeColor) {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                            state.activeTab = 3
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(hex: "161918"))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.09), lineWidth: 1))
                .shadow(color: Color.black.opacity(0.45), radius: 12, x: 0, y: 6)
                
                Spacer()
                
                // Floating Action Button (FAB) -> Burn to Onboard Memory
                Button(action: {
                    state.applyAllSettings()
                }) {
                    ZStack {
                        Circle()
                            .fill(activeThemeColor)
                            .frame(width: 52, height: 52)
                            .shadow(color: activeThemeColor.opacity(0.35), radius: 10, x: 0, y: 4)
                        
                        if state.isApplying {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 19, weight: .bold))
                                .foregroundColor(.black)
                        }
                    }
                }
                .buttonStyle(PlainButtonStyle())
                .focusable(false)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
            
            // Toast Notification
            if state.showSavedToast {
                VStack {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(activeThemeColor)
                        Text(state.toastText)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .background(Color(hex: "1C211F"))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(activeThemeColor.opacity(0.4), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .padding(.top, 14)
            }
        }
        .frame(minWidth: 430, idealWidth: 440, maxWidth: 500, minHeight: 740, idealHeight: 800, maxHeight: 880)
    }
    
    var tabTitle: String {
        switch state.activeTab {
        case 1: return "Sensitivity"
        case 2: return "Performance"
        case 3: return "Lighting"
        default: return "Synapse"
        }
    }
    
    var tabSubtitle: String {
        switch state.activeTab {
        case 1: return "Optical Sensor Calibration"
        case 2: return "Polling Rate & Space Gestures"
        case 3: return "Hardware LED Mode & Intensity"
        default: return "Razer DeathAdder Essential"
        }
    }
    
    // MARK: - Card 1: DPI Sensitivity
    var dpiCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "292652"))
                        .frame(width: 42, height: 42)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(hex: "A5B4FC"))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("DPI Sensitivity")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    HStack(spacing: 4) {
                        Text("Active:")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "8E9491"))
                        Text("+\(state.dpi) DPI")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(activeThemeColor)
                        Text("· 1:1 raw")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Color(hex: "8E9491"))
                    }
                }
                Spacer()
            }
            
            // Preset Pills
            HStack(spacing: 8) {
                ForEach(dpiPresets, id: \.self) { val in
                    Button(action: {
                        state.setDPI(val)
                    }) {
                        Text(String(val))
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(state.dpi == val ? .white : Color(hex: "8E9491"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                state.dpi == val ?
                                    activeThemeColor.opacity(0.25) :
                                    Color(hex: "1F2321")
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        state.dpi == val ? activeThemeColor.opacity(0.65) : Color.white.opacity(0.04),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable(false)
                }
            }
            
            // Custom DPI Slider
            VStack(spacing: 4) {
                Slider(
                    value: Binding(
                        get: { Double(state.dpi) },
                        set: { state.setDPI(Int($0)) }
                    ),
                    in: 100...6400,
                    step: 100
                )
                .accentColor(activeThemeColor)
                
                HStack {
                    Text("100 DPI")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "6A706D"))
                    Spacer()
                    Text("6400 DPI Max")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "6A706D"))
                }
            }
        }
        .padding(18)
        .background(Color(hex: "161918"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // Extra card for Tab 1 (DPI Fine Stepper)
    var dpiFineTuneCard: some View {
        HStack(spacing: 10) {
            Button(action: { state.setDPI(state.dpi - 100) }) {
                Text("-100 DPI")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1F2321"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(false)
            
            Button(action: { state.setDPI(1600) }) {
                Text("Reset 1600")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(activeThemeColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(activeThemeColor.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(false)
            
            Button(action: { state.setDPI(state.dpi + 100) }) {
                Text("+100 DPI")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "1F2321"))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(false)
        }
        .padding(16)
        .background(Color(hex: "161918"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Card 2: Polling Rate
    var pollingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(state.pollingRate) Hz Polling")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(-0.3)
                    
                    Text("Response interval: \(state.pollingRate == 1000 ? "1.0 ms" : (state.pollingRate == 500 ? "2.0 ms" : "8.0 ms")) ultra-low latency.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "A3E5B5"))
                }
                Spacer()
            }
            
            HStack(spacing: 10) {
                ForEach(pollingPresets, id: \.self) { rate in
                    Button(action: {
                        state.setPollingRate(rate)
                    }) {
                        HStack(spacing: 4) {
                            Text("\(rate) Hz")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            if state.pollingRate == rate {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 5, height: 5)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            state.pollingRate == rate ?
                                Color.white.opacity(0.25) :
                                Color.black.opacity(0.25)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(state.pollingRate == rate ? 0.45 : 0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable(false)
                }
            }
        }
        .padding(18)
        .background(Color(hex: "0E381C"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(hex: "00E676").opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Card 3: Aura & Lighting
    var lightingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "342554"))
                        .frame(width: 42, height: 42)
                    Image(systemName: "sun.max.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(activeThemeColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Aura & Lighting")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Logo & Wheel LED · Extended Matrix")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(Color(hex: "8E9491"))
                }
                Spacer()
            }
            
            // 4 Working Hardware Modes: Static, Breathing, Reactive Click, Off
            HStack(spacing: 6) {
                let modes = [("Static", 1), ("Breathing", 2), ("Reactive", 3), ("Off", 0)]
                ForEach(modes, id: \.1) { name, code in
                    Button(action: {
                        state.setLightingMode(code)
                    }) {
                        Text(name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(state.lightingMode == code ? .white : Color(hex: "8E9491"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                state.lightingMode == code ?
                                    activeThemeColor.opacity(0.28) :
                                    Color(hex: "1F2321")
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        state.lightingMode == code ? activeThemeColor.opacity(0.65) : Color.white.opacity(0.04),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable(false)
                }
            }
            
            // Brightness Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("LED Brightness")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8E9491"))
                    Spacer()
                    Text("\(Int(state.brightness))%")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(activeThemeColor)
                }
                
                Slider(
                    value: Binding(
                        get: { state.brightness },
                        set: { state.setBrightness($0) }
                    ),
                    in: 0...100,
                    step: 5
                )
                .accentColor(activeThemeColor)
            }
            
            // Theme & Intensity Swatches
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Aura Theme & LED Intensity Presets")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8E9491"))
                    Spacer()
                    Text(currentColorName)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(activeThemeColor)
                }
                
                HStack(spacing: 14) {
                    ForEach(colorPresets, id: \.hex) { preset in
                        Button(action: {
                            state.selectColorPreset(hex: preset.hex, targetBrightness: preset.brightness)
                        }) {
                            ZStack {
                                Circle()
                                    .fill(preset.color)
                                    .frame(width: 30, height: 30)
                                    .shadow(color: preset.color.opacity(0.45), radius: 6, x: 0, y: 0)
                                
                                if state.selectedColorHex == preset.hex {
                                    Circle()
                                        .stroke(Color.white, lineWidth: 2.5)
                                        .frame(width: 35, height: 35)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        .focusable(false)
                    }
                    Spacer()
                }
            }
        }
        .padding(18)
        .background(Color(hex: "161918"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    var currentColorName: String {
        colorPresets.first(where: { $0.hex == state.selectedColorHex })?.name ?? "Custom"
    }
    
    // MARK: - Card 3.5: Scroll Wheel Speed Card
    var scrollWheelCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(hex: "1C3835"))
                        .frame(width: 42, height: 42)
                    Image(systemName: "computermouse.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(activeThemeColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Scroll Wheel Speed")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Active: Level \(state.scrollSpeed) / 10 · HID Acceleration")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "8E9491"))
                }
                Spacer()
            }
            
            // Quick Scroll Speed Presets
            let scrollPresets = [("Slow", 1), ("Default", 3), ("Medium", 5), ("Fast", 8), ("Max", 10)]
            HStack(spacing: 8) {
                ForEach(scrollPresets, id: \.1) { label, speed in
                    Button(action: {
                        state.setScrollSpeed(speed)
                    }) {
                        Text("\(label) \(speed)x")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(state.scrollSpeed == speed ? .white : Color(hex: "8E9491"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                state.scrollSpeed == speed ?
                                    activeThemeColor.opacity(0.26) :
                                    Color(hex: "1F2321")
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        state.scrollSpeed == speed ? activeThemeColor.opacity(0.65) : Color.white.opacity(0.04),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .focusable(false)
                }
            }
            
            // Smooth 1-10 Slider
            VStack(spacing: 3) {
                Slider(
                    value: Binding(
                        get: { Double(state.scrollSpeed) },
                        set: { state.setScrollSpeed(Int($0.rounded())) }
                    ),
                    in: 1...10,
                    step: 1
                )
                .accentColor(activeThemeColor)
                
                HStack {
                    Text("1x Precision")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "6E7571"))
                    Spacer()
                    Text("10x Hyper Scroll")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(Color(hex: "6E7571"))
                }
            }
        }
        .padding(18)
        .background(Color(hex: "161918"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - Card 4: Gestures (Karabiner Space Swipe Status + Direction Flip)
    var gestureCard: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "292652"))
                    .frame(width: 42, height: 42)
                Image(systemName: "hand.draw.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "A5B4FC"))
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text("3-Finger Spaces Swipe")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(state.invertSwipeButtons ? "Btn 4 → Right · Btn 5 → Left" : "Btn 4 → Left · Btn 5 → Right")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(Color(hex: "8E9491"))
            }
            Spacer()
            
            Button(action: {
                state.toggleSwipeDirection()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 11, weight: .bold))
                    Text(state.invertSwipeButtons ? "Inverted" : "Standard")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
                .foregroundColor(activeThemeColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(activeThemeColor.opacity(0.15))
                .clipShape(Capsule())
            }
            .buttonStyle(PlainButtonStyle())
            .focusable(false)
        }
        .padding(16)
        .background(Color(hex: "161918"))
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// Dock Button Component
struct DockButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let accent: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                if isSelected {
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                }
            }
            .foregroundColor(isSelected ? .black : Color(hex: "7B827E"))
            .padding(.horizontal, isSelected ? 12 : 8)
            .padding(.vertical, 8)
            .background(isSelected ? accent : Color.clear)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .focusable(false)
    }
}

// Color Hex Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 230, 118)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
