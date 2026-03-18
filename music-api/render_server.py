# Sri Keyan Music API
# Python backend for Tamil music streaming

import asyncio
import os
from ytmusicapi import YTMusic
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
import httpx

ytmusic = YTMusic("headers_auth.json")

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {"message": "Sri Keyan Music API", "status": "running"}

@app.get("/search")
async def search(q: str = ""):
    try:
        results = ytmusic.search(q, filter="songs", limit=20)
        songs = []
        for r in results:
            if r.get("resultType") == "song":
                thumbnail = r.get("thumbnails", [{}])[-1].get("url", "") if r.get("thumbnails") else ""
                if "lh3.googleusercontent.com" in thumbnail:
                    video_id = r.get("videoId", "")
                    thumbnail = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
                songs.append({
                    "id": r.get("videoId", ""),
                    "title": r.get("title", "Unknown"),
                    "artist": ", ".join([a.get("name", "") for a in r.get("artists", [])]),
                    "album": r.get("album", {}).get("name", "") if isinstance(r.get("album"), dict) else str(r.get("album", "")),
                    "duration": r.get("duration", ""),
                    "thumbnail": thumbnail,
                    "videoId": r.get("videoId", ""),
                })
        return songs
    except Exception as e:
        return {"error": str(e)}

@app.get("/home")
async def home():
    try:
        charts = ytmusic.get_home(limit=20)
        all_songs = []
        for section in charts:
            for item in section.get("contents", []):
                if isinstance(item, dict) and "musicTwoRowRenderer" in item:
                    renderer = item["musicTwoRowRenderer"]
                    video_id = renderer.get("title", {}).get("runs", [{}])[0].get("navigationEndpoint", {}).get("watchEndpoint", {}).get("videoId", "")
                    thumbnail = renderer.get("thumbnail", {}).get("thumbnails", [{}])[-1].get("url", "") if renderer.get("thumbnail", {}).get("thumbnails") else ""
                    if "lh3.googleusercontent.com" in thumbnail and video_id:
                        thumbnail = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
                    title_runs = renderer.get("title", {}).get("runs", [])
                    title = title_runs[0].get("text", "") if title_runs else ""
                    subtitle_runs = renderer.get("subtitle", {}).get("runs", [])
                    artist = " ".join([r.get("text", "") for r in subtitle_runs])
                    if video_id:
                        all_songs.append({
                            "id": video_id,
                            "title": title,
                            "artist": artist,
                            "thumbnail": thumbnail,
                            "videoId": video_id,
                        })
        return all_songs[:20]
    except Exception as e:
        return {"error": str(e)}

@app.get("/playlist/{playlist_id}")
async def get_playlist(playlist_id: str):
    try:
        playlist = ytmusic.get_playlist(playlist_id, limit=50)
        tracks = playlist.get("tracks", [])
        songs = []
        for track in tracks:
            video_id = track.get("videoId", "")
            thumbnail = track.get("thumbnails", [{}])[-1].get("url", "") if track.get("thumbnails") else ""
            if "lh3.googleusercontent.com" in thumbnail and video_id:
                thumbnail = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
            songs.append({
                "id": video_id,
                "title": track.get("title", "Unknown"),
                "artist": ", ".join([a.get("name", "") for a in track.get("artists", [])]),
                "album": track.get("album", {}).get("name", "") if isinstance(track.get("album"), dict) else str(track.get("album", "")),
                "duration": track.get("duration", ""),
                "thumbnail": thumbnail,
                "videoId": video_id,
            })
        return songs
    except Exception as e:
        return {"error": str(e)}

@app.get("/stream/{video_id}")
async def stream(video_id: str):
    try:
        proc = await asyncio.create_subprocess_exec(
            "yt-dlp", "-g", "-f", "bestaudio",
            f"https://www.youtube.com/watch?v={video_id}",
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        stream_url, _ = await proc.communicate()
        url = stream_url.decode().strip()
        if url:
            return {"url": url}
        return {"error": "Could not get stream URL"}
    except Exception as e:
        return {"error": str(e)}

@app.get("/lyrics")
async def get_lyrics(video_id: str = ""):
    try:
        result = ytmusic.get_lyrics(video_id)
        return {"lyrics": result.get("lyrics", "") if isinstance(result, dict) else str(result)}
    except Exception:
        return {"lyrics": "Lyrics not available"}

@app.get("/charts")
async def get_charts():
    try:
        charts = ytmusic.get_charts("in")
        songs = []
        for track in charts.get("songChart", {}).get("tracks", [])[:20]:
            video_id = track.get("videoId", "")
            thumbnail = track.get("thumbnails", [{}])[-1].get("url", "") if track.get("thumbnails") else ""
            if "lh3.googleusercontent.com" in thumbnail and video_id:
                thumbnail = f"https://img.youtube.com/vi/{video_id}/mqdefault.jpg"
            songs.append({
                "id": video_id,
                "title": track.get("title", "Unknown"),
                "artist": ", ".join([a.get("name", "") for a in track.get("artists", [])]),
                "thumbnail": thumbnail,
                "videoId": video_id,
            })
        return songs
    except Exception as e:
        return {"error": str(e)}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", 10000)))
