import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
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

class _MusicAppState extends State<MusicApp> {
  bool _isInitialized = false;
  double _loadingProgress = 0.0;
  bool _showPreferences = false;
  List<String> _selectedLanguages = [];

  static const Color accent = Color(0xFFFF6B35);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);

  @override
  void initState() {
    super.initState();
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
    setState(() => _showPreferences = false);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: accent,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(primary: accent, secondary: accent, surface: background),
      ),
      home: !_isInitialized 
          ? _buildSplashScreen() 
          : _showPreferences 
              ? _buildPreferencesScreen() 
              : const MusicPlayerScreen(),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: accent,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.music_note, size: 60, color: background),
            ),
            const SizedBox(height: 24),
            const Text(
              'Sri Keyan',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: accent,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Container(
              width: 200,
              height: 4,
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(2),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _loadingProgress,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreferencesScreen() {
    final languages = ['Tamil', 'Hindi', 'English', 'Malayalam', 'Telugu'];
    
    return Scaffold(
      backgroundColor: background,
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
                    color: accent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.settings, color: background, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              const Center(
                child: Text(
                  'Welcome to Sri Keyan!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Select your preferred languages',
                  style: TextStyle(fontSize: 14, color: textSecondary),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Preferred Languages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
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
                        color: isSelected ? accent : surface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        lang,
                        style: TextStyle(
                          color: isSelected ? background : textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                    backgroundColor: accent,
                    foregroundColor: background,
                    disabledBackgroundColor: surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
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
    final preview = json['media_preview_url'] ?? json['previewUrl'] ?? '';
    final mediaUrl = json['media_url'] ?? json['downloadUrl'] ?? '';
    final image = json['image'] ?? json['thumbnail'] ?? json['albumArt'] ?? '';
    final songId = json['id'] ?? json['e_songid'] ?? json['videoId'] ?? '';
    
    String imageUrl = image;
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = 'https://c-sf.smule.com' + imageUrl;
    }
    
    return Song(
      id: songId.toString(),
      title: json['song'] ?? json['title'] ?? json['name'] ?? 'Unknown',
      artist: json['primary_artists'] ?? json['singers'] ?? json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? json['album_name'] ?? 'Unknown Album',
      imageUrl: imageUrl,
      audioUrl: preview.isNotEmpty ? preview : mediaUrl,
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

enum RepeatMode { off, one, all }

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
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showFullPlayer = false;
  String _currentCategory = 'For You';
  String _currentLyrics = '';
  final ScrollController _lyricsScrollController = ScrollController();
  bool _isDesktop = false;
  bool _isLoadingMore = false;
  int _page = 1;
  String _lastCategory = 'For You';
  RepeatMode _repeatMode = RepeatMode.all;

  static const Color accent = Color(0xFFFF6B35);
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF5F5F5);
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF888888);

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
          }
        });
      }
    });
  }

  Future<void> _fetchLyrics(String songId, String songName) async {
    try {
      final lyrics = await JioSaavnApi.getLyrics(songId);
      if (mounted) {
        setState(() {
          _currentLyrics = lyrics.isNotEmpty ? lyrics : '♪ ♫ ♪\n\n$songName\n\n♪ ♫ ♪\n\nLyrics not available';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentLyrics = '♪ ♫ ♪\n\n$songName\n\n♪ ♫ ♪\n\nLyrics not available';
        });
      }
    }
  }

  Future<void> _playSong(int index) async {
    if (index < 0 || index >= _songs.length) return;
    
    setState(() {
      _currentIndex = index;
      _isBuffering = true;
      _duration = Duration.zero;
      _position = Duration.zero;
      _currentLyrics = '';
    });
    
    final song = _songs[index];
    _fetchLyrics(song.id, song.title);
    
    if (song.audioUrl.isNotEmpty) {
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(song.audioUrl);
        await _audioPlayer.play();
      } catch (e) {
        debugPrint('Error playing: $e');
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

  void _cycleRepeatMode() {
    setState(() {
      switch (_repeatMode) {
        case RepeatMode.off:
          _repeatMode = RepeatMode.all;
          break;
        case RepeatMode.all:
          _repeatMode = RepeatMode.one;
          break;
        case RepeatMode.one:
          _repeatMode = RepeatMode.off;
          break;
      }
    });
  }

  Future<void> _playNext() async {
    if (_songs.isEmpty) return;
    
    if (_repeatMode == RepeatMode.one) {
      await _audioPlayer.seek(Duration.zero);
      await _audioPlayer.play();
      return;
    }
    
    int nextIndex = _currentIndex + 1;
    if (nextIndex >= _songs.length) {
      if (_repeatMode == RepeatMode.all) {
        nextIndex = 0;
      } else {
        return;
      }
    }
    await _playSong(nextIndex);
  }

  Future<void> _playPrevious() async {
    if (_position.inSeconds > 3) {
      await _audioPlayer.seek(Duration.zero);
    } else {
      int prevIndex = _currentIndex - 1;
      if (prevIndex < 0) {
        prevIndex = _repeatMode == RepeatMode.all ? _songs.length - 1 : 0;
      }
      await _playSong(prevIndex);
    }
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
        backgroundColor: background,
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
          _buildPlaylistTabs(),
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
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: background, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'Sri Keyan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      height: 44,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: const TextStyle(color: textPrimary, fontSize: 14),
        decoration: const InputDecoration(
          hintText: 'Search songs...',
          hintStyle: TextStyle(color: textSecondary, fontSize: 14),
          prefixIcon: Icon(Icons.search, color: textSecondary, size: 20),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildPlaylistTabs() {
    final playlists = ['For You', 'Tamil Hits', 'Melody', 'Sad Songs', 'Party', '90s Tamil', '2000s Tamil'];
    
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final isSelected = _currentCategory == playlist;
          return GestureDetector(
            onTap: () => _changePlaylist(playlist),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? accent : surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Center(
                child: Text(
                  playlist,
                  style: TextStyle(
                    color: isSelected ? background : textSecondary,
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
      return const Center(child: CircularProgressIndicator(color: accent));
    }
    
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 60, color: textSecondary),
            const SizedBox(height: 16),
            const Text('No songs found', style: TextStyle(color: textSecondary, fontSize: 16)),
          ],
        ),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification &&
            notification.metrics.extentAfter < 200 &&
            !_isLoadingMore &&
            !_isSearching &&
            _currentCategory == 'For You') {
          _loadMoreSongs();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: displaySongs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx >= displaySongs.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(color: accent),
              ),
            );
          }
          final song = displaySongs[idx];
          final isSelected = idx == _currentIndex && !_isSearching;
          return _buildSongCard(song, isSelected, idx);
        },
      ),
    );
  }

  Future<void> _loadMoreSongs() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);
    _page++;
    
    try {
      final newSongs = await JioSaavnApi.search('tamil songs page $_page');
      if (newSongs.isNotEmpty && mounted) {
        setState(() {
          _songs = [..._songs, ...newSongs];
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (e) {
      debugPrint('Error loading more songs: $e');
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Widget _buildSongCard(Song song, bool isSelected, int index) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? accent.withValues(alpha: 0.1) : background,
        borderRadius: BorderRadius.circular(12),
        border: isSelected ? Border.all(color: accent, width: 1.5) : Border.all(color: surface, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: song.imageUrl.isNotEmpty
                ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: accent))
                : const Icon(Icons.music_note, color: accent),
          ),
        ),
        title: Text(
          song.title,
          style: TextStyle(
            color: textPrimary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          song.artist,
          style: const TextStyle(color: textSecondary, fontSize: 12),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Text(
          _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
          style: const TextStyle(color: textSecondary, fontSize: 11),
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
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(14),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: background))
                        : const Icon(Icons.music_note, color: background),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: background),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 32),
                  color: background,
                  onPressed: _togglePlayPause,
                ),
                IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  color: background,
                  onPressed: _playNext,
                ),
                IconButton(
                  icon: Icon(
                    _repeatMode == RepeatMode.one ? Icons.repeat_one : Icons.repeat,
                    size: 22,
                  ),
                  color: background,
                  onPressed: _cycleRepeatMode,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(_formatDuration(_position), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 3,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                      activeTrackColor: background,
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      thumbColor: background,
                    ),
                    child: Slider(
                      value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()) : 0,
                      min: 0,
                      max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
                      onChanged: _duration.inSeconds > 0 ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt())) : null,
                    ),
                  ),
                ),
                Text(_formatDuration(_duration), style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8))),
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
            width: 340,
            decoration: BoxDecoration(
              color: surface,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Column(
              children: [
                _buildSidebarHeader(),
                _buildSearchBar(),
                _buildPlaylistTabs(),
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
              color: accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.music_note, color: background, size: 22),
          ),
          const SizedBox(width: 10),
          const Text(
            'Sri Keyan',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopNowPlaying() {
    if (_songs.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 100, color: textSecondary),
            SizedBox(height: 20),
            Text('Select a song to play', style: TextStyle(color: textSecondary, fontSize: 18)),
          ],
        ),
      );
    }
    
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          _buildDesktopAlbumArt(song),
          const SizedBox(height: 24),
          Text(
            song.title,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: const TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 24),
          _buildDesktopProgressSection(),
          const SizedBox(height: 24),
          _buildControlsSection(),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
              labelColor: background,
              unselectedLabelColor: textSecondary,
              dividerColor: Colors.transparent,
              tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
            ),
          ),
          SizedBox(height: 280, child: TabBarView(controller: _tabController, children: [_buildLyricsTab(), _buildSongDetailsTab(song)])),
        ],
      ),
    );
  }

  Widget _buildDesktopAlbumArt(Song song) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: accent, size: 100))
            : const Icon(Icons.music_note, color: accent, size: 100),
      ),
    );
  }

  Widget _buildDesktopProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              activeTrackColor: accent,
              inactiveTrackColor: surface,
              thumbColor: accent,
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
              Text(_formatDuration(_position), style: const TextStyle(color: textSecondary)),
              Text(_formatDuration(_duration), style: const TextStyle(color: textSecondary)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    IconData repeatIcon;
    Color repeatColor = textSecondary;
    
    switch (_repeatMode) {
      case RepeatMode.off:
        repeatIcon = Icons.repeat;
        repeatColor = textSecondary;
        break;
      case RepeatMode.one:
        repeatIcon = Icons.repeat_one;
        repeatColor = accent;
        break;
      case RepeatMode.all:
        repeatIcon = Icons.repeat;
        repeatColor = accent;
        break;
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        const SizedBox(width: 48),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded, size: 40),
          color: textPrimary,
          onPressed: _playPrevious,
        ),
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
          ),
          child: _isBuffering
              ? const Center(child: SizedBox(width: 30, height: 30, child: CircularProgressIndicator(strokeWidth: 3, color: background)))
              : IconButton(
                  icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
                  color: background,
                  onPressed: _togglePlayPause,
                ),
        ),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 40),
          color: textPrimary,
          onPressed: _playNext,
        ),
        IconButton(
          icon: Icon(repeatIcon, size: 28),
          color: repeatColor,
          onPressed: _cycleRepeatMode,
        ),
        const SizedBox(width: 20),
      ],
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
      child: _currentLyrics.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_note, size: 50, color: textSecondary),
                  SizedBox(height: 16),
                  Text('Loading lyrics...', style: TextStyle(color: textSecondary)),
                ],
              ),
            )
          : SingleChildScrollView(
              controller: _lyricsScrollController,
              child: Text(
                _currentLyrics,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  color: textPrimary,
                  height: 1.8,
                ),
              ),
            ),
    );
  }

  Widget _buildSongDetailsTab(Song song) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
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
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(color: textSecondary, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    
    return Scaffold(
      backgroundColor: background,
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
                    color: textPrimary,
                    onPressed: () => setState(() => _showFullPlayer = false),
                  ),
                  const Text(
                    'Now Playing',
                    style: TextStyle(color: textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildFullPlayerAlbumArt(song),
                    _buildFullPlayerSongInfo(song),
                    _buildDesktopProgressSection(),
                    const SizedBox(height: 20),
                    _buildControlsSection(),
                    const SizedBox(height: 20),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(12)),
                        labelColor: background,
                        unselectedLabelColor: textSecondary,
                        dividerColor: Colors.transparent,
                        tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
                      ),
                    ),
                    SizedBox(
                      height: 250,
                      child: TabBarView(
                        controller: _tabController,
                        children: [_buildLyricsTab(), _buildSongDetailsTab(song)],
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

  Widget _buildFullPlayerAlbumArt(Song song) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.2),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: accent, size: 100))
            : const Icon(Icons.music_note, color: accent, size: 100),
      ),
    );
  }

  Widget _buildFullPlayerSongInfo(Song song) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            song.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            song.artist,
            style: const TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w600),
          ),
          if (song.album.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(song.album, style: const TextStyle(fontSize: 14, color: textSecondary)),
          ],
        ],
      ),
    );
  }
}

class JioSaavnApi {
  static const String _apiUrl = 'https://saavnapi-nine.vercel.app';
  static const String _proxyUrl = 'https://sri-keyan-music-player.onrender.com';

  static String getProxyUrl(String audioUrl) {
    if (audioUrl.contains('preview.saavncdn.com')) {
      return audioUrl;
    }
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
    return '';
  }

  static Future<String?> getStreamUrl(String songId) async {
    try {
      final response = await http.get(
        Uri.parse('$_proxyUrl/play?id=$songId'),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['url'] ?? data['media_url'];
      }
    } catch (e) {
      debugPrint('Error getting stream: $e');
    }
    return null;
  }
}
