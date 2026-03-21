import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const MusicApp());
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );
    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );
    _controller.forward();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _isInitialized = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFF0A1929),
          body: Center(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.3),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.music_note,
                            size: 60,
                            color: Color(0xFF0A1929),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Sri Keyan',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'MassTamil Music',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                            letterSpacing: 4,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Sri Keyan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.white,
        scaffoldBackgroundColor: const Color(0xFF0A1929),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1929),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          secondary: Color(0xFF1A365D),
          surface: Color(0xFF0A1929),
        ),
      ),
      themeMode: ThemeMode.dark,
      home: const MusicPlayerScreen(),
    );
  }
}

class Album {
  final String title;
  final String url;
  final String image;
  final String info;

  Album({
    required this.title,
    required this.url,
    required this.image,
    required this.info,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      image: json['image'] ?? '',
      info: json['info'] ?? '',
    );
  }
}

class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String imageUrl;
  final String audioUrl;
  final String duration;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.audioUrl,
    required this.duration,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Unknown',
      artist: json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? '',
      imageUrl: json['image'] ?? '',
      audioUrl: json['url'] ?? '',
      duration: json['duration'] ?? '0:00',
    );
  }
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<Album> _albums = [];
  List<Song> _songs = [];
  List<Song> _searchResults = [];
  List<dynamic> _searchAlbums = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isBuffering = false;
  bool _showAlbumView = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _showFullPlayer = false;
  String _currentAlbum = 'Latest Tamil Songs';
  Album? _currentAlbumData;

  static const Color primaryColor = Color(0xFF0A1929);
  static const Color secondaryColor = Color(0xFF1A365D);

  @override
  void initState() {
    super.initState();
    _loadAlbums();
    _focusNode.requestFocus();
  }

  Future<void> _loadAlbums() async {
    setState(() => _isLoading = true);
    try {
      final albums = await MassTamilApi.getLatest();
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadAlbum(Album album) async {
    setState(() {
      _isLoading = true;
      _showAlbumView = true;
      _currentAlbum = album.title;
      _currentAlbumData = album;
    });
    
    try {
      final songs = await MassTamilApi.getAlbumSongs(album.url);
      setState(() {
        _songs = songs;
        _isLoading = false;
      });
      if (songs.isNotEmpty) {
        _playSong(0);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration ?? Duration.zero);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.loading || 
                         state.processingState == ProcessingState.buffering;
        });
        
        if (state.processingState == ProcessingState.completed) {
          _playNext();
        }
      }
    });
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    
    setState(() {
      _currentIndex = index;
      _isBuffering = true;
    });
    
    final song = _songs[index];
    
    if (song.audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(song.audioUrl);
        await _audioPlayer.play();
        _initAudio();
      } catch (e) {
        debugPrint('Error playing: $e');
        if (mounted) setState(() => _isBuffering = false);
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _playNext() async {
    int nextIndex = (_currentIndex + 1) % _songs.length;
    await _playSong(nextIndex);
  }

  Future<void> _playPrevious() async {
    int prevIndex = (_currentIndex - 1 + _songs.length) % _songs.length;
    await _playSong(prevIndex);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Future<void> _search(String query) async {
    setState(() => _isSearching = query.isNotEmpty);
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchAlbums = [];
      });
      return;
    }

    try {
      final results = await MassTamilApi.search(query);
      setState(() {
        _searchResults = results['songs'] ?? [];
        _searchAlbums = results['albums'] ?? [];
      });
    } catch (e) {
      setState(() {
        _searchResults = [];
        _searchAlbums = [];
      });
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        body: _showFullPlayer
            ? _buildFullPlayer()
            : _buildMainScreen(),
      ),
    );
  }

  Widget _buildMainScreen() {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: _isSearching ? _buildSearchResults() : _buildAlbumGrid(),
          ),
          if (_songs.isNotEmpty && _showAlbumView) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white, size: 28),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sri Keyan',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _currentAlbum,
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            ],
          ),
          Row(
            children: [
              if (_showAlbumView)
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    setState(() {
                      _showAlbumView = false;
                      _songs = [];
                      _audioPlayer.stop();
                    });
                  },
                ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: _loadAlbums,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _search,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search Tamil songs...',
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _search('');
                    },
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumGrid() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        return _AlbumCard(
          album: album,
          onTap: () => _loadAlbum(album),
        );
      },
    );
  }

  Widget _buildSearchResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_searchAlbums.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Movies',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _searchAlbums.length,
                itemBuilder: (context, index) {
                  final album = _searchAlbums[index];
                  return _AlbumCard(
                    album: Album(
                      title: album['title'] ?? '',
                      url: album['url'] ?? '',
                      image: album['image'] ?? '',
                      info: '',
                    ),
                    onTap: () => _loadAlbum(Album.fromJson(album)),
                  );
                },
              ),
            ),
          ],
          if (_searchResults.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Songs',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                return _SongTile(
                  song: _searchResults[index],
                  index: index,
                  onTap: () {
                    setState(() {
                      _songs = _searchResults;
                      _currentIndex = index;
                      _showAlbumView = true;
                      _searchController.clear();
                      _isSearching = false;
                    });
                    _playSong(index);
                  },
                );
              },
            ),
          ],
          if (_searchAlbums.isEmpty && _searchResults.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No results found',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    
    final song = _songs[_currentIndex];
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1A365D), Color(0xFF0A1929)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: secondaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                            Center(child: Text(song.title[0], style: const TextStyle(fontSize: 24, color: Colors.white))))
                        : Center(child: Text(song.title[0], style: const TextStyle(fontSize: 24, color: Colors.white))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  color: Colors.white,
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: Colors.white,
                  onPressed: _playNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatDuration(_position), style: const TextStyle(fontSize: 11, color: Colors.white70)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white24,
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _position.inSeconds.toDouble(),
                      min: 0,
                      max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                      onChanged: (value) => _audioPlayer.seek(Duration(seconds: value.toInt())),
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    
    final song = _songs[_currentIndex];
    
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, size: 32),
          onPressed: () => setState(() => _showFullPlayer = false),
        ),
        title: Column(
          children: [
            const Text('Now Playing', style: TextStyle(color: Colors.white, fontSize: 16)),
            Text(
              _currentAlbum,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                color: secondaryColor,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: song.imageUrl.isNotEmpty
                    ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                        Center(child: Text(song.title[0], style: const TextStyle(fontSize: 100, color: Colors.white))))
                    : Center(child: Text(song.title[0], style: const TextStyle(fontSize: 100, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              song.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              song.artist,
              style: const TextStyle(fontSize: 16, color: Colors.white70),
            ),
            const SizedBox(height: 32),
            SliderTheme(
              data: SliderThemeData(
                trackHeight: 4,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                value: _position.inSeconds.toDouble(),
                min: 0,
                max: _duration.inSeconds.toDouble().clamp(1, double.infinity),
                onChanged: (value) => _audioPlayer.seek(Duration(seconds: value.toInt())),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: const TextStyle(color: Colors.white70)),
                Text(_formatDuration(_duration), style: const TextStyle(color: Colors.white70)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, size: 40),
                  color: Colors.white,
                  onPressed: _playPrevious,
                ),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(_isBuffering ? Icons.hourglass_empty : (_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded), size: 48),
                    color: const Color(0xFF0A1929),
                    onPressed: _togglePlayPause,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded, size: 40),
                  color: Colors.white,
                  onPressed: _playNext,
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final Album album;
  final VoidCallback onTap;

  const _AlbumCard({required this.album, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: album.image.isNotEmpty
                    ? Image.network(
                        album.image,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xFF1A365D),
                          child: const Center(
                            child: Icon(Icons.music_note, size: 40, color: Colors.white54),
                          ),
                        ),
                      )
                    : Container(
                        color: const Color(0xFF1A365D),
                        child: const Center(
                          child: Icon(Icons.music_note, size: 40, color: Colors.white54),
                        ),
                      ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                album.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final int index;
  final VoidCallback onTap;

  const _SongTile({
    required this.song,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFF1A365D),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.imageUrl.isNotEmpty
                ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) =>
                    Center(child: Text(song.title[0], style: const TextStyle(fontSize: 20, color: Colors.white))))
                : Center(child: Text(song.title[0], style: const TextStyle(fontSize: 20, color: Colors.white))),
          ),
        ),
        title: Text(
          song.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(color: Colors.grey),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          song.duration,
          style: const TextStyle(color: Colors.grey, fontSize: 12),
        ),
        onTap: onTap,
      ),
    );
  }
}

class MassTamilApi {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'https://sri-keyan-music-player.onrender.com';
    }
    return 'http://localhost:5000';
  }

  static Future<List<Album>> getLatest() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/latest'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> albums = data['albums'] ?? [];
        return albums.map((item) => Album.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Song>> getAlbumSongs(String url) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/album?url=${Uri.encodeComponent(url)}'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songs = data['songs'] ?? [];
        return songs.map((item) => Song.fromJson(item)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>> search(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}'),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] ?? [];
        
        List<Song> songs = [];
        List<dynamic> albums = [];
        
        for (var item in results) {
          if (item['type'] == 'movie') {
            albums.add(item);
          }
        }
        
        return {'songs': songs, 'albums': albums};
      }
    } catch (_) {}
    return {'songs': [], 'albums': []};
  }
}
