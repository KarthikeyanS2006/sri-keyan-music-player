import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseManager.instance.init();
  runApp(const MusicApp());
}

class SupabaseManager {
  static final SupabaseManager instance = SupabaseManager._();
  SupabaseManager._();

  late SupabaseClient client;
  String? _userId;

  static const String _supabaseUrl = 'https://ncghdfjeymfwqjduvrmq.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jZ2hkZmpleW1md3FqZHV2cm1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NTI4MzQsImV4cCI6MjA5MDMyODgzNH0.qcj9CBI9QoNgilLEFnTT_7ciWHVc5fmFLG_54jOXi4U';

  Future<void> init() async {
    client = SupabaseClient(_supabaseUrl, _supabaseKey);
    await _ensureTablesExist();
    await _ensureUserId();
  }

  Future<void> _ensureTablesExist() async {
    try {
      await client.from('user_profiles').select('id').limit(1).maybeSingle();
    } catch (e) {
      debugPrint('Tables check error: $e');
    }
  }

  Future<void> _ensureUserId() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('user_id');
    
    if (_userId == null) {
      _userId = const Uuid().v4();
      await prefs.setString('user_id', _userId!);
      
      try {
        await client.from('user_profiles').insert({
          'id': _userId,
          'created_at': DateTime.now().toIso8601String(),
          'artist_scores': {},
          'language_scores': {},
          'liked_songs': [],
          'recently_played': [],
          'total_interactions': 0,
          'total_watch_time': 0,
        });
      } catch (e) {
        debugPrint('Error creating user profile: $e');
      }
    }
  }

  String get userId => _userId ?? '';

  Future<void> updateTasteProfile(Map<String, dynamic> profile) async {
    if (_userId == null) return;
    try {
      await client.from('user_profiles').update(profile).eq('id', _userId!).select();
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getTasteProfile() async {
    if (_userId == null) return null;
    try {
      final response = await client.from('user_profiles').select().eq('id', _userId!).maybeSingle();
      if (response != null) {
        return Map<String, dynamic>.from(response as Map);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> recordInteraction(Map<String, dynamic> interaction) async {
    if (_userId == null) return;
    try {
      await client.from('song_interactions').insert({
        'user_id': _userId!,
        ...interaction,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error recording interaction: $e');
    }
  }

  Future<void> savePlaylist(Map<String, dynamic> playlist) async {
    if (_userId == null) return;
    try {
      await client.from('playlists').upsert({
        'user_id': _userId!,
        'playlist_data': playlist,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error saving playlist: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPlaylists() async {
    if (_userId == null) return [];
    try {
      final response = await client.from('playlists').select().eq('user_id', _userId!);
      return List<Map<String, dynamic>>.from(response.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [];
    }
  }
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
            const SizedBox(height: 8),
            const Text(
              'Your AI-Powered Music Player',
              style: TextStyle(fontSize: 14, color: textSecondary),
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
                  onPressed: _savePreferences,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: background,
                    disabledBackgroundColor: surface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                    elevation: 8,
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

enum SongMood { highEnergy, chill, emotional, party, romantic }

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
  final SongMood mood;

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
    this.mood = SongMood.chill,
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
    String title = json['song'] ?? json['title'] ?? '';
    String album = json['album'] ?? '';
    String combined = '$title $album'.toLowerCase();
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

    SongMood mood = SongMood.chill;
    if (combined.contains('kuthu') || combined.contains('party') || combined.contains('dance')) {
      mood = SongMood.party;
    } else if (combined.contains('love') || combined.contains('romantic') || combined.contains('pudhu')) {
      mood = SongMood.romantic;
    } else if (combined.contains('sad') || combined.contains('melancholy')) {
      mood = SongMood.emotional;
    } else if (combined.contains('bgm') || combined.contains('theme')) {
      mood = SongMood.highEnergy;
    }
    
    return Song(
      id: songId.toString(),
      title: title,
      artist: json['primary_artists'] ?? json['singers'] ?? json['artist'] ?? 'Unknown Artist',
      album: album.isNotEmpty ? album : 'Unknown Album',
      imageUrl: imageUrl,
      audioUrl: mediaUrl,
      duration: json['duration'] ?? '0',
      url: json['perma_url'] ?? json['url'] ?? '',
      year: json['year'] ?? '',
      language: language,
      mood: mood,
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

  String get moodEmoji {
    switch (mood) {
      case SongMood.highEnergy:
        return '🔥';
      case SongMood.chill:
        return '☕';
      case SongMood.emotional:
        return '😢';
      case SongMood.party:
        return '🎉';
      case SongMood.romantic:
        return '💕';
    }
  }
}

enum InteractionType { watch, like, skip, addToPlaylist, notInterested, share, rewatch, playlistPlay }

class SongInteraction {
  final String songId;
  final String artist;
  final String language;
  final InteractionType type;
  final int watchDuration;
  final int totalDuration;
  final DateTime timestamp;
  final bool isSession;

  SongInteraction({
    required this.songId,
    required this.artist,
    required this.language,
    required this.type,
    required this.watchDuration,
    required this.totalDuration,
    required this.timestamp,
    this.isSession = false,
  });

  double get watchPercentage => totalDuration > 0 ? watchDuration / totalDuration : 0;
  double get satisfactionScore {
    double base = watchPercentage;
    switch (type) {
      case InteractionType.like:
        base += 0.3;
        break;
      case InteractionType.rewatch:
        base += 0.4;
        break;
      case InteractionType.playlistPlay:
        base += 0.2;
        break;
      case InteractionType.share:
        base += 0.5;
        break;
      case InteractionType.skip:
        base -= 0.3;
        break;
      case InteractionType.notInterested:
        base -= 0.5;
        break;
      default:
        break;
    }
    return base.clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
    'songId': songId,
    'artist': artist,
    'language': language,
    'type': type.name,
    'watchDuration': watchDuration,
    'totalDuration': totalDuration,
    'timestamp': timestamp.toIso8601String(),
    'isSession': isSession,
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
    isSession: json['isSession'] ?? false,
  );
}

class UserTasteProfile {
  Map<String, int> artistScores = {};
  Map<String, int> languageScores = {};
  Map<String, int> moodScores = {};
  Map<String, int> searchHistory = {};
  int totalInteractions = 0;
  int totalWatchTime = 0;
  int satisfactionScore = 0;
  int sessionInteractions = 0;
  List<String> likedSongs = [];
  List<String> dislikedSongs = [];
  List<String> notInterestedSongs = [];
  List<String> recentlyPlayed = [];
  List<String> rewatchedSongs = [];
  List<String> sharedSongs = [];

  UserTasteProfile();

  void updateFromInteraction(SongInteraction interaction) {
    totalInteractions++;
    if (interaction.isSession) sessionInteractions++;
    totalWatchTime += interaction.watchDuration;
    satisfactionScore += (interaction.satisfactionScore * 100).round();

    switch (interaction.type) {
      case InteractionType.watch:
        int watchScore = (interaction.watchPercentage * 10).round();
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + watchScore;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + watchScore;
        if (!recentlyPlayed.contains(interaction.songId)) {
          recentlyPlayed.insert(0, interaction.songId);
          if (recentlyPlayed.length > 50) recentlyPlayed.removeLast();
        }
        break;
      case InteractionType.like:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 15;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + 15;
        if (!likedSongs.contains(interaction.songId)) likedSongs.add(interaction.songId);
        dislikedSongs.remove(interaction.songId);
        if (!recentlyPlayed.contains(interaction.songId)) {
          recentlyPlayed.insert(0, interaction.songId);
        }
        break;
      case InteractionType.rewatch:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 20;
        if (!rewatchedSongs.contains(interaction.songId)) rewatchedSongs.add(interaction.songId);
        if (!likedSongs.contains(interaction.songId)) likedSongs.add(interaction.songId);
        break;
      case InteractionType.share:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 25;
        if (!sharedSongs.contains(interaction.songId)) sharedSongs.add(interaction.songId);
        break;
      case InteractionType.skip:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) - 5;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) - 5;
        break;
      case InteractionType.notInterested:
        if (!notInterestedSongs.contains(interaction.songId)) notInterestedSongs.add(interaction.songId);
        dislikedSongs.add(interaction.songId);
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) - 10;
        break;
      case InteractionType.addToPlaylist:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 10;
        languageScores[interaction.language] = (languageScores[interaction.language] ?? 0) + 10;
        break;
      case InteractionType.playlistPlay:
        artistScores[interaction.artist] = (artistScores[interaction.artist] ?? 0) + 8;
        break;
    }

    artistScores.removeWhere((key, value) => value <= 0);
    languageScores.removeWhere((key, value) => value <= 0);
  }

  void addSearchQuery(String query) {
    searchHistory[query] = (searchHistory[query] ?? 0) + 1;
    if (searchHistory.length > 100) {
      searchHistory.remove(searchHistory.keys.first);
    }
  }

  List<String> getTopSearches(int count) {
    final sorted = searchHistory.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(count).map((e) => e.key).toList();
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
  bool isRewatched(String songId) => rewatchedSongs.contains(songId);
  bool isShared(String songId) => sharedSongs.contains(songId);

  double get averageSatisfaction => totalInteractions > 0 ? satisfactionScore / totalInteractions : 0;
  double get sessionVsTotalRatio => totalInteractions > 0 ? sessionInteractions / totalInteractions : 0;

  Map<String, dynamic> toJson() => {
    'artistScores': artistScores,
    'languageScores': languageScores,
    'moodScores': moodScores,
    'searchHistory': searchHistory,
    'totalInteractions': totalInteractions,
    'totalWatchTime': totalWatchTime,
    'satisfactionScore': satisfactionScore,
    'sessionInteractions': sessionInteractions,
    'likedSongs': likedSongs,
    'dislikedSongs': dislikedSongs,
    'notInterestedSongs': notInterestedSongs,
    'recentlyPlayed': recentlyPlayed,
    'rewatchedSongs': rewatchedSongs,
    'sharedSongs': sharedSongs,
  };

  factory UserTasteProfile.fromJson(Map<String, dynamic> json) {
    final profile = UserTasteProfile();
    profile.artistScores = Map<String, int>.from(json['artistScores'] ?? {});
    profile.languageScores = Map<String, int>.from(json['languageScores'] ?? {});
    profile.moodScores = Map<String, int>.from(json['moodScores'] ?? {});
    profile.searchHistory = Map<String, int>.from(json['searchHistory'] ?? {});
    profile.totalInteractions = json['totalInteractions'] ?? 0;
    profile.totalWatchTime = json['totalWatchTime'] ?? 0;
    profile.satisfactionScore = json['satisfactionScore'] ?? 0;
    profile.sessionInteractions = json['sessionInteractions'] ?? 0;
    profile.likedSongs = List<String>.from(json['likedSongs'] ?? []);
    profile.dislikedSongs = List<String>.from(json['dislikedSongs'] ?? []);
    profile.notInterestedSongs = List<String>.from(json['notInterestedSongs'] ?? []);
    profile.recentlyPlayed = List<String>.from(json['recentlyPlayed'] ?? []);
    profile.rewatchedSongs = List<String>.from(json['rewatchedSongs'] ?? []);
    profile.sharedSongs = List<String>.from(json['sharedSongs'] ?? []);
    return profile;
  }
}

class MusicPlaylist {
  final String id;
  String name;
  String description;
  final DateTime createdAt;
  List<String> songIds;
  bool isAutoGenerated;
  final String? basedOnArtist;
  final String? basedOnMood;

  MusicPlaylist({
    required this.id,
    required this.name,
    this.description = '',
    required this.createdAt,
    List<String>? songIds,
    this.isAutoGenerated = false,
    this.basedOnArtist,
    this.basedOnMood,
  }) : songIds = songIds ?? [];

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    'createdAt': createdAt.toIso8601String(),
    'songIds': songIds,
    'isAutoGenerated': isAutoGenerated,
    'basedOnArtist': basedOnArtist,
    'basedOnMood': basedOnMood,
  };

  factory MusicPlaylist.fromJson(Map<String, dynamic> json) => MusicPlaylist(
    id: json['id'],
    name: json['name'],
    description: json['description'] ?? '',
    createdAt: DateTime.parse(json['createdAt']),
    songIds: List<String>.from(json['songIds'] ?? []),
    isAutoGenerated: json['isAutoGenerated'] ?? false,
    basedOnArtist: json['basedOnArtist'],
    basedOnMood: json['basedOnMood'],
  );
}

class RecommendationEngine {
  static final RecommendationEngine instance = RecommendationEngine._();
  RecommendationEngine._();

  UserTasteProfile tasteProfile = UserTasteProfile();
  List<SongInteraction> _interactionHistory = [];
  List<MusicPlaylist> _playlists = [];

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

    final playlistsJson = prefs.getString('playlists');
    if (playlistsJson != null) {
      try {
        final list = jsonDecode(playlistsJson) as List;
        _playlists = list.map((e) => MusicPlaylist.fromJson(e)).toList();
      } catch (e) {
        _playlists = [];
      }
    }

    if (_playlists.isEmpty) {
      await _createDefaultPlaylists();
    }
  }

  Future<void> _createDefaultPlaylists() async {
    _playlists = [
      MusicPlaylist(
        id: 'favorites',
        name: 'Favorites',
        description: 'Your liked songs',
        createdAt: DateTime.now(),
      ),
      MusicPlaylist(
        id: 'discover_mix',
        name: 'Discover Mix',
        description: 'AI-generated mix based on your taste',
        createdAt: DateTime.now(),
        isAutoGenerated: true,
      ),
      MusicPlaylist(
        id: 'recently_played',
        name: 'Recently Played',
        description: 'Songs you\'ve been listening to',
        createdAt: DateTime.now(),
        isAutoGenerated: true,
      ),
    ];
    await _savePlaylists();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('taste_profile', jsonEncode(tasteProfile.toJson()));
    await prefs.setString('interaction_history', jsonEncode(_interactionHistory.map((e) => e.toJson()).toList()));
  }

  Future<void> _savePlaylists() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('playlists', jsonEncode(_playlists.map((e) => e.toJson()).toList()));
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
    
    if (_interactionHistory.length > 1000) {
      _interactionHistory = _interactionHistory.sublist(_interactionHistory.length - 1000);
    }
    
    await _saveToStorage();
  }

  void addSearchQuery(String query) {
    tasteProfile.addSearchQuery(query);
    _saveToStorage();
  }

  double calculateSongScore(Song song, {bool useSessionWeight = false}) {
    if (tasteProfile.isNotInterested(song.id) || tasteProfile.isDisliked(song.id)) {
      return -1000;
    }

    double score = 0;
    final sessionWeight = useSessionWeight ? 2.0 : 1.0;

    final artistScore = tasteProfile.artistScores[song.artist] ?? 0;
    score += artistScore * 2.0 * sessionWeight;

    final languageScore = tasteProfile.languageScores[song.language] ?? 0;
    score += languageScore * 1.5 * sessionWeight;

    if (tasteProfile.isLiked(song.id)) {
      score += 50;
    }

    if (tasteProfile.isRewatched(song.id)) {
      score += 40;
    }

    if (tasteProfile.isShared(song.id)) {
      score += 30;
    }

    final topArtists = tasteProfile.getTopArtists(5);
    if (topArtists.contains(song.artist)) {
      score += 30;
    }

    final topLanguages = tasteProfile.getTopLanguages(2);
    if (topLanguages.contains(song.language)) {
      score += 20;
    }

    final recentPlayed = tasteProfile.recentlyPlayed.take(20).toList();
    int recencyBonus = 0;
    for (int i = 0; i < recentPlayed.length; i++) {
      if (recentPlayed[i] == song.id) {
        recencyBonus = (10 - i).clamp(0, 10);
        break;
      }
    }
    score += recencyBonus.toDouble();

    score += (tasteProfile.totalInteractions.clamp(0, 200) / 10);

    score += tasteProfile.averageSatisfaction * 10;

    final topSearches = tasteProfile.getTopSearches(5);
    final titleLower = song.title.toLowerCase();
    for (var search in topSearches) {
      if (titleLower.contains(search.toLowerCase())) {
        score += 15;
      }
    }

    return score;
  }

  List<Song> getRecommendedSongs(List<Song> songs, {int limit = 20, bool useSessionWeight = false}) {
    final scoredSongs = songs.map((song) => MapEntry(song, calculateSongScore(song, useSessionWeight: useSessionWeight))).toList();
    scoredSongs.sort((a, b) => b.value.compareTo(a.value));
    return scoredSongs.take(limit).map((e) => e.key).toList();
  }

  List<Song> getRecommendedForYou(List<Song> songs) {
    return getRecommendedSongs(songs, limit: 25);
  }

  List<Song> getSimilarToRecent(List<Song> songs) {
    if (tasteProfile.recentlyPlayed.isEmpty) return songs.take(15).toList();
    
    final recentArtists = <String>{};
    final recentLanguages = <String>{};
    
    for (var interaction in _interactionHistory.take(30)) {
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

  List<Song> getFansAlsoLiked(List<Song> songs) {
    final topArtists = tasteProfile.getTopArtists(3);
    final topLikedSongs = tasteProfile.likedSongs.take(10).toList();
    
    final fansAlsoLike = songs.where((song) {
      if (tasteProfile.isNotInterested(song.id)) return false;
      if (topLikedSongs.contains(song.id)) return false;
      return topArtists.contains(song.artist);
    }).toList();
    
    fansAlsoLike.sort((a, b) => calculateSongScore(b).compareTo(calculateSongScore(a)));
    return fansAlsoLike.take(15).toList();
  }

  List<Song> getDiscoverMix(List<Song> songs) {
    final mix = <Song>[];
    final topArtists = tasteProfile.getTopArtists(3);
    final topLanguages = tasteProfile.getTopLanguages(2);
    
    final scored = songs.where((s) => !tasteProfile.isNotInterested(s.id)).toList();
    scored.sort((a, b) => calculateSongScore(b).compareTo(calculateSongScore(a)));
    
    int added = 0;
    for (var song in scored) {
      if (added >= 20) break;
      if (topArtists.contains(song.artist) || topLanguages.contains(song.language)) {
        mix.add(song);
        added++;
      }
    }
    
    if (mix.length < 20) {
      for (var song in scored) {
        if (added >= 20) break;
        if (!mix.contains(song)) {
          mix.add(song);
          added++;
        }
      }
    }
    
    return mix;
  }

  List<MusicPlaylist> getPlaylists() => _playlists;

  Future<void> createPlaylist(String name, {String description = ''}) async {
    final playlist = MusicPlaylist(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      description: description,
      createdAt: DateTime.now(),
    );
    _playlists.add(playlist);
    await _savePlaylists();
  }

  Future<void> deletePlaylist(String id) async {
    _playlists.removeWhere((p) => p.id == id);
    await _savePlaylists();
  }

  Future<void> addSongToPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1 && !_playlists[index].songIds.contains(songId)) {
      _playlists[index].songIds.add(songId);
      _playlists[index].songIds.insert(0, _playlists[index].songIds.removeLast());
      await _savePlaylists();
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String songId) async {
    final index = _playlists.indexWhere((p) => p.id == playlistId);
    if (index != -1) {
      _playlists[index].songIds.remove(songId);
      await _savePlaylists();
    }
  }

  List<Song> getSongsFromPlaylist(MusicPlaylist playlist, List<Song> allSongs) {
    return playlist.songIds
        .map((id) => allSongs.firstWhere((s) => s.id == id, orElse: () => allSongs.first))
        .where((s) => s.id != allSongs.first.id)
        .toList();
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
  
  List<Song> _songs = [];
  List<Song> _searchResults = [];
  List<Song> _recommendedSongs = [];
  List<Song> _similarSongs = [];
  List<Song> _fansAlsoLiked = [];
  List<Song> _discoverMix = [];
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
  List<MusicPlaylist> _playlists = [];
  String? _currentPlaylistFilter;

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
      _playlists = RecommendationEngine.instance.getPlaylists();
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
      
      final recommended = RecommendationEngine.instance.getRecommendedForYou(songs);
      final similar = RecommendationEngine.instance.getSimilarToRecent(songs);
      final fansAlso = RecommendationEngine.instance.getFansAlsoLiked(songs);
      final discoverMix = RecommendationEngine.instance.getDiscoverMix(songs);
      
      setState(() {
        _songs = songs;
        _recommendedSongs = recommended;
        _similarSongs = similar;
        _fansAlsoLiked = fansAlso;
        _discoverMix = discoverMix;
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
        if (position.inSeconds == _duration.inSeconds && _duration.inSeconds > 0) {
          _onSongComplete();
        }
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
      final wasRewatched = RecommendationEngine.instance.tasteProfile.isRewatched(song.id);
      
      RecommendationEngine.instance.recordInteraction(SongInteraction(
        songId: song.id,
        artist: song.artist,
        language: song.language,
        type: wasRewatched ? InteractionType.rewatch : InteractionType.watch,
        watchDuration: _duration.inSeconds,
        totalDuration: _duration.inSeconds,
        timestamp: DateTime.now(),
        isSession: true,
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
        isSession: true,
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
    }
  }

  Future<void> _shareSong(Song song) async {
    final shareText = '🎵 Listen to "${song.title}" by ${song.artist} on Sri Keyan Music!\n\n${song.url}';
    await Share.share(shareText, subject: song.title);
    
    RecommendationEngine.instance.recordInteraction(SongInteraction(
      songId: song.id,
      artist: song.artist,
      language: song.language,
      type: InteractionType.share,
      watchDuration: _position.inSeconds,
      totalDuration: _duration.inSeconds,
      timestamp: DateTime.now(),
      isSession: true,
    ));
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
    if (query.isNotEmpty) {
      RecommendationEngine.instance.addSearchQuery(query);
    }
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
      isSession: true,
    ));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isLiked ? 'Removed from likes' : 'Added to favorites'),
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
      isSession: true,
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

  void _showAddToPlaylistDialog(Song song) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add to Playlist', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ..._playlists.map((playlist) => ListTile(
              leading: Icon(playlist.isAutoGenerated ? Icons.auto_awesome : Icons.playlist_play),
              title: Text(playlist.name),
              subtitle: Text('${playlist.songIds.length} songs'),
              onTap: () {
                RecommendationEngine.instance.addSongToPlaylist(playlist.id, song.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added to ${playlist.name}')),
                );
              },
            )),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Create New Playlist'),
              onTap: () {
                Navigator.pop(context);
                _showCreatePlaylistDialog(song);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showCreatePlaylistDialog(Song? song) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Playlist'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Playlist Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await RecommendationEngine.instance.createPlaylist(nameController.text);
                if (song != null && _playlists.isNotEmpty) {
                  await RecommendationEngine.instance.addSongToPlaylist(
                    RecommendationEngine.instance.getPlaylists().last.id,
                    song.id,
                  );
                }
                setState(() {
                  _playlists = RecommendationEngine.instance.getPlaylists();
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showArtistPage(String artist) async {
    setState(() => _isLoading = true);
    try {
      final artistSongs = await JioSaavnApi.search('$artist tamil songs');
      setState(() {
        _songs = artistSongs;
        _currentCategory = artist;
        _isLoading = false;
        _isSearching = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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
          IconButton(
            icon: const Icon(Icons.library_music),
            color: accent,
            onPressed: () => _showPlaylistsSheet(),
          ),
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
                    'AI',
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

  void _showPlaylistsSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Your Playlists', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () {
                    Navigator.pop(context);
                    _showCreatePlaylistDialog(null);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _playlists.length,
                itemBuilder: (context, index) {
                  final playlist = _playlists[index];
                  return ListTile(
                    leading: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: playlist.isAutoGenerated ? Colors.purple.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        playlist.isAutoGenerated ? Icons.auto_awesome : Icons.playlist_play,
                        color: playlist.isAutoGenerated ? Colors.purple : accent,
                      ),
                    ),
                    title: Text(playlist.name),
                    subtitle: Text(playlist.description.isNotEmpty ? playlist.description : '${playlist.songIds.length} songs'),
                    trailing: playlist.isAutoGenerated 
                        ? IconButton(
                            icon: const Icon(Icons.refresh),
                            onPressed: () async {
                              if (playlist.id == 'discover_mix') {
                                final mix = RecommendationEngine.instance.getDiscoverMix(_songs);
                                setState(() {
                                  _discoverMix = mix;
                                  _songs = mix;
                                  _currentCategory = 'Discover Mix';
                                });
                              }
                            },
                          )
                        : IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await RecommendationEngine.instance.deletePlaylist(playlist.id);
                              setState(() {
                                _playlists = RecommendationEngine.instance.getPlaylists();
                              });
                            },
                          ),
                    onTap: () {
                      if (playlist.id == 'discover_mix') {
                        setState(() {
                          _songs = _discoverMix;
                          _currentCategory = 'Discover Mix';
                        });
                      }
                      Navigator.pop(context);
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
            onTap: () => _changePlaylist(playlist['name'] as String),
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
    final profile = RecommendationEngine.instance.tasteProfile;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (profile.totalInteractions > 3) ...[
            _buildSectionHeader('Discover Mix', Icons.auto_awesome, trailing: 'Updated Daily'),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_discoverMix.take(10).toList()),
            const SizedBox(height: 24),
            
            _buildSectionHeader('Because You Like ${profile.topArtist}', Icons.thumb_up),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_similarSongs.take(10).toList()),
            const SizedBox(height: 24),

            if (_fansAlsoLiked.isNotEmpty) ...[
              _buildSectionHeader('Fans Also Like', Icons.people),
              const SizedBox(height: 8),
              _buildHorizontalSongList(_fansAlsoLiked.take(10).toList()),
              const SizedBox(height: 24),
            ],

            _buildSectionHeader('Recommended for You', Icons.recommend),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_recommendedSongs.take(10).toList()),
            const SizedBox(height: 24),
          ],
          
          _buildSectionHeader('Your Taste Profile', Icons.insights),
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

  Widget _buildSectionHeader(String title, IconData icon, {String? trailing}) {
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
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trailing,
                style: const TextStyle(fontSize: 10, color: Colors.purple, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHorizontalSongList(List<Song> songs) {
    if (songs.isEmpty) return const SizedBox.shrink();
    
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
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(song.moodEmoji, style: const TextStyle(fontSize: 12)),
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
    final topSearches = profile.getTopSearches(3);
    
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
              _buildStatItem('Songs', '${profile.totalInteractions}', Icons.play_circle),
              _buildStatItem('Watch Time', '${(profile.totalWatchTime / 60).round()}m', Icons.timer),
              _buildStatItem('Liked', '${profile.likedSongs.length}', Icons.favorite),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top Artists', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: topArtists.take(3).map((artist) {
                        return GestureDetector(
                          onTap: () => _showArtistPage(artist),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(artist, style: const TextStyle(color: accent, fontSize: 11)),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward, color: accent, size: 10),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Languages', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: topLanguages.map((lang) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(lang, style: const TextStyle(color: Colors.blue, fontSize: 11)),
              );
            }).toList(),
          ),
          if (topSearches.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: topSearches.map((search) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(search, style: const TextStyle(color: textSecondary, fontSize: 11)),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: accent, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: textSecondary),
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
                      Positioned(
                        top: 4,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(song.moodEmoji, style: const TextStyle(fontSize: 10)),
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
                            child: GestureDetector(
                              onTap: () => _showArtistPage(song.artist),
                              child: Text(
                                song.artist,
                                style: const TextStyle(color: accent, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                          onTap: () => _shareSong(song),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.share, color: Colors.green, size: 18),
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
                    _buildOptionButton(Icons.playlist_add, 'Playlist', () => _showAddToPlaylistDialog(song)),
                    _buildOptionButton(Icons.shuffle, 'Shuffle', () {}),
                    _buildOptionButton(Icons.share, 'Share', () => _shareSong(song)),
                    _buildOptionButton(Icons.download, 'Download', () => _downloadSong(song)),
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
                IconButton(
                  icon: const Icon(Icons.share, size: 22),
                  color: background,
                  onPressed: () => _shareSong(song),
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
                child: Column(
                  children: [
                    IconButton(
                      icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 32),
                      color: isLiked ? Colors.red : textSecondary,
                      onPressed: () => _toggleLike(song),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, size: 28),
                      color: Colors.green,
                      onPressed: () => _shareSong(song),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(song.moodEmoji, style: const TextStyle(fontSize: 20)),
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
          GestureDetector(
            onTap: () => _showArtistPage(song.artist),
            child: Text(
              song.artist,
              style: const TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(song.language, style: const TextStyle(color: Colors.blue, fontSize: 12)),
              ),
              const SizedBox(width: 8),
              if (song.isMovieSong)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(song.movieName, style: const TextStyle(color: Colors.purple, fontSize: 12)),
                ),
            ],
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
          _buildDetailRow('Mood', '${song.moodEmoji} ${song.mood.name}'),
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
                    icon: const Icon(Icons.share, size: 28),
                    color: Colors.green,
                    onPressed: () => _shareSong(song),
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
                        Positioned(
                          top: 8,
                          left: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(song.moodEmoji, style: const TextStyle(fontSize: 20)),
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
          GestureDetector(
            onTap: () => _showArtistPage(song.artist),
            child: Text(
              song.artist,
              style: const TextStyle(fontSize: 16, color: accent, fontWeight: FontWeight.w600),
            ),
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
  static const List<String> _proxyUrls = [
    'https://corsproxy.io/?',
    'https://api.allorigins.win/raw?url=',
    '',
  ];

  static String getProxyUrl(String audioUrl) {
    for (var proxy in _proxyUrls) {
      if (proxy.isEmpty) {
        return audioUrl;
      }
      return '$proxy${Uri.encodeComponent(audioUrl)}';
    }
    return audioUrl;
  }

  static Future<List<Song>> getHome({String? singer}) async {
    try {
      final query = singer ?? 'tamil songs';
      final response = await http.get(
        Uri.parse('$_apiUrl/result/?query=$query'),
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> songsJson = [];
        if (data is List) {
          songsJson = data;
        } else if (data is Map && data.containsKey('results')) {
          songsJson = data['results'] as List? ?? [];
        }
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
        headers: {'Accept': 'application/json'},
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> songsJson = [];
        if (data is List) {
          songsJson = data;
        } else if (data is Map && data.containsKey('results')) {
          songsJson = data['results'] as List? ?? [];
        }
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
        headers: {'Accept': 'application/json'},
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
