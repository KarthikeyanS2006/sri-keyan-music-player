import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
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
  double _loadingProgress = 0.0;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color secondaryOrange = Color(0xFFFF8C42);
  static const Color lightOrange = Color(0xFFFFB38A);
  static const Color accentOrange = Color(0xFFFF4500);
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
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() => _loadingProgress = i / 100);
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
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
                          child: const Icon(
                            Icons.music_note,
                            size: 70,
                            color: white,
                          ),
                        ),
                        const SizedBox(height: 32),
                        ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [primaryOrange, secondaryOrange],
                          ).createShader(bounds),
                          child: const Text(
                            'Sri Keyan',
                            style: TextStyle(
                              fontSize: 42,
                              fontWeight: FontWeight.bold,
                              color: white,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Music Player',
                          style: TextStyle(
                            fontSize: 16,
                            color: textGray,
                            letterSpacing: 4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          width: 200,
                          height: 4,
                          decoration: BoxDecoration(
                            color: lightGray,
                            borderRadius: BorderRadius.circular(2),
                          ),
                          child: FractionallySizedBox(
                            alignment: Alignment.centerLeft,
                            widthFactor: _loadingProgress,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [primaryOrange, secondaryOrange],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${(_loadingProgress * 100).toInt()}%',
                          style: TextStyle(
                            color: textGray,
                            fontSize: 14,
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
        appBarTheme: const AppBarTheme(
          backgroundColor: white,
          foregroundColor: textDark,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            color: textDark,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
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

class _MusicPlayerScreenState extends State<MusicPlayerScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showFullPlayer = false;
  String _currentCategory = 'Trending';
  String _currentLyrics = '';
  List<String> _lyricLines = [];
  int _currentLyricIndex = -1;
  final ScrollController _lyricsScrollController = ScrollController();
  bool _isDesktop = false;
  bool _isTablet = false;

  bool get isMobile => !_isDesktop && !_isTablet;

  void _updateDeviceType() {
    final width = MediaQuery.of(context).size.width;
    setState(() {
      _isDesktop = width > 1024;
      _isTablet = width > 600 && width <= 1024;
    });
  }

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
    _focusNode.requestFocus();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateDeviceType();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateDeviceType();
    }
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final songs = await JioSaavnApi.getHome();
      setState(() {
        _songs = songs;
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
            _playNext();
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
      _lyricsScrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
    return '''♪ ♫ ♪ ♫ ♪ ♫ ♪

🎵 Now Playing 🎵

$songName

♪ ♫ ♫ ♪ ♫ ♫ ♪

🎶 Lyrics not available 🎶

The full lyrics will appear here
when available from JioSaavn

♪ ♫ ♪ ♫ ♪ ♫ ♪

Thank you for listening!''';
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    
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
      } catch (e) {
        debugPrint('Error playing: $e');
        if (mounted) {
          setState(() => _isBuffering = false);
        }
      }
    } else {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  Future<void> _openYoutubeTrailer(String movieName) async {
    final movie = movieName
        .replaceAll("From '", "")
        .replaceAll("from '", "")
        .replaceAll("'", "")
        .replaceAll("(", "")
        .replaceAll(")", "")
        .replaceAll("From ", "")
        .trim();
    
    final searchQuery = Uri.encodeComponent('$movie tamil movie trailer');
    // This will be handled by the button tap
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

  void _changeCategory(String category) async {
    setState(() {
      _currentCategory = category;
      _isLoading = true;
      _isSearching = false;
      _searchController.clear();
    });
    
    List<Song> songs;
    switch (category) {
      case 'Tamil':
        songs = await JioSaavnApi.search('tamil songs');
        break;
      case 'Hindi':
        songs = await JioSaavnApi.search('hindi songs');
        break;
      case 'Melody':
        songs = await JioSaavnApi.search('tamil melody songs');
        break;
      case 'Party':
        songs = await JioSaavnApi.search('tamil party songs');
        break;
      case 'Trending':
      default:
        songs = await JioSaavnApi.getHome();
    }
    
    setState(() {
      _songs = songs.isNotEmpty ? songs : _songs;
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
        body: _showFullPlayer
            ? _buildFullPlayer()
            : _buildMainScreen(),
      ),
    );
  }

  Widget _buildMainScreen() {
    if (_isDesktop) {
      return _buildDesktopLayout();
    }
    return SafeArea(
      child: Column(
        children: [
          _buildAppBar(),
          _buildSearchBar(),
          _buildCategoryTabs(),
          Expanded(child: _buildSongList()),
          if (_songs.isNotEmpty) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return SafeArea(
      child: Row(
        children: [
          // Side panel for desktop
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(2, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                _buildAppBar(),
                _buildSearchBar(),
                _buildCategoryTabs(),
                Expanded(child: _buildSongList()),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: _buildDesktopNowPlaying(),
                ),
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
            Text(
              'Select a song to play',
              style: TextStyle(color: textGray, fontSize: 18),
            ),
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
          Text(
            song.title,
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textDark),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: TextStyle(fontSize: 18, color: primaryOrange, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 24),
          _buildControlsSection(),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(
              color: lightGray,
              borderRadius: BorderRadius.circular(16),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: const LinearGradient(colors: [primaryOrange, secondaryOrange]),
                borderRadius: BorderRadius.circular(16),
              ),
              labelColor: white,
              unselectedLabelColor: textGray,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '🎵 Lyrics'),
                Tab(text: 'ℹ️ Details'),
              ],
            ),
          ),
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildLyricsTab(),
                _buildSongDetailsTab(song),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [primaryOrange, secondaryOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.music_note, color: white, size: 28),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [primaryOrange, secondaryOrange],
                ).createShader(bounds),
                child: const Text(
                  'Sri Keyan',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: white,
                  ),
                ),
              ),
              Text(
                'Music Player',
                style: TextStyle(
                  fontSize: 12,
                  color: textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: TextStyle(color: textDark),
        decoration: InputDecoration(
          hintText: 'Search songs, albums, artists...',
          hintStyle: TextStyle(color: textGray),
          prefixIcon: Icon(Icons.search, color: textGray),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, color: textGray),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    final categories = ['Trending', 'Tamil', 'Hindi', 'Melody', 'Party'];
    
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = _currentCategory == categories[index];
          return GestureDetector(
            onTap: () => _changeCategory(categories[index]),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? const LinearGradient(
                        colors: [primaryOrange, secondaryOrange],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : lightGray,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Center(
                child: Text(
                  categories[index],
                  style: TextStyle(
                    color: isSelected ? white : textGray,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryOrange),
            const SizedBox(height: 16),
            Text('Loading songs...', style: TextStyle(color: textGray)),
          ],
        ),
      );
    }
    
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 80, color: lightOrange),
            const SizedBox(height: 16),
            Text(
              _isSearching ? 'No songs found' : 'No songs available',
              style: TextStyle(fontSize: 18, color: textGray, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${displaySongs.length} Songs',
                style: TextStyle(color: textGray, fontWeight: FontWeight.w600),
              ),
              if (_isSearching)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                  child: Text('Clear', style: TextStyle(color: primaryOrange)),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: displaySongs.length,
            itemBuilder: (context, idx) {
              final song = displaySongs[idx];
              final isSelected = idx == _currentIndex && !_isSearching;
              
              return _SongTile(
                song: song,
                isSelected: isSelected,
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
            colors: [primaryOrange, secondaryOrange],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: primaryOrange.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
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
                    color: white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                            const Icon(Icons.music_note, color: white))
                        : const Icon(Icons.music_note, color: white),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        song.artist,
                        style: TextStyle(color: white.withValues(alpha: 0.8), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  color: white,
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: white,
                  onPressed: _playNext,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatDuration(_position), style: TextStyle(fontSize: 11, color: white.withValues(alpha: 0.8))),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                      activeTrackColor: white,
                      inactiveTrackColor: white.withValues(alpha: 0.3),
                      thumbColor: white,
                    ),
                    child: Slider(
                      value: _duration.inSeconds > 0 
                          ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble())
                          : 0,
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                      onChanged: _duration.inSeconds > 0 
                          ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt()))
                          : null,
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: TextStyle(fontSize: 11, color: white.withValues(alpha: 0.8))),
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
    
    return SafeArea(
      child: Scaffold(
        backgroundColor: white,
        body: Column(
          children: [
            _buildFullPlayerHeader(song),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    if (song.isMovieSong)
                      _buildTrailerSection(song),
                    _buildAlbumArt(song),
                    _buildSongInfo(song),
                    const SizedBox(height: 20),
                    _buildProgressSection(),
                    const SizedBox(height: 20),
                    _buildControlsSection(),
                    const SizedBox(height: 20),
                    _buildTabBar(),
                    SizedBox(
                      height: 250,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildLyricsTab(),
                          _buildSongDetailsTab(song),
                        ],
                      ),
                    ),
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

  Widget _buildFullPlayerHeader(Song song) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down, size: 32),
            color: textDark,
            onPressed: () => setState(() => _showFullPlayer = false),
          ),
          Column(
            children: [
              Text('Now Playing', style: TextStyle(color: textGray, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(
                _currentCategory,
                style: TextStyle(color: primaryOrange, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.queue_music),
            color: textDark,
            onPressed: () => _showQueueBottomSheet(),
          ),
        ],
      ),
    );
  }

  Widget _buildTrailerSection(Song song) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.movie, color: primaryOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                'Movie Trailer',
                style: TextStyle(color: textDark, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                song.movieName,
                style: TextStyle(color: primaryOrange, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () async {
              final movie = song.movieName
                  .replaceAll("From '", "")
                  .replaceAll("from '", "")
                  .replaceAll("'", "")
                  .replaceAll("(", "")
                  .replaceAll(")", "")
                  .replaceAll("From ", "")
                  .trim();
              final searchQuery = Uri.encodeComponent('$movie tamil movie trailer');
              final url = Uri.parse('https://www.youtube.com/results?search_query=$searchQuery');
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF0000), Color(0xFFFF4444)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_circle_outline, color: white, size: 50),
                    SizedBox(height: 8),
                    Text('Tap to watch trailer on YouTube', style: TextStyle(color: white)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildAlbumArt(Song song) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [primaryOrange, secondaryOrange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: primaryOrange.withValues(alpha: 0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                const Icon(Icons.music_note, color: white, size: 100))
            : const Icon(Icons.music_note, color: white, size: 100),
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
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textDark),
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
            Text(
              song.album,
              style: TextStyle(fontSize: 14, color: textGray),
            ),
          ],
        ],
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
              value: _duration.inSeconds > 0 
                  ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble())
                  : 0,
              min: 0,
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
              onChanged: _duration.inSeconds > 0 
                  ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt()))
                  : null,
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
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 45),
          color: textDark,
          onPressed: _playPrevious,
        ),
        Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [primaryOrange, secondaryOrange],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: primaryOrange.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: _isBuffering
              ? const Center(
                  child: SizedBox(
                    width: 35,
                    height: 35,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: white,
                    ),
                  ),
                )
              : IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 45),
                  color: white,
                  onPressed: _togglePlayPause,
                ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 45),
          color: textDark,
          onPressed: _playNext,
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [primaryOrange, secondaryOrange],
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: white,
        unselectedLabelColor: textGray,
        dividerColor: Colors.transparent,
        tabs: const [
          Tab(text: '🎵 Lyrics'),
          Tab(text: 'ℹ️ Details'),
        ],
      ),
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(15),
      ),
      child: _lyricLines.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 50, color: lightOrange),
                  const SizedBox(height: 16),
                  Text('Loading lyrics...', style: TextStyle(color: textGray)),
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
                      fontSize: isCurrentLyric ? 18 : 15,
                      fontWeight: isCurrentLyric ? FontWeight.bold : FontWeight.normal,
                      color: isCurrentLyric ? primaryOrange : textGray,
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
      decoration: BoxDecoration(
        color: lightGray,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Title', song.title),
          _buildDetailRow('Artist', song.artist),
          if (song.album.isNotEmpty) _buildDetailRow('Album', song.album),
          if (song.year.isNotEmpty) _buildDetailRow('Year', song.year),
          if (song.duration.isNotEmpty) _buildDetailRow('Duration', '${int.tryParse(song.duration) != null ? _formatDuration(Duration(seconds: int.parse(song.duration))) : song.duration}'),
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
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(color: textGray, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: textDark),
            ),
          ),
        ],
      ),
    );
  }

  void _showQueueBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.queue_music, color: primaryOrange),
                const SizedBox(width: 8),
                Text(
                  'Up Next',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _songs.length,
                itemBuilder: (context, index) {
                  final song = _songs[index];
                  final isCurrent = index == _currentIndex;
                  return ListTile(
                    leading: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: isCurrent ? primaryOrange : lightGray,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: song.imageUrl.isNotEmpty
                            ? Image.network(song.imageUrl, fit: BoxFit.cover)
                            : Icon(Icons.music_note, color: isCurrent ? white : textGray),
                      ),
                    ),
                    title: Text(
                      song.title,
                      style: TextStyle(
                        color: isCurrent ? primaryOrange : textDark,
                        fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      song.artist,
                      style: TextStyle(color: textGray, fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: isCurrent
                        ? Icon(Icons.equalizer, color: primaryOrange)
                        : Text(
                            _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
                            style: TextStyle(color: textGray, fontSize: 12),
                          ),
                    onTap: () {
                      Navigator.pop(context);
                      _playSong(index);
                    },
                  );
                },
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
  final bool isSelected;
  final VoidCallback onTap;

  const _SongTile({
    required this.song,
    required this.isSelected,
    required this.onTap,
  });

  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color lightGray = Color(0xFFF8F9FA);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textGray = Color(0xFF6C757D);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? primaryOrange.withValues(alpha: 0.1) : lightGray,
        borderRadius: BorderRadius.circular(12),
        border: isSelected
            ? Border.all(color: primaryOrange, width: 2)
            : null,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: Container(
          width: 55,
          height: 55,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: isSelected
                ? const LinearGradient(colors: [primaryOrange, Color(0xFFFF8C42)])
                : null,
            color: isSelected ? null : const Color(0xFFE0E0E0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: song.imageUrl.isNotEmpty
                ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => 
                    Icon(Icons.music_note, color: isSelected ? Colors.white : textGray))
                : Icon(Icons.music_note, color: isSelected ? Colors.white : textGray),
          ),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
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
            ? const Icon(Icons.equalizer, color: primaryOrange)
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.isMovieSong)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(Icons.movie, size: 16, color: primaryOrange),
                    ),
                  Text(
                    _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
                    style: TextStyle(color: textGray, fontSize: 12),
                  ),
                ],
              ),
        onTap: onTap,
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String minutes = twoDigits(duration.inMinutes.remainder(60));
    String seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
      final response = await http.get(
        Uri.parse('$_apiUrl/result/?query=tamil+songs'),
      ).timeout(const Duration(seconds: 15));
      
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
      final response = await http.get(
        Uri.parse('$_apiUrl/result/?query=${Uri.encodeComponent(query)}'),
      ).timeout(const Duration(seconds: 15));
      
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
      // Try official API first
      final response = await http.get(
        Uri.parse('$_apiUrl/lyrics/?id=$songId'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lyrics'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching lyrics from API: $e');
    }
    
    // Try from song details
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/song/?id=$songId'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['lyrics'] ?? '';
      }
    } catch (e) {
      debugPrint('Error fetching lyrics: $e');
    }
    return '';
  }

  static Future<String?> getPlayUrl(String songId) async {
    return null;
  }
}
