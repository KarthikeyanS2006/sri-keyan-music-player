# YouTube Music API Setup

## Installation

```bash
pip install flask flask-cors ytmusicapi yt-dlp
```

## Running the Server

```bash
python music_server.py
```

The server will automatically use the headers from `headers_auth.json`.

## Test the Server

```bash
curl http://localhost:5000/check      # Should return {"status": "connected"}
curl http://localhost:5000/home      # Should return Tamil songs
curl http://localhost:5000/search?q=anirudh  # Should return search results
```

## Run Flutter App

```bash
flutter run -d chrome
```

## Notes

- **Audio Streaming**: Uses yt-dlp to get direct audio streams from YouTube
- **Thumbnails**: YouTube Music thumbnails may get rate limited (429 errors). If this happens:
  - Wait a few minutes and refresh
  - The app will show the song title's first letter as a fallback
- **Authentication**: If the server fails to connect, you need to update `headers_auth.json` with fresh browser headers from music.youtube.com

## Troubleshooting

If thumbnails don't load:
1. Wait 5-10 minutes (rate limit cooldown)
2. Or search for songs to get fresh results
