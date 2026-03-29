import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class _MusicAppState extends State<MusicApp> {
  bool _isInitialized = false;
  double _loadingProgress = 0.0;
  bool _showPreferences = false;
  List<String> _selectedLanguages = [];
  List<String> _selectedSingers = [];

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
    await prefs.setStringList('singers', _selectedSingers);
    
    await RecommendationEngine.instance.init();
    await RecommendationEngine.instance.updateTasteProfile(
      languages: _selectedLanguages,
      artists: _selectedSingers,
    );
    
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
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 30,
                    offset: const Offset(0, 15),
                  ),
                ],
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
    final singers = ['A.R. Rahman', 'Anirudh', 'Ilaiyaraaja', 'Vishal', 'Harris Jayaraj', 'G.V. Prakash'];
    
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
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.music_note, color: background, size: 40),
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
              Center(
                child: Text(
                  'Help us personalize your experience',
                  style: TextStyle(fontSize: 16, color: textSecondary),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Select Your Favorite Singers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
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
                        color: isSelected ? accent : surface,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
                      ),
                      child: Text(
                        singer,
                        style: TextStyle(
                          color: isSelected ? background : textSecondary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
                        boxShadow: isSelected ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ] : null,
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
                  onPressed: _selectedLanguages.isNotEmpty || _selectedSingers.isNotEmpty ? _savePreferences : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: background,
                    disabledBackgroundColor: surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: _selectedLanguages.isNotEmpty || _selectedSingers.isNotEmpty ? 8 : 0,
                  ),
                  child: const Text(
                    'Get Started',
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
  final String language;

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
    this.language = 'Tamil',
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final mediaUrl = json['media_url'] ?? json['downloadUrl'] ?? '';
    final image = json['image'] ?? json['thumbnail'] ?? json['albumArt'] ?? '';
    final songId = json['id'] ?? json['e_songid'] ?? json['videoId'] ?? '';
    
    String imageUrl = image;
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = 'https://c.saavncdn.com' + imageUrl;
    }
    
    String language = 'Tamil';
    final title = json['song'] ?? json['title'] ?? '';
    final album = json['album'] ?? '';
    final combined = '$title $album'.toLowerCase();
    if (combined.contains('hindi') || combined.contains('bollywood')) {
      language = 'Hindi';
    } else if (combined.contains('english') || combined.contains('hollywood')) {
      language = 'English';
    } else if (combined.contains('malayalam')) {
      language = 'Malayalam';
    } else if (combined.contains('telugu')) {
      language = 'Telugu';
    } else {
      language = 'Tamil';
    }
    
    return Song(
      id: songId.toString(),
      title: json['song'] ?? json['title'] ?? json['name'] ?? 'Unknown',
      artist: json['primary_artists'] ?? json['singers'] ?? json['artist'] ?? 'Unknown Artist',
      album: json['album'] ?? json['album_name'] ?? 'Unknown Album',
      imageUrl: imageUrl,
      audioUrl: mediaUrl,
      duration: json['duration'] ?? '0',
      url: json['perma_url'] ?? json['url'] ?? '',
      year: json['year'] ?? '',
      language: language,
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

enum InteractionType { watch, like, skip, addToPlaylist, notInterested }

class SongInteraction {
  final String songId;
  final String artist;
  final String language;
  final InteractionType type;
  final int watchDuration;
  final int totalDuration;
  final DateTime timestamp;

  SongInteraction({
    required this.songId,
    required this.artist,
    required this.language,
    required this.type,
    required this.watchDuration,
    required this.totalDuration,
    required this.timestamp,
  });

  double get watchPercentage => totalDuration > 0 ? watchDuration / totalDuration : 0;

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'artist': artist,
    'language': language,
    'type': type.name,
    'watchDuration': watchDuration,
    'totalDuration': totalDuration,
    'timestamp': timestamp.toIso8601String(),
  };

  factory SongInteraction.fromJson(Map<String, dynamic> json) => SongInteraction(
    songId: json['songId'],
    artist: json['artist'],
    language: json['language'],
    type: InteractionType.values.firstWhere(
      (e) => e.name == json['type'],
      orElse: () => InteractionType.watch,
    ),
    watchDuration: json['watchDuration'],
    totalDuration: json['totalDuration'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

class UserTasteProfile {
  Map<String, int> artistScores = {};
  Map<String, int> languageScores = {};
  int totalInteractions = 0;
  int totalWatchTime = 0;
  List<String> likedSongs = [];
  List<String> dislikedSongs = [];
  List<String> notInterestedSongs = [];
  List<String> recentlyPlayed = [];

  UserTasteProfile();

  void updateFromInteraction(SongInteraction interaction) {
    totalInteractions++;
    totalWatchTime += interaction.watchDuration;

    switch (interaction.type) {
      case InteractionType.watch:
        int watchScore = (interaction.watchPercentage * 10).round();
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + watchScore;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + watchScore;
        if (!recentlyPlayed.contains(interaction.songId)) {
          recentlyPlayed.insert(0, interaction.songId);
          if (recentlyPlayed.length > 20) recentlyPlayed.removeLast();
        }
        break;
      case InteractionType.like:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 10;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + 10;
        if (!likedSongs.contains(interaction.songId)) likedSongs.add(interaction.songId);
        dislikedSongs.remove(interaction.songId);
        if (!recentlyPlayed.contains(interaction.songId)) {
          recentlyPlayed.insert(0, interaction.songId);
          if (recentlyPlayed.length > 20) recentlyPlayed.removeLast();
        }
        break;
      case InteractionType.skip:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) - 3;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) - 3;
        break;
      case InteractionType.notInterested:
        if (!notInterestedSongs.contains(interaction.songId)) notInterestedSongs.add(interaction.songId);
        dislikedSongs.add(interaction.songId);
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) - 5;
        break;
      case InteractionType.addToPlaylist:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 5;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + 5;
        break;
    }

    artistScores.removeWhere((key, value) => value <= 0);
    languageScores.removeWhere((key, value) => value <= 0);
  }

  List<String> getTopArtists(int count) {
    final sorted = artistScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
  }

  List<String> getTopLanguages(int count) {
    final sorted = languageScores.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
  }

  String get topArtist => getTopArtists(1).firstOrNull ?? 'Anirudh';
  String get topLanguage => getTopLanguages(1).firstOrNull ?? 'Tamil';

  bool isLiked(String songId) => likedSongs.contains(songId);
  bool isNotInterested(String songId) => notInterestedSongs.contains(songId);
  bool isDisliked(String songId) => dislikedSongs.contains(songId);

  Map<String, dynamic> toJson() => {
    'artistScores': artistScores,
    'languageScores': languageScores,
    'totalInteractions': totalInteractions,
    'totalWatchTime': totalWatchTime,
    'likedSongs': likedSongs,
    'dislikedSongs': dislikedSongs,
    'notInterestedSongs': notInterestedSongs,
    'recentlyPlayed': recentlyPlayed,
  };

  factory UserTasteProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserTasteProfile();
    profile.artistScores = Map<String, int>.from(json['artistScores'] ?? {});
    profile.languageScores = Map<String, int>.from(json['languageScores'] ?? {});
    profile.totalInteractions = json['totalInteractions'] ?? 0;
    profile.totalWatchTime = json['totalWatchTime'] ?? 0;
    profile.likedSongs = List<String>.from(json['likedSongs'] ?? []);
    profile.dislikedSongs = List<String>.from(json['dislikedSongs'] ?? []);
    profile.notInterestedSongs = List<String>.from(json['notInterestedSongs'] ?? []);
    profile.recentlyPlayed = List<String>.from(json['recentlyPlayed'] ?? []);
    return profile;
  }
}

