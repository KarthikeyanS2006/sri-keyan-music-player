"""
JioSaavn Music API Server
A simple API to fetch Tamil/Hindi songs from JioSaavn
"""

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import json
import os
import re
import requests
from urllib.parse import quote

app = Flask(__name__)
CORS(app)

BASE_URL = "https://www.jiosaavn.com"

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'en-US,en;q=0.9',
    'Referer': 'https://www.jiosaavn.com/',
    'Origin': 'https://www.jiosaavn.com',
}

session = requests.Session()
session.headers.update(HEADERS)

@app.route('/')
def home():
    return jsonify({
        'status': 'ok',
        'message': 'JioSaavn Music API',
        'endpoints': {
            '/search?q=QUERY': 'Search for songs',
            '/album?url=URL': 'Get album songs from URL',
            '/trending': 'Get trending Tamil songs',
            '/home': 'Get home/category songs',
            '/play?id=ID': 'Get song details by ID'
        }
    })

@app.route('/search')
def search():
    """Search for songs"""
    query = request.args.get('q', '')
    
    if not query:
        return jsonify({'results': []})
    
    try:
        # JioSaavn API endpoint
        api_url = f"https://www.jiosaavn.com/api.php?__call=search.getResultsByQuery&query={quote(query)}&p=1&n=20&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        results = []
        
        # Parse the response - JioSaavn returns nested JSON strings
        if isinstance(data, dict) and 'results' in data:
            for item in data['results'][:20]:
                try:
                    results.append({
                        'id': item.get('id', ''),
                        'title': item.get('title', ''),
                        'artist': item.get('singers', item.get('artist', '')),
                        'album': item.get('album', ''),
                        'album_url': item.get('album_url', ''),
                        'image': item.get('image', '').replace('150x150', '500x500'),
                        'duration': item.get('duration', ''),
                        'url': item.get('url', ''),
                        'perma_url': item.get('perma_url', ''),
                        'year': item.get('year', ''),
                        'language': item.get('language', ''),
                    })
                except:
                    continue
        elif isinstance(data, list):
            for item in data[:20]:
                try:
                    results.append({
                        'id': item.get('id', ''),
                        'title': item.get('title', ''),
                        'artist': item.get('singers', item.get('artist', '')),
                        'album': item.get('album', ''),
                        'album_url': item.get('album_url', ''),
                        'image': item.get('image', '').replace('150x150', '500x500'),
                        'duration': item.get('duration', ''),
                        'url': item.get('url', ''),
                        'perma_url': item.get('perma_url', ''),
                        'year': item.get('year', ''),
                        'language': item.get('language', ''),
                    })
                except:
                    continue
        
        return jsonify({'results': results})
    
    except Exception as e:
        return jsonify({'error': str(e), 'results': []}), 500

@app.route('/home')
@app.route('/trending')
def home_trending():
    """Get trending/home songs"""
    try:
        # Fetch from JioSaavn featured/trending
        api_url = "https://www.jiosaavn.com/api.php?__call=content.getHomeData&marker=0&platform=web&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        songs = []
        
        # Parse different sections
        if isinstance(data, dict):
            # Try to get topcharts or featured content
            for section in ['topcharts', 'new_trending', 'featured_playlists_details', 'modules']:
                if section in data:
                    section_data = data[section]
                    if isinstance(section_data, dict) and 'lists' in section_data:
                        for playlist in section_data['lists'][:3]:
                            if 'list' in playlist:
                                for item in playlist['list'][:10]:
                                    try:
                                        songs.append({
                                            'id': item.get('id', ''),
                                            'title': item.get('title', ''),
                                            'artist': item.get('subtitle', item.get('singers', '')),
                                            'album': item.get('album', ''),
                                            'image': item.get('image', '').replace('150x150', '500x500'),
                                            'duration': item.get('duration', ''),
                                            'url': item.get('url', ''),
                                            'perma_url': item.get('perma_url', ''),
                                        })
                                    except:
                                        continue
                    elif isinstance(section_data, list):
                        for item in section_data[:10]:
                            try:
                                songs.append({
                                    'id': item.get('id', ''),
                                    'title': item.get('title', ''),
                                    'artist': item.get('subtitle', item.get('singers', '')),
                                    'album': item.get('album', ''),
                                    'image': item.get('image', '').replace('150x150', '500x500'),
                                    'duration': item.get('duration', ''),
                                    'url': item.get('url', ''),
                                    'perma_url': item.get('perma_url', ''),
                                })
                            except:
                                continue
        
        # If still empty, return default Tamil songs
        if not songs:
            # Fallback to search for Tamil songs
            return search_tamil_songs()
        
        return jsonify({'songs': songs})
    
    except Exception as e:
        return search_tamil_songs()

