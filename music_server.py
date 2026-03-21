"""
MassTamil Music API Server
A simple API to scrape and stream Tamil songs from masstamilan.dev
"""

from flask import Flask, request, jsonify, Response
from flask_cors import CORS
import json
import os
import re
import urllib.parse
import requests
from bs4 import BeautifulSoup
import time

app = Flask(__name__)
CORS(app)

BASE_URL = "https://www.masstamilan.dev"
CDN_URL = "https://masstamilan.download"

# Create a session for better Cloudflare handling
session = requests.Session()

HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9',
    'Accept-Encoding': 'gzip, deflate, br',
    'DNT': '1',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Sec-Fetch-Dest': 'document',
    'Sec-Fetch-Mode': 'navigate',
    'Sec-Fetch-Site': 'none',
    'Sec-Fetch-User': '?1',
    'Cache-Control': 'max-age=0',
}

@app.route('/')
def home():
    return jsonify({
        'status': 'ok',
        'message': 'MassTamil Music API',
        'endpoints': {
            '/latest': 'Get latest Tamil movies',
            '/album?url=URL': 'Get songs from album page',
            '/search?q=QUERY': 'Search for songs/movies',
            '/play?path=PATH': 'Get audio URL from download path'
        }
    })

def make_request(url, max_retries=3):
    """Make request with retries for Cloudflare"""
    for attempt in range(max_retries):
        try:
            # First visit homepage to get cookies
            if attempt == 0:
                session.get(BASE_URL, headers=HEADERS, timeout=10)
                time.sleep(1)
            
            response = session.get(url, headers=HEADERS, timeout=30)
            
            # Check if blocked
            if 'Just a moment' in response.text or 'cf-challenge' in response.text:
                time.sleep(2)
                continue
                
            return response
        except Exception as e:
            if attempt == max_retries - 1:
                raise e
            time.sleep(1)
    return None

@app.route('/latest')
def latest():
    """Get latest Tamil movie albums"""
    try:
        response = make_request(BASE_URL)
        if not response:
            return jsonify({'error': 'Failed to fetch - site may be blocking', 'albums': []}), 500
            
        soup = BeautifulSoup(response.text, 'html.parser')
        
        albums = []
        
        # Find album grid items
        album_items = soup.find_all('div', class_='a-i')
        
        for item in album_items[:20]:
            link = item.find('a')
            if link:
                href = link.get('href', '')
                img = item.find('img')
                title_elem = item.find('h2')
                
                if href and title_elem:
                    albums.append({
                        'title': title_elem.text.strip(),
                        'url': f"{BASE_URL}{href}",
                        'image': f"{BASE_URL}{img.get('src', '')}" if img else '',
                        'info': item.find('p').text.strip() if item.find('p') else ''
                    })
        
        return jsonify({'albums': albums})
    
    except Exception as e:
        return jsonify({'error': str(e), 'albums': []}), 500

@app.route('/album')
def album():
    """Get songs from an album/movie page"""
    url = request.args.get('url', '')
    
    if not url:
        return jsonify({'error': 'URL parameter required'}), 400
    
    # Add base URL if not present
    if not url.startswith('http'):
        url = f"{BASE_URL}{url}"
    
    try:
        response = make_request(url)
        if not response:
            return jsonify({'error': 'Failed to fetch - site may be blocking', 'songs': []}), 500
            
        soup = BeautifulSoup(response.text, 'html.parser')
        
        songs = []
        album_name = ''
        album_image = ''
        movie_info = {}
        
        # Get album name from h1
        h1 = soup.find('h1')
        if h1:
            album_name = h1.text.strip().replace('Tamil mp3 songs download MassTamilan.com', '').strip()
        
        # Get album image
        img = soup.find('meta', property='og:image')
        if img:
            album_image = img.get('content', '')
        
        # Get movie info from fieldset
        fieldset = soup.find('fieldset')
        if fieldset:
            for b in fieldset.find_all('b'):
                label = b.text.strip().replace(':', '')
                value = b.next_sibling
                if value:
                    # Clean up the value - get text from <a> tags
                    val_text = ''
                    for sibling in fieldset.find_all('b'):
                        if sibling.text.strip().replace(':', '') == label:
                            val_text = sibling.next_sibling
                            if val_text:
                                val_text = val_text.strip()
                                # Get all text including links
                                next_elem = sibling
                                while True:
                                    next_elem = next_elem.next_sibling
                                    if next_elem is None or isinstance(next_elem, type(b)):
                                        break
                                    if hasattr(next_elem, 'text'):
                                        val_text += ' ' + str(next_elem.text).strip()
                                val_text = val_text.strip().strip(',').strip()
                                if val_text:
                                    movie_info[label] = val_text
                                break
        
        # Find all tracks in table
        table = soup.find('table', {'id': 'tl'})
        if table:
            rows = table.find_all('tr')
            for i, row in enumerate(rows[1:], 1):  # Skip header
                # Get song name
                name_elem = row.find('span', itemprop='name')
                song_name = name_elem.text.strip() if name_elem else ''
                
                # Get artists
                artist_elem = row.find('span', itemprop='byArtist')
                artists = artist_elem.text.strip() if artist_elem else ''
                
                # Get duration
                duration_elem = row.find('span', itemprop='duration')
                duration = duration_elem.text.strip() if duration_elem else ''
                
                # Get download path
                dl_link = row.find('a', href=lambda x: x and '/downloader/' in x and '/p128_cdn/' in x)
                dl_path = dl_link['href'] if dl_link else ''
                
                if song_name and dl_path:
                    # Generate audio URL
                    # Pattern: /t/YEAR/AlbumName/quality/SongName.mp3
                    path_parts = dl_path.split('/')
                    if len(path_parts) >= 6:
                        year = path_parts[-5] if len(path_parts) > 5 else '2026'
                        album_slug = path_parts[-4]
                        quality = path_parts[-3]
                        song_name_encoded = path_parts[-1].replace('.mp3', '').replace('%20', ' ')
                        # Try to construct direct URL
                        # Format: https://masstamilan.download/t/2026/Kaalidas-2/128/Minmini Penne.mp3
                        audio_url = f"{CDN_URL}/t/{year}/{album_slug}/{quality}/{song_name_encoded}.mp3"
                    else:
                        audio_url = f"{CDN_URL}{dl_path}"
                    
                    songs.append({
                        'id': str(i),
                        'title': song_name,
                        'artist': artists,
                        'album': album_name,
                        'image': album_image,
                        'duration': duration,
                        'url': audio_url,
                        'dl_path': dl_path,
                    })
        
        return jsonify({
            'songs': songs,
            'album': album_name,
            'image': album_image,
            'info': movie_info
        })
    
    except Exception as e:
        return jsonify({'error': str(e), 'songs': []}), 500

