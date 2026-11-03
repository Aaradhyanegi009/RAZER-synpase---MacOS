# Razer Synapse - macOS

Native macOS control app for the Razer DeathAdder Essential (VID `0x1532`, PID `0x0098`), built in Swift, AppKit, SwiftUI, and IOKit.

Unlike Electron-based utilities that drop USB connections when connected through USB-C hubs or adapters, this app talks directly to `IOUSBDeviceInterface` via shared USB control transfers (`SET_REPORT` / `GET_REPORT`) without seizing the HID interface.

## Features

- **USB Hub Safe**: Uses shared `IOUSBDeviceInterface` control transfers so the mouse never disconnects through USB-C hubs or docks.
- **DPI Sensitivity**: Hardware presets (`400`, `800`, `1600`, `3200`, `6400` DPI) and a continuous `100` to `6400` DPI slider written directly to onboard memory.
- **Polling Rate**: Switch between `125 Hz`, `500 Hz`, and `1000 Hz` response intervals.
- **Scroll Wheel Speed**: Adjust macOS HID scroll wheel acceleration from `1x` (precision) to `10x` (fast) in real time via `hidutil`.
- **Extended Matrix Lighting**: Full support for the DeathAdder Essential `0x0098` Extended Matrix protocol (`Class 0x0F`, `Transaction ID 0x3F`), including `Static`, `Breathing`, `Reactive`, `Off`, and `0-100%` hardware LED brightness.
- **3-Finger Spaces Swipe**: Integrates with Karabiner-Elements to bind Mouse Buttons 4 and 5 to macOS desktop space switching (`Control + Left/Right Arrow`) with a toggle for standard or inverted direction.

## Build from Source

Requirements: macOS 13.0 or later and Xcode Command Line Tools (`swift`).

```bash
git clone https://github.com/Aaradhyanegi009/RAZER-synpase---MacOS.git
cd RAZER-synpase---MacOS
swift build -c release
```

To install into `/Applications/Synapse.app`:

```bash
cp .build/release/SynapseMac /Applications/Synapse.app/Contents/MacOS/SynapseMac
open /Applications/Synapse.app
```

## Project Structure

- `Sources/CRazer/`: C bridge implementing Razer USB HID feature report packets, CRC checksums, and Extended Matrix LED commands over `IOKit`.
- `Sources/SynapseMac/`: SwiftUI interface and hardware state controller.
- `Resources/`: Official app icon (`AppIcon.icns`) and vector assets.

## License

MIT
