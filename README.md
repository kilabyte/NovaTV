# NovaTV

[![Build and Release](https://github.com/kilabyte/NovaTV/actions/workflows/build-release.yml/badge.svg)](https://github.com/kilabyte/NovaTV/actions/workflows/build-release.yml)
[![Release](https://img.shields.io/github/v/release/kilabyte/NovaTV?include_prereleases)](https://github.com/kilabyte/NovaTV/releases)
[![License](https://img.shields.io/github/license/kilabyte/NovaTV)](LICENSE)

A cross-platform IPTV player built with Flutter. Supports M3U playlists and XMLTV EPG data.

## Features

- M3U playlist support (URL or local file)
- XMLTV EPG integration with 7-day TV Guide
- Channel search and favorites
- Mini-player / picture-in-picture
- Dark theme UI

## Platforms

- macOS
- iOS
- Android
- Windows
- Linux

## Installation

Download the latest build from the [Releases](https://github.com/kilabyte/NovaTV/releases) page.

## Building from Source

Requires Flutter 3.x and Dart 3.x.

```bash
git clone https://github.com/kilabyte/NovaTV.git
cd NovaTV
flutter pub get
flutter run -d macos
```

Build for release:

```bash
flutter build macos --release
flutter build ios --release
flutter build apk --release
flutter build windows --release
flutter build linux --release
```

If you modify Hive models, regenerate the adapters:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Usage

1. Go to Settings and add a playlist (M3U URL)
2. Optionally add an XMLTV EPG URL for the TV Guide
3. Browse channels and start watching

## Project Structure

```
lib/
├── config/       # Theme, routes, configuration
├── core/         # Shared utilities
├── features/
│   ├── playlist/ # M3U parsing, channels
│   ├── epg/      # XMLTV parsing, TV Guide
│   ├── player/   # Video playback
│   ├── search/   # Search functionality
│   ├── settings/ # App preferences
│   └── home/     # Dashboard
└── shared/       # Reusable widgets
```

## Dependencies

- Flutter / Dart
- Riverpod (state management)
- Hive CE (local storage)
- media_kit (video playback)
- go_router (navigation)
- dio (HTTP)

## License

BSD 3-Clause License. See [LICENSE](LICENSE).