@app.route('/play')
def play():
    """Get direct audio URL from download path"""
    path = request.args.get('path', '')
    title = request.args.get('title', '')
    
    if not path:
        return jsonify({'error': 'path parameter required'}), 400
    
    # Add base URL if not present
    if not path.startswith('http'):
        path = f"{BASE_URL}{path}"
    
    try:
        response = requests.get(path, headers=HEADERS, timeout=30)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Try to find direct audio URL
        # Method 1: Check for download link
        download_link = soup.find('a', href=lambda x: x and 'masstamilan.download' in x)
        if download_link:
            audio_url = download_link['href']
            return jsonify({
                'url': audio_url,
                'title': title,
            })
        
        # Method 2: Check for redirect URL
        redirect = soup.find('meta', attrs={'http-equiv': 'refresh'})
        if redirect:
            content = redirect.get('content', '')
            if 'url=' in content.lower():
                url_part = content.lower().split('url=')[-1]
                return jsonify({
                    'url': url_part.strip(),
                    'title': title,
                })
        
        return jsonify({'error': 'Audio URL not found', 'url': None}), 404
    
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/search')
def search():
    """Search for songs or movies"""
    query = request.args.get('q', '')
    
    if not query:
        return jsonify({'results': []})
    
    try:
        search_url = f"{BASE_URL}/search?keyword={urllib.parse.quote(query)}"
        response = make_request(search_url)
        if not response:
            return jsonify({'error': 'Failed to fetch - site may be blocking', 'results': []}), 500
        soup = BeautifulSoup(response.text, 'html.parser')
        
        results = []
        
        # Find all movie/album links
        for link in soup.find_all('a', href=True):
            href = link.get('href', '')
            title = link.text.strip()
            
            # Only get movie/album pages
            if ('-songs' in href or href.startswith('/movie')) and title and len(title) > 3:
                # Avoid duplicates
                if not any(r['url'] == f"{BASE_URL}{href}" for r in results):
                    results.append({
                        'title': title,
                        'url': f"{BASE_URL}{href}",
                        'type': 'movie'
                    })
        
        return jsonify({'results': results[:20]})
    
    except Exception as e:
        return jsonify({'error': str(e), 'results': []}), 500

@app.route('/trending')
def trending():
    """Get trending albums"""
    try:
        search_url = f"{BASE_URL}/tamil-songs"
        response = make_request(search_url)
        if not response:
            return jsonify({'error': 'Failed to fetch - site may be blocking', 'albums': []}), 500
        soup = BeautifulSoup(response.text, 'html.parser')
        
        albums = []
        
        # Find album grid items
        album_items = soup.find_all('div', class_='a-i')
        
        for item in album_items[:20]:
            link = item.find('a')
            if link:
                href = link.get('href', '')
                img = item.find('img')
                title_elem = item.find('h2')
                
                if href and title_elem:
                    albums.append({
                        'title': title_elem.text.strip(),
                        'url': f"{BASE_URL}{href}",
                        'image': f"{BASE_URL}{img.get('src', '')}" if img else '',
                        'info': item.find('p').text.strip() if item.find('p') else ''
                    })
        
        return jsonify({'albums': albums})
    
    except Exception as e:
        return jsonify({'error': str(e), 'albums': []}), 500

if __name__ == '__main__':
    print("MassTamil Music Server running at http://localhost:5000")
    app.run(host='0.0.0.0', port=5000, debug=False)
