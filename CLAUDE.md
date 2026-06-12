# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Git Remotes

- **origin** (`git.kilabyte.io`) - Private personal GitLab, primary development
- **github** (`github.com/kilabyte/NovaTV`) - Public repository, releases published here

## Releases

Releases are built and published to GitHub via GitHub Actions:

```bash
# Create and push a version tag to trigger a release
git tag v1.0.1
git push github v1.0.1
```

The CI workflow builds for Android (APK/AAB), Linux, Windows, macOS, and iOS, then uploads all artifacts to GitHub Releases.

### macOS CI Build Notes

The macOS build uses **unsigned code** (Gatekeeper bypass) since we don't have signing certificates in CI:
- Uses `xcodebuild` directly with `CODE_SIGN_IDENTITY=""`, `CODE_SIGNING_REQUIRED=NO`, `CODE_SIGNING_ALLOWED=NO`
- App bundle path: `build/macos/Build/Products/Release/NovaTV.app`
- Users must right-click → Open to bypass Gatekeeper on first launch

To add proper signing/notarization later, you'd need these GitHub secrets:
- `MACOS_CERTIFICATE` - Base64 encoded .p12 "Developer ID Application" certificate
- `MACOS_CERTIFICATE_PWD` - Certificate password
- `MACOS_CODESIGN_ID` - e.g., "Developer ID Application: Your Name (TEAMID)"
- `MACOS_NOTARY_USER`, `MACOS_TEAM_ID`, `MACOS_NOTARY_PWD` - For notarization

## Slash Commands

- `/ship-it` - Bump app version and build number, commit, push to both remotes, and tag to trigger the GitHub Actions release

## Project Overview

Nova IPTV is a cross-platform IPTV player built with Flutter. It supports M3U playlists, XMLTV EPG data, and targets macOS (primary), iOS, Android, Windows, Linux, and Web.

**Bundle ID:** `io.kilabyte.novatv` (all platforms)

## Build Commands

```bash
# Run in debug mode
flutter run -d macos    # or: ios, android, windows, linux, chrome

# Build release
flutter build macos --release
flutter build ios --release
flutter build apk --release      # Android
flutter build windows --release
flutter build linux --release
# flutter build web --release    # not currently supported — see "Web Platform" below

# Clean build (recommended when assets/icons change)
flutter clean && flutter build macos --release

# Analyze code
flutter analyze

# Run tests
flutter test

# Regenerate Hive adapters after modifying @HiveType models
dart run build_runner build --delete-conflicting-outputs
```

## Web Platform

Web is not currently a supported target. `dart:io` is imported unconditionally
in `player_screen.dart`, `xmltv_parser.dart`, and `window_service.dart`, so
`flutter build web` will fail. Restoring web support would require:

1. Split each `dart:io`-using file into `*_stub.dart` / `*_native.dart` /
   `*_web.dart` and re-export via `if (dart.library.html)` conditional imports
2. Add an `HtmlElementView`-backed player for the web mini/full player
3. Host HLS.js from `web/index.html` and add `web/env.js` default-playlist config
4. Wire `ui_web.platformViewRegistry.registerViewFactory` for the video element

Track as a feature if needed; do not advertise web support in release notes
until the conditional-import split exists.

## Release Build Locations

- **macOS:** `build/macos/Build/Products/Release/NovaTV.app`
- **iOS:** Archive via Xcode → Organizer
- **Android:** `build/app/outputs/flutter-apk/app-release.apk`
- **Windows:** `build/windows/x64/runner/Release/`
- **Linux:** `build/linux/x64/release/bundle/`

## App Store Deployment (macOS)

```bash
flutter clean && flutter build macos --release
open macos/Runner.xcworkspace
# In Xcode: Product → Archive → Distribute App → App Store Connect
```

Required Info.plist key for Mac App Store: `LSApplicationCategoryType` = `public.app-category.video`

## Architecture

### Clean Architecture Layers

