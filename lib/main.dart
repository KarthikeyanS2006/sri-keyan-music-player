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
                          'Music Player',
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
        brightness: Brightness.light,
        primaryColor: const Color(0xFF0A1929),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF0A1929),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF0A1929),
          secondary: Color(0xFF1A365D),
          surface: Colors.white,
        ),
      ),
      darkTheme: ThemeData(
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
      album: json['album'] ?? 'Unknown Album',
      imageUrl: json['image'] ?? '',
      audioUrl: json['audio'] ?? '',
      duration: json['duration'] ?? '0',
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
  final TextEditingController _headersController = TextEditingController();
  
  List<Song> _allSongs = [];
  List<Song> _songs = [];
  List<Song> _searchResults = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isBuffering = false;
  bool _isConnected = false;
  bool _isSettingUp = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  double _volume = 1.0;
  bool _showFullPlayer = false;
  String _currentPlaylist = 'Tamil Hits';

  static const Color primaryColor = Color(0xFF0A1929);
  static const Color secondaryColor = Color(0xFF1A365D);

  @override
  void initState() {
    super.initState();
    _checkConnection();
    _focusNode.requestFocus();
  }

  Future<void> _checkConnection() async {
    final connected = await MusicApiService.checkConnection();
    if (mounted) {
      setState(() => _isConnected = connected);
      if (connected) {
        _loadSongs();
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _setupConnection() async {
    final headers = _headersController.text.trim();
    if (headers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter authentication headers')),
      );
      return;
    }
    
    setState(() => _isSettingUp = true);
    
    final success = await MusicApiService.setup(headers);
    
    if (mounted) {
      setState(() => _isSettingUp = false);
      if (success) {
        setState(() => _isConnected = true);
        _loadSongs();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Setup failed. Check your headers.')),
        );
      }
    }
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await MusicApiService.getHomeSongs();
      setState(() {
        _allSongs = songs;
        _songs = songs;
        _isLoading = false;
      });
      _initAudio();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initAudio() async {
    if (_songs.isEmpty) return;
    
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
    String? audioUrl = await MusicApiService.getStreamUrl(song.id);
    
    if (audioUrl != null && audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.setUrl(audioUrl);
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Error: $e');
        if (mounted) setState(() => _isBuffering = false);
      }
    } else {
      if (mounted) setState(() => _isBuffering = false);
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

  Future<void> _setVolume(double value) async {
    setState(() => _volume = value.clamp(0.0, 1.0));
    await _audioPlayer.setVolume(_volume);
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
        _isSearching = false;
      });
      return;
    }

    try {
      final results = await MusicApiService.searchSongs(query);
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() => _searchResults = []);
    }
  }

  void _changePlaylist(String playlist) async {
    setState(() {
      _currentPlaylist = playlist;
      _isLoading = true;
      _isSearching = false;
      _searchController.clear();
    });
    
    try {
      List<Song> songs;
      switch (playlist) {
        case 'Top Trending':
          songs = await MusicApiService.searchSongs('top tamil songs 2024');
          break;
        case 'Most Played':
          songs = await MusicApiService.searchSongs('most viewed tamil songs');
          break;
        case '2024 Hits':
          songs = await MusicApiService.searchSongs('tamil 2024 hits');
          break;
        case '2023 Hits':
          songs = await MusicApiService.searchSongs('tamil 2023 hits');
          break;
        case '2022 Hits':
          songs = await MusicApiService.searchSongs('tamil 2022 hits');
          break;
        case '90s Tamil':
          songs = await MusicApiService.searchSongs('90s tamil songs');
          break;
        case 'Melody Songs':
          songs = await MusicApiService.searchSongs('tamil melody songs');
          break;
        case 'Party Songs':
          songs = await MusicApiService.searchSongs('tamil party songs');
          break;
        case 'Sad Songs':
          songs = await MusicApiService.searchSongs('tamil sad songs');
          break;
        case 'Romance':
          songs = await MusicApiService.searchSongs('tamil love songs');
          break;
        case 'Devotional':
          songs = await MusicApiService.searchSongs('tamil devotional songs');
          break;
        case 'Hip Hop':
          songs = await MusicApiService.searchSongs('tamil hiphop songs');
          break;
        case 'Tamil Hits':
        default:
          songs = await MusicApiService.getHomeSongs();
      }
      
      setState(() {
        _songs = songs.isNotEmpty ? songs : _allSongs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _songs = _allSongs;
        _isLoading = false;
      });
    }
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Row(
          children: [
            Icon(Icons.music_note, color: Colors.white, size: 32),
            SizedBox(width: 12),
            Text('Sri Keyan', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Tamil Music Player', style: TextStyle(color: Colors.white70)),
            SizedBox(height: 16),
            Text('Developer: karthikeyan S', 
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('Powered by YouTube Music API', style: TextStyle(color: Colors.white60, fontSize: 12)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showShortcuts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Keyboard Controls', style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ShortcutRow(keys: 'Space', action: 'Play / Pause'),
            _ShortcutRow(keys: 'Left Arrow', action: 'Previous'),
            _ShortcutRow(keys: 'Right Arrow', action: 'Next'),
            _ShortcutRow(keys: 'Up Arrow', action: 'Volume Up'),
            _ShortcutRow(keys: 'Down Arrow', action: 'Volume Down'),
            _ShortcutRow(keys: 'M', action: 'Mute'),
            _ShortcutRow(keys: 'F', action: 'Full Player'),
            _ShortcutRow(keys: 'Esc', action: 'Exit Full'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    if (event.logicalKey == LogicalKeyboardKey.space) {
      _togglePlayPause();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _playPrevious();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
      _playNext();
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      _setVolume(_volume + 0.1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      _setVolume(_volume - 0.1);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyM) {
      _setVolume(_volume == 0 ? 1.0 : 0.0);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
      setState(() => _showFullPlayer = !_showFullPlayer);
      return KeyEventResult.handled;
    } else if (event.logicalKey == LogicalKeyboardKey.escape && _showFullPlayer) {
      setState(() => _showFullPlayer = false);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _headersController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected && !_isLoading) {
      return _buildSetupScreen();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      autofocus: true,
      child: Scaffold(
        body: _showFullPlayer
            ? _buildFullPlayer(isDark)
            : _buildMainScreen(isDark),
      ),
    );
  }

  Widget _buildSetupScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1929),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              const Icon(Icons.music_note, size: 80, color: Colors.white),
              const SizedBox(height: 24),
              const Text(
                'Sri Keyan',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect to YouTube Music',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'To get authentication headers:\n'
                  '1. Open YouTube Music in browser\n'
                  '2. Press F12 → Network tab\n'
                  '3. Play a song → copy the request headers\n'
                  '4. Or search for "ytmusicapi headers guide"',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _headersController,
                maxLines: 6,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Paste authentication headers here...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.1),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSettingUp ? null : _setupConnection,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0A1929),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSettingUp
                      ? const CircularProgressIndicator()
                      : const Text('Connect', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _checkConnection,
                child: const Text('Retry Connection', style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMainScreen(bool isDark) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(isDark),
          _buildSearchBar(isDark),
          _buildPlaylistTabs(isDark),
          Expanded(child: _buildSongList(isDark)),
          _buildMiniPlayer(isDark),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good ${_getGreeting()}',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.music_note, color: Colors.white, size: 24),
                      const SizedBox(width: 8),
                      const Text(
                        'Sri Keyan',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.white),
                    onPressed: _showAbout,
                  ),
                  IconButton(
                    icon: const Icon(Icons.keyboard, color: Colors.white),
                    onPressed: _showShortcuts,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: _loadSongs,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.playlist_play, color: Colors.white, size: 16),
                const SizedBox(width: 6),
                Text(
                  _currentPlaylist,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _search,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search songs...',
            hintStyle: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
            prefixIcon: Icon(Icons.search, color: isDark ? Colors.grey[500] : Colors.grey[400]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: isDark ? Colors.grey[500] : Colors.grey[400]),
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

  Widget _buildPlaylistTabs(bool isDark) {
    final playlists = [
      'Tamil Hits',
      'Top Trending',
      'Most Played',
      '2024 Hits',
      '2023 Hits',
      'Melody Songs',
      'Party Songs',
      'Romance',
      'Sad Songs',
      'Devotional',
      'Hip Hop',
      '90s Tamil',
      '2022 Hits',
    ];
    
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final isSelected = _currentPlaylist == playlists[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(playlists[index], style: const TextStyle(fontSize: 12)),
              selected: isSelected,
              onSelected: (_) => _changePlaylist(playlists[index]),
              backgroundColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[100],
              selectedColor: Colors.white.withValues(alpha: 0.2),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[400],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? Colors.white : Colors.transparent,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongList(bool isDark) {
    final displaySongs = _isSearching ? _searchResults : _songs;
    
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: 16),
            Text(
              'Loading $_currentPlaylist...',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isSearching ? Icons.search_off : Icons.music_off,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No songs found' : 'No songs available',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${displaySongs.length} Songs',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              if (!_isSearching)
                Text(
                  _currentPlaylist,
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: displaySongs.length,
            itemBuilder: (context, idx) {
              final song = displaySongs[idx];
              final isSelected = idx == _currentIndex && !_isSearching;
        
        return _SongTile(
          song: song,
          isSelected: isSelected,
          isPlaying: isSelected && _isPlaying,
          index: idx,
          onTap: () {
            if (_isSearching) {
              setState(() {
                _songs = List.from(_searchResults);
                _currentIndex = idx;
                _isSearching = false;
                _searchController.clear();
              });
            }
            _playSong(_isSearching ? _songs.indexOf(song) : idx);
            },
          );
        },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniPlayer(bool isDark) {
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
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _isBuffering
                        ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : song.imageUrl.isNotEmpty
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
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${_currentIndex + 1}/${_songs.length}',
                              style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              song.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
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

  Widget _buildFullPlayer(bool isDark) {
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
              '$_currentPlaylist - ${_songs.length} songs',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: _showAbout,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
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
                child: _isBuffering
                    ? const Center(child: CircularProgressIndicator(color: Colors.white))
                    : song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                            Center(child: Text(song.title[0], style: const TextStyle(fontSize: 100, color: Colors.white))))
                        : Center(child: Text(song.title[0], style: const TextStyle(fontSize: 100, color: Colors.white))),
              ),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${song.artist} - ${song.album}',
                        style: const TextStyle(fontSize: 16, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
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
                  icon: const Icon(Icons.shuffle, size: 28),
                  color: Colors.white70,
                  onPressed: () {},
                ),
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
                IconButton(
                  icon: const Icon(Icons.repeat, size: 28),
                  color: Colors.white70,
                  onPressed: () {},
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildVolumeControl(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Column(
      children: [
        Row(
          children: [
            Icon(
              _volume == 0 ? Icons.volume_off : Icons.volume_down,
              color: Colors.white70,
              size: 20,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderThemeData(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  activeTrackColor: Colors.white,
                  inactiveTrackColor: Colors.white24,
                  thumbColor: Colors.white,
                ),
                child: Slider(
                  value: _volume,
                  min: 0,
                  max: 1,
                  onChanged: _setVolume,
                ),
              ),
            ),
            Icon(Icons.volume_up, color: Colors.white70, size: 20),
          ],
        ),
      ],
    );
  }
}

class _ShortcutRow extends StatelessWidget {
  final String keys;
  final String action;

  const _ShortcutRow({required this.keys, required this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(keys, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          Text(action, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }
}

class _SongTile extends StatelessWidget {
  final Song song;
  final bool isSelected;
  final bool isPlaying;
  final int? index;
  final VoidCallback onTap;

  const _SongTile({
    required this.song,
    required this.isSelected,
    required this.isPlaying,
    this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Stack(
          children: [
            Container(
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
            if (index != null && !isSelected && !isPlaying)
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${index! + 1}',
                    style: const TextStyle(fontSize: 10, color: Colors.white70),
                  ),
                ),
              ),
          ],
        ),
        title: Text(
          song.title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : Colors.grey[300],
          ),
        ),
        subtitle: Text(
          '${song.artist} - ${song.album}',
          style: TextStyle(color: Colors.grey[500]),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? const Icon(Icons.equalizer, color: Colors.white)
            : const Icon(Icons.more_vert, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}

class MusicApiService {
  static String get _baseUrl {
    if (kIsWeb) {
      return 'https://sri-keyan-music-player.onrender.com';
    }
    return 'http://localhost:5000';
  }
  
  static bool isConnected = false;

  static Future<bool> checkConnection() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/check')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        isConnected = data['status'] == 'connected';
      }
    } catch (_) {}
    return isConnected;
  }

  static Future<List<Song>> getHomeSongs() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/home')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> songs = data['songs'] ?? [];
        return songs.map((item) => Song(
          id: item['id'] ?? '',
          title: item['title'] ?? 'Unknown',
          artist: item['artist'] ?? 'Unknown Artist',
          album: item['album'] ?? 'Unknown Album',
          imageUrl: item['image'] ?? '',
          audioUrl: '',
          duration: item['duration'] ?? '0:00',
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Song>> searchSongs(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/search?q=${Uri.encodeComponent(query)}'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        return results.map((item) => Song(
          id: item['id'] ?? '',
          title: item['title'] ?? 'Unknown',
          artist: item['artist'] ?? 'Unknown Artist',
          album: item['album'] ?? 'Unknown Album',
          imageUrl: item['image'] ?? '',
          audioUrl: '',
          duration: item['duration'] ?? '0:00',
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<String?> getStreamUrl(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/stream/$videoId'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'];
      }
    } catch (_) {}
    return null;
  }

  static Future<String?> getLyrics(String videoId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/lyrics?id=$videoId'),
      ).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lyrics'];
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getPlaylists() async {
    try {
      final response = await http.get(Uri.parse('$_baseUrl/playlist')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['playlists'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  static Future<List<Song>> getPlaylistTracks(String playlistId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/playlist_tracks?id=$playlistId'),
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> tracks = data['tracks'] ?? [];
        return tracks.map((item) => Song(
          id: item['id'] ?? '',
          title: item['title'] ?? 'Unknown',
          artist: item['artist'] ?? 'Unknown Artist',
          album: item['album'] ?? 'Unknown Album',
          imageUrl: item['image'] ?? '',
          audioUrl: '',
          duration: item['duration'] ?? '0:00',
        )).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> setup(String headers) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/setup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'headers': headers}),
      ).timeout(const Duration(seconds: 10));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }
}