class RecommendationEngine {
  static final RecommendationEngine instance = RecommendationEngine._();
  RecommendationEngine._();

  UserTasteProfile tasteProfile = UserTasteProfile();
  List<SongInteraction> _interactionHistory = [];

  Future<void> init() async {
    await _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final profileJson = prefs.getString('taste_profile');
    if (profileJson != null) {
      try {
        tasteProfile = UserTasteProfile.fromJson(jsonDecode(profileJson));
      } catch (e) {
        tasteProfile = UserTasteProfile();
      }
    }

    final historyJson = prefs.getString('interaction_history');
    if (historyJson != null) {
      try {
        final list = jsonDecode(historyJson) as List;
        _interactionHistory = list.map((e) => SongInteraction.fromJson(e)).toList();
      } catch (e) {
        _interactionHistory = [];
      }
    }
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('taste_profile', jsonEncode(tasteProfile.toJson()));
    await prefs.setString('interaction_history', jsonEncode(_interactionHistory.map((e) => e.toJson()).toList()));
  }

  Future<void> updateTasteProfile({
    List<String>? languages,
    List<String>? artists,
  }) async {
    if (languages != null) {
      for (var lang in languages) {
        tasteProfile.languageScores[lang] = (tasteProfile.languageScores[lang] ?? 0) + 20;
      }
    }
    if (artists != null) {
      for (var artist in artists) {
        tasteProfile.artistScores[artist] = (tasteProfile.artistScores[artist] ?? 0) + 20;
      }
    }
    await _saveToStorage();
  }

