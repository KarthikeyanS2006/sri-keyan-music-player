import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MusicApp());
}

class MusicApp extends StatefulWidget {
  const MusicApp({super.key});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> with SingleTickerProviderStateMixin {
  bool _isInitialized = false;
  double _loadingProgress = 0.0;
  bool _showPreferences = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  
  List<String> _selectedLanguages = [];
  List<String> _selectedSingers = [];

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color secondaryOrange = Color(0xFFFF8C42);
  static const Color lightOrange = Color(0xFFFFB38A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textGray = Color(0xFF6C757D);

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
    _checkPreferences();
  }

  Future<void> _checkPreferences() async {
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 30));
      if (mounted) setState(() => _loadingProgress = i / 100);
    }
    
    final prefs = await SharedPreferences.getInstance();
    final hasSetPreferences = prefs.getBool('preferences_set') ?? false;
    
    if (mounted) {
      setState(() {
        _showPreferences = !hasSetPreferences;
        _isInitialized = true;
      });
    }
  }

  Future<void> _savePreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('preferences_set', true);
    await prefs.setStringList('languages', _selectedLanguages);
    await prefs.setStringList('singers', _selectedSingers);
    setState(() => _showPreferences = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _showPreferences) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _showPreferences ? _buildPreferencesScreen() : _buildSplashScreen(),
      );
    }

    return MaterialApp(
      title: 'Sri Keyan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: white,
        fontFamily: 'Poppins',
        colorScheme: ColorScheme.light(
          primary: primaryOrange,
          secondary: secondaryOrange,
          surface: white,
          onPrimary: white,
          onSecondary: white,
          onSurface: textDark,
        ),
      ),
      home: const MusicPlayerScreen(),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: white,
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
                      width: 140,
                      height: 140,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [primaryOrange, secondaryOrange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: primaryOrange.withValues(alpha: 0.4),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.music_note, size: 70, color: white),
                    ),
                    const SizedBox(height: 32),
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [primaryOrange, secondaryOrange],
                      ).createShader(bounds),
                      child: const Text(
                        'Sri Keyan',
                        style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: white, letterSpacing: 2),
                      ),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loadingProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]),
                            borderRadius: BorderRadius.circular(2),
                          ),
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
    );
  }

  Widget _buildPreferencesScreen() {
    final languages = ['Tamil', 'Hindi', 'English', 'Malayalam', 'Telugu', 'Kannada'];
    final singers = ['A.R. Rahman', 'Anirudh', 'Ilaiyaraaja', 'Vishal', 'Harris Jayaraj', 'G.V. Prakash'];
    
    return Scaffold(
      backgroundColor: white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.settings, color: white, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Welcome to Sri Keyan!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Select your preferences to personalize your experience',
                  style: TextStyle(fontSize: 14, color: textGray),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Text('🎵 Preferred Languages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: languages.map((lang) {
                  final isSelected = _selectedLanguages.contains(lang);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedLanguages.remove(lang);
                        } else {
                          _selectedLanguages.add(lang);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(colors: [primaryOrange, secondaryOrange]) : null,
                        color: isSelected ? null : lightGray,
                        borderRadius: BorderRadius.circular(20),
                        border: isSelected ? null : Border.all(color: Colors.transparent),
                      ),
                      child: Text(lang, style: TextStyle(color: isSelected ? white : textGray, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              Text('🎤 Favorite Singers', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textDark)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: singers.map((singer) {
                  final isSelected = _selectedSingers.contains(singer);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedSingers.remove(singer);
                        } else {
                          _selectedSingers.add(singer);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? const LinearGradient(colors: [primaryOrange, secondaryOrange]) : null,
                        color: isSelected ? null : lightGray,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(singer, style: TextStyle(color: isSelected ? white : textGray, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedLanguages.isNotEmpty ? _savePreferences : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryOrange,
                    foregroundColor: white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text('Continue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
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
  final String url;
  final String year;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.imageUrl,
    required this.audioUrl,
    required this.duration,
    this.url = '',
    this.year = '',
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] ?? json['e_songid'] ?? '',
      title: json['song'] ?? json['title'] ?? 'Unknown',
      artist: json['primary_artists'] ?? json['singers'] ?? 'Unknown Artist',
      album: json['album'] ?? '',
      imageUrl: json['image'] ?? '',
      audioUrl: json['media_url'] ?? '',
      duration: json['duration'] ?? '0',
      url: json['perma_url'] ?? json['url'] ?? '',
      year: json['year'] ?? '',
    );
  }

  String get movieName {
    final match = RegExp(r'\([^)]*\)').firstMatch(title);
    if (match != null) {
      return match.group(0)!.replaceAll('(', '').replaceAll(')', '').trim();
    }
    return album.isNotEmpty ? album : '';
  }

  bool get isMovieSong => movieName.isNotEmpty;
}

class MusicPlayerScreen extends StatefulWidget {
  const MusicPlayerScreen({super.key});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

class _MusicPlayerScreenState extends State<MusicPlayerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  late TabController _tabController;
  
  List<Song> _songs = [];
  List<Song> _searchResults = [];
  List<Song> _playlistSongs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isBuffering = false;
  bool _isFading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showFullPlayer = false;
  String _currentCategory = 'For You';
  String _currentLyrics = '';
  List<String> _lyricLines = [];
  int _currentLyricIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
  bool _isDesktop = false;
  String _currentPlaylistType = '';

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color secondaryOrange = Color(0xFFFF8C42);
  static const Color lightOrange = Color(0xFFFFB38A);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textGray = Color(0xFF6C757D);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDeviceType();
    });
    _loadSongs();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDeviceType();
  }

  void _updateDeviceType() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _isDesktop = width > 1024;
    });
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await JioSaavnApi.getHome();
      setState(() {
        _songs = songs;
        _currentPlaylistType = 'home';
        _isLoading = false;
      });
      _initAudio();
    } catch (e) {
      debugPrint('Error loading songs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initAudio() async {
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null && duration.inSeconds > 0) {
        setState(() => _duration = duration);
      }
    });

    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
        _updateCurrentLyric(position);
      }
    });

    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isBuffering = state.processingState == ProcessingState.loading || 
                         state.processingState == ProcessingState.buffering;
          
          if (state.processingState == ProcessingState.completed) {
            _fadeToNext();
          } else if (state.processingState == ProcessingState.idle) {
            _isBuffering = false;
          }
        });
      }
    });
  }

  void _updateCurrentLyric(Duration position) {
    if (_lyricLines.isEmpty) return;
    for (int i = _lyricLines.length - 1; i >= 0; i--) {
      if (i * 3 <= position.inSeconds) {
        if (_currentLyricIndex != i && _lyricsScrollController.hasClients) {
          setState(() => _currentLyricIndex = i);
          _scrollToLyric(i);
        }
        break;
      }
    }
  }

  void _scrollToLyric(int index) {
    if (_lyricsScrollController.hasClients) {
      final offset = index * 60.0;
      _lyricsScrollController.animateTo(offset, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  Future<void> _fetchLyrics(String songId, String songName) async {
    try {
      final lyrics = await JioSaavnApi.getLyrics(songId);
      if (lyrics.isNotEmpty) {
        setState(() {
          _currentLyrics = lyrics;
          _lyricLines = lyrics.split('\n').where((line) => line.trim().isNotEmpty).toList();
          _currentLyricIndex = -1;
        });
      } else {
        setState(() {
          _currentLyrics = _generatePlaceholderLyrics(songName);
          _lyricLines = _currentLyrics.split('\n').where((line) => line.trim().isNotEmpty).toList();
          _currentLyricIndex = -1;
        });
      }
    } catch (e) {
      setState(() {
        _currentLyrics = _generatePlaceholderLyrics(songName);
        _lyricLines = _currentLyrics.split('\n').where((line) => line.trim().isNotEmpty).toList();
      });
    }
  }

  String _generatePlaceholderLyrics(String songName) {
    return '♪ ♫ ♪ ♫ ♪ ♫ ♪\n\n🎵 $songName 🎵\n\n♪ ♫ ♫ ♪ ♫ ♫ ♪\n\n🎶 Lyrics coming soon 🎶\n\n♪ ♫ ♪ ♫ ♪ ♫ ♪';
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    
    // Fade out current song
    if (_isPlaying) {
      setState(() => _isFading = true);
      await _fadeVolume(1.0, 0.0, 500);
    }
    
    setState(() {
      _currentIndex = index;
      _isBuffering = true;
      _duration = Duration.zero;
      _position = Duration.zero;
      _currentLyrics = '';
      _lyricLines = [];
      _currentLyricIndex = -1;
    });
    
    final song = _songs[index];
    _fetchLyrics(song.id, song.title);
    
    if (song.audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        final playUrl = JioSaavnApi.getProxyUrl(song.audioUrl);
        await _audioPlayer.setUrl(playUrl);
        await _audioPlayer.play();
        
        // Fade in
        await _fadeVolume(0.0, 1.0, 1000);
        setState(() => _isFading = false);
      } catch (e) {
        debugPrint('Error playing: $e');
        if (mounted) setState(() => _isBuffering = false);
      }
    } else {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  Future<void> _fadeVolume(double from, double to, int durationMs) async {
    final steps = 20;
    final stepDuration = durationMs ~/ steps;
    for (int i = 0; i <= steps; i++) {
      final volume = from + (to - from) * (i / steps);
      await _audioPlayer.setVolume(volume);
      await Future.delayed(Duration(milliseconds: stepDuration));
    }
  }

  Future<void> _fadeToNext() async {
    if (_isFading) return;
    setState(() => _isFading = true);
    await _fadeVolume(1.0, 0.0, 800);
    await _playSong((_currentIndex + 1) % _songs.length);
  }

  Future<void> _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  Future<void> _playNext() async {
    await _playSong((_currentIndex + 1) % _songs.length);
  }

  Future<void> _playPrevious() async {
    await _playSong((_currentIndex - 1 + _songs.length) % _songs.length);
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
      setState(() => _searchResults = []);
      return;
    }
    try {
      final results = await JioSaavnApi.search(query);
      setState(() => _searchResults = results);
    } catch (e) {
      setState(() => _searchResults = []);
    }
  }

  void _changePlaylist(String playlistType) async {
    setState(() {
      _currentCategory = playlistType;
      _isLoading = true;
      _isSearching = false;
      _searchController.clear();
    });
    
    List<Song> songs;
    switch (playlistType) {
      case 'Tamil Hits':
        songs = await JioSaavnApi.search('tamil hit songs 2024');
        break;
      case 'Melody':
        songs = await JioSaavnApi.search('tamil melody songs');
        break;
      case 'Sad Songs':
        songs = await JioSaavnApi.search('tamil sad songs');
        break;
      case 'Party':
        songs = await JioSaavnApi.search('tamil party songs');
        break;
      case '90s Tamil':
        songs = await JioSaavnApi.search('tamil 1990s songs');
        break;
      case '2000s Tamil':
        songs = await JioSaavnApi.search('tamil 2000s songs');
        break;
      case 'Hindi':
        songs = await JioSaavnApi.search('hindi songs');
        break;
      case 'English':
        songs = await JioSaavnApi.search('english top songs');
        break;
      case 'For You':
      default:
        songs = await JioSaavnApi.getHome();
    }
    
    setState(() {
      _songs = songs.isNotEmpty ? songs : _songs;
      _currentPlaylistType = playlistType;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      child: Scaffold(
        backgroundColor: white,
        body: _showFullPlayer ? _buildFullPlayer() : (_isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
      ),
    );
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Column(
        children: [
          _buildMinimalAppBar(),
          _buildMinimalSearchBar(),
          _buildPlaylistRow(),
          Expanded(child: _buildSongList()),
          if (_songs.isNotEmpty) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildMinimalAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: white, size: 22),
          ),
          const SizedBox(width: 10),
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(colors: [primaryOrange, secondaryOrange]).createShader(bounds),
            child: const Text('Sri Keyan', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: white)),
          ),
          const Spacer(),
          IconButton(icon: Icon(Icons.library_music, color: textDark), onPressed: () {}),
          IconButton(icon: Icon(Icons.settings, color: textDark), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildMinimalSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: TextStyle(color: textDark, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search songs...',
          hintStyle: TextStyle(color: textGray, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: textGray, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPlaylistRow() {
    final playlists = ['For You', 'Tamil Hits', 'Melody', 'Sad Songs', 'Party', '90s Tamil'];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final isSelected = _currentCategory == playlists[index];
          return GestureDetector(
            onTap: () => _changePlaylist(playlists[index]),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? primaryOrange : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  playlists[index],
                  style: TextStyle(
                    color: isSelected ? white : textGray,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSongList() {
    final displaySongs = _isSearching ? _searchResults : _songs;
    
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryOrange));
    }
    
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 60, color: lightOrange),
            Text('No songs found', style: TextStyle(color: textGray, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: displaySongs.length,
      itemBuilder: (context, idx) {
        final song = displaySongs[idx];
        final isSelected = idx == _currentIndex && !_isSearching;
        
        return _buildSongCard(song, isSelected, idx);
      },
    );
  }

  Widget _buildSongCard(Song song, bool isSelected, int index) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryOrange.withValues(alpha: 0.1) : lightGray,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: primaryOrange, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: isSelected ? const LinearGradient(colors: [primaryOrange, secondaryOrange]) : null,
            color: isSelected ? null : const Color(0xFFE0E0E0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.imageUrl.isNotEmpty
                ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.music_note, color: isSelected ? white : textGray))
                : Icon(Icons.music_note, color: isSelected ? white : textGray),
          ),
        ),
        title: Text(
          song.title,
          style: TextStyle(color: textDark, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(color: textGray, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: isSelected
            ? Icon(Icons.equalizer, color: primaryOrange, size: 20)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.isMovieSong)
                    Padding(padding: const EdgeInsets.only(right: 6), child: Icon(Icons.movie, size: 14, color: primaryOrange)),
                  Text(_formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)), style: TextStyle(color: textGray, fontSize: 11)),
                ],
              ),
        onTap: () {
          if (_isSearching) {
            setState(() {
              _songs = List.from(_searchResults);
              _currentIndex = index;
              _isSearching = false;
              _searchController.clear();
            });
          }
          _playSong(_isSearching ? _songs.indexOf(song) : index);
        },
      ),
    );
  }

  Widget _buildMiniPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: primaryOrange.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(color: white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: white))
                        : const Icon(Icons.music_note, color: white),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(song.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: white), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text(song.artist, style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                IconButton(icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32), color: white, onPressed: _togglePlayPause),
                IconButton(icon: const Icon(Icons.skip_next_rounded), color: white, onPressed: _playNext),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(_formatDuration(_position), style: TextStyle(fontSize: 10, color: white.withValues(alpha: 0.8))),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 2,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: white,
                      inactiveTrackColor: white.withValues(alpha: 0.3),
                      thumbColor: white,
                    ),
                    child: Slider(
                      value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()) : 0,
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                      onChanged: _duration.inSeconds > 0 ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt())) : null,
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: TextStyle(fontSize: 10, color: white.withValues(alpha: 0.8))),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SafeArea(
      child: Row(
        children: [
          // Left sidebar
          Container(
            width: 280,
            decoration: BoxDecoration(
              color: white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(2, 0))],
            ),
            child: Column(
              children: [
                _buildMinimalAppBar(),
                _buildMinimalSearchBar(),
                _buildPlaylistRow(),
                const SizedBox(height: 8),
                Expanded(child: _buildSongList()),
              ],
            ),
          ),
          // Main area
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildDesktopNowPlaying()),
                if (_songs.isNotEmpty) _buildMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNowPlaying() {
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 100, color: lightOrange),
            const SizedBox(height: 20),
            Text('Select a song to play', style: TextStyle(color: textGray, fontSize: 18)),
          ],
        ),
      );
    }
    
    final song = _songs[_currentIndex];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          if (song.isMovieSong) _buildTrailerSection(song),
          _buildAlbumArt(song),
          const SizedBox(height: 24),
          Text(song.title, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(song.artist, style: TextStyle(fontSize: 16, color: primaryOrange, fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 24),
          _buildControlsSection(),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]), borderRadius: BorderRadius.circular(16)),
              labelColor: white,
              unselectedLabelColor: textGray,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: '🎵 Lyrics'), Tab(text: 'ℹ️ Details')],
            ),
          ),
          SizedBox(height: 280, child: TabBarView(controller: _tabController, children: [_buildLyricsTab(), _buildSongDetailsTab(song)])),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song) {
    return Container(
      width: _isDesktop ? 320 : 280,
      height: _isDesktop ? 320 : 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: primaryOrange.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 15))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: white, size: 100))
            : const Icon(Icons.music_note, color: white, size: 100),
      ),
    );
  }

  Widget _buildTrailerSection(Song song) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: GestureDetector(
        onTap: () async {
          final movie = song.movieName.replaceAll("From '", "").replaceAll("from '", "").replaceAll("'", "").replaceAll("(", "").replaceAll(")", "").replaceAll("From ", "").trim();
          final url = Uri.parse('https://www.youtube.com/results?search_query=$movie tamil movie trailer');
          if (await canLaunchUrl(url)) {
            await launchUrl(url, mode: LaunchMode.externalApplication);
          }
        },
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFF0000), Color(0xFFFF4444)]),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.play_circle_outline, color: white, size: 40),
                SizedBox(width: 10),
                Text('Watch Trailer on YouTube', style: TextStyle(color: white, fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: primaryOrange,
              inactiveTrackColor: lightOrange.withValues(alpha: 0.3),
              thumbColor: primaryOrange,
            ),
            child: Slider(
              value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()) : 0,
              min: 0,
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
              onChanged: _duration.inSeconds > 0 ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt())) : null,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatDuration(_position), style: TextStyle(color: textGray)),
              Text(_formatDuration(_duration), style: TextStyle(color: textGray)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        IconButton(icon: const Icon(Icons.skip_previous_rounded, size: 45), color: textDark, onPressed: _playPrevious),
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]),
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: primaryOrange.withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 5))],
          ),
          child: _isBuffering
              ? const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: white)))
              : IconButton(icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42), color: white, onPressed: _togglePlayPause),
        ),
        IconButton(icon: const Icon(Icons.skip_next_rounded, size: 45), color: textDark, onPressed: _playNext),
      ],
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(15)),
      child: _lyricLines.isEmpty
          ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.music_note, size: 50, color: lightOrange), const SizedBox(height: 16), Text('Loading lyrics...', style: TextStyle(color: textGray))]))
          : ListView.builder(
              controller: _lyricsScrollController,
              itemCount: _lyricLines.length,
              itemBuilder: (context, index) {
                final isCurrentLyric = index == _currentLyricIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _lyricLines[index],
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: isCurrentLyric ? 17 : 14, fontWeight: isCurrentLyric ? FontWeight.bold : FontWeight.normal, color: isCurrentLyric ? primaryOrange : textGray),
                  ),
                );
              },
            ),
    );
  }

  Widget _buildSongDetailsTab(Song song) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Title', song.title),
          _buildDetailRow('Artist', song.artist),
          if (song.album.isNotEmpty) _buildDetailRow('Album', song.album),
          if (song.year.isNotEmpty) _buildDetailRow('Year', song.year),
          if (song.duration.isNotEmpty) _buildDetailRow('Duration', _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0))),
          if (song.isMovieSong) _buildDetailRow('Movie', song.movieName),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: textGray, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(color: textDark))),
        ],
      ),
    );
  }

  Widget _buildFullPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    
    return SafeArea(
      child: Scaffold(
        backgroundColor: white,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.keyboard_arrow_down, size: 32), color: textDark, onPressed: () => setState(() => _showFullPlayer = false)),
                  Column(children: [Text('Now Playing', style: TextStyle(color: textGray, fontSize: 12)), Text(_currentCategory, style: TextStyle(color: primaryOrange, fontSize: 14, fontWeight: FontWeight.bold))]),
                  IconButton(icon: const Icon(Icons.queue_music), color: textDark, onPressed: () {}),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (song.isMovieSong) _buildTrailerSection(song),
                    _buildAlbumArt(song),
                    _buildSongInfo(song),
                    _buildProgressSection(),
                    const SizedBox(height: 20),
                    _buildControlsSection(),
                    const SizedBox(height: 20),
                    Container(margin: const EdgeInsets.symmetric(horizontal: 20), decoration: BoxDecoration(color: lightGray, borderRadius: BorderRadius.circular(12)), child: TabBar(controller: _tabController, indicator: BoxDecoration(gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]), borderRadius: BorderRadius.circular(12)), labelColor: white, unselectedLabelColor: textGray, dividerColor: Colors.transparent, tabs: const [Tab(text: '🎵 Lyrics'), Tab(text: 'ℹ️ Details')])),
                    SizedBox(height: 250, child: TabBarView(controller: _tabController, children: [_buildLyricsTab(), _buildSongDetailsTab(song)])),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongInfo(Song song) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(song.title, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Text(song.artist, style: TextStyle(fontSize: 16, color: primaryOrange, fontWeight: FontWeight.w600)),
          if (song.album.isNotEmpty) ...[const SizedBox(height: 4), Text(song.album, style: TextStyle(fontSize: 14, color: textGray))],
        ],
      ),
    );
  }
}

class JioSaavnApi {
  static const String _apiUrl = 'https://saavnapi-nine.vercel.app';
  static const String _proxyUrl = 'https://sri-keyan-music-player.onrender.com';

  static String getProxyUrl(String audioUrl) {
    return '$_proxyUrl/proxy?url=${Uri.encodeComponent(audioUrl)}';
  }

  static Future<List<Song>> getHome() async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/result/?query=tamil+songs')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Song.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching home: $e');
    }
    return [];
  }

  static Future<List<Song>> search(String query) async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/result/?query=${Uri.encodeComponent(query)}')).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) => Song.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('Error searching: $e');
    }
    return [];
  }

  static Future<String> getLyrics(String songId) async {
    try {
      final response = await http.get(Uri.parse('$_apiUrl/lyrics/?id=$songId')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lyrics'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
    }
    
    try {
      final response = await http.get(Uri.parse('$_apiUrl/song/?id=$songId')).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lyrics'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
    }
    return '';
  }
}