Each feature follows clean architecture with three layers:
- **domain/**: Entities, repository interfaces, and use cases
- **data/**: Models (with Hive adapters), data sources, repository implementations, parsers
- **presentation/**: Screens, widgets, and Riverpod providers

### Key Features (lib/features/)

- **playlist/**: M3U parsing, channel management, favorites
- **epg/**: XMLTV parsing, program guide data, TV Guide screen
- **player/**: Video playback via media_kit, mini-player PiP support
- **settings/**: App settings persisted via Hive

### State Management

Uses **Flutter Riverpod** exclusively:
- `StateNotifierProvider` for complex state (playlists, player, settings)
- `FutureProvider` for async data (channels, favorites, EPG)
- `StateProvider` for simple UI state (search query, filters)
- Provider families with `.family` for parameterized data (channels by playlist)

### Storage

**Hive CE** for local persistence:
- Models use `@HiveType` and `@HiveField` annotations
- After adding/modifying Hive fields, run `build_runner` to regenerate `*.g.dart` files
- Adapters are auto-registered via `lib/hive_registrar.g.dart`
- Type IDs: PlaylistModel=0, ChannelModel=1, ProgramModel=3, EpgChannelModel=4, EpgMetadataModel=5, AppSettingsModel=6 (ID 2 unused)
- AppSettingsModel field IDs: 0-17 used, next available is 18

**Adding new persisted settings:**
1. Add `@HiveField(N)` to `AppSettingsModel` (use next available ID)
2. Add to constructor and `copyWith()` method
3. Add setter in `AppSettingsNotifier` that calls `_saveSettings()`
4. Run `dart run build_runner build --delete-conflicting-outputs`

### Navigation

**go_router** with ShellRoute pattern:
- Main screens wrapped in `AppShell` (sidebar navigation)
- Player route outside shell for fullscreen experience
- Routes defined in `lib/config/router/routes.dart`
- Router created via `appRouterProvider` which reads last selected sidebar route from settings
- Sidebar selection persists across app restarts (stored in `AppSettingsModel.lastSelectedSidebarRoute`)

### Video Playback

**Native platforms (media_kit)** handle HLS/DASH/RTMP streams:
- Global `PlayerState` managed by `PlayerNotifier` in `lib/features/player/presentation/providers/player_providers.dart`
- Supports mini-player (PiP) via `isMinimized` state
- Custom HTTP headers per-channel for authentication
- Player transitions use `CinematicSlideUpTransition` (slides up on enter, shrinks to corner on PiP minimize)

**Web platform:** not currently supported. See the "Web Platform" section
above for what restoring it would require.

### Auto-Refresh System

Playlists and EPG auto-refresh on app startup:
- Each playlist has `autoRefresh` and `refreshIntervalHours` settings
- `Playlist.needsRefresh` getter checks if refresh is due
- `AppShell._checkAutoRefresh()` triggers refresh on startup for stale data
- Recently watched channels persist via Hive (`recently_watched` box)

## Design System

### Colors (lib/config/theme/app_colors.dart)

Clean solid dark design with single cyan accent (`#00D4FF`):
- `AppColors.background` - Pure dark (#0A0A0A)
- `AppColors.surface` - Content areas (#1A1A1A)
- `AppColors.surfaceElevated` - Cards/modals (#242424)
- `AppColors.primary` - Accent color (#00D4FF)
- `AppColors.textPrimary/Secondary/Muted` - Text hierarchy

Avoid gradients in new UI components.

### TV Guide Implementation

The TV Guide uses `LinkedScrollControllerGroup` for synchronized scrolling between:
- Time header (horizontal)
- Channel column (vertical)
- Program grid (both directions)

Programs are fetched for a 7-day range (yesterday + today + 5 days ahead).

### App Icon Assets

**In-app icons:** `assets/icons/` (SVG + PNGs)

**Platform icons (must stay in sync):**
- macOS: `macos/Runner/Assets.xcassets/AppIcon.appiconset/`
- iOS: `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- Android: `android/app/src/main/res/mipmap-*/ic_launcher.png`
- Windows: `windows/runner/resources/app_icon.ico`

When updating the app icon, update all platforms and do a clean build.

## Data Flow Example

Adding a playlist:
1. User submits URL → `AddPlaylistScreen`
2. `PlaylistNotifier.addPlaylist()` → `AddPlaylist` use case
3. `PlaylistRepositoryImpl` → fetches M3U, parses with `M3UParser`
4. Channels saved to Hive → providers invalidated → UI updates
5. If EPG URL present → `EpgRefreshNotifier.refreshEpg()` auto-triggers