def search_tamil_songs():
    """Fallback: Search for Tamil songs"""
    try:
        api_url = "https://www.jiosaavn.com/api.php?__call=search.getResultsByQuery&query=tamil+songs&p=1&n=20&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        songs = []
        
        if isinstance(data, dict) and 'results' in data:
            for item in data['results'][:20]:
                try:
                    songs.append({
                        'id': item.get('id', ''),
                        'title': item.get('title', ''),
                        'artist': item.get('singers', item.get('artist', '')),
                        'album': item.get('album', ''),
                        'image': item.get('image', '').replace('150x150', '500x500'),
                        'duration': item.get('duration', ''),
                        'url': item.get('url', ''),
                        'perma_url': item.get('perma_url', ''),
                        'year': item.get('year', ''),
                    })
                except:
                    continue
        elif isinstance(data, list):
            for item in data[:20]:
                try:
                    songs.append({
                        'id': item.get('id', ''),
                        'title': item.get('title', ''),
                        'artist': item.get('singers', item.get('artist', '')),
                        'album': item.get('album', ''),
                        'image': item.get('image', '').replace('150x150', '500x500'),
                        'duration': item.get('duration', ''),
                        'url': item.get('url', ''),
                        'perma_url': item.get('perma_url', ''),
                        'year': item.get('year', ''),
                    })
                except:
                    continue
        
        return jsonify({'songs': songs})
    
    except Exception as e:
        return jsonify({'error': str(e), 'songs': []}), 500

@app.route('/album')
def album():
    """Get album songs from URL or ID"""
    url = request.args.get('url', '')
    album_id = request.args.get('id', '')
    
    if not url and not album_id:
        return jsonify({'error': 'url or id parameter required', 'songs': []}), 400
    
    try:
        if album_id:
            api_url = f"https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&albumid={album_id}&marker=0&_marker=0"
        else:
            # Extract album ID from URL
            # URL format: https://www.jiosaavn.com/album/album-name/ID
            parts = url.split('/')
            album_id = parts[-1] if parts else ''
            api_url = f"https://www.jiosaavn.com/api.php?__call=content.getAlbumDetails&albumid={album_id}&marker=0&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        songs = []
        album_name = ''
        album_image = ''
        
        if isinstance(data, dict):
            album_name = data.get('title', data.get('album_title', ''))
            album_image = data.get('image', '').replace('150x150', '500x500')
            
            # Songs are in 'songs' key
            if 'songs' in data:
                for item in data['songs']:
                    try:
                        songs.append({
                            'id': item.get('id', ''),
                            'title': item.get('title', ''),
                            'artist': item.get('singers', item.get('primary_artists', '')),
                            'album': album_name,
                            'image': item.get('image', album_image).replace('150x150', '500x500'),
                            'duration': item.get('duration', ''),
                            'url': item.get('url', ''),
                            'perma_url': item.get('perma_url', ''),
                            'year': item.get('year', ''),
                        })
                    except:
                        continue
        
        return jsonify({
            'songs': songs,
            'album': album_name,
            'image': album_image
        })
    
    except Exception as e:
        return jsonify({'error': str(e), 'songs': []}), 500