  Future<void> recordInteraction(SongInteraction interaction) async {
    _interactionHistory.add(interaction);
    tasteProfile.updateFromInteraction(interaction);
    
    if (_interactionHistory.length > 500) {
      _interactionHistory = _interactionHistory.sublist(_interactionHistory.length - 500);
    }
    
    await _saveToStorage();
  }

  double calculateSongScore(Song song) {
    if (tasteProfile.isNotInterested(song.id) || tasteProfile.isDisliked(song.id)) {
      return -1000;
    }

    double score = 0;

    final artistScore = tasteProfile.artistScores[song.artist] ?? 0;
    score += artistScore * 2.0;

    final languageScore = tasteProfile.languageScores[song.language] ?? 0;
    score += languageScore * 1.5;

    if (tasteProfile.isLiked(song.id)) {
      score += 50;
    }

    final topArtists = tasteProfile.getTopArtists(3);
    if (topArtists.contains(song.artist)) {
      score += 30;
    }

    final topLanguages = tasteProfile.getTopLanguages(2);
    if (topLanguages.contains(song.language)) {
      score += 20;
    }

    final recentPlayed = tasteProfile.recentlyPlayed.take(10).toList();
    score += (10 - recentPlayed.indexOf(song.id)).clamp(0, 10).toDouble();

    score += (tasteProfile.totalInteractions.clamp(0, 100) / 10);

    return score;
  }

  List<Song> getRecommendedSongs(List<Song> songs, {int limit = 20}) {
    final scoredSongs = songs.map((song) => MapEntry(song, calculateSongScore(song))).toList();
    scoredSongs.sort((a, b) => b.value.compareTo(a.value));
    return scoredSongs.take(limit).map((e) => e.key).toList();
  }

  List<Song> getRecommendedForYou(List<Song> songs) {
    return getRecommendedSongs(songs, limit: 20);
  }

  List<Song> getSimilarToRecent(List<Song> songs) {
    if (tasteProfile.recentlyPlayed.isEmpty) return songs.take(10).toList();
    
    final recentArtists = <String>{};
    final recentLanguages = <String>{};
    
    for (var interaction in _interactionHistory.take(20)) {
      if (interaction.type == InteractionType.watch && interaction.watchPercentage > 0.5) {
        recentArtists.add(interaction.artist);
        recentLanguages.add(interaction.language);
      }
    }
    
    final similar = songs.where((song) {
      if (tasteProfile.isNotInterested(song.id)) return false;
      return recentArtists.contains(song.artist) || recentLanguages.contains(song.language);
    }).toList();
    
    similar.sort((a, b) => calculateSongScore(b).compareTo(calculateSongScore(a)));
    return similar.take(15).toList();
  }

  Future<void> clearHistory() async {
    _interactionHistory = [];
    tasteProfile = UserTasteProfile();
    await _saveToStorage();
  }
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
  late TabController _moodTabController;
  
