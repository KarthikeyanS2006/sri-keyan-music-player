import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';

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
  bool _isDarkMode = false;

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF0F0F0);
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF282828);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF888888);
  static const Color textLightGray = Color(0xFFB3B3B3);

  @override
  void initState() {
    super.initState();
    _isDarkMode = _isNightTime();
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

  bool _isNightTime() {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
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
    setState(() => _showPreferences = false);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Color get _backgroundColor => _isDarkMode ? darkBg : white;
  Color get _surfaceColor => _isDarkMode ? darkSurface : lightGray;
  Color get _cardColor => _isDarkMode ? darkCard : white;
  Color get _textColor => _isDarkMode ? white : textDark;
  Color get _subTextColor => _isDarkMode ? textLightGray : textGray;

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _showPreferences) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: _isDarkMode ? Brightness.dark : Brightness.light,
          primaryColor: primaryOrange,
          scaffoldBackgroundColor: _backgroundColor,
          colorScheme: _isDarkMode 
              ? ColorScheme.dark(primary: primaryOrange, secondary: primaryOrange)
              : ColorScheme.light(primary: primaryOrange, secondary: primaryOrange),
        ),
        home: _showPreferences ? _buildPreferencesScreen() : _buildSplashScreen(),
      );
    }

    return MaterialApp(
      title: 'Sri Keyan',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: _isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: primaryOrange,
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: _isDarkMode 
            ? ColorScheme.dark(primary: primaryOrange, secondary: primaryOrange, surface: darkSurface)
            : ColorScheme.light(primary: primaryOrange, secondary: primaryOrange, surface: white),
      ),
      home: const MusicPlayerScreen(),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: _backgroundColor,
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
                        color: primaryOrange,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(Icons.music_note, size: 70, color: white),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      'Sri Keyan',
                      style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: primaryOrange, letterSpacing: 2),
                    ),
                    const SizedBox(height: 48),
                    Container(
                      width: 200,
                      height: 4,
                      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(2)),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: _loadingProgress,
                        child: Container(
                          decoration: BoxDecoration(
                            color: primaryOrange,
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
    final languages = ['Tamil', 'Hindi', 'English', 'Malayalam', 'Telugu'];
    
    return Scaffold(
      backgroundColor: _backgroundColor,
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
                    color: primaryOrange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.settings, color: white, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  'Welcome to Sri Keyan!',
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: _textColor),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Select your preferred languages',
                  style: TextStyle(fontSize: 14, color: _subTextColor),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              Text('Preferred Languages', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textColor)),
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
                        color: isSelected ? primaryOrange : _surfaceColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang,
                        style: TextStyle(
                          color: isSelected ? white : _subTextColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                        ),
                      ),
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
                    disabledBackgroundColor: _surfaceColor,
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
  final String previewUrl;
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
    this.previewUrl = '',
    required this.duration,
    this.url = '',
    this.year = '',
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    // Use preview URL if available (no DRM)
    final preview = json['media_preview_url'] ?? '';
    final mediaUrl = json['media_url'] ?? '';
    
    return Song(
      id: json['id'] ?? json['e_songid'] ?? '',
      title: json['song'] ?? json['title'] ?? 'Unknown',
      artist: json['primary_artists'] ?? json['singers'] ?? 'Unknown Artist',
      album: json['album'] ?? '',
      imageUrl: json['image'] ?? '',
      audioUrl: preview.isNotEmpty ? preview : mediaUrl,
      previewUrl: preview,
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
  Set<String> _downloadedSongs = {};
  bool _shuffleOn = false;
  bool _repeatOn = false;
  List<int> _shuffledIndices = [];

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGray = Color(0xFFF0F0F0);
  static const Color darkBg = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkCard = Color(0xFF282828);
  static const Color textDark = Color(0xFF333333);
  static const Color textGray = Color(0xFF888888);
  static const Color textLightGray = Color(0xFFB3B3B3);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDeviceType();
    });
    _loadSongs();
    _checkDownloadedSongs();
  }

  bool get _isDarkMode {
    final hour = DateTime.now().hour;
    return hour >= 18 || hour < 6;
  }

  Color get _backgroundColor => _isDarkMode ? darkBg : white;
  Color get _surfaceColor => _isDarkMode ? darkSurface : lightGray;
  Color get _cardColor => _isDarkMode ? darkCard : white;
  Color get _textColor => _isDarkMode ? white : textDark;
  Color get _subTextColor => _isDarkMode ? textLightGray : textGray;

  void _checkDownloadedSongs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory('${directory.path}/sri_keyan_songs');
      if (await dir.exists()) {
        final files = await dir.list().toList();
        setState(() {
          _downloadedSongs = files
              .whereType<File>()
              .map((f) => f.path.split('/').last.split('.').first)
              .toSet();
        });
      }
    } catch (e) {
      debugPrint('Error checking downloads: $e');
    }
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
        _shuffledIndices = List.generate(songs.length, (i) => i);
        _shuffledIndices.shuffle();
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
            if (_repeatOn) {
              _playSong(_currentIndex);
            } else {
              _fadeToNext();
            }
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
    return '♪ ♫ ♪ ♫ ♪ ♫ ♪\n\n$songName\n\n♪ ♫ ♫ ♪ ♫ ♫ ♪\n\nLyrics coming soon\n\n♪ ♫ ♪ ♫ ♪ ♫ ♪';
  }

  int _getActualIndex(int displayIndex) {
    if (_shuffleOn) {
      return _shuffledIndices[displayIndex];
    }
    return displayIndex;
  }

  Future<void> _playSong(int index) async {
    final actualIndex = _getActualIndex(index);
    if (actualIndex < 0 || actualIndex >= _songs.length) return;
    
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
    
    final song = _songs[actualIndex];
    _fetchLyrics(song.id, song.title);
    
    if (song.audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        String playUrl;
        
        if (_downloadedSongs.contains(song.id)) {
          final directory = await getApplicationDocumentsDirectory();
          playUrl = '${directory.path}/sri_keyan_songs/${song.id}.mp3';
        } else {
          playUrl = JioSaavnApi.getProxyUrl(song.audioUrl);
        }
        
        await _audioPlayer.setUrl(playUrl);
        await _audioPlayer.play();
        
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

  Future<void> _downloadSong(Song song) async {
    if (_downloadedSongs.contains(song.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Already downloaded'),
          backgroundColor: primaryOrange,
        ),
      );
      return;
    }

    try {
      final directory = await getApplicationDocumentsDirectory();
      final dir = Directory('${directory.path}/sri_keyan_songs');
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }

      final file = File('${dir.path}/${song.id}.mp3');
      final response = await http.get(Uri.parse(song.audioUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        setState(() {
          _downloadedSongs.add(song.id);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded: ${song.title}'),
              backgroundColor: primaryOrange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Download failed'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
    int nextIndex;
    if (_shuffleOn) {
      nextIndex = (_currentIndex + 1) % _songs.length;
    } else {
      nextIndex = (_currentIndex + 1) % _songs.length;
    }
    await _playSong(nextIndex);
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
    if (_position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
    } else {
      await _playSong((_currentIndex - 1 + _songs.length) % _songs.length);
    }
  }

  void _toggleShuffle() {
    setState(() {
      _shuffleOn = !_shuffleOn;
      if (_shuffleOn) {
        _shuffledIndices.shuffle();
      }
    });
  }

  void _toggleRepeat() {
    setState(() {
      _repeatOn = !_repeatOn;
    });
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
      case 'For You':
      default:
        songs = await JioSaavnApi.getHome();
    }
    
    setState(() {
      _songs = songs.isNotEmpty ? songs : _songs;
      _shuffledIndices = List.generate(_songs.length, (i) => i);
      _shuffledIndices.shuffle();
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
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: _showFullPlayer 
            ? _buildFullPlayer() 
            : (_isDesktop ? _buildDesktopLayout() : _buildMobileLayout()),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.space) {
        _togglePlayPause();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        _playNext();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        _playPrevious();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        _audioPlayer.setVolume((_audioPlayer.volume + 0.1).clamp(0.0, 1.0));
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        _audioPlayer.setVolume((_audioPlayer.volume - 0.1).clamp(0.0, 1.0));
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        _toggleShuffle();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyR) {
        _toggleRepeat();
        return KeyEventResult.handled;
      } else if (event.logicalKey == LogicalKeyboardKey.keyL) {
        setState(() => _showFullPlayer = !_showFullPlayer);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          _buildSearchBar(),
          _buildPlaylistGrid(),
          Expanded(child: _buildSongList()),
          if (_songs.isNotEmpty) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: white, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Sri Keyan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
          ),
          const Spacer(),
          IconButton(icon: Icon(Icons.library_music, color: _textColor), onPressed: () {}),
          IconButton(icon: Icon(Icons.settings, color: _textColor), onPressed: () {}),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: _surfaceColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: TextStyle(color: _textColor, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search songs...',
          hintStyle: TextStyle(color: _subTextColor, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: _subTextColor, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPlaylistGrid() {
    final playlists = [
      {'name': 'For You', 'icon': Icons.favorite, 'color': primaryOrange},
      {'name': 'Tamil Hits', 'icon': Icons.star, 'color': Colors.blue},
      {'name': 'Melody', 'icon': Icons.music_note, 'color': Colors.purple},
      {'name': 'Sad Songs', 'icon': Icons.sentiment_dissatisfied, 'color': Colors.indigo},
      {'name': 'Party', 'icon': Icons.celebration, 'color': Colors.pink},
      {'name': '90s Tamil', 'icon': Icons.history, 'color': Colors.teal},
      {'name': '2000s Tamil', 'icon': Icons.access_time, 'color': Colors.amber},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Text(
            'Your Playlists',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: playlists.length,
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              final isSelected = _currentCategory == playlist['name'];
              return GestureDetector(
                onTap: () => _changePlaylist(playlist['name'] as String),
                child: Container(
                  width: 100,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? primaryOrange : (_cardColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        playlist['icon'] as IconData,
                        color: isSelected ? white : (playlist['color'] as Color),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          playlist['name'] as String,
                          style: TextStyle(
                            color: isSelected ? white : _textColor,
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
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
            Icon(Icons.music_off, size: 60, color: _subTextColor),
            const SizedBox(height: 16),
            Text('No songs found', style: TextStyle(color: _subTextColor, fontSize: 16)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: displaySongs.length,
      itemBuilder: (context, idx) {
        final song = displaySongs[idx];
        final actualIndex = _isSearching ? idx : _songs.indexOf(song);
        final isSelected = actualIndex == _getActualIndex(_currentIndex) && !_isSearching;
        
        return _buildSongCard(song, isSelected, idx);
      },
    );
  }

  Widget _buildSongCard(Song song, bool isSelected, int index) {
    final isDownloaded = _downloadedSongs.contains(song.id);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? primaryOrange.withValues(alpha: 0.15) : _cardColor,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: primaryOrange, width: 1.5) : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: primaryOrange.withValues(alpha: 0.2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.imageUrl.isNotEmpty
                ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.music_note, color: primaryOrange))
                : Icon(Icons.music_note, color: primaryOrange),
          ),
        ),
        title: Text(
          song.title,
          style: TextStyle(color: _textColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.w600, fontSize: 14),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: TextStyle(color: _subTextColor, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDownloaded)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Icon(Icons.download_done, size: 16, color: primaryOrange),
              )
            else
              IconButton(
                icon: Icon(Icons.download_outlined, size: 18, color: _subTextColor),
                onPressed: () => _downloadSong(song),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            const SizedBox(width: 8),
            Text(
              _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
              style: TextStyle(color: _subTextColor, fontSize: 11)
            ),
          ],
        ),
        onTap: () {
          if (_isSearching) {
            setState(() {
              _songs = List.from(_searchResults);
              _shuffledIndices = List.generate(_songs.length, (i) => i);
              _shuffledIndices.shuffle();
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
    final actualIndex = _getActualIndex(_currentIndex);
    if (actualIndex < 0 || actualIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[actualIndex];
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: primaryOrange.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryOrange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(Icons.music_note, color: primaryOrange))
                        : Icon(Icons.music_note, color: primaryOrange),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: TextStyle(color: _subTextColor, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                  color: primaryOrange,
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: _textColor,
                  onPressed: _playNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatDuration(_position), style: TextStyle(fontSize: 10, color: _subTextColor)),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: primaryOrange,
                      inactiveTrackColor: _surfaceColor,
                      thumbColor: primaryOrange,
                    ),
                    child: Slider(
                      value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()) : 0,
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                      onChanged: _duration.inSeconds > 0 ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt())) : null,
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: TextStyle(fontSize: 10, color: _subTextColor)),
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
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: _surfaceColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                _buildSearchBar(),
                _buildPlaylistGrid(),
                const SizedBox(height: 8),
                Expanded(child: _buildSongList()),
              ],
            ),
          ),
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

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: primaryOrange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: white, size: 22),
          ),
          const SizedBox(width: 10),
          Text(
            'Sri Keyan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: _textColor),
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
            Icon(Icons.music_note, size: 100, color: _subTextColor),
            const SizedBox(height: 20),
            Text('Select a song to play', style: TextStyle(color: _subTextColor, fontSize: 18)),
          ],
        ),
      );
    }
    
    final actualIndex = _getActualIndex(_currentIndex);
    if (actualIndex < 0 || actualIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[actualIndex];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          if (song.isMovieSong) _buildTrailerSection(song),
          _buildAlbumArt(song),
          const SizedBox(height: 24),
          Text(
            song.title,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: _textColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: TextStyle(fontSize: 16, color: primaryOrange, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 24),
          _buildControlsSection(),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(16)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: primaryOrange, borderRadius: BorderRadius.circular(16)),
              labelColor: white,
              unselectedLabelColor: _subTextColor,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
            ),
          ),
          SizedBox(height: 280, child: TabBarView(controller: _tabController, children: [_buildLyricsTab(), _buildSongDetailsTab(song)])),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: primaryOrange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: primaryOrange, size: 100))
            : const Icon(Icons.music_note, color: primaryOrange, size: 100),
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
          height: 60,
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.play_circle_outline, color: white, size: 30),
                const SizedBox(width: 8),
                const Text('Watch Trailer', style: TextStyle(color: white, fontSize: 14, fontWeight: FontWeight.bold)),
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
              inactiveTrackColor: _surfaceColor,
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
              Text(_formatDuration(_position), style: TextStyle(color: _subTextColor)),
              Text(_formatDuration(_duration), style: TextStyle(color: _subTextColor)),
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
        IconButton(
          icon: Icon(Icons.shuffle, size: 24),
          color: _shuffleOn ? primaryOrange : _subTextColor,
          onPressed: _toggleShuffle,
        ),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 40),
          color: _textColor,
          onPressed: _playPrevious,
        ),
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: primaryOrange,
            shape: BoxShape.circle,
          ),
          child: _isBuffering
              ? const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: white)))
              : IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  color: white,
                  onPressed: _togglePlayPause,
                ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 40),
          color: _textColor,
          onPressed: _playNext,
        ),
        IconButton(
          icon: Icon(_repeatOn ? Icons.repeat_one : Icons.repeat, size: 24),
          color: _repeatOn ? primaryOrange : _subTextColor,
          onPressed: _toggleRepeat,
        ),
      ],
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(15)),
      child: _lyricLines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 50, color: _subTextColor),
                  const SizedBox(height: 16),
                  Text('Loading lyrics...', style: TextStyle(color: _subTextColor)),
                ],
              ),
            )
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
                    style: TextStyle(
                      fontSize: isCurrentLyric ? 17 : 14,
                      fontWeight: isCurrentLyric ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentLyric ? primaryOrange : _subTextColor,
                    ),
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
      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(15)),
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
          SizedBox(width: 80, child: Text(label, style: TextStyle(color: _subTextColor, fontWeight: FontWeight.w600))),
          Expanded(child: Text(value, style: TextStyle(color: _textColor))),
        ],
      ),
    );
  }

  Widget _buildFullPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    final actualIndex = _getActualIndex(_currentIndex);
    if (actualIndex < 0 || actualIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[actualIndex];
    
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                    color: _textColor,
                    onPressed: () => setState(() => _showFullPlayer = false),
                  ),
                  Column(
                    children: [
                      Text('Now Playing', style: TextStyle(color: _subTextColor, fontSize: 12)),
                      Text(_currentCategory, style: TextStyle(color: primaryOrange, fontSize: 14, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.queue_music),
                    color: _textColor,
                    onPressed: () {},
                  ),
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(color: _surfaceColor, borderRadius: BorderRadius.circular(12)),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(color: primaryOrange, borderRadius: BorderRadius.circular(12)),
                        labelColor: white,
                        unselectedLabelColor: _subTextColor,
                        dividerColor: Colors.transparent,
                        tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
                      ),
                    ),
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
          Text(
            song.title,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _textColor),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: TextStyle(fontSize: 16, color: primaryOrange, fontWeight: FontWeight.w600),
          ),
          if (song.album.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(song.album, style: TextStyle(fontSize: 14, color: _subTextColor)),
          ],
        ],
      ),
    );
  }
}

class JioSaavnApi {
  static const String _apiUrl = 'https://saavnapi-nine.vercel.app';
  static const String _proxyUrl = 'https://sri-keyan-music-player.onrender.com/proxy';

  static String getProxyUrl(String audioUrl) {
    // Use preview URL which doesn't have DRM
    if (audioUrl.contains('preview.saavncdn.com')) {
      return audioUrl;
    }
    return '$_proxyUrl?url=${Uri.encodeComponent(audioUrl)}';
  }

  static String getPreviewUrl(String? previewUrl) {
    if (previewUrl != null && previewUrl.isNotEmpty) {
      return previewUrl;
    }
    return '';
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