@app.route('/play')
def play():
    """Get song details including download URL"""
    song_id = request.args.get('id', '')
    url = request.args.get('url', '')
    
    if not song_id and not url:
        return jsonify({'error': 'id or url parameter required'}), 400
    
    try:
        if song_id:
            api_url = f"https://www.jiosaavn.com/api.php?__call=song.getDetails&pids={song_id}&marker=0&_marker=0"
        else:
            # Extract ID from URL
            # URL format: https://www.jiosaavn.com/song/song-name/ID
            parts = url.split('/')
            song_id = parts[-1] if parts else ''
            api_url = f"https://www.jiosaavn.com/api.php?__call=song.getDetails&pids={song_id}&marker=0&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        if isinstance(data, dict) and song_id in data:
            item = data[song_id]
            return jsonify({
                'id': item.get('id', ''),
                'title': item.get('song', item.get('title', '')),
                'artist': item.get('singers', item.get('artist', '')),
                'album': item.get('album_name', item.get('album', '')),
                'image': item.get('image', '').replace('150x150', '500x500'),
                'duration': item.get('duration', ''),
                'url': item.get('media_url', item.get('url', '')),
                'download_url': item.get('media_preview_url', item.get('media_url', '')),
                'perma_url': item.get('perma_url', ''),
                'lyrics': item.get('lyrics', ''),
            })
        elif isinstance(data, list) and len(data) > 0:
            item = data[0]
            return jsonify({
                'id': item.get('id', ''),
                'title': item.get('song', item.get('title', '')),
                'artist': item.get('singers', item.get('artist', '')),
                'album': item.get('album_name', item.get('album', '')),
                'image': item.get('image', '').replace('150x150', '500x500'),
                'duration': item.get('duration', ''),
                'url': item.get('media_url', item.get('url', '')),
                'download_url': item.get('media_preview_url', item.get('media_url', '')),
                'perma_url': item.get('perma_url', ''),
                'lyrics': item.get('lyrics', ''),
            })
        
        return jsonify({'error': 'Song not found'}), 404
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/lyrics')
def lyrics():
    """Get song lyrics"""
    song_id = request.args.get('id', '')
    url = request.args.get('url', '')
    
    if not song_id and not url:
        return jsonify({'lyrics': ''})
    
    try:
        if song_id:
            api_url = f"https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyricsid={song_id}&marker=0&_marker=0"
        else:
            # Extract ID from URL
            parts = url.split('/')
            song_id = parts[-1] if parts else ''
            api_url = f"https://www.jiosaavn.com/api.php?__call=lyrics.getLyrics&lyricsid={song_id}&marker=0&_marker=0"
        
        response = session.get(api_url, timeout=30)
        data = response.json()
        
        lyrics_text = ''
        if isinstance(data, dict):
            lyrics_text = data.get('lyrics', data.get('text', ''))
        
        return jsonify({'lyrics': lyrics_text})
    
    except Exception as e:
        return jsonify({'lyrics': '', 'error': str(e)})

@app.route('/proxy')
def proxy():
    """Proxy audio requests with CORS headers"""
    url = request.args.get('url', '')
    
    if not url:
        return jsonify({'error': 'url parameter required'}), 400
    
    try:
        response = requests.get(url, stream=True, headers=HEADERS, timeout=30)
        
        return Response(
            response.iter_content(chunk_size=8192),
            status=response.status_code,
            headers={
                'Content-Type': 'audio/mp4',
                'Content-Length': response.headers.get('Content-Length', ''),
                'Accept-Ranges': 'bytes',
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, OPTIONS',
                'Access-Control-Allow-Headers': '*',
            }
        )
    except Exception as e:
        return jsonify({'error': str(e)}), 500

if __name__ == '__main__':
    print("JioSaavn Music Server running at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
