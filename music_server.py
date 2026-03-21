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
import urllib.parse

app = Flask(__name__)
CORS(app)

ytmusic = None

def setup_ytmusic():
    global ytmusic
    
    headers_from_env = os.environ.get('YTMUSIC_HEADERS', '')
    print(f"YTMUSIC_HEADERS env var present: {bool(headers_from_env)}")
    
    if headers_from_env:
        try:
            if headers_from_env.startswith('{'):
                headers_dict = json.loads(headers_from_env)
                ytmusic = YTMusic(headers_dict)
                print("Connected to YouTube Music from env!")
                return True
            else:
                print("Headers from env not valid JSON")
        except Exception as e:
            print(f"Error loading from env: {e}")
    
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
    if not ytmusic:
        return jsonify({'error': 'Not connected to YouTube Music'}), 400
    
    try:
        import yt_dlp
        import tempfile
        import json
        
        cookie_file = None
        
        # Try to read from environment variable first
        headers_from_env = os.environ.get('YTMUSIC_HEADERS', '')
        if headers_from_env:
            try:
                auth_data = json.loads(headers_from_env)
                if 'cookie' in auth_data:
                    cookie_str = auth_data['cookie']
                    with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as cf:
                        cf.write("# Netscape HTTP Cookie File\n")
                        for cookie in cookie_str.split(';'):
                            cookie = cookie.strip()
                            if '=' in cookie:
                                parts = cookie.split('=')
                                name = parts[0]
                                value = '='.join(parts[1:])
                                cf.write(f".youtube.com\tTRUE\t/\tFALSE\t0\t{name}\t{value}\n")
                        cookie_file = cf.name
            except:
                pass
        
        # If no env var, try reading from file
        if not cookie_file and os.path.exists('headers_auth.json'):
            try:
                with open('headers_auth.json', 'r', encoding='utf-8') as f:
                    content = f.read()
                    if content.startswith('{'):
                        auth_data = json.loads(content)
                        if 'cookie' in auth_data:
                            cookie_str = auth_data['cookie']
                            with tempfile.NamedTemporaryFile(mode='w', suffix='.txt', delete=False) as cf:
                                cf.write("# Netscape HTTP Cookie File\n")
                                for cookie in cookie_str.split(';'):
                                    cookie = cookie.strip()
                                    if '=' in cookie:
                                        parts = cookie.split('=')
                                        name = parts[0]
                                        value = '='.join(parts[1:])
                                        cf.write(f".youtube.com\tTRUE\t/\tFALSE\t0\t{name}\t{value}\n")
                                cookie_file = cf.name
            except:
                pass
        
        if cookie_file:
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
                'cookiefile': cookie_file,
            }
        else:
            ydl_opts = {
                'format': 'bestaudio/best',
                'quiet': True,
                'no_warnings': True,
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

@app.route('/masstamilan', methods=['GET'])
def masstamilan():
    """Scrape songs from masstamilan.dev"""
    url = request.args.get('url', '')
    
    if not url:
        return jsonify({'error': 'URL parameter required'}), 400
    
    try:
        import requests
        from bs4 import BeautifulSoup
        bs4_available = True
    except ImportError:
        bs4_available = False
    
    if not bs4_available:
        return jsonify({'error': 'BeautifulSoup not installed', 'songs': []}), 500
    
    try:
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Accept-Language': 'en-US,en;q=0.5',
            'Referer': 'https://www.masstamilan.dev/',
        }
        
        response = requests.get(url, headers=headers, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        songs = []
        album_name = ''
        
        h1 = soup.find('h1')
        if h1:
            album_name = h1.text.strip().replace('Tamil mp3 songs download MassTamilan.com', '').strip()
        
        table = soup.find('table', {'id': 'tl'})
        if table:
            rows = table.find_all('tr')
            for i, row in enumerate(rows[1:], 1):
                cells = row.find_all('td')
                if len(cells) >= 1:
                    name_elem = row.find('span', itemprop='name')
                    song_name = name_elem.text.strip() if name_elem else ''
                    
                    artist_elem = row.find('span', itemprop='byArtist')
                    artists = artist_elem.text.strip() if artist_elem else ''
                    
                    duration_elem = row.find('span', itemprop='duration')
                    duration = duration_elem.text.strip() if duration_elem else ''
                    
                    img_elem = soup.find('meta', property='og:image')
                    image = img_elem['content'] if img_elem else ''
                    
                    dl_link = row.find('a', href=lambda x: x and '/downloader/' in x)
                    dl_path = dl_link['href'] if dl_link else ''
                    
                    if song_name:
                        songs.append({
                            'id': str(i),
                            'title': song_name,
                            'artist': artists,
                            'album': album_name,
                            'image': image,
                            'duration': duration,
                            'dl_path': dl_path,
                        })
        
        return jsonify({'songs': songs, 'album': album_name})
    
    except Exception as e:
        return jsonify({'error': str(e), 'songs': []}), 500

@app.route('/masstamilan/play', methods=['GET'])
def masstamilan_play():
    """Get direct audio URL from masstamilan"""
    dl_path = request.args.get('path', '')
    title = request.args.get('title', '')
    album = request.args.get('album', '')
    
    if not dl_path:
        return jsonify({'error': 'path parameter required'}), 400
    
    try:
        import requests
        from bs4 import BeautifulSoup
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Referer': 'https://www.masstamilan.dev/',
        }
        
        full_url = f'https://www.masstamilan.dev{dl_path}'
        response = requests.get(full_url, headers=headers, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Find audio source
        audio = soup.find('audio', {'id': 'album-audio'})
        if audio and audio.get('src'):
            return jsonify({
                'url': audio['src'],
                'title': title,
            })
        
        # Try to find download link
        download_link = soup.find('a', href=lambda x: x and 'masstamilan.download' in x)
        if download_link:
            return jsonify({
                'url': download_link['href'],
                'title': title,
            })
        
        return jsonify({'error': 'Audio not found'}), 404
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/masstamilan/search', methods=['GET'])
def masstamilan_search():
    """Search songs on masstamilan.dev"""
    query = request.args.get('q', '')
    
    if not query:
        return jsonify({'results': []})
    
    try:
        import requests
        from bs4 import BeautifulSoup
        
        headers = {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
            'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
            'Referer': 'https://www.masstamilan.dev/',
        }
        
        search_url = f'https://www.masstamilan.dev/search?keyword={urllib.parse.quote(query)}'
        response = requests.get(search_url, headers=headers, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        results = []
        
        # Find all song links
        for link in soup.find_all('a', href=True):
            href = link['href']
            if '/mp3-song' in href or '-songs' in href:
                title = link.text.strip()
                if title and len(title) > 3:
                    results.append({
                        'title': title,
                        'url': f'https://www.masstamilan.dev{href}',
                    })
        
        return jsonify({'results': results[:20]})
    
    except Exception as e:
        return jsonify({'error': str(e), 'results': []}), 500

if __name__ == '__main__':
    setup_ytmusic()
    print("Server running at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)