  List<Song> _songs = [];
  List<Song> _searchResults = [];
  List<Song> _recommendedSongs = [];
  List<Song> _similarSongs = [];
  int _currentIndex = 0;
  bool _isPlaying = false;
  bool _isLoading = true;
  bool _isSearching = false;
  bool _isBuffering = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _showFullPlayer = false;
  String _currentLyrics = '';
  final ScrollController _lyricsScrollController = ScrollController();
  bool _isDesktop = false;
  bool _isLoadingMore = false;
  int _page = 1;
  RepeatMode _repeatMode = RepeatMode.all;
  String? _preferredSinger;
  List<String> _selectedSingers = [];
  List<String> _selectedLanguages = [];
  int _watchStartTime = 0;
  final Set<String> _likedSongs = {};
  final Set<String> _showOptionsForSong = {};

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
    _moodTabController = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDeviceType();
      _loadPreferences();
    });
    _loadSongs();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final singers = prefs.getStringList('singers') ?? [];
    final languages = prefs.getStringList('languages') ?? [];
    if (singers.isNotEmpty) {
      setState(() {
        _selectedSingers = singers;
        _preferredSinger = singers.first;
      });
    }
    setState(() => _selectedLanguages = languages);
    
    await RecommendationEngine.instance.init();
    setState(() {
      _likedSongs.addAll(RecommendationEngine.instance.tasteProfile.likedSongs);
    });
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
      final songs = await JioSaavnApi.getHome(singer: _preferredSinger);
      
      final recommended = RecommendationEngine.instance.getRecommendedSongs(songs);
      final similar = RecommendationEngine.instance.getSimilarToRecent(songs);
      
      setState(() {
        _songs = songs;
        _recommendedSongs = recommended;
        _similarSongs = similar.toList();
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
            _onSongComplete();
          }
        });
      }
    });
  }

  void _onSongComplete() {
    if (_currentIndex >= 0 && _currentIndex < _songs.length) {
      final song = _songs[_currentIndex];
      RecommendationEngine.instance.recordInteraction(SongInteraction(
        songId: song.id,
        artist: song.artist,
        language: song.language,
        type: InteractionType.watch,
        watchDuration: _duration.inSeconds,
        totalDuration: _duration.inSeconds,
        timestamp: DateTime.now(),
      ));
    }
    _playNext();
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
    
    if (_currentIndex >= 0 && _currentIndex < _songs.length && _position.inSeconds > 5) {
      final prevSong = _songs[_currentIndex];
      final watchDuration = _position.inSeconds;
      
      RecommendationEngine.instance.recordInteraction(SongInteraction(
        songId: prevSong.id,
        artist: prevSong.artist,
        language: prevSong.language,
        type: watchDuration < 30 ? InteractionType.skip : InteractionType.watch,
        watchDuration: watchDuration,
        totalDuration: _duration.inSeconds > 0 ? _duration.inSeconds : int.tryParse(prevSong.duration) ?? 0,
        timestamp: DateTime.now(),
      ));
    }
    
    setState(() {
      _currentIndex = index;
      _isBuffering = true;
      _duration = Duration.zero;
      _position = Duration.zero;
      _currentLyrics = '';
      _watchStartTime = DateTime.now().millisecondsSinceEpoch;
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

  Future<void> _downloadSong(Song song) async {
    if (song.audioUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No audio available for download')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opening ${song.title} for download...')),
    );

    final downloadUrl = JioSaavnApi.getProxyUrl(song.audioUrl);
    final uri = Uri.parse(downloadUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link')),
        );
      }
    }
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
      final scored = RecommendationEngine.instance.getRecommendedSongs(results, limit: results.length);
      setState(() => _searchResults = scored);
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
      case 'Happy':
        songs = await JioSaavnApi.search('tamil happy songs');
        break;
      case 'Sad':
        songs = await JioSaavnApi.search('tamil sad songs');
        break;
      case 'Trending':
        songs = await JioSaavnApi.search('tamil trending songs 2024');
        break;
      case 'Party':
        songs = await JioSaavnApi.search('tamil party songs');
        break;
      case 'For You':
      default:
        songs = await JioSaavnApi.getHome(singer: _preferredSinger);
    }
    
    setState(() {
      _songs = songs.isNotEmpty ? songs : _songs;
      _isLoading = false;
    });
  }

  Future<void> _toggleLike(Song song) async {
    final isLiked = _likedSongs.contains(song.id);
    
    if (isLiked) {
      _likedSongs.remove(song.id);
    } else {
      _likedSongs.add(song.id);
    }
    
    setState(() {});
    
    await RecommendationEngine.instance.recordInteraction(SongInteraction(
      songId: song.id,
      artist: song.artist,
      language: song.language,
      type: isLiked ? InteractionType.skip : InteractionType.like,
      watchDuration: 0,
      totalDuration: 0,
      timestamp: DateTime.now(),
    ));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLiked ? 'Removed from likes' : 'Added to likes'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  Future<void> _markNotInterested(Song song) async {
    await RecommendationEngine.instance.recordInteraction(SongInteraction(
      songId: song.id,
      artist: song.artist,
      language: song.language,
      type: InteractionType.notInterested,
      watchDuration: 0,
      totalDuration: 0,
      timestamp: DateTime.now(),
    ));
    
    setState(() {
      _songs.removeWhere((s) => s.id == song.id);
      _showOptionsForSong.remove(song.id);
    });
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Won\'t show this song again'),
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioPlayer.dispose();
    _searchController.dispose();
    _focusNode.dispose();
    _tabController.dispose();
    _moodTabController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  String _currentCategory = 'For You';

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
          _buildMobileHeader(),
          _buildSearchBar(),
          _buildPlaylistTabs(),
          Expanded(child: _buildSongList()),
          if (_songs.isNotEmpty) _buildMiniPlayer(),
        ],
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.music_note, color: background, size: 24),
          ),
          const SizedBox(width: 12),
          const Text(
            'Sri Keyan',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
          const Spacer(),
          if (RecommendationEngine.instance.tasteProfile.totalInteractions > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.auto_awesome, color: accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'AI Powered',
                    style: const TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: const TextStyle(color: textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search songs, artists...',
          hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
          prefixIcon: const Icon(Icons.search, color: textSecondary, size: 22),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: textSecondary, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }

  Widget _buildPlaylistTabs() {
    final playlists = [
      {'name': 'For You', 'icon': Icons.favorite},
      {'name': 'Happy', 'icon': Icons.sentiment_satisfied},
      {'name': 'Sad', 'icon': Icons.sentiment_dissatisfied},
      {'name': 'Trending', 'icon': Icons.trending_up},
      {'name': 'Party', 'icon': Icons.celebration},
    ];
    
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: playlists.length,
        itemBuilder: (context, index) {
          final playlist = playlists[index];
          final isSelected = _currentCategory == playlist['name'];
          return GestureDetector(
            onTap: () {
              _moodTabController.animateTo(index);
              _changePlaylist(playlist['name'] as String);
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? accent : surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: isSelected ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playlist['icon'] as IconData,
                    size: 16,
                    color: isSelected ? background : textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    playlist['name'] as String,
                    style: TextStyle(
                      color: isSelected ? background : textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
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

    if (_currentCategory == 'For You' && !_isSearching && _recommendedSongs.isNotEmpty) {
      return _buildForYouContent(displaySongs);
    }

    return _buildSongListView(displaySongs);
  }

  Widget _buildForYouContent(List<Song> allSongs) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (RecommendationEngine.instance.tasteProfile.totalInteractions > 5) ...[
            _buildSectionHeader('Recommended for You', Icons.auto_awesome),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_recommendedSongs.take(10).toList()),
            const SizedBox(height: 24),
            _buildSectionHeader('Because You Like ${RecommendationEngine.instance.tasteProfile.topArtist}', Icons.thumb_up),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_similarSongs.take(10).toList()),
            const SizedBox(height: 24),
          ],
          _buildSectionHeader('Your Taste Profile', Icons.person),
          const SizedBox(height: 8),
          _buildTasteProfileCard(),
          const SizedBox(height: 24),
          _buildSectionHeader('All Songs', Icons.library_music),
          const SizedBox(height: 8),
          ...allSongs.asMap().entries.map((entry) {
            final song = entry.value;
            final isSelected = entry.key == _currentIndex;
            return _buildSongCard(song, isSelected, entry.key);
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Icon(icon, color: accent, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHorizontalSongList(List<Song> songs) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: songs.length,
        itemBuilder: (context, index) {
          final song = songs[index];
          return _buildHorizontalSongCard(song, index);
        },
      ),
    );
  }

  Widget _buildHorizontalSongCard(Song song, int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _songs = List.from(_recommendedSongs);
          _currentIndex = index;
        });
        _playSong(index);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 140,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: surface,
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, width: 140, height: 140, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: accent, size: 40)))
                        : Center(child: Icon(Icons.music_note, color: accent, size: 40)),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.5),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.play_arrow, color: background, size: 16),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              style: const TextStyle(fontSize: 11, color: textSecondary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTasteProfileCard() {
    final profile = RecommendationEngine.instance.tasteProfile;
    final topArtists = profile.getTopArtists(5);
    final topLanguages = profile.getTopLanguages(5);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Songs Played', '${profile.totalInteractions}'),
              _buildStatItem('Watch Time', '${(profile.totalWatchTime / 60).round()} min'),
              _buildStatItem('Liked', '${profile.likedSongs.length}'),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Top Artists', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topArtists.map((artist) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(artist, style: const TextStyle(color: accent, fontSize: 12)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Languages', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: topLanguages.map((lang) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(lang, style: const TextStyle(color: Colors.blue, fontSize: 12)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: textSecondary),
        ),
      ],
    );
  }

  Widget _buildSongListView(List<Song> displaySongs) {
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
    final isLiked = _likedSongs.contains(song.id);
    final showOptions = _showOptionsForSong.contains(song.id);
    
    return GestureDetector(
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
      onLongPress: () {
        setState(() {
          if (showOptions) {
            _showOptionsForSong.remove(song.id);
          } else {
            _showOptionsForSong.add(song.id);
          }
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.08) : background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : Colors.transparent,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: surface,
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: song.imageUrl.isNotEmpty
                            ? Image.network(song.imageUrl, fit: BoxFit.cover, width: 56, height: 56, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: accent))
                            : const Icon(Icons.music_note, color: accent),
                      ),
                      if (isSelected)
                        Container(
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: Icon(Icons.equalizer, color: background, size: 24),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: TextStyle(
                          color: textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.artist,
                              style: const TextStyle(color: textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              song.language,
                              style: const TextStyle(color: Colors.blue, fontSize: 9, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
                      style: const TextStyle(color: textSecondary, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleLike(song),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isLiked ? Colors.red.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              isLiked ? Icons.favorite : Icons.favorite_border,
                              color: isLiked ? Colors.red : accent,
                              size: 18,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        GestureDetector(
                          onTap: () => _downloadSong(song),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.download, color: accent, size: 18),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            if (showOptions) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: surface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildOptionButton(Icons.playlist_add, 'Add to Playlist', () {}),
                    _buildOptionButton(Icons.shuffle, 'Shuffle Play', () {}),
                    _buildOptionButton(Icons.share, 'Share', () {}),
                    _buildOptionButton(Icons.not_interested, 'Not Interested', () => _markNotInterested(song)),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: textSecondary, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: textSecondary, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildMiniPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    final isLiked = _likedSongs.contains(song.id);
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
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
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: song.imageUrl.isNotEmpty
                        ? Image.network(song.imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.music_note, color: background, size: 28))
                        : const Icon(Icons.music_note, color: background, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: background,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 24),
                  color: isLiked ? Colors.red : background,
                  onPressed: () => _toggleLike(song),
                ),
                _buildMiniPlayerControls(),
              ],
            ),
            const SizedBox(height: 10),
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniPlayerControls() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 36),
          color: background,
          onPressed: _togglePlayPause,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded, size: 30),
          color: background,
          onPressed: _playNext,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inSeconds > 0 
        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    
    return Column(
      children: [
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_position),
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
            ),
            Text(
              _formatDuration(_duration),
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.8)),
            ),
          ],
        ),
      ],
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
              boxShadow: [
                BoxShadow(
                  color: accent.withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
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
    final isLiked = _likedSongs.contains(song.id);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Stack(
            children: [
              _buildDesktopAlbumArt(song),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 32),
                  color: isLiked ? Colors.red : background,
                  onPressed: () => _toggleLike(song),
                ),
              ),
            ],
          ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
          decoration: BoxDecoration(
            color: accent,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
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
          _buildDetailRow('Language', song.language),
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
    final isLiked = _likedSongs.contains(song.id);
    
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
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 28),
                    color: textPrimary,
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
                    Stack(
                      children: [
                        _buildFullPlayerAlbumArt(song),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: IconButton(
                            icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 32),
                            color: isLiked ? Colors.red : textSecondary,
                            onPressed: () => _toggleLike(song),
                          ),
                        ),
                      ],
                    ),
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
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.3),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
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
    return '$_proxyUrl/proxy?url=${Uri.encodeComponent(audioUrl)}';
  }

  static Future<List<Song>> getHome({String? singer}) async {
    try {
      final query = singer ?? 'tamil songs';
      final response = await http.get(Uri.parse('$_apiUrl/result/?query=$query'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final songsJson = data['results'] as List? ?? [];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('API Error: $e');
    }
    return [];
  }

  static Future<List<Song>> search(String query) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/result/?query=${Uri.encodeComponent(query)}'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final songsJson = data['results'] as List? ?? [];
        return songsJson.map((json) => Song.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('Search Error: $e');
    }
    return [];
  }

  static Future<String> getLyrics(String songId) async {
    try {
      final response = await http.get(
        Uri.parse('$_apiUrl/lyrics/?id=$songId'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['lyrics'] ?? '';
      }
    } catch (e) {
      debugPrint('Lyrics Error: $e');
    }
    return '';
  }
}
