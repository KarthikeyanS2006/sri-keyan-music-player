# Sri Keyan - Tamil Music Player

A beautiful Tamil music player built with Flutter and MassTamil API.

![Sri Keyan](https://img.shields.io/badge/Sri%20Keyan-Music%20Player-blue)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)
![Python](https://img.shields.io/badge/Python-3.x-green)

Developed by **[karthikeyan S](https://github.com/KarthikeyanS2006)**

## Features

- **Beautiful UI** - Dark navy blue theme with smooth animations
- **Movie Grid** - Browse latest Tamil movies with posters
- **Direct Streaming** - Play songs directly from MassTamil
- **Search** - Search for any Tamil movie or song
- **Mini Player** - Quick access to now playing
- **Full Player** - Complete music experience with controls
- **Responsive** - Works on mobile, tablet, and desktop

## API Endpoints

| Endpoint | Description |
|----------|-------------|
| `/latest` | Get latest Tamil movies |
| `/album?url=URL` | Get songs from a movie page |
| `/search?q=QUERY` | Search for movies/songs |
| `/play?path=PATH` | Get audio URL |

## Installation

### Backend Setup

```bash
# Install dependencies
pip install flask flask-cors requests beautifulsoup4

# Run the server
python music_server.py
```

The server will start at `http://localhost:5000`

### Flutter App Setup

```bash
# Get dependencies
flutter pub get

# Run locally
flutter run -d chrome
```

## Deployment

### Backend (Render)

1. Go to [render.com](https://render.com)
2. Create new Web Service
3. Connect your GitHub repo
4. Set:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `gunicorn music_server:app --timeout 120`

### Flutter Web

The app auto-deploys to GitHub Pages on every push.

## Tech Stack

- **Frontend**: Flutter Web
- **Backend**: Python Flask
- **API Source**: MassTamil.dev
- **Audio CDN**: MassTamil.download

## Project Structure

```
test_app/
├── lib/
│   └── main.dart          # Flutter app
├── music_server.py        # Python API server
├── requirements.txt       # Python dependencies
└── web/                   # Flutter web files
```

## Connect With Me

- **GitHub**: [KarthikeyanS2006](https://github.com/KarthikeyanS2006)

## Disclaimer

This project is for educational purposes. Music content is sourced from MassTamil.dev. Use responsibly and respect copyright.
