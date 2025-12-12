# NovaTV

[![Build and Release](https://github.com/kilabyte/NovaIPTV/actions/workflows/build-release.yml/badge.svg)](https://github.com/kilabyte/NovaIPTV/actions/workflows/build-release.yml)
[![Release](https://img.shields.io/github/v/release/kilabyte/NovaIPTV?include_prereleases)](https://github.com/kilabyte/NovaIPTV/releases)
[![License](https://img.shields.io/github/license/kilabyte/NovaIPTV)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20iOS%20%7C%20Android%20%7C%20Windows%20%7C%20Linux-blue)]()

A modern, cross-platform IPTV player built with Flutter. I was frustrated with the existing IPTV apps out there—clunky interfaces, poor EPG support, and apps that felt like they were designed in 2010. So I built NovaTV to be the IPTV player I actually wanted to use.

## Why NovaTV?

Most IPTV players are either:
- Overcomplicated with features nobody uses
- Stuck with outdated UIs that hurt to look at
- Missing proper EPG (TV Guide) integration
- Not truly cross-platform

NovaTV focuses on what matters: a clean interface, reliable playback, and a TV Guide that actually works.

## Features

- **Clean, Modern UI** — Dark theme with a TiViMate-inspired sidebar layout
- **M3U Playlist Support** — Load playlists from any URL or local file
- **XMLTV EPG Integration** — Full TV Guide with 7-day program data
- **Smart Search** — Find channels by name, category, or search upcoming shows by title
- **Favorites** — Quick access to your most-watched channels
- **Mini-Player** — Keep watching while browsing (PiP support)
- **Cross-Platform** — macOS, iOS, Android, Windows, Linux

## Installation

### macOS

Download the latest release from the [Releases](../../releases) page, or build from source:

```bash
flutter build macos --release
```

### iOS

```bash
flutter build ios --release
```

### Android

```bash
flutter build apk --release
```

### Windows

```bash
flutter build windows --release
```

### Linux

```bash
flutter build linux --release
```

## Building from Source

### Prerequisites

- Flutter 3.x or later
- Dart 3.x or later
- For macOS: Xcode 15+
- For iOS: Xcode 15+ and CocoaPods
- For Android: Android SDK

### Setup

```bash
# Clone the repository
git clone https://github.com/yourusername/novatv.git
cd novatv

# Install dependencies
flutter pub get

# Run in debug mode
flutter run -d macos  # or ios, android, windows, linux

# Build for release
flutter build macos --release
```

### Regenerating Code

If you modify any Hive models (files with `@HiveType` annotations), regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Usage

### Adding a Playlist

1. Go to **Settings** → **Add Playlist**
2. Enter your M3U playlist URL
3. Optionally add an XMLTV EPG URL for TV Guide data
4. Give it a name and save

### TV Guide

The TV Guide shows 7 days of programming data (yesterday + today + 5 days ahead). Scroll horizontally to browse different times, or tap the calendar icon to jump to a specific day.

### Search

Search finds both:
- **Channels** — by name, TVG name, or category
- **Shows** — by program title (current and upcoming)

Program results show a "SHOW" badge with the channel name and air time.

## Architecture

NovaTV follows Clean Architecture with feature-based organization:

```
lib/
├── config/           # Theme, routes, app configuration
├── core/             # Shared utilities, error handling
├── features/
│   ├── playlist/     # M3U parsing, channel management
│   ├── epg/          # XMLTV parsing, TV Guide
│   ├── player/       # Video playback, mini-player
│   ├── search/       # Channel & program search
│   ├── settings/     # App preferences
│   └── home/         # Dashboard screen
└── shared/           # Reusable widgets
```

### Tech Stack

- **Flutter** — Cross-platform UI
- **Riverpod** — State management
- **Hive CE** — Local storage
- **media_kit** — Video playback (MPV-based)
- **go_router** — Navigation
- **dio** — HTTP client

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

BSD 3-Clause License — see [LICENSE](LICENSE) for details.