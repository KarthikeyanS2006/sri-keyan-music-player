# Sri Keyan - Tamil Music Player

A beautiful Tamil music player built with Flutter and YouTube Music API.

![Sri Keyan](https://img.shields.io/badge/Sri%20Keyan-Music%20Player-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Python](https://img.shields.io/badge/Python-3.x-green)

Developed by **[karthikeyan S](https://github.com/KarthikeyanS2006)**

## Features

- **Beautiful UI** - Dark navy blue theme with smooth animations
- **Splash Screen** - Animated loading screen on app start
- **Mobile Responsive** - Works perfectly on mobile and desktop
- **Keyboard Controls** - Full PC keyboard support
- **Multiple Playlists** - Various Tamil music categories
  - Top Trending
  - Most Played
  - Year-wise playlists (2024, 2023, 2022)
  - Genre-based (Melody, Party, Romance, Sad, Devotional, Hip Hop)
  - 90s Tamil Classics
- **Search** - Search any Tamil song
- **Mini Player** - Quick access to now playing
- **Full Player** - Complete music experience
- **Volume Control** - Easy volume adjustment
- **Song Counter** - Shows current position in playlist

## Keyboard Controls

| Key | Action |
|-----|--------|
| Space | Play / Pause |
| Left Arrow | Previous Song |
| Right Arrow | Next Song |
| Up Arrow | Volume Up |
| Down Arrow | Volume Down |
| M | Mute / Unmute |
| F | Toggle Full Player |
| Esc | Exit Full Player |

## Screenshots

The app features a dark navy blue theme with:
- Animated splash screen with "Sri Keyan" branding
- Clean song list with album art
- Mini player with progress bar
- Full-screen player with all controls
- Smooth scrolling playlist tabs
- Mobile responsive design

## Installation

### Prerequisites

- Flutter SDK 3.x
- Python 3.8+
- Chrome browser (for web)

### Backend Setup

1. Navigate to project directory:
```bash
cd test_app
```

2. Install Python dependencies:
```bash
pip install flask flask-cors ytmusicapi yt-dlp
```

3. Run the backend server:
```bash
python music_server.py
```

The server will start at `http://localhost:5000`

### YouTube Music Authentication

The app uses your YouTube Music browser session for authentication. Headers are stored in `headers_auth.json`.

If authentication fails, you can update headers:

1. Open Chrome and go to [music.youtube.com](https://music.youtube.com)
2. Login to your account
3. Open Developer Tools (F12)
4. Go to Network tab
5. Find any POST request to `/youtubei/v1/browse`
6. Copy the request headers
7. Replace the contents of `headers_auth.json` with the headers

### Flutter App Setup

For Web/Chrome:
```bash
flutter run -d chrome
```

For Mobile:
```bash
flutter run -d android
# or
flutter run -d ios
```

For Windows:
```bash
flutter run -d windows
```

## Cloud Deployment (For Mobile Access)

To access the app on mobile devices, deploy the backend to Render.com:

### Quick Setup:

1. Go to [render.com](https://render.com) → Sign up/Login
2. Click "New +" → "Web Service"
3. Connect this repository or upload the `music-api` folder
4. Configure:
   - **Name**: `sri-keyan-api`
   - **Build Command**: `pip install -r requirements.txt`
   - **Start Command**: `python render_server.py`
5. Add Environment Variable: `PORT` = `10000`
6. Click "Create Web Service"

### Update App:

Once deployed, update `lib/main.dart` line 1237:
```dart
static String get _baseUrl {
  if (kIsWeb) {
    return const String.fromEnvironment('API_URL', 
      defaultValue: 'https://YOUR-RENDER-APP.onrender.com');
  }
  return 'http://localhost:5000';
}
```

See `music-api/README.md` for detailed instructions.

## Project Structure

```
test_app/
├── lib/
│   └── main.dart          # Main Flutter app
├── music_server.py        # Python backend (local)
├── music-api/             # Backend for cloud deployment
│   ├── render_server.py
│   └── requirements.txt
├── headers_auth.json      # YouTube Music authentication headers
├── pubspec.yaml           # Flutter dependencies
├── SETUP.md               # Setup instructions
└── README.md              # This file
```

## Connect With Me

- **GitHub**: [KarthikeyanS2006](https://github.com/KarthikeyanS2006)

## License

This project is for educational purposes. Music playback uses YouTube Music's public API.

## Disclaimer

This app is not affiliated with YouTube or Google. Use responsibly and respect copyright.
