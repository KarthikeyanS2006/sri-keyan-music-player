"""
YouTube Music API Server
Run: python music_server.py
Then start Flutter app
"""

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
from ytmusicapi import YTMusic
import json
import os

app = Flask(__name__)
CORS(app)

ytmusic = None

def setup_ytmusic():
    global ytmusic
    
    # First check for headers in environment variable (for persistent deployment)
    headers_from_env = os.environ.get('YTMUSIC_HEADERS', '')
    if headers_from_env:
        try:
            with open('headers_auth.json', 'w', encoding='utf-8') as f:
                f.write(headers_from_env)
            print("Headers loaded from environment variable")
        except Exception as e:
            print(f"Error writing headers from env: {e}")
    
    try:
        if os.path.exists('headers_auth.json'):
            with open('headers_auth.json', 'r', encoding='utf-8') as f:
                content = f.read().strip()
                if content.startswith('{'):
                    ytmusic = YTMusic('headers_auth.json')
                    print("Connected to YouTube Music!")
                    return True
                else:
                    print("Headers file is empty or invalid")
                    return False
        else:
            print("headers_auth.json not found.")
            return False
    except Exception as e:
        print(f"Error: {e}")
        return False

@app.route('/setup', methods=['POST'])
def setup():
    """Save authentication headers from client"""
    data = request.json
    headers_raw = data.get('headers', '')
    
    try:
        with open('headers_auth.json', 'w') as f:
            f.write(headers_raw)
        
        global ytmusic
        ytmusic = YTMusic('headers_auth.json')
        return jsonify({'status': 'success', 'message': 'Connected to YouTube Music!'})
    except Exception as e:
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/check', methods=['GET'])
def check():
    """Check if connected"""
    if ytmusic:
        return jsonify({'status': 'connected'})
    return jsonify({'status': 'not_connected'})

@app.route('/search', methods=['GET'])
def search():
    """Search for songs"""
    query = request.args.get('q', '')
    if not query:
        return jsonify({'results': []})
    
    if not ytmusic:
        return jsonify({'error': 'Not connected to YouTube Music'}), 400
    
    try:
        results = ytmusic.search(query, filter='songs', limit=20)
        songs = []
        for item in results:
            video_id = item.get('videoId', '')
            if not video_id:
                continue
            # Use YouTube thumbnail instead of Googleusercontent (more reliable)
            img_url = f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg'
            songs.append({
                'id': video_id,
                'title': item.get('title', 'Unknown'),
                'artist': ', '.join([a.get('name', '') for a in item.get('artists', [])]),
                'album': item.get('album', {}).get('name', 'Unknown Album') if item.get('album') else 'Unknown Album',
                'image': img_url,
                'duration': item.get('duration', '0:00'),
            })
        return jsonify({'results': songs})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/lyrics', methods=['GET'])
def lyrics():
    """Get song lyrics"""
    video_id = request.args.get('id', '')
    if not video_id or not ytmusic:
        return jsonify({'lyrics': None})
    
    try:
        result = ytmusic.get_lyrics(video_id)
        if result:
            lyrics_text = result.get('lyrics', '')
            if isinstance(lyrics_text, dict):
                lyrics_text = lyrics_text.get('simple_lyrics', {}).get('lyrics', '')
            return jsonify({'lyrics': lyrics_text})
        return jsonify({'lyrics': None})
    except Exception as e:
        print(f"Lyrics error: {e}")
        return jsonify({'lyrics': None})

@app.route('/playlist', methods=['GET'])
def get_playlist():
    """Get user's playlists"""
    if not ytmusic:
        return jsonify({'error': 'Not connected'}), 400
    
    try:
        playlists = ytmusic.get_library_playlists(limit=20)
        return jsonify({'playlists': playlists})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/playlist_tracks', methods=['GET'])
def playlist_tracks():
    """Get tracks from a playlist"""
    playlist_id = request.args.get('id', '')
    if not playlist_id or not ytmusic:
        return jsonify({'tracks': []})
    
    try:
        tracks = ytmusic.get_playlist(playlist_id, limit=50)
        songs = []
        for item in tracks.get('tracks', []):
            video_id = item.get('videoId', '')
            if not video_id:
                continue
            img_url = f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg'
            songs.append({
                'id': video_id,
                'title': item.get('title', 'Unknown'),
                'artist': ', '.join([a.get('name', '') for a in item.get('artists', [])]),
                'album': item.get('album', {}).get('name', 'Unknown') if item.get('album') else 'Unknown',
                'image': img_url,
                'duration': item.get('duration', ''),
            })
        return jsonify({'tracks': songs})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/home', methods=['GET'])
def home():
    """Get home/up next songs"""
    if not ytmusic:
        return jsonify({'error': 'Not connected'}), 400
    
    try:
        results = ytmusic.search("tamil songs", filter='songs', limit=20)
        songs = []
        
        for item in results:
            if not isinstance(item, dict):
                continue
            video_id = item.get('videoId', '')
            if video_id:
                artists_list = item.get('artists') or []
                artist_names = []
                if isinstance(artists_list, list):
                    for a in artists_list:
                        if isinstance(a, dict):
                            artist_names.append(a.get('name', ''))
                
                album_info = item.get('album')
                album_name = album_info.get('name', 'Unknown') if isinstance(album_info, dict) else 'Unknown'
                
                # Use YouTube thumbnail instead of Googleusercontent (more reliable)
                img_url = f'https://img.youtube.com/vi/{video_id}/mqdefault.jpg'
                
                songs.append({
                    'id': video_id,
                    'title': item.get('title', 'Unknown'),
                    'artist': ', '.join(artist_names),
                    'album': album_name,
                    'image': img_url,
                    'duration': item.get('duration', ''),
                })
        return jsonify({'songs': songs})
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/stream/<video_id>', methods=['GET'])
def stream(video_id):
    """Stream audio for a YouTube video"""
    try:
        import yt_dlp
        
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'no_warnings': True,
            'extract_flat': False,
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f'https://www.youtube.com/watch?v={video_id}', download=False)
            if info and 'url' in info:
                return jsonify({
                    'url': info['url'],
                    'title': info.get('title', ''),
                    'duration': info.get('duration', 0),
                })
        return jsonify({'error': 'No audio available'}), 404
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/audio_proxy/<video_id>', methods=['GET'])
def audio_proxy(video_id):
    """Proxy audio stream with proper CORS headers"""
    try:
        import yt_dlp
        import requests
        
        ydl_opts = {
            'format': 'bestaudio/best',
            'quiet': True,
            'no_warnings': True,
        }
        
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f'https://www.youtube.com/watch?v={video_id}', download=False)
            if info and 'url' in info:
                audio_url = info['url']
                headers = {
                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
                }
                resp = requests.get(audio_url, headers=headers, stream=True, timeout=30)
                return Response(
                    resp.iter_content(chunk_size=32768),
                    status=200,
                    headers={
                        'Content-Type': resp.headers.get('Content-Type', 'audio/mpeg'),
                        'Content-Length': resp.headers.get('Content-Length', ''),
                        'Accept-Ranges': 'bytes',
                        'Access-Control-Allow-Origin': '*',
                    }
                )
        return 'No audio', 404
    except Exception as e:
        return f'Error: {e}', 500

if __name__ == '__main__':
    setup_ytmusic()
    print("Server running at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)