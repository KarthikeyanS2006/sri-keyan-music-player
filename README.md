# Keyan Music - Tamil Music Player

AI-powered music player built with Flutter. Stream Tamil music with personalized recommendations.

A product of **Sri Keyan Developments**

[![Build APK](https://github.com/KarthikeyanS2006/sri-keyan-music-player/actions/workflows/android.yml/badge.svg)](https://github.com/KarthikeyanS2006/sri-keyan-music-player/actions/workflows/android.yml)
[![Deploy Web](https://github.com/KarthikeyanS2006/sri-keyan-music-player/actions/workflows/deploy.yml/badge.svg)](https://KarthikeyanS2006.github.io/sri-keyan-music-player/)

Developed by **[Karthikeyan S](https://github.com/KarthikeyanS2006)**

## Download

### Android APK

The APK is automatically built on every push to `master` via GitHub Actions.

1. Go to **[Actions > Build Android APK](https://github.com/KarthikeyanS2006/sri-keyan-music-player/actions/workflows/android.yml)**
2. Click the latest successful workflow run (green checkmark)
3. Scroll down to **Artifacts**
4. Download **`keyan-music-release-apk`**
5. Install the APK (enable "Install from unknown sources" if needed)

### Live Web App

**[Launch Web App](https://KarthikeyanS2006.github.io/sri-keyan-music-player/)**

Auto-deploys to GitHub Pages on every push.

## Features

- **AI Recommendations** - Smart song suggestions based on your listening history, liked songs, preferred artists and languages
- **Library** - Create and manage playlists, view recently played, liked songs with quick play
- **Personalized Home** - Discover Mix, "Because You Like", "Fans Also Like", and taste profile stats
- **Full Player** - Album art, seekable progress bar, lyrics, song details, repeat modes
- **Mini Player** - Quick controls without leaving your current screen
- **Search** - Fast debounced search with cached results
- **Keyboard Shortcuts** - Space (play/pause), arrows (next/prev), Ctrl+K (search)
- **Theme** - Dark/Light/System theme with black & white design
- **Responsive** - Adapts to phone, tablet, desktop, and TV layouts
- **Stats Dashboard** - Total listening time, songs played, listening streak, top artists
- **Share & Download** - Share songs or download for offline

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Web + Android) |
| Music API | JioSaavn (via saavnapi.vercel.app) |
| Audio | just_audio |
| State | setState + RecommendationEngine |
| CI/CD | GitHub Actions |
| Hosting | GitHub Pages (web), Artifacts (APK) |

## Project Structure

```
sri-keyan-music-player/
├── lib/main.dart              # Single-file Flutter app
├── .github/workflows/
│   ├── android.yml            # APK build workflow
│   └── deploy.yml             # Web deploy workflow
├── web/index.html             # Web entry point
├── music_server.py            # JioSaavn API proxy (Flask)
├── music-api/                 # YouTube Music API (FastAPI)
└── pubspec.yaml               # Flutter dependencies
```

## Run Locally

```bash
# Get dependencies
flutter pub get

# Run on web
flutter run -d chrome

# Build for web
flutter build web --release --base-href /sri-keyan-music-player/

# Build APK
flutter build apk --release
```

## How It Works

1. **Onboarding** - Select preferred singers and languages on first launch
2. **Home** - See personalized recommendations, trending songs, and your taste profile
3. **Search** - Find any song with instant results
4. **Library** - Organize playlists, view liked songs and recently played
5. **Settings** - Change theme, view stats, manage preferences
6. **Play** - Full playback controls with seek, repeat, share, and download

## Connect

- **GitHub**: [KarthikeyanS2006](https://github.com/KarthikeyanS2006)
- **Live**: [Keyan Music](https://KarthikeyanS2006.github.io/sri-keyan-music-player/)

## Disclaimer

This project is for educational purposes. Music content is sourced from JioSaavn. Use responsibly and respect copyright.

---

**Part of Sri Keyan Developments**
