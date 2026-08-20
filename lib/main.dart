import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase/supabase.dart';
import 'package:uuid/uuid.dart';
import 'audio_handler.dart';
import 'download_helper.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.system) {
    _load();
  }

  static const _prefKey = 'theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == 'light') value = ThemeMode.light;
    if (saved == 'dark') value = ThemeMode.dark;
  }

  Future<void> setMode(ThemeMode mode) async {
    value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, mode.name);
  }
}

class AppTheme {
  static final ThemeController controller = ThemeController();

  static const Color accent = Color(0xFFFFFFFF);
  static const Color accentLight = Color(0xFF000000);
  static const Color background = Color(0xFF080808);
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFF111111);
  static const Color surfaceLightMode = Color(0xFFF0F0F0);
  static const Color surfaceLight = Color(0xFF0A0A0A);
  static const Color surfaceLightLight = Color(0xFFE0E0E0);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textSecondaryLight = Color(0xFF666666);

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF000000),
        secondary: Color(0xFF000000),
        surface: Color(0xFFFFFFFF),
        onPrimary: Color(0xFFFFFFFF),
        onSecondary: Color(0xFFFFFFFF),
        onSurface: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: backgroundLight,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFFFFFFFF),
        secondary: Color(0xFFFFFFFF),
        surface: Color(0xFF080808),
        onPrimary: Color(0xFF000000),
        onSecondary: Color(0xFF000000),
        onSurface: Color(0xFFFFFFFF),
      ),
      scaffoldBackgroundColor: background,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await SupabaseManager.instance.init().timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        debugPrint('Supabase init timed out - continuing without cloud sync');
      },
    );
  } catch (e) {
    debugPrint('Supabase init failed (app will work offline): $e');
  }
  AudioPlayerHandler audioHandler;
  try {
    audioHandler = await AudioPlayerHandler.init().timeout(
      const Duration(seconds: 8),
      onTimeout: () {
        debugPrint('Audio service init timed out - continuing without media notification');
        return AudioPlayerHandler();
      },
    );
  } catch (e) {
    debugPrint('Audio service init failed (app will work without notification): $e');
    audioHandler = AudioPlayerHandler();
  }
  runApp(MusicApp(audioHandler: audioHandler));
}

class SupabaseManager {
  static final SupabaseManager instance = SupabaseManager._();
  SupabaseManager._();

  late SupabaseClient client;
  String? _userId;

  static const String _supabaseUrl = 'https://ncghdfjeymfwqjduvrmq.supabase.co';
  static const String _supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5jZ2hkZmpleW1md3FqZHV2cm1xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ3NTI4MzQsImV4cCI6MjA5MDMyODgzNH0.qcj9CBI9QoNgilLEFnTT_7ciWHVc5fmFLG_54jOXi4U';

  bool _isAvailable = false;
  bool get isAvailable => _isAvailable;

  Future<void> init() async {
    try {
      client = SupabaseClient(_supabaseUrl, _supabaseKey);
      await _ensureTablesExist().timeout(const Duration(seconds: 4));
      await _ensureUserId().timeout(const Duration(seconds: 4));
      _isAvailable = true;
    } catch (e) {
      debugPrint('Supabase unavailable: $e');
      _isAvailable = false;
    }
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
    if (_userId == null || !_isAvailable) return;
    try {
      await client.from('user_profiles').update(profile).eq('id', _userId!).select();
    } catch (e) {
      debugPrint('Error updating profile: $e');
    }
  }

  Future<Map<String, dynamic>?> getTasteProfile() async {
    if (_userId == null || !_isAvailable) return null;
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
    if (_userId == null || !_isAvailable) return;
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
    if (_userId == null || !_isAvailable) return;
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
    if (_userId == null || !_isAvailable) return [];
    try {
      final response = await client.from('playlists').select().eq('user_id', _userId!);
      return List<Map<String, dynamic>>.from(response.map((e) => Map<String, dynamic>.from(e as Map)));
    } catch (e) {
      return [];
    }
  }
}

class MusicApp extends StatefulWidget {
  final AudioPlayerHandler audioHandler;
  const MusicApp({super.key, required this.audioHandler});

  @override
  State<MusicApp> createState() => _MusicAppState();
}

class _MusicAppState extends State<MusicApp> {
  bool _isInitialized = false;
  double _loadingProgress = 0.0;
  bool _showPreferences = false;
  List<String> _selectedLanguages = [];
  List<String> _selectedSingers = [];
  List<String> _selectedGenres = [];

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get accent => _isDark ? AppTheme.accent : AppTheme.accentLight;
  Color get background => _isDark ? AppTheme.background : AppTheme.backgroundLight;
  Color get surface => _isDark ? AppTheme.surface : AppTheme.surfaceLightMode;
  Color get surfaceLight => _isDark ? AppTheme.surfaceLight : AppTheme.surfaceLightLight;
  Color get textPrimary => _isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
  Color get textSecondary => _isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

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
    await prefs.setStringList('genres', _selectedGenres);
    
    await RecommendationEngine.instance.init();
    await RecommendationEngine.instance.updateTasteProfile(
      languages: _selectedLanguages,
      artists: _selectedSingers,
      genres: _selectedGenres,
    );
    
    setState(() => _showPreferences = false);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: AppTheme.controller,
      builder: (context, mode, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: mode,
        home: !_isInitialized 
            ? _buildSplashScreen() 
            : _showPreferences 
                ? _buildPreferencesScreen() 
                : MusicPlayerScreen(audioHandler: widget.audioHandler),
      ),
    );
  }

  Widget _buildSplashScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF040404),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(
                            colors: [
                              Colors.transparent,
                              Colors.white.withValues(alpha: 0.6),
                              Colors.transparent,
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.2, 0.4, 1.0],
                          ),
                        ),
                      ),
                      Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF040404),
                        ),
                      ),
                      ClipOval(
                        child: Image.asset(
                          'assets/logo.png',
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'SRI KEYAN',
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 8,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'WHERE MUSIC LIVES',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.3),
                    letterSpacing: 6,
                    fontFamily: 'monospace',
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: List.generate(24, (i) {
                      return AnimatedContainer(
                        duration: Duration(milliseconds: 400 + (i % 5) * 120),
                        curve: Curves.easeInOut,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        width: 3,
                        height: _loadingProgress < 1.0 ? 4.0 : (4.0 + (((i * 7 + 3) % 5) * 4.0)),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(1.5),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: 224,
                  height: 1,
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.white.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Loading your world',
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.2),
                    letterSpacing: 4,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesScreen() {
    final languages = ['Tamil', 'Hindi', 'English', 'Malayalam', 'Telugu', 'Kannada', 'Bengali', 'Marathi', 'Punjabi', 'Gujarati', 'Rajasthani', 'Bhojpuri', 'Assamese', 'Odia', 'Sindhi', 'Konkani', 'Manipuri', 'Nepali', 'Sinhala', 'Urdu'];
    final singers = [
      'A.R. Rahman', 'Anirudh', 'Ilaiyaraaja', 'Vishal', 'Harris Jayaraj', 'G.V. Prakash',
      'Yuvan Shankar Raja', 'Devi Sri Prasad', 'Thaman S', 'Rockstar DSP', 'Santhosh Narayanan', 'Sean Roldan',
      'Sid Sriram', 'SP Balasubrahmanyam', 'K.J. Yesudas', 'K.S. Chithra', 'Shreya Ghoshal', 'Arijit Singh',
      'Amit Trivedi', 'Pritam', 'Vishal-Shekhar', 'Salim-Sulaiman', 'Sachin-Jigar', 'Badshah',
      'Diljit Dosanjh', 'A.R. Rahman', 'Shankar Mahadevan', 'Sonu Nigam', 'Udit Narayan', 'Alka Yagnik',
      'Sunidhi Chauhan', 'Neha Kakkar', 'Tulsi Kumar', 'Badshah', 'Honey Singh', 'Rajiv Gandhi',
      'Anand Bhaskar', 'Prateek Kuhad', 'The Local Train', 'Kailash Kher',
    ];
    final genres = [
      'Film Soundtrack', 'Classical', 'Carnatic', 'Hindustani', 'Folk', 'Devotional',
      'Ghazal', 'Qawwali', 'Sufi', 'Indie Pop', 'Rock', 'Metal', 'Jazz',
      'Blues', 'Electronic', 'EDM', 'Hip Hop', 'Rap', 'R&B', 'Soul',
      'Acoustic', 'Unplugged', 'Workout', 'Dance', 'Romance', 'Melody',
      'BGM / Theme', 'Retro', '90s Hits', '2000s Hits', 'Lofi', 'Chill',
    ];

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
                  child: Icon(Icons.music_note, color: background, size: 40),
                ),
              ),
              const SizedBox(height: 24),
              Center(
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
              Text(
                'Select Your Favorite Singers',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick at least 3 for better recommendations',
                style: TextStyle(fontSize: 12, color: textSecondary),
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
                        color: isSelected ? accent : surfaceLight,
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
              Text(
                'Preferred Languages',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick at least 2 to unlock language-based mixes',
                style: TextStyle(fontSize: 12, color: textSecondary),
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
                        color: isSelected ? accent : surfaceLight,
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
              const SizedBox(height: 32),
              Text(
                'What Do You Listen To?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              const SizedBox(height: 4),
              Text(
                'So we can build the perfect mix for you',
                style: TextStyle(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: genres.map((genre) {
                  final isSelected = _selectedGenres.contains(genre);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) {
                          _selectedGenres.remove(genre);
                        } else {
                          _selectedGenres.add(genre);
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? accent : surfaceLight,
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
                        genre,
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

  double valence;
  double energy;
  double tempo;
  double acousticness;

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
    this.valence = 0.5,
    this.energy = 0.5,
    this.tempo = 120.0,
    this.acousticness = 0.3,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    final mediaUrl = json['media_url'] ?? json['downloadUrl'] ?? json['media_preview_url'] ?? '';
    final image = json['image'] ?? json['thumbnail'] ?? json['albumArt'] ?? '';
    final songId = json['id'] ?? json['e_songid'] ?? json['videoId'] ?? '';

    String toStringVal(Object? v) => v == null ? '' : v.toString();
    
    String imageUrl = image;
    if (imageUrl.isNotEmpty && !imageUrl.startsWith('http')) {
      imageUrl = 'https://c.saavncdn.com' + imageUrl;
    }
    
    String language = 'Tamil';
    String title = toStringVal(json['song'] ?? json['title']);
    String album = toStringVal(json['album']);
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
    
    String artist = toStringVal(json['primary_artists'] ?? json['singers'] ?? json['artist']);
    if (artist.isEmpty) artist = 'Unknown Artist';
    if (artist.startsWith('{')) artist = 'Unknown Artist';

    double valence = 0.5;
    double energy = 0.5;
    double tempo = 120.0;
    double acousticness = 0.3;
    if (mood == SongMood.party) { valence = 0.85; energy = 0.9; tempo = 130.0; acousticness = 0.1; }
    else if (mood == SongMood.highEnergy) { valence = 0.7; energy = 0.95; tempo = 140.0; acousticness = 0.05; }
    else if (mood == SongMood.romantic) { valence = 0.65; energy = 0.35; tempo = 85.0; acousticness = 0.6; }
    else if (mood == SongMood.emotional) { valence = 0.25; energy = 0.3; tempo = 80.0; acousticness = 0.55; }
    else {
      final titleLower = title.toLowerCase();
      if (titleLower.contains('lofi') || titleLower.contains('acoustic') || titleLower.contains('unplugged')) { valence = 0.4; energy = 0.25; tempo = 75.0; acousticness = 0.8; }
      else if (titleLower.contains('remix') || titleLower.contains('edm') || titleLower.contains('bass')) { valence = 0.7; energy = 0.85; tempo = 128.0; acousticness = 0.05; }
      else if (titleLower.contains('classical') || titleLower.contains('carnatic') || titleLower.contains('hindustani')) { valence = 0.45; energy = 0.2; tempo = 70.0; acousticness = 0.9; }
      else if (titleLower.contains('devotional') || titleLower.contains('bhajan') || titleLower.contains('temple')) { valence = 0.5; energy = 0.15; tempo = 65.0; acousticness = 0.85; }
    }

    return Song(
      id: songId.toString(),
      title: title,
      artist: artist,
      album: album.isNotEmpty ? album : 'Unknown Album',
      imageUrl: imageUrl,
      audioUrl: mediaUrl,
      duration: toStringVal(json['duration']),
      url: toStringVal(json['perma_url'] ?? json['url']),
      year: toStringVal(json['year']),
      language: language,
      mood: mood,
      valence: valence,
      energy: energy,
      tempo: tempo,
      acousticness: acousticness,
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
      MusicPlaylist(id: 'favorites', name: 'Favorites', description: 'Your liked songs', createdAt: DateTime.now()),
      MusicPlaylist(id: 'discover_mix', name: 'Discover Mix', description: 'AI-generated mix based on your taste', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'recently_played', name: 'Recently Played', description: 'Songs you\'ve been listening to', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'daily_mix_1', name: 'Daily Mix 1', description: 'Your top picks', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'daily_mix_2', name: 'Daily Mix 2', description: 'Fresh finds for you', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'daily_mix_3', name: 'Daily Mix 3', description: 'More of what you love', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'tamil_hitz', name: 'Tamil Hitz', description: 'Top Tamil chartbusters', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'hindi_hitz', name: 'Hindi Hitz', description: 'Bollywood chartbusters', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'romantic_tamil', name: 'Romantic Tamil', description: 'Tamil love songs', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'melody_nights', name: 'Melody Nights', description: 'Soft Tamil melodies for late nights', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'party_starter', name: 'Party Starter', description: 'Get the party going', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'workout_beats', name: 'Workout Beats', description: 'High-energy tracks to pump you up', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'study_lofi', name: 'Study Lofi', description: 'Chill beats to focus', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'sleep_well', name: 'Sleep Well', description: 'Relaxing songs to wind down', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'rainy_day', name: 'Rainy Day', description: 'Songs for rainy vibes', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'road_trip', name: 'Road Trip', description: 'Perfect travel playlist', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'morning_coffee', name: 'Morning Coffee', description: 'Ease into your morning', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'throwback_90s', name: 'Throwback 90s', description: '90s nostalgia hits', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'throwback_2000s', name: 'Throwback 2000s', description: '2000s golden era', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'ar_rahman_classics', name: 'A.R. Rahman Classics', description: 'The Mozart of Madras', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'A.R. Rahman'),
      MusicPlaylist(id: 'anirudh_essentials', name: 'Anirudh Essentials', description: 'Top Anirudh tracks', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Anirudh'),
      MusicPlaylist(id: 'ilaiyaraaja_golden', name: 'Ilaiyaraaja Golden', description: 'Timeless Ilaiyaraaja', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Ilaiyaraaja'),
      MusicPlaylist(id: 'yuvan_vibes', name: 'Yuvan Vibes', description: 'Yuvan Shankar Raja hits', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Yuvan Shankar Raja'),
      MusicPlaylist(id: 'sid_sriram_soul', name: 'Sid Sriram Soul', description: 'Soulful Sid Sriram', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Sid Sriram'),
      MusicPlaylist(id: 'harris_energy', name: 'Harris Energy', description: 'Harris Jayaraj bangers', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Harris Jayaraj'),
      MusicPlaylist(id: 'dsp_power', name: 'DSP Power', description: 'Devi Sri Prasad energy', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Devi Sri Prasad'),
      MusicPlaylist(id: 'thaman_feast', name: 'Thaman Feast', description: 'Thaman S power tracks', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Thaman S'),
      MusicPlaylist(id: 'gv_prakash_vibes', name: 'G.V. Prakash Vibes', description: 'G.V. Prakash Kumar collection', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'G.V. Prakash'),
      MusicPlaylist(id: 'arijit_singh_hindi', name: 'Arijit Singh Hindi', description: 'Arijit Singh best Hindi', createdAt: DateTime.now(), isAutoGenerated: true, basedOnArtist: 'Arijit Singh'),
      MusicPlaylist(id: 'classical_carnatic', name: 'Carnatic Classical', description: 'Pure Carnatic music', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'devotional_mix', name: 'Devotional Mix', description: 'Spiritual songs', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'indie_tamil', name: 'Indie Tamil', description: 'Tamil indie scene', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'electronic_mix', name: 'Electronic Mix', description: 'Electronic & EDM vibes', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'acoustic_unplugged', name: 'Acoustic Unplugged', description: 'Raw acoustic sessions', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'ghazal_nights', name: 'Ghazal Nights', description: 'Soulful ghazals', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'qawwali_spirit', name: 'Qawwali Spirit', description: 'Sufi qawwali vibes', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'kuthu_king', name: 'Kuthu King', description: 'Dappankuthu madness', createdAt: DateTime.now(), isAutoGenerated: true, basedOnMood: 'party'),
      MusicPlaylist(id: 'sad_songs', name: 'Sad Songs', description: 'Heartbreak & emotions', createdAt: DateTime.now(), isAutoGenerated: true, basedOnMood: 'emotional'),
      MusicPlaylist(id: 'love_stories', name: 'Love Stories', description: 'Romantic ballads', createdAt: DateTime.now(), isAutoGenerated: true, basedOnMood: 'romantic'),
      MusicPlaylist(id: 'bgm_collection', name: 'BGM Collection', description: 'Best background scores', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'retro_tamil', name: 'Retro Tamil', description: 'Classic Tamil gold', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'bollywood_hitz', name: 'Bollywood Hitz', description: 'Top Bollywood numbers', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'english_pop', name: 'English Pop', description: 'Global pop hits', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'malayalam_melodies', name: 'Malayalam Melodies', description: 'Mallu music gems', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'telugu_trending', name: 'Telugu Trending', description: 'Telugu chart toppers', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'punjabi_vibes', name: 'Punjabi Vibes', description: 'Punjabi bangers', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'kannada_golden', name: 'Kannada Golden', description: 'Kannada classics', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'bengali_soul', name: 'Bengali Soul', description: 'Bengali music gems', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'new_releases', name: 'New Releases', description: 'Fresh new tracks', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'top_charts_india', name: 'Top Charts India', description: 'India-wide chart toppers', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'discovery_radar', name: 'Discovery Radar', description: 'Explore new artists & genres', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'relaxation_zone', name: 'Relaxation Zone', description: 'Calm & peaceful tracks', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'energy_boost', name: 'Energy Boost', description: 'Instant energy tracks', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'sufi_soul', name: 'Sufi Soul', description: 'Spiritual Sufi journey', createdAt: DateTime.now(), isAutoGenerated: true),
      MusicPlaylist(id: 'festival_mix', name: 'Festival Mix', description: 'Festival celebration songs', createdAt: DateTime.now(), isAutoGenerated: true),
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
    List<String>? genres,
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
    if (genres != null) {
      for (var genre in genres) {
        tasteProfile.moodScores[genre] = (tasteProfile.moodScores[genre] ?? 0) + 20;
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

  Timer? _searchSaveDebounce;

  void addSearchQuery(String query) {
    tasteProfile.addSearchQuery(query);
    _searchSaveDebounce?.cancel();
    _searchSaveDebounce = Timer(const Duration(seconds: 2), () {
      _saveToStorage();
    });
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

    final moodScores = tasteProfile.moodScores;
    for (var entry in moodScores.entries) {
      if (titleLower.contains(entry.key.toLowerCase())) {
        score += entry.value * 0.5;
      }
    }

    final explorationBonus = (DateTime.now().millisecond % 20) - 10;
    score += explorationBonus;

    if (song.imageUrl.isNotEmpty) score += 1;

    return score;
  }

  List<Song> getRecommendedSongs(List<Song> songs, {int limit = 20, bool useSessionWeight = false}) {
    final scoredSongs = songs.map((song) => MapEntry(song, calculateSongScore(song, useSessionWeight: useSessionWeight))).toList();
    scoredSongs.sort((a, b) => b.value.compareTo(a.value));
    return scoredSongs.take(limit).map((e) => e.key).toList();
  }

  List<Song> getRecommendedForYou(List<Song> songs) {
    final exploitation = getRecommendedSongs(songs, limit: 30);
    final exploration = getExplorationSongs(songs, limit: 10);
    final seen = <String>{};
    final combined = <Song>[];
    for (var s in [...exploitation, ...exploration]) {
      if (seen.add(s.id)) combined.add(s);
    }
    return combined;
  }

  List<Song> getExplorationSongs(List<Song> songs, {int limit = 10}) {
    final explored = tasteProfile.recentlyPlayed.toSet();
    final topArtists = tasteProfile.getTopArtists(5).toSet();
    final topLanguages = tasteProfile.getTopLanguages(3).toSet();
    
    final discovery = songs.where((s) {
      if (tasteProfile.isNotInterested(s.id)) return false;
      if (explored.contains(s.id)) return false;
      if (topArtists.contains(s.artist) && topLanguages.contains(s.language)) return false;
      return true;
    }).toList();
    
    discovery.shuffle();
    return discovery.take(limit).toList();
  }

  List<Song> getSimilarToRecent(List<Song> songs) {
    if (tasteProfile.recentlyPlayed.isEmpty && tasteProfile.likedSongs.isEmpty) {
      return songs.take(20).toList();
    }
    
    final profileArtists = <String, int>{};
    final profileLanguages = <String, int>{};
    
    for (var interaction in _interactionHistory.take(100)) {
      final weight = interaction.type == InteractionType.like ? 3 :
                     interaction.type == InteractionType.rewatch ? 4 :
                     interaction.type == InteractionType.skip ? -1 :
                     interaction.watchPercentage > 0.7 ? 2 : 1;
      profileArtists[interaction.artist] = (profileArtists[interaction.artist] ?? 0) + weight;
      profileLanguages[interaction.language] = (profileLanguages[interaction.language] ?? 0) + weight;
    }

    final topArtists = profileArtists.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topArtistNames = topArtists.take(10).map((e) => e.key).toSet();
    final topLangNames = profileLanguages.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final topLangSet = topLangNames.take(5).map((e) => e.key).toSet();

    final similar = songs.where((song) {
      if (tasteProfile.isNotInterested(song.id)) return false;
      if (topArtistNames.contains(song.artist)) return true;
      if (topLangSet.contains(song.language) && song.energy > 0.3) return true;
      return false;
    }).toList();
    
    similar.sort((a, b) {
      final scoreA = calculateSongScore(a) + (topArtistNames.contains(a.artist) ? 30 : 0) + (topLangSet.contains(a.language) ? 15 : 0);
      final scoreB = calculateSongScore(b) + (topArtistNames.contains(b.artist) ? 30 : 0) + (topLangSet.contains(b.language) ? 15 : 0);
      return scoreB.compareTo(scoreA);
    });
    
    return similar.take(25).toList();
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
    return fansAlsoLike.take(25).toList();
  }

  List<Song> getDiscoverMix(List<Song> songs) {
    final mix = <Song>[];
    final topArtists = tasteProfile.getTopArtists(5);
    final topLanguages = tasteProfile.getTopLanguages(3);
    
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
    
    final discovered = <Song>[];
    for (var song in scored) {
      if (added >= 35) break;
      if (!mix.contains(song) && !topArtists.contains(song.artist)) {
        discovered.add(song);
        added++;
      }
    }
    discovered.shuffle();
    mix.addAll(discovered.take(15));
    
    if (mix.length < 40) {
      for (var song in scored) {
        if (added >= 40) break;
        if (!mix.contains(song)) {
          mix.add(song);
          added++;
        }
      }
    }
    
    return mix;
  }

  List<Song> getRecentlyPlayedSongs(List<Song> allSongs) {
    final recentIds = tasteProfile.recentlyPlayed;
    final recent = <Song>[];
    for (var id in recentIds) {
      final match = allSongs.where((s) => s.id == id);
      if (match.isNotEmpty) recent.add(match.first);
      if (recent.length >= 20) break;
    }
    return recent;
  }

  List<Song> getMoodBasedSongs(List<Song> songs, String mood) {
    final moodQueries = {
      'happy': ['happy', 'upbeat', 'feel good'],
      'sad': ['sad', 'melancholy', 'heartbreak'],
      'energetic': ['dance', 'party', 'energetic'],
      'chill': ['chill', 'relax', 'acoustic'],
      'romantic': ['love', 'romantic', 'kiss'],
    };
    final keywords = moodQueries[mood] ?? ['tamil songs'];
    final filtered = songs.where((s) {
      final title = s.title.toLowerCase();
      final artist = s.artist.toLowerCase();
      return keywords.any((k) => title.contains(k) || artist.contains(k));
    }).toList();
    if (filtered.isEmpty) return getRecommendedSongs(songs, limit: 10);
    return filtered.take(10).toList();
  }

  List<MusicPlaylist> getPlaylists() => _playlists;

  String _getTimeContext() {
    final hour = DateTime.now().hour;
    if (hour >= 6 && hour < 10) return 'morning';
    if (hour >= 10 && hour < 14) return 'afternoon';
    if (hour >= 14 && hour < 18) return 'evening';
    if (hour >= 18 && hour < 22) return 'night';
    return 'late_night';
  }

  double _calculateAudioMatchScore(Song song, Song currentSong) {
    double score = 0;
    score += (1.0 - (song.energy - currentSong.energy).abs()) * 15;
    score += (1.0 - (song.valence - currentSong.valence).abs()) * 10;
    score += (1.0 - (song.tempo - currentSong.tempo).abs() / 80.0) * 8;
    score += (1.0 - (song.acousticness - currentSong.acousticness).abs()) * 5;
    return score;
  }

  double _calculateMetadataNlpScore(Song song) {
    double score = 0;
    final titleLower = song.title.toLowerCase();
    final artistLower = song.artist.toLowerCase();

    final topSearches = tasteProfile.getTopSearches(10);
    for (var search in topSearches) {
      final searchLower = search.toLowerCase();
      if (titleLower.contains(searchLower) || searchLower.contains(titleLower)) {
        score += 20;
      }
      final searchWords = searchLower.split(RegExp(r'\s+'));
      for (var word in searchWords) {
        if (word.length > 2 && titleLower.contains(word)) score += 5;
      }
    }

    final recentInteractions = _interactionHistory.take(50);
    for (var interaction in recentInteractions) {
      if (interaction.artist.toLowerCase() == artistLower) {
        score += 3;
      }
    }

    final topArtists = tasteProfile.getTopArtists(5);
    if (topArtists.contains(song.artist)) score += 15;

    final topLanguages = tasteProfile.getTopLanguages(3);
    if (topLanguages.contains(song.language)) score += 10;

    return score;
  }

  Song getSmartNextSong(List<Song> allSongs, Song? currentSong, {bool wasSkipped = false}) {
    if (allSongs.isEmpty) return currentSong ?? allSongs.first;
    if (allSongs.length == 1) return allSongs.first;

    final timeContext = _getTimeContext();
    final isExploration = DateTime.now().millisecond % 5 == 0;

    if (isExploration) {
      final explored = tasteProfile.recentlyPlayed.toSet();
      final candidates = allSongs.where((s) {
        if (explored.contains(s.id)) return false;
        if (s.id == currentSong?.id) return false;
        return true;
      }).toList();
      if (candidates.isNotEmpty) {
        candidates.shuffle();
        return candidates.first;
      }
    }

    final scored = allSongs.where((s) => s.id != currentSong?.id).map((song) {
      double score = calculateSongScore(song, useSessionWeight: true);

      score += _calculateMetadataNlpScore(song);

      if (currentSong != null) {
        score += _calculateAudioMatchScore(song, currentSong);
      }

      switch (timeContext) {
        case 'morning':
          score += song.energy * 20;
          score += song.valence * 15;
          break;
        case 'afternoon':
          score += song.energy * 10;
          break;
        case 'evening':
          score += (1.0 - song.energy) * 10;
          score += song.acousticness * 15;
          break;
        case 'night':
          score += (1.0 - song.energy) * 15;
          score += song.acousticness * 20;
          score += (1.0 - song.valence) * 10;
          break;
        case 'late_night':
          score += song.acousticness * 25;
          score += (1.0 - song.energy) * 20;
          score += (1.0 - song.valence) * 15;
          break;
      }

      if (wasSkipped) {
        if (currentSong != null) {
          final audioDiff = (song.energy - currentSong.energy).abs() +
              (song.valence - currentSong.valence).abs();
          score += audioDiff * 15;
        }
      }

      final jitter = (DateTime.now().millisecond % 8) - 4;
      score += jitter;

      return MapEntry(song, score);
    }).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.first.key;
  }

  void populatePlaylistsWithSongs(List<Song> allSongs) {
    for (var playlist in _playlists) {
      if (playlist.songIds.isNotEmpty) continue;

      List<Song> matched;
      switch (playlist.id) {
        case 'tamil_hitz':
          matched = allSongs.where((s) => s.language == 'Tamil' && s.energy > 0.6).toList();
          break;
        case 'hindi_hitz':
          matched = allSongs.where((s) => s.language == 'Hindi' && s.energy > 0.6).toList();
          break;
        case 'romantic_tamil':
          matched = allSongs.where((s) => s.mood == SongMood.romantic || s.acousticness > 0.5).toList();
          break;
        case 'melody_nights':
          matched = allSongs.where((s) => s.energy < 0.4 && s.acousticness > 0.4).toList();
          break;
        case 'party_starter':
          matched = allSongs.where((s) => s.mood == SongMood.party || s.energy > 0.8).toList();
          break;
        case 'workout_beats':
          matched = allSongs.where((s) => s.energy > 0.75 && s.tempo > 110).toList();
          break;
        case 'study_lofi':
          matched = allSongs.where((s) => s.acousticness > 0.6 || s.energy < 0.35).toList();
          break;
        case 'sleep_well':
          matched = allSongs.where((s) => s.energy < 0.25 && s.acousticness > 0.5).toList();
          break;
        case 'rainy_day':
          matched = allSongs.where((s) => s.valence < 0.5 && s.acousticness > 0.4).toList();
          break;
        case 'road_trip':
          matched = allSongs.where((s) => s.energy > 0.5 && s.valence > 0.5).toList();
          break;
        case 'morning_coffee':
          matched = allSongs.where((s) => s.energy < 0.5 && s.acousticness > 0.3).toList();
          break;
        case 'throwback_90s':
          matched = allSongs.where((s) => s.year.isNotEmpty && int.tryParse(s.year) != null && int.parse(s.year) < 2000).toList();
          break;
        case 'throwback_2000s':
          matched = allSongs.where((s) {
            if (s.year.isEmpty) return false;
            final y = int.tryParse(s.year);
            return y != null && y >= 2000 && y < 2010;
          }).toList();
          break;
        case 'ar_rahman_classics':
          matched = allSongs.where((s) => s.artist.contains('Rahman') || s.artist.contains('A.R.')).toList();
          break;
        case 'anirudh_essentials':
          matched = allSongs.where((s) => s.artist.contains('Anirudh')).toList();
          break;
        case 'ilaiyaraaja_golden':
          matched = allSongs.where((s) => s.artist.contains('Ilaiyaraaja')).toList();
          break;
        case 'yuvan_vibes':
          matched = allSongs.where((s) => s.artist.contains('Yuvan')).toList();
          break;
        case 'sid_sriram_soul':
          matched = allSongs.where((s) => s.artist.contains('Sid Sriram')).toList();
          break;
        case 'harris_energy':
          matched = allSongs.where((s) => s.artist.contains('Harris')).toList();
          break;
        case 'dsp_power':
          matched = allSongs.where((s) => s.artist.contains('DSP') || s.artist.contains('Devi Sri')).toList();
          break;
        case 'thaman_feast':
          matched = allSongs.where((s) => s.artist.contains('Thaman')).toList();
          break;
        case 'gv_prakash_vibes':
          matched = allSongs.where((s) => s.artist.contains('G.V. Prakash')).toList();
          break;
        case 'arijit_singh_hindi':
          matched = allSongs.where((s) => s.artist.contains('Arijit')).toList();
          break;
        case 'classical_carnatic':
          matched = allSongs.where((s) => s.mood == SongMood.highEnergy && s.acousticness > 0.5 || s.title.toLowerCase().contains('classical')).toList();
          break;
        case 'devotional_mix':
          matched = allSongs.where((s) => s.title.toLowerCase().contains('devotional') || s.title.toLowerCase().contains('bhajan') || s.title.toLowerCase().contains('temple')).toList();
          break;
        case 'indie_tamil':
          matched = allSongs.where((s) => s.language == 'Tamil' && s.album.toLowerCase().contains('single')).toList();
          break;
        case 'electronic_mix':
          matched = allSongs.where((s) => s.energy > 0.7 && s.acousticness < 0.2).toList();
          break;
        case 'acoustic_unplugged':
          matched = allSongs.where((s) => s.acousticness > 0.6).toList();
          break;
        case 'ghazal_nights':
          matched = allSongs.where((s) => s.title.toLowerCase().contains('ghazal') || s.title.toLowerCase().contains('qawwali')).toList();
          break;
        case 'qawwali_spirit':
          matched = allSongs.where((s) => s.title.toLowerCase().contains('qawwali') || s.title.toLowerCase().contains('sufi')).toList();
          break;
        case 'kuthu_king':
          matched = allSongs.where((s) => s.mood == SongMood.party || s.title.toLowerCase().contains('kuthu')).toList();
          break;
        case 'sad_songs':
          matched = allSongs.where((s) => s.mood == SongMood.emotional || s.valence < 0.3).toList();
          break;
        case 'love_stories':
          matched = allSongs.where((s) => s.mood == SongMood.romantic || s.title.toLowerCase().contains('love')).toList();
          break;
        case 'bgm_collection':
          matched = allSongs.where((s) => s.title.toLowerCase().contains('bgm') || s.title.toLowerCase().contains('theme')).toList();
          break;
        case 'retro_tamil':
          matched = allSongs.where((s) => s.language == 'Tamil' && s.year.isNotEmpty && int.tryParse(s.year) != null && int.parse(s.year) < 2005).toList();
          break;
        case 'bollywood_hitz':
          matched = allSongs.where((s) => s.language == 'Hindi').toList();
          break;
        case 'english_pop':
          matched = allSongs.where((s) => s.language == 'English').toList();
          break;
        case 'malayalam_melodies':
          matched = allSongs.where((s) => s.language == 'Malayalam').toList();
          break;
        case 'telugu_trending':
          matched = allSongs.where((s) => s.language == 'Telugu').toList();
          break;
        case 'punjabi_vibes':
          matched = allSongs.where((s) => s.language == 'Punjabi').toList();
          break;
        case 'kannada_golden':
          matched = allSongs.where((s) => s.language == 'Kannada').toList();
          break;
        case 'bengali_soul':
          matched = allSongs.where((s) => s.language == 'Bengali').toList();
          break;
        case 'new_releases':
          matched = allSongs.where((s) {
            if (s.year.isEmpty) return false;
            final y = int.tryParse(s.year);
            return y != null && y >= 2024;
          }).toList();
          break;
        case 'top_charts_india':
          matched = allSongs.where((s) => s.energy > 0.6 && s.valence > 0.5).toList();
          break;
        case 'discovery_radar':
          matched = allSongs.where((s) => !tasteProfile.isNotInterested(s.id)).toList();
          matched.shuffle();
          break;
        case 'relaxation_zone':
          matched = allSongs.where((s) => s.energy < 0.4).toList();
          break;
        case 'energy_boost':
          matched = allSongs.where((s) => s.energy > 0.8).toList();
          break;
        case 'sufi_soul':
          matched = allSongs.where((s) => s.title.toLowerCase().contains('sufi') || s.title.toLowerCase().contains('qawwali')).toList();
          break;
        case 'festival_mix':
          matched = allSongs.where((s) => s.valence > 0.7 && s.energy > 0.5).toList();
          break;
        case 'daily_mix_1':
          matched = getRecommendedSongs(allSongs, limit: 50);
          break;
        case 'daily_mix_2':
          matched = getRecommendedSongs(allSongs, limit: 50);
          matched.shuffle();
          break;
        case 'daily_mix_3':
          matched = getDiscoverMix(allSongs);
          break;
        case 'discover_mix':
          matched = getDiscoverMix(allSongs);
          break;
        default:
          matched = getRecommendedSongs(allSongs, limit: 50);
      }

      matched.shuffle();
      playlist.songIds = matched.take(50).map((s) => s.id).toList();
    }
  }

  int get totalSongsPlayed => _interactionHistory.length;

  double get totalListeningHours {
    final totalSeconds = _interactionHistory.fold<int>(0, (sum, i) => sum + i.totalDuration);
    return totalSeconds / 3600.0;
  }

  int get totalListeningMinutes {
    final totalSeconds = _interactionHistory.fold<int>(0, (sum, i) => sum + i.totalDuration);
    return totalSeconds ~/ 60;
  }

  List<String> get topArtists {
    final map = <String, int>{};
    for (var i in _interactionHistory) {
      map[i.artist] = (map[i.artist] ?? 0) + 1;
    }
    final sorted = map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).map((e) => e.key).toList();
  }

  Map<String, int> get genreDistribution {
    final map = <String, int>{};
    for (var i in _interactionHistory) {
      map[i.language] = (map[i.language] ?? 0) + 1;
    }
    return map;
  }

  int get listeningStreak {
    if (_interactionHistory.isEmpty) return 0;
    int streak = 0;
    var checkDate = DateTime.now();
    final dates = _interactionHistory.map((i) => DateTime(i.timestamp.year, i.timestamp.month, i.timestamp.day)).toSet().toList()..sort((a, b) => b.compareTo(a));
    for (var date in dates) {
      final diff = DateTime(checkDate.year, checkDate.month, checkDate.day).difference(date).inDays;
      if (diff <= 1) {
        streak++;
        checkDate = date;
      } else {
        break;
      }
    }
    return streak;
  }

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
  final AudioPlayerHandler audioHandler;
  const MusicPlayerScreen({super.key, required this.audioHandler});

  @override
  State<MusicPlayerScreen> createState() => _MusicPlayerScreenState();
}

enum RepeatMode { off, one, all }

class _MusicPlayerScreenState extends State<MusicPlayerScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late AudioPlayer _audioPlayer;
  late final AudioPlayerHandler _audioHandler = widget.audioHandler;
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
  List<String> _selectedLanguages = [];
  List<String> _selectedGenres = [];
  final Set<String> _likedSongs = {};
  final Set<String> _showOptionsForSong = {};
  List<MusicPlaylist> _playlists = [];
  
  Timer? _searchDebounce;
  final Map<String, List<Song>> _searchCache = {};
  bool _songCompleteGuard = false;
  bool _shuffleEnabled = false;
  List<int> _shuffledIndices = [];
  bool _isSmallScreen = false;
  bool _isTablet = false;
  bool _isTV = false;
  bool _isLandscape = false;
  int _bottomNavIndex = 0;
  bool _sidebarExpanded = true;
  String? _downloadingSongId;
  final Set<String> _downloadedSongIds = {};
  bool _likeAnimating = false;
  bool _shareAnimating = false;
  bool _showDownloadBanner = true;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get accent => _isDark ? AppTheme.accent : AppTheme.accentLight;
  Color get background => _isDark ? AppTheme.background : AppTheme.backgroundLight;
  Color get surface => _isDark ? AppTheme.surface : AppTheme.surfaceLightMode;
  Color get surfaceLight => _isDark ? AppTheme.surfaceLight : AppTheme.surfaceLightLight;
  Color get textPrimary => _isDark ? AppTheme.textPrimary : AppTheme.textPrimaryLight;
  Color get textSecondary => _isDark ? AppTheme.textSecondary : AppTheme.textSecondaryLight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this);
    _audioPlayer = _audioHandler.player;
    _audioHandler.onNext = _playNext;
    _audioHandler.onPrevious = _playPrevious;
    _requestNotificationPermission();
    _requestStoragePermission();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateDeviceType();
      _loadPreferences();
    });
    _loadSongs();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final singers = prefs.getStringList('singers') ?? [];
    final genres = prefs.getStringList('genres') ?? [];
    final languages = prefs.getStringList('languages') ?? [];
    if (singers.isNotEmpty) {
      setState(() {
        _preferredSinger = singers.first;
      });
    }
    if (genres.isNotEmpty) {
      setState(() {
        _selectedGenres = genres;
      });
    }
    if (languages.isNotEmpty) {
      setState(() {
        _selectedLanguages = languages;
      });
    }
    
    await RecommendationEngine.instance.init();
    setState(() {
      _likedSongs.addAll(RecommendationEngine.instance.tasteProfile.likedSongs);
      _playlists = RecommendationEngine.instance.getPlaylists();
    });
  }

  void _updateDeviceType() {
    final size = MediaQuery.of(context).size;
    final width = size.width;
    final height = size.height;
    setState(() {
      _isSmallScreen = width <= 600;
      _isTablet = width > 600 && width <= 1024;
      _isDesktop = width > 1024 && width <= 1920;
      _isTV = width > 1920 || height > 1080;
      _isLandscape = width > height;
    });
  }

  double get _responsivePadding {
    if (_isTV) return 32;
    if (_isDesktop) return 24;
    if (_isTablet) return 20;
    return 16;
  }

  double get _responsiveFontScale {
    if (_isTV) return 1.4;
    if (_isDesktop) return 1.1;
    if (_isTablet) return 1.05;
    return 1.0;
  }

  double get _albumArtSize {
    if (_isTV) return 360;
    if (_isDesktop) return 300;
    if (_isTablet) return 280;
    if (_isSmallScreen && _isLandscape) return 180;
    return 260;
  }

  double get _songCardArtSize {
    if (_isTV) return 80;
    if (_isDesktop) return 64;
    if (_isTablet) return 60;
    return 56;
  }

  double get _miniPlayerArtSize {
    if (_isTV) return 64;
    if (_isDesktop) return 54;
    return 50;
  }

  @override
  void didChangeMetrics() {
    _updateDeviceType();
  }

  Future<void> _loadSongs() async {
    setState(() => _isLoading = true);
    try {
      final primarySinger = _preferredSinger ?? 'Anirudh';
      final results = await Future.wait([
        JioSaavnApi.getHome(singer: primarySinger),
        JioSaavnApi.search('tamil hit songs'),
        JioSaavnApi.search('tamil melody songs'),
        JioSaavnApi.search('tamil romantic songs'),
        JioSaavnApi.search('tamil kuthu songs'),
        JioSaavnApi.search('hindi hit songs'),
        JioSaavnApi.search('english pop songs'),
        JioSaavnApi.search('A.R. Rahman hits'),
        JioSaavnApi.search('Ilaiyaraaja classics'),
        JioSaavnApi.search('tamil sad songs'),
        JioSaavnApi.search('tamil 90s songs'),
        JioSaavnApi.search('tamil love songs'),
      ]);
      
      final allSongs = <Song>[];
      final seenIds = <String>{};
      for (var batch in results) {
        for (var song in batch) {
          if (!seenIds.contains(song.id) && song.audioUrl.isNotEmpty) {
            seenIds.add(song.id);
            allSongs.add(song);
          }
        }
      }
      
      final recommended = RecommendationEngine.instance.getRecommendedForYou(allSongs);
      final similar = RecommendationEngine.instance.getSimilarToRecent(allSongs);
      final fansAlso = RecommendationEngine.instance.getFansAlsoLiked(allSongs);
      final discoverMix = RecommendationEngine.instance.getDiscoverMix(allSongs);
      
      setState(() {
        _songs = allSongs;
        _recommendedSongs = recommended;
        _similarSongs = similar;
        _fansAlsoLiked = fansAlso;
        _discoverMix = discoverMix;
        _isLoading = false;
      });
      RecommendationEngine.instance.populatePlaylistsWithSongs(allSongs);
      setState(() {
        _playlists = RecommendationEngine.instance.getPlaylists();
      });
      _initAudio();
    } catch (e) {
      debugPrint('Error loading songs: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initAudio() async {
    _setupPlayerListeners();
  }

  void _setupPlayerListeners() {
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
            if (!_songCompleteGuard) {
              _songCompleteGuard = true;
              _onSongComplete();
            }
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
    _songCompleteGuard = false;
    _searchDebounce?.cancel();
    
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
    });
    
    final song = _songs[index];
    _fetchLyrics(song.id, song.title);
    _audioHandler.setMediaItem(
      id: song.id,
      title: song.title,
      artist: song.artist,
      album: song.album,
      artUri: song.imageUrl,
    );
    
    if (song.audioUrl.isNotEmpty) {
      bool played = false;
      for (final playUrl in JioSaavnApi.getPlayableUrls(song.audioUrl)) {
        try {
          debugPrint('Trying URL: $playUrl');
          await _audioPlayer.stop();
          await _audioPlayer.setUrl(playUrl);
          await _audioPlayer.play();
          played = true;
          break;
        } catch (e) {
          debugPrint('Failed URL $playUrl: $e');
        }
      }
      if (!played) {
        await _resetPlayer();
        if (mounted) {
          setState(() => _isBuffering = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Unable to play "${song.title}". Try another song.'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else {
      if (mounted) setState(() => _isBuffering = false);
    }
  }

  Future<void> _resetPlayer() async {
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      debugPrint('Dispose error: $e');
    }
    _audioPlayer = AudioPlayer();
    _audioHandler.attachPlayer(_audioPlayer);
    _setupPlayerListeners();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available for download')),
        );
      }
      return;
    }

    setState(() => _downloadingSongId = song.id);

    try {
      final downloadUrl = JioSaavnApi.getPlayableUrls(song.audioUrl).first;

      if (kIsWeb) {
        final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));
        if (response.statusCode != 200) throw Exception('Download failed');
        final fileName = '${song.artist.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')} - ${song.title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')}.mp3';
        downloadFile(response.bodyBytes, fileName);
        if (mounted) {
          setState(() {
            _downloadedSongIds.add(song.id);
            _downloadingSongId = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download started')),
          );
        }
        return;
      }

      final response = await http.get(Uri.parse(downloadUrl)).timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception('Download failed with status ${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final fileName = '${song.artist.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')} - ${song.title.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_')}.mp3';
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(response.bodyBytes);

      const channel = MethodChannel('com.srikeyan.music/downloads');
      await channel.invokeMethod<String>('saveToDownloads', {
        'filePath': tempFile.path,
        'fileName': fileName,
      });

      if (mounted) {
        setState(() {
          _downloadedSongIds.add(song.id);
          _downloadingSongId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to Downloads/Keyan Music: $fileName'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        setState(() => _downloadingSongId = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e')),
        );
      }
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

    int nextIndex;
    
    if (_shuffleEnabled && _shuffledIndices.isNotEmpty) {
      final currentPos = _shuffledIndices.indexOf(_currentIndex);
      if (currentPos >= 0 && currentPos < _shuffledIndices.length - 1) {
        nextIndex = _shuffledIndices[currentPos + 1];
      } else if (_repeatMode == RepeatMode.all) {
        nextIndex = _shuffledIndices.first;
      } else {
        return;
      }
    } else {
      final wasSkipped = _position.inSeconds < 30 && _duration.inSeconds > 30;
      final currentSong = _songs[_currentIndex];
      
      final smartNext = RecommendationEngine.instance.getSmartNextSong(
        _songs,
        currentSong,
        wasSkipped: wasSkipped,
      );
      
      nextIndex = _songs.indexOf(smartNext);
      if (nextIndex == -1 || nextIndex == _currentIndex) {
        nextIndex = _currentIndex + 1;
        if (nextIndex >= _songs.length) {
          if (_repeatMode == RepeatMode.all) {
            nextIndex = 0;
          } else {
            return;
          }
        }
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
    _searchDebounce?.cancel();
    setState(() => _isSearching = query.isNotEmpty);
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }
    if (_searchCache.containsKey(query)) {
      setState(() => _searchResults = _searchCache[query]!);
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted) return;
      try {
        final queries = <String>[query];
        if (!query.contains('songs')) {
          queries.add('$query songs');
        }
        if (_selectedLanguages.isNotEmpty) {
          for (var lang in _selectedLanguages.take(2)) {
            if (!query.toLowerCase().contains(lang.toLowerCase())) {
              queries.add('$query $lang songs');
            }
          }
        }
        if (_selectedGenres.isNotEmpty && !query.contains(RegExp(r'songs|music|hits|trending'))) {
          final randomGenre = _selectedGenres[DateTime.now().millisecond % _selectedGenres.length];
          queries.add('$randomGenre $query');
        }
        
        final results = await Future.wait(queries.map((q) => JioSaavnApi.search(q)));
        if (!mounted) return;
        
        final seen = <String>{};
        final allResults = <Song>[];
        for (var batch in results) {
          for (var song in batch) {
            if (seen.add(song.id) && song.audioUrl.isNotEmpty) {
              allResults.add(song);
            }
          }
        }
        
        _searchCache[query] = allResults;
        if (_searchCache.length > 50) {
          final oldestKey = _searchCache.keys.first;
          _searchCache.remove(oldestKey);
        }
        final scored = RecommendationEngine.instance.getRecommendedSongs(allResults, limit: allResults.length);
        if (_searchController.text == query) {
          setState(() => _searchResults = scored);
        }
      } catch (e) {
        if (mounted) setState(() => _searchResults = []);
      }
    });
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
        songs = await JioSaavnApi.search('tamil trending songs 2025');
        break;
      case 'Party':
        songs = await JioSaavnApi.search('tamil party songs');
        break;
      case 'Romance':
        songs = await JioSaavnApi.search('tamil romantic love songs');
        break;
      case 'Workout':
        songs = await JioSaavnApi.search('workout gym songs');
        break;
      case 'Chill':
        songs = await JioSaavnApi.search('chill lofi songs');
        break;
      case 'Melody':
        songs = await JioSaavnApi.search('tamil melody songs');
        break;
      case 'Classical':
        songs = await JioSaavnApi.search('carnatic classical music');
        break;
      case 'Indie':
        songs = await JioSaavnApi.search('tamil indie songs');
        break;
      case '90s':
        final r1 = await JioSaavnApi.search('tamil 90s songs');
        final r2 = await JioSaavnApi.search('tamil old songs 90s');
        final seen = <String>{};
        songs = [...r1, ...r2].where((s) => seen.add(s.id) && s.audioUrl.isNotEmpty).toList();
        break;
      case 'For You':
      default:
        final r1 = await JioSaavnApi.getHome(singer: _preferredSinger);
        final r2 = await JioSaavnApi.search('tamil hit songs');
        final seen = <String>{};
        songs = [...r1, ...r2].where((s) => seen.add(s.id) && s.audioUrl.isNotEmpty).toList();
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
      setState(() => _likeAnimating = true);
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) setState(() => _likeAnimating = false);
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
          content: Text(isLiked ? 'Removed from favorites' : 'Added to favorites'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_showFullPlayer) {
          setState(() => _showFullPlayer = false);
        } else if (_bottomNavIndex != 0) {
          setState(() => _bottomNavIndex = 0);
        } else {
          _minimizeApp();
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
          backgroundColor: background,
          body: _showFullPlayer 
              ? _buildFullPlayer() 
              : (_isTV ? _buildTVLayout() 
                : _isDesktop ? _buildDesktopLayout() 
                : _isTablet ? _buildTabletLayout() 
                : _buildMobileLayout()),
        ),
      ),
    );
  }

  Future<void> _minimizeApp() async {
    if (kIsWeb) return;
    try {
      const methodChannel = MethodChannel('com.srikeyan.music/minimize');
      await methodChannel.invokeMethod('moveToBack');
    } catch (e) {
      debugPrint('Minimize error: $e');
      if (!kIsWeb) await SystemNavigator.pop();
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) return;
    try {
      const methodChannel = MethodChannel('com.srikeyan.music/permissions');
      await methodChannel.invokeMethod('requestNotificationsPermission');
    } catch (e) {
      debugPrint('Notification permission request error: $e');
    }
  }

  Future<void> _requestStoragePermission() async {
    if (kIsWeb) return;
    try {
      const channel = MethodChannel('com.srikeyan.music/permissions');
      await channel.invokeMethod('requestStoragePermission');
    } catch (e) {
      debugPrint('Storage permission request error: $e');
    }
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
      } else if (event.logicalKey == LogicalKeyboardKey.escape) {
        if (_showFullPlayer) {
          setState(() => _showFullPlayer = false);
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyF) {
        if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
          _focusNode.requestFocus();
          return KeyEventResult.handled;
        }
      } else if (event.logicalKey == LogicalKeyboardKey.keyS) {
        if (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) {
          if (_currentIndex >= 0 && _currentIndex < _songs.length) {
            _downloadSong(_songs[_currentIndex]);
          }
          return KeyEventResult.handled;
        }
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _buildMobileLayout() {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _bottomNavIndex == 0
                ? Column(
                    children: [
                      _buildMobileHeader(),
                      _buildSearchBar(),
                      _buildPlaylistTabs(),
                      Expanded(child: _buildSongList()),
                    ],
                  )
                : _bottomNavIndex == 1
                    ? _buildSearchFullScreen()
                    : _bottomNavIndex == 2
                        ? _buildLibraryScreen()
                        : _buildSettingsScreen(),
          ),
          if (_songs.isNotEmpty && _bottomNavIndex == 0) _buildMiniPlayer(),
          _buildBottomNavBar(),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: _isDark
                ? Colors.white.withValues(alpha: 0.04)
                : Colors.white.withValues(alpha: 0.7),
            border: Border(top: BorderSide(color: textSecondary.withValues(alpha: 0.08), width: 0.5)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildNavItem(0, Icons.home_rounded, 'Home'),
                  _buildNavItem(1, Icons.search_rounded, 'Search'),
                  _buildNavItem(2, Icons.library_music_rounded, 'Library'),
                  _buildNavItem(3, Icons.settings_rounded, 'Settings'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _bottomNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _bottomNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? accent : textSecondary,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? accent : textSecondary,
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchFullScreen() {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(_responsivePadding),
          child: _buildSearchBar(),
        ),
        Expanded(child: _buildSongList()),
      ],
    );
  }

  Widget _buildLibraryScreen() {
    final profile = RecommendationEngine.instance.tasteProfile;
    final engine = RecommendationEngine.instance;
    final recentlyPlayed = engine.getRecentlyPlayedSongs(_songs);

    return SingleChildScrollView(
      padding: EdgeInsets.all(_responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Library',
                style: TextStyle(fontSize: 24 * _responsiveFontScale, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              IconButton(
                icon: Icon(Icons.add, color: accent),
                onPressed: () => _showCreatePlaylistDialog(null),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (profile.totalInteractions > 0) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildStatPill('${profile.totalInteractions}', 'Songs'),
                  _buildStatPill('${engine.totalListeningMinutes}m', 'Played'),
                  _buildStatPill('${engine.listeningStreak}', 'Day Streak'),
                  _buildStatPill('${_likedSongs.length}', 'Liked'),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
          if (recentlyPlayed.isNotEmpty) ...[
            _buildSectionHeader('Recently Played', trailing: '${recentlyPlayed.length} songs'),
            const SizedBox(height: 8),
            SizedBox(
              height: 110,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recentlyPlayed.length,
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final song = recentlyPlayed[index];
                  final songIdx = _songs.indexOf(song);
                  return GestureDetector(
                    onTap: () {
                      if (songIdx >= 0) {
                        setState(() => _currentIndex = songIdx);
                        _playSong(songIdx);
                      } else {
                        setState(() {
                          _songs.insert(0, song);
                          _currentIndex = 0;
                        });
                        _playSong(0);
                      }
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.15), blurRadius: 8, offset: const Offset(0, 4))],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: song.imageUrl.isNotEmpty
                                ? Image.network(song.imageUrl, fit: BoxFit.cover, cacheWidth: 144, errorBuilder: (_, __, ___) => Container(color: surface, child: Icon(Icons.music_note, color: textSecondary)))
                                : Container(color: surface, child: Icon(Icons.music_note, color: textSecondary)),
                          ),
                        ),
                        const SizedBox(height: 6),
                        SizedBox(
                          width: 72,
                          child: Text(song.title, style: TextStyle(color: textPrimary, fontSize: 10, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
          _buildSectionHeader('Playlists', trailing: '${_playlists.length}'),
          const SizedBox(height: 8),
          if (_playlists.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Icon(Icons.library_music, size: 40, color: textSecondary),
                  const SizedBox(height: 8),
                  Text('No playlists yet', style: TextStyle(color: textSecondary)),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () => _showCreatePlaylistDialog(null),
                    child: Text('Create one', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_playlists.length, (index) {
              final playlist = _playlists[index];
              return GestureDetector(
                onTap: () => _showPlaylistDetail(playlist),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: surfaceLight, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      Container(
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
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(playlist.name, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                            const SizedBox(height: 2),
                            Text(
                              playlist.description.isNotEmpty ? playlist.description : '${playlist.songIds.length} songs',
                              style: TextStyle(color: textSecondary, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: textSecondary),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 20),
          _buildSectionHeader('Liked Songs', trailing: '${_likedSongs.length} songs'),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () {
              final liked = _songs.where((s) => _likedSongs.contains(s.id)).toList();
              if (liked.isNotEmpty) {
                setState(() {
                  _songs = liked;
                  _currentIndex = 0;
                });
                _playSong(0);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accent, accent.withValues(alpha: 0.7)]),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.favorite, color: background, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${_likedSongs.length} liked songs', style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                        const SizedBox(height: 2),
                        Text('Tap to play all favorites', style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  Icon(Icons.play_circle_fill, color: accent, size: 28),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_songs.isNotEmpty) ...[
            _buildSectionHeader('All Songs', trailing: '${_songs.length} songs'),
            const SizedBox(height: 8),
            ...List.generate(_songs.length.clamp(0, 50), (index) {
              final song = _songs[index];
              return _buildSongCard(song, index == _currentIndex, index);
            }),
          ],
        ],
      ),
    );
  }

  void _showPlaylistDetail(MusicPlaylist playlist) {
    final playlistSongs = RecommendationEngine.instance.getSongsFromPlaylist(playlist, _songs);
    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: textSecondary.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: playlist.isAutoGenerated ? Colors.purple.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(playlist.isAutoGenerated ? Icons.auto_awesome : Icons.playlist_play, color: playlist.isAutoGenerated ? Colors.purple : accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(playlist.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
                        Text('${playlistSongs.length} songs', style: TextStyle(color: textSecondary, fontSize: 12)),
                      ],
                    ),
                  ),
                  if (playlistSongs.isNotEmpty)
                    IconButton(
                      icon: Icon(Icons.play_circle_fill, color: accent, size: 32),
                      onPressed: () {
                        setState(() {
                          _songs = playlistSongs;
                          _currentIndex = 0;
                        });
                        _playSong(0);
                        Navigator.pop(context);
                      },
                    ),
                ],
              ),
            ),
            Expanded(
              child: playlistSongs.isEmpty
                  ? Center(child: Text('No songs in this playlist', style: TextStyle(color: textSecondary)))
                  : ListView.builder(
                      controller: scrollController,
                      itemCount: playlistSongs.length,
                      itemBuilder: (context, index) {
                        final song = playlistSongs[index];
                        final globalIdx = _songs.indexOf(song);
                        return ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: song.imageUrl.isNotEmpty
                                ? Image.network(song.imageUrl, width: 44, height: 44, fit: BoxFit.cover, cacheWidth: 88, errorBuilder: (_, __, ___) => Icon(Icons.music_note, color: textSecondary))
                                : Icon(Icons.music_note, color: textSecondary),
                          ),
                          title: Text(song.title, style: TextStyle(color: textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text(song.artist, style: TextStyle(color: textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                          trailing: IconButton(
                            icon: Icon(Icons.close, color: textSecondary, size: 18),
                            onPressed: () async {
                              await RecommendationEngine.instance.removeSongFromPlaylist(playlist.id, song.id);
                              setState(() => _playlists = RecommendationEngine.instance.getPlaylists());
                              if (mounted) Navigator.pop(context);
                              _showPlaylistDetail(playlist);
                            },
                          ),
                          onTap: () {
                            if (globalIdx >= 0) {
                              setState(() => _currentIndex = globalIdx);
                              _playSong(globalIdx);
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

  Widget _buildSettingsScreen() {
    return Padding(
      padding: EdgeInsets.all(_responsivePadding),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(fontSize: 24 * _responsiveFontScale, fontWeight: FontWeight.bold, color: textPrimary),
            ),
            const SizedBox(height: 24),
            _buildSettingsTile(
              icon: Icons.palette,
              title: 'Theme',
              subtitle: 'Change app appearance',
              trailing: ValueListenableBuilder<ThemeMode>(
                valueListenable: AppTheme.controller,
                builder: (context, mode, _) => Icon(
                  mode == ThemeMode.dark ? Icons.dark_mode : mode == ThemeMode.light ? Icons.light_mode : Icons.brightness_auto,
                  color: accent,
                ),
              ),
              onTap: _cycleTheme,
            ),
            _buildSettingsTile(
              icon: Icons.auto_awesome,
              title: 'AI Recommendations',
              subtitle: 'Smart song suggestions based on your taste',
              trailing: Icon(
                RecommendationEngine.instance.tasteProfile.totalInteractions > 0 ? Icons.check_circle : Icons.info_outline,
                color: RecommendationEngine.instance.tasteProfile.totalInteractions > 0 ? Colors.green : textSecondary,
              ),
              onTap: () {},
            ),
            _buildSettingsTile(
              icon: Icons.info_outline,
              title: 'About',
              subtitle: 'Keyan Music Player v1.0',
              onTap: () => _showAboutDialog(context),
            ),
            const Spacer(),
            Center(
              child: Column(
                children: [
                  Icon(Icons.music_note, size: 40, color: textSecondary),
                  const SizedBox(height: 8),
                  Text('Sri Keyan Music', style: TextStyle(color: textSecondary, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text('Part of Sri Keyan Developments', style: TextStyle(color: textSecondary, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: surfaceLight,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textPrimary)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: TextStyle(color: textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
                if (trailing != null) trailing else Icon(Icons.chevron_right, color: textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: surfaceLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipOval(
              child: Image.asset(
                'assets/logo.png',
                width: 72,
                height: 72,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(height: 16),
            Text('Keyan Music', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
            const SizedBox(height: 4),
            Text('v1.0.0', style: TextStyle(fontSize: 14, color: textSecondary)),
            const SizedBox(height: 12),
            Text('AI-Powered Tamil Music Player', style: TextStyle(fontSize: 13, color: textSecondary)),
            const SizedBox(height: 16),
            Divider(color: textSecondary.withValues(alpha: 0.2)),
            const SizedBox(height: 8),
            Text('A product of', style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 4),
            Text('Sri Keyan Developments', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: accent)),
            const SizedBox(height: 16),
            Text('Developed by Karthikeyan S', style: TextStyle(fontSize: 12, color: textSecondary)),
            const SizedBox(height: 4),
            Text('github.com/KarthikeyanS2006', style: TextStyle(fontSize: 11, color: textSecondary)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: TextStyle(color: accent)),
          ),
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
            child: Icon(Icons.music_note, color: background, size: 24),
          ),
          const SizedBox(width: 12),
          Text(
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
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.controller,
            builder: (context, mode, _) => IconButton(
              icon: Icon(
                mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
              ),
              color: accent,
              onPressed: () => _cycleTheme(),
            ),
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
                  Icon(Icons.auto_awesome, color: accent, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    'AI',
                    style: TextStyle(
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

  void _cycleTheme() {
    final current = AppTheme.controller.value;
    final next = switch (current) {
      ThemeMode.light => ThemeMode.dark,
      ThemeMode.dark => ThemeMode.system,
      ThemeMode.system => ThemeMode.light,
    };
    AppTheme.controller.setMode(next);
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
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _search,
        style: TextStyle(color: Colors.white, fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Search',
          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 13),
          prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.2), size: 16),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close, color: Colors.white.withValues(alpha: 0.2), size: 14),
                  onPressed: () {
                    _searchController.clear();
                    _search('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
      {'name': 'Romance', 'icon': Icons.favorite_border},
      {'name': 'Workout', 'icon': Icons.fitness_center},
      {'name': 'Chill', 'icon': Icons.spa},
      {'name': 'Melody', 'icon': Icons.queue_music},
      {'name': 'Classical', 'icon': Icons.piano},
      {'name': 'Indie', 'icon': Icons.album},
      {'name': '90s', 'icon': Icons.history},
    ];
    
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
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
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    playlist['icon'] as IconData,
                    size: 13,
                    color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.3),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    playlist['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.black : Colors.white.withValues(alpha: 0.3),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 12,
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
      return Center(child: CircularProgressIndicator(color: accent));
    }
    
    if (displaySongs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 60, color: textSecondary),
            const SizedBox(height: 16),
            Text('No songs found', style: TextStyle(color: textSecondary, fontSize: 16)),
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
          _buildHeroSection(),
          const SizedBox(height: 24),
          
          if (_discoverMix.isNotEmpty) ...[
            _buildSectionHeader('Discover Mix', trailing: 'Updated Daily'),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_discoverMix.take(20).toList()),
            const SizedBox(height: 24),
          ],
          
          if (_fansAlsoLiked.isNotEmpty) ...[
            _buildSectionHeader('Fans Also Like', trailing: '${_fansAlsoLiked.length} songs'),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_fansAlsoLiked.take(20).toList()),
            const SizedBox(height: 24),
          ],
          
          if (_recommendedSongs.isNotEmpty) ...[
            _buildSectionHeader('Recommended for You', trailing: '${_recommendedSongs.length} songs'),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_recommendedSongs.take(20).toList()),
            const SizedBox(height: 24),
          ],
          
          if (_similarSongs.isNotEmpty && profile.totalInteractions > 3) ...[
            _buildSectionHeader('Because You Like ${profile.topArtist}'),
            const SizedBox(height: 8),
            _buildHorizontalSongList(_similarSongs.take(20).toList()),
            const SizedBox(height: 24),
          ],
          
          _buildSectionHeader('Playlists', trailing: '${_playlists.length}'),
          const SizedBox(height: 8),
          _buildHorizontalPlaylistGrid(_playlists),
          const SizedBox(height: 24),
          
          _buildSectionHeader('Your Taste Profile'),
          const SizedBox(height: 8),
          _buildTasteProfileCard(),
          const SizedBox(height: 24),
          
          _buildSectionHeader('All Songs', trailing: '${allSongs.length} songs'),
          const SizedBox(height: 8),
          ...allSongs.asMap().entries.map((entry) {
            final song = entry.value;
            final isSelected = entry.key == _currentIndex;
            return _buildSongCard(song, isSelected, entry.key);
          }),
          if (kIsWeb && _showDownloadBanner) ...[
            const SizedBox(height: 24),
            _buildDownloadBanner(),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDownloadBanner() {
    return AnimatedOpacity(
      opacity: _showDownloadBanner ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: accent.withValues(alpha: 0.2), width: 1),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  ClipOval(
                    child: Image.asset(
                      'assets/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Download Keyan Music',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Get the Android APK for the best experience',
                          style: TextStyle(fontSize: 13, color: textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://github.com/KarthikeyanS2006/sri-keyan-music-player/actions/workflows/android.yml');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download_rounded, size: 18),
                    label: const Text('Get APK'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: () => setState(() => _showDownloadBanner = false),
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: textSecondary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.close_rounded, size: 16, color: textSecondary),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroSection() {
    final heroSong = _songs.isNotEmpty ? _songs[_currentIndex.clamp(0, _songs.length - 1)] : null;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 220,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF111111),
              const Color(0xFF080808),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (heroSong != null && heroSong.imageUrl.isNotEmpty)
              Opacity(
                opacity: 0.3,
                child: Image.network(
                  heroSong.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox(),
                ),
              ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    const Color(0xFF080808).withValues(alpha: 0.8),
                    const Color(0xFF080808),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SRI KEYAN',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withValues(alpha: 0.3),
                      letterSpacing: 4,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your Daily Mix',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Curated just for you',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),
            if (heroSong != null)
              Positioned(
                right: 20,
                bottom: 20,
                child: GestureDetector(
                  onTap: () {
                    final idx = _songs.indexOf(heroSong);
                    if (idx >= 0) _playSong(idx);
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.black, size: 28),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, {String? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                trailing,
                style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.3), fontFamily: 'monospace'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatPill(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontFamily: 'monospace',
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 8,
            color: Colors.white.withValues(alpha: 0.3),
            letterSpacing: 1,
            fontFamily: 'monospace',
          ),
        ),
      ],
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

  Widget _buildHorizontalPlaylistGrid(List<MusicPlaylist> playlists) {
    if (playlists.isEmpty) return const SizedBox.shrink();
    final displayPlaylists = playlists.take(20).toList();
    return SizedBox(
      height: 180,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        itemCount: displayPlaylists.length,
        itemBuilder: (context, index) {
          final playlist = displayPlaylists[index];
          final icons = [Icons.playlist_play, Icons.auto_awesome, Icons.favorite, Icons.trending_up, Icons.music_note, Icons.library_music];
          final colors = [Colors.purple, Colors.blue, Colors.red, Colors.orange, Colors.teal, Colors.indigo];
          final colorIdx = index % colors.length;
          return GestureDetector(
            onTap: () => _showPlaylistDetail(playlist),
            child: Container(
              width: 140,
              margin: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 136,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors[colorIdx].withValues(alpha: 0.4),
                          colors[colorIdx].withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        playlist.isAutoGenerated ? Icons.auto_awesome : icons[colorIdx],
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    playlist.name,
                    style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    playlist.description,
                    style: TextStyle(fontSize: 9, color: Colors.white.withValues(alpha: 0.4)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHorizontalSongCard(Song song, int index) {
    return GestureDetector(
      onTap: () {
        final songIndex = _songs.indexOf(song);
        if (songIndex == -1) {
          setState(() {
            _songs.insert(0, song);
            _currentIndex = 0;
          });
        } else {
          setState(() => _currentIndex = songIndex);
        }
        _playSong(_currentIndex);
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 136,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.05),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (song.imageUrl.isNotEmpty)
                      Image.network(
                        song.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: 280,
                        color: Colors.white.withValues(alpha: 0.85),
                        colorBlendMode: BlendMode.saturation,
                        errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.15), size: 36)),
                      )
                    else
                      Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.15), size: 36)),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Icon(Icons.play_arrow_rounded, color: Colors.black, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.85)),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              style: TextStyle(fontSize: 10, color: Colors.white.withValues(alpha: 0.3)),
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
        color: surfaceLight,
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
                    Text('Top Artists', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
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
                                Flexible(child: Text(artist, style: TextStyle(color: accent, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 4),
                                Icon(Icons.arrow_forward, color: accent, size: 10),
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
          Text('Languages', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
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
            Text('Recent Searches', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary, fontSize: 12)),
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
                  child: Text(search, style: TextStyle(color: textSecondary, fontSize: 11)),
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: accent,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: textSecondary),
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
            !_isSearching) {
          _loadMoreSongs();
        }
        return false;
      },
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: displaySongs.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, idx) {
          if (idx >= displaySongs.length) {
            return Center(
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
      final queries = [
        'tamil latest songs',
        'hindi latest songs',
        'english latest songs',
        'tamil indie songs',
        'Malayalam songs',
        'Telugu songs',
        'Kannada songs',
        'tamil devotional songs',
        'workout songs',
        'chill songs',
        'Bollywood songs',
        'party songs',
      ];
      final query = queries[_page % queries.length];
      final results = await JioSaavnApi.search(query);
      if (results.isNotEmpty && mounted) {
        final existingIds = _songs.map((s) => s.id).toSet();
        final newSongs = results.where((s) => !existingIds.contains(s.id) && s.audioUrl.isNotEmpty).toList();
        setState(() {
          _songs = [..._songs, ...newSongs];
          _isLoadingMore = false;
        });
        RecommendationEngine.instance.populatePlaylistsWithSongs(_songs);
        setState(() {
          _playlists = RecommendationEngine.instance.getPlaylists();
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
    final artSize = _songCardArtSize;
    
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
        margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Center(
                child: isSelected && _isPlaying
                    ? _buildEqualizerBars()
                    : Text(
                        '${(index + 1).toString().padLeft(2, '0')}',
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: artSize,
              height: artSize,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (song.imageUrl.isNotEmpty)
                      Image.network(
                        song.imageUrl,
                        fit: BoxFit.cover,
                        cacheWidth: (artSize * 2).toInt(),
                        color: Colors.white.withValues(alpha: 0.85),
                        colorBlendMode: BlendMode.saturation,
                        errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.3), size: 20)),
                      )
                    else
                      Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.3), size: 20)),
                    if (isSelected)
                      Container(
                        color: Colors.black.withValues(alpha: 0.4),
                        child: Center(
                          child: _isPlaying
                              ? _buildEqualizerBars(large: true)
                              : Icon(Icons.pause, color: Colors.white, size: 18),
                        ),
                      ),
                  ],
                ),
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
                      color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Flexible(
              fit: FlexFit.loose,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.language.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        song.language.toUpperCase(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 8, letterSpacing: 0.5, fontFamily: 'monospace'),
                      ),
                    ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _toggleLike(song),
                    child: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.white : Colors.white.withValues(alpha: 0.2),
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0)),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 11, fontFamily: 'monospace'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEqualizerBars({bool large = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (i) {
        return AnimatedContainer(
          duration: Duration(milliseconds: 400 + i * 130),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 1),
          width: large ? 3 : 2,
          height: large ? 16.0 : 12.0,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(1),
          ),
        );
      }),
    );
  }

  Widget _buildMiniPlayer() {
    if (_songs.isEmpty) return const SizedBox.shrink();
    if (_currentIndex < 0 || _currentIndex >= _songs.length) return const SizedBox.shrink();
    final song = _songs[_currentIndex];
    final isLiked = _likedSongs.contains(song.id);
    final artSize = _miniPlayerArtSize;
    final progress = _duration.inSeconds > 0 
        ? (_position.inSeconds / _duration.inSeconds).clamp(0.0, 1.0)
        : 0.0;
    
    return GestureDetector(
      onTap: () => setState(() => _showFullPlayer = true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: _isDark ? 0.3 : 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: artSize,
                    height: artSize,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: song.imageUrl.isNotEmpty
                          ? Image.network(song.imageUrl, fit: BoxFit.cover, cacheWidth: 128, 
                              color: Colors.white.withValues(alpha: 0.85),
                              colorBlendMode: BlendMode.saturation,
                              errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.3), size: 24)))
                          : Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.3), size: 24)),
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
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          song.artist,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _toggleLike(song),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(
                        isLiked ? Icons.favorite : Icons.favorite_border,
                        size: 16,
                        color: isLiked ? Colors.white : Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Center(
                        child: Icon(
                          _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: _playNext,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Icon(Icons.skip_next_rounded, size: 18, color: Colors.white.withValues(alpha: 0.5)),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 2,
              ),
            ),
          ],
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout() {
    return SafeArea(
      child: Row(
        children: [
          NavigationRail(
            selectedIndex: _bottomNavIndex,
            onDestinationSelected: (index) => setState(() => _bottomNavIndex = index),
            backgroundColor: surface,
            selectedIconTheme: IconThemeData(color: background, size: 24),
            unselectedIconTheme: IconThemeData(color: textSecondary, size: 22),
            selectedLabelTextStyle: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w600),
            unselectedLabelTextStyle: TextStyle(color: textSecondary, fontSize: 10),
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.music_note, color: background, size: 22),
              ),
            ),
            indicatorColor: accent.withValues(alpha: 0.15),
            trailing: Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: ValueListenableBuilder<ThemeMode>(
                    valueListenable: AppTheme.controller,
                    builder: (context, mode, _) => IconButton(
                      icon: Icon(
                        mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                        color: accent,
                        size: 22,
                      ),
                      onPressed: _cycleTheme,
                    ),
                  ),
                ),
              ),
            ),
            destinations: const [
              NavigationRailDestination(icon: Icon(Icons.home_rounded), label: Text('Home')),
              NavigationRailDestination(icon: Icon(Icons.search_rounded), label: Text('Search')),
              NavigationRailDestination(icon: Icon(Icons.library_music_rounded), label: Text('Library')),
              NavigationRailDestination(icon: Icon(Icons.settings_rounded), label: Text('Settings')),
            ],
          ),
          Container(width: 0.5, color: textSecondary.withValues(alpha: 0.1)),
          Expanded(
            child: Column(
              children: [
                if (_bottomNavIndex == 0) ...[
                  _buildTabletHeader(),
                  _buildPlaylistTabs(),
                ],
                Expanded(
                  child: _bottomNavIndex == 0
                      ? _buildSongList()
                      : _bottomNavIndex == 1
                          ? Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.all(_responsivePadding),
                                  child: _buildSearchBar(),
                                ),
                                Expanded(child: _buildSongList()),
                              ],
                            )
                          : _bottomNavIndex == 2
                              ? _buildTabletLibraryContent()
                              : _buildTabletSettingsContent(),
                ),
                if (_songs.isNotEmpty && _bottomNavIndex == 0) _buildMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletHeader() {
    return Padding(
      padding: EdgeInsets.fromLTRB(_responsivePadding, 12, _responsivePadding, 8),
      child: Row(
        children: [
          Text(
            'Sri Keyan',
            style: TextStyle(
              fontSize: 22 * _responsiveFontScale,
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
                  Icon(Icons.auto_awesome, color: accent, size: 14),
                  const SizedBox(width: 4),
                  Text('AI', style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTabletLibraryContent() {
    return Padding(
      padding: EdgeInsets.all(_responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Your Library', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
              IconButton(icon: Icon(Icons.add, color: accent), onPressed: () => _showCreatePlaylistDialog(null)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _playlists.isEmpty
                ? Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_music, size: 50, color: textSecondary),
                      const SizedBox(height: 12),
                      Text('No playlists yet', style: TextStyle(color: textSecondary)),
                    ],
                  ))
                : ListView.builder(
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: playlist.isAutoGenerated ? Colors.purple.withValues(alpha: 0.1) : accent.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            playlist.isAutoGenerated ? Icons.auto_awesome : Icons.playlist_play,
                            color: playlist.isAutoGenerated ? Colors.purple : accent,
                          ),
                        ),
                        title: Text(playlist.name, style: TextStyle(color: textPrimary)),
                        subtitle: Text(
                          playlist.description.isNotEmpty ? playlist.description : '${playlist.songIds.length} songs',
                          style: TextStyle(color: textSecondary, fontSize: 12),
                        ),
                        trailing: Icon(Icons.chevron_right, color: textSecondary),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletSettingsContent() {
    return Padding(
      padding: EdgeInsets.all(_responsivePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textPrimary)),
          const SizedBox(height: 24),
          _buildSettingsTile(
            icon: Icons.palette,
            title: 'Theme',
            subtitle: 'Change app appearance',
            trailing: ValueListenableBuilder<ThemeMode>(
              valueListenable: AppTheme.controller,
              builder: (context, mode, _) => Icon(
                mode == ThemeMode.dark ? Icons.dark_mode : mode == ThemeMode.light ? Icons.light_mode : Icons.brightness_auto,
                color: accent,
              ),
            ),
            onTap: _cycleTheme,
          ),
          _buildSettingsTile(
            icon: Icons.auto_awesome,
            title: 'AI Recommendations',
            subtitle: 'Smart suggestions based on your taste',
            onTap: () {},
          ),
          _buildSettingsTile(
            icon: Icons.info_outline,
            title: 'About',
            subtitle: 'Keyan Music Player v1.0',
            onTap: () => _showAboutDialog(context),
          ),
        ],
      ),
    );
  }

  Widget _buildTVLayout() {
    return SafeArea(
      child: Row(
        children: [
          Container(
            width: 80,
            color: surface,
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.music_note, color: background, size: 28),
                ),
                const SizedBox(height: 24),
                _buildTVNavItem(0, Icons.home_rounded, 'Home'),
                _buildTVNavItem(1, Icons.search_rounded, 'Search'),
                _buildTVNavItem(2, Icons.library_music_rounded, 'Library'),
                _buildTVNavItem(3, Icons.settings_rounded, 'Settings'),
                const Spacer(),
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: AppTheme.controller,
                  builder: (context, mode, _) => _buildTVNavItem(
                    -1,
                    mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                    'Theme',
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
          Container(width: 0.5, color: textSecondary.withValues(alpha: 0.1)),
          Expanded(
            child: Column(
              children: [
                if (_bottomNavIndex == 0) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                    child: Row(
                      children: [
                        Text('Sri Keyan', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                        const Spacer(),
                        if (RecommendationEngine.instance.tasteProfile.totalInteractions > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.auto_awesome, color: accent, size: 16),
                                const SizedBox(width: 6),
                                Text('AI Powered', style: TextStyle(color: accent, fontSize: 14, fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                  _buildPlaylistTabs(),
                ],
                Expanded(
                  child: _bottomNavIndex == 0
                      ? _buildSongList()
                      : _bottomNavIndex == 1
                          ? Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  SizedBox(
                                    width: 600,
                                    child: _buildSearchBar(),
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(child: _buildSongList()),
                                ],
                              ),
                            )
                          : _bottomNavIndex == 2
                              ? _buildTabletLibraryContent()
                              : _buildTabletSettingsContent(),
                ),
                if (_songs.isNotEmpty && _bottomNavIndex == 0) _buildMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTVNavItem(int index, IconData icon, String label) {
    final isSelected = _bottomNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        color: isSelected ? accent.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            if (index >= 0) setState(() => _bottomNavIndex = index);
            if (index == -1) _cycleTheme();
          },
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: isSelected ? accent : textSecondary, size: 28),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? accent : textSecondary,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    final sidebarWidth = _sidebarExpanded ? 280.0 : 64.0;
    return SafeArea(
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: sidebarWidth,
            color: const Color(0xFF0A0A0A),
            child: Column(
              children: [
                _buildSidebarHeader(),
                if (_sidebarExpanded) ...[
                  _buildSearchBar(),
                  const SizedBox(height: 16),
                ],
                Expanded(
                  child: _sidebarExpanded
                      ? _buildSongList()
                      : Column(
                          children: [
                            const SizedBox(height: 8),
                            _buildSidebarNavItem(0, Icons.home_rounded),
                            _buildSidebarNavItem(1, Icons.search_rounded),
                            _buildSidebarNavItem(2, Icons.library_music_rounded),
                            const Spacer(),
                          ],
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (_sidebarExpanded) ...[
                  _buildDesktopTopBar(),
                ],
                Expanded(child: _buildDesktopNowPlaying()),
                if (_songs.isNotEmpty && _bottomNavIndex == 0) _buildMiniPlayer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarNavItem(int index, IconData icon) {
    final isSelected = _bottomNavIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: GestureDetector(
        onTap: () => setState(() => _bottomNavIndex = index),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isSelected ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.3),
              size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        children: [
          Text(
            'SRI KEYAN',
            style: TextStyle(
              fontSize: 9,
              color: Colors.white.withValues(alpha: 0.3),
              letterSpacing: 4,
              fontFamily: 'monospace',
            ),
          ),
          const Spacer(),
          if (RecommendationEngine.instance.tasteProfile.totalInteractions > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.auto_awesome, color: Colors.white.withValues(alpha: 0.5), size: 10),
                  const SizedBox(width: 4),
                  Text('AI', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 9, fontFamily: 'monospace')),
                ],
              ),
            ),
          const SizedBox(width: 12),
          ValueListenableBuilder<ThemeMode>(
            valueListenable: AppTheme.controller,
            builder: (context, mode, _) => GestureDetector(
              onTap: _cycleTheme,
              child: Icon(
                mode == ThemeMode.dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                color: Colors.white.withValues(alpha: 0.3),
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: _sidebarExpanded
          ? Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _sidebarExpanded = false),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.music_note, color: Colors.black, size: 18),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'SRI KEYAN',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                    fontFamily: 'monospace',
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => setState(() => _sidebarExpanded = false),
                  child: Icon(
                    Icons.chevron_left,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ),
              ],
            )
          : GestureDetector(
              onTap: () => setState(() => _sidebarExpanded = true),
              child: Center(
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.black, size: 18),
                ),
              ),
            ),
    );
  }

  Widget _buildDesktopNowPlaying() {
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_note, size: 80, color: Colors.white.withValues(alpha: 0.1)),
            const SizedBox(height: 20),
            Text('Select a song to play', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 14)),
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
          _buildDesktopAlbumArt(song),
          const SizedBox(height: 24),
          Text(
            song.title,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showArtistPage(song.artist),
            child: Text(
              song.artist,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4)),
            ),
          ),
          const SizedBox(height: 20),
          _buildActionButtons(song, isLiked),
          const SizedBox(height: 24),
          _buildDesktopProgressSection(),
          const SizedBox(height: 8),
          _buildControlsSection(),
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 100),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              labelColor: Colors.black,
              unselectedLabelColor: Colors.white.withValues(alpha: 0.3),
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
            ),
          ),
          SizedBox(height: 280, child: TabBarView(controller: _tabController, children: [_buildLyricsTab(), _buildSongDetailsTab(song)])),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Song song, bool isLiked) {
    final isDownloading = _downloadingSongId == song.id;
    final isDownloaded = _downloadedSongIds.contains(song.id);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _toggleLike(song),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isLiked ? Colors.white : Colors.white.withValues(alpha: 0.2),
                width: 2.5,
              ),
              color: isLiked ? Colors.white.withValues(alpha: 0.1) : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedScale(
                  scale: _likeAnimating ? 1.6 : 1.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.elasticOut,
                  child: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  isLiked ? 'Liked' : 'Like',
                  style: TextStyle(
                    color: isLiked ? Colors.white : Colors.white.withValues(alpha: 0.3),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_likeAnimating) ...[
                  const SizedBox(width: 8),
                  ...List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0.0, end: 1.0),
                      duration: Duration(milliseconds: 600 + i * 100),
                      builder: (context, value, child) {
                        return Transform.translate(
                          offset: Offset(0, -20 * value),
                          child: Opacity(
                            opacity: (1.0 - value).clamp(0.0, 1.0),
                            child: Icon(
                              Icons.favorite,
                              color: Colors.white,
                              size: 10.0 - i * 2,
                            ),
                          ),
                        );
                      },
                    ),
                  )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: isDownloading ? null : () => _downloadSong(song),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDownloaded
                    ? Colors.white
                    : isDownloading
                        ? Colors.white.withValues(alpha: 0.5)
                        : Colors.white.withValues(alpha: 0.2),
                width: 2.5,
              ),
              color: isDownloaded
                  ? Colors.white.withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: isDownloading
                      ? const SizedBox(
                          key: ValueKey('progress'),
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : isDownloaded
                          ? const Icon(
                              Icons.check_circle,
                              key: ValueKey('done'),
                              color: Colors.white,
                              size: 20,
                            )
                          : Icon(
                              Icons.download_outlined,
                              key: ValueKey('download'),
                              color: Colors.white.withValues(alpha: 0.3),
                              size: 20,
                            ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    isDownloading
                        ? 'Downloading...'
                        : isDownloaded
                            ? 'Downloaded'
                            : 'Download',
                    key: ValueKey(isDownloading ? 'dl' : isDownloaded ? 'done' : 'idle'),
                    style: TextStyle(
                      color: isDownloaded
                          ? Colors.white
                          : isDownloading
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTapDown: (_) => setState(() => _shareAnimating = true),
          onTapUp: (_) {
            setState(() => _shareAnimating = false);
            _shareSong(song);
          },
          onTapCancel: () => setState(() => _shareAnimating = false),
          child: AnimatedScale(
            scale: _shareAnimating ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 2.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.share_outlined,
                    color: Colors.white.withValues(alpha: 0.3),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Share',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopAlbumArt(Song song) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, cacheWidth: 560,
                color: Colors.white.withValues(alpha: 0.85),
                colorBlendMode: BlendMode.saturation,
                errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.1), size: 80)))
            : Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.1), size: 80)),
      ),
    );
  }

  Widget _buildDesktopProgressSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
              activeTrackColor: Colors.white,
              inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
              thumbColor: Colors.white,
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            ),
            child: Slider(
              value: _duration.inSeconds > 0 ? _position.inSeconds.toDouble().clamp(0, _duration.inSeconds.toDouble()) : 0,
              min: 0,
              max: _duration.inSeconds > 0 ? _duration.inSeconds.toDouble() : 1,
              onChanged: _duration.inSeconds > 0 ? (value) => _audioPlayer.seek(Duration(seconds: value.toInt())) : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_formatDuration(_position), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontFamily: 'monospace')),
                Text(_formatDuration(_duration), style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 10, fontFamily: 'monospace')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    IconData repeatIcon;
    Color repeatColor = Colors.white.withValues(alpha: 0.3);
    
    switch (_repeatMode) {
      case RepeatMode.off:
        repeatIcon = Icons.repeat;
        repeatColor = Colors.white.withValues(alpha: 0.3);
        break;
      case RepeatMode.one:
        repeatIcon = Icons.repeat_one;
        repeatColor = Colors.white;
        break;
      case RepeatMode.all:
        repeatIcon = Icons.repeat;
        repeatColor = Colors.white;
        break;
    }

    final playPauseSize = _isTV ? 80.0 : _isDesktop ? 64.0 : 56.0;
    final iconSize = _isTV ? 52.0 : _isDesktop ? 40.0 : 36.0;
    final smallIconSize = _isTV ? 36.0 : _isDesktop ? 28.0 : 24.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _shuffleEnabled = !_shuffleEnabled;
              if (_shuffleEnabled) {
                final smartOrder = <int>[];
                final remaining = List<int>.generate(_songs.length, (i) => i)
                  ..removeWhere((i) => i == _currentIndex);
                final scores = remaining.map((i) => MapEntry(i, RecommendationEngine.instance.calculateSongScore(_songs[i], useSessionWeight: true))).toList()
                  ..sort((a, b) => b.value.compareTo(a.value));
                for (var entry in scores) {
                  smartOrder.add(entry.key);
                }
                _shuffledIndices = [_currentIndex, ...smartOrder];
              }
            });
          },
          child: Icon(
            Icons.shuffle,
            size: smallIconSize,
            color: _shuffleEnabled ? Colors.white : Colors.white.withValues(alpha: 0.3),
          ),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: _playPrevious,
          child: Icon(Icons.skip_previous_rounded, size: iconSize, color: Colors.white),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            width: playPauseSize,
            height: playPauseSize,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: _isBuffering
                ? Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black)))
                : Center(
                    child: Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      size: iconSize - 8,
                      color: Colors.black,
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: _playNext,
          child: Icon(Icons.skip_next_rounded, size: iconSize, color: Colors.white),
        ),
        const SizedBox(width: 28),
        GestureDetector(
          onTap: _cycleRepeatMode,
          child: Icon(repeatIcon, size: smallIconSize, color: repeatColor),
        ),
      ],
    );
  }

  Widget _buildLyricsTab() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
      child: _currentLyrics.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lyrics_outlined, size: 40, color: Colors.white.withValues(alpha: 0.1)),
                  const SizedBox(height: 12),
                  Text('No lyrics available', style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 12)),
                ],
              ),
            )
          : SingleChildScrollView(
              controller: _lyricsScrollController,
              child: Text(
                _currentLyrics,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.7),
                  height: 2.0,
                  letterSpacing: 0.3,
                ),
              ),
            ),
    );
  }

  Widget _buildSongDetailsTab(Song song) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.03), borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Title', song.title),
            _buildDetailRow('Artist', song.artist),
            if (song.album.isNotEmpty) _buildDetailRow('Album', song.album),
            if (song.year.isNotEmpty) _buildDetailRow('Year', song.year),
            if (song.duration.isNotEmpty) _buildDetailRow('Duration', _formatDuration(Duration(seconds: int.tryParse(song.duration) ?? 0))),
            if (song.isMovieSong) _buildDetailRow('Movie', song.movieName),
            _buildDetailRow('Language', song.language.toUpperCase()),
            _buildDetailRow('Mood', '${song.moodEmoji} ${song.mood.name}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label.toUpperCase(),
              style: TextStyle(color: Colors.white.withValues(alpha: 0.2), fontSize: 9, letterSpacing: 1, fontFamily: 'monospace'),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13),
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
    
    final albumSize = _albumArtSize;
    final isCompact = _isSmallScreen && _isLandscape;
    
    return Scaffold(
      backgroundColor: background,
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity != null && details.primaryVelocity! > 300) {
            setState(() => _showFullPlayer = false);
          }
        },
        child: SafeArea(
          child: isCompact ? _buildCompactFullPlayer(song, isLiked, albumSize) : _buildStandardFullPlayer(song, isLiked, albumSize),
        ),
      ),
    );
  }

  Widget _buildCompactFullPlayer(Song song, bool isLiked, double albumSize) {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Stack(
                  children: [
                    _buildFullPlayerAlbumArt(song, albumSize * 0.8),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: IconButton(
                        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 28),
                        color: isLiked ? Colors.red : textSecondary,
                        onPressed: () => _toggleLike(song),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildFullPlayerSongInfo(song),
              const SizedBox(height: 12),
              _buildDesktopProgressSection(),
              const SizedBox(height: 12),
              _buildControlsSection(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStandardFullPlayer(Song song, bool isLiked, double albumSize) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: _responsivePadding, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.keyboard_arrow_down, size: 32),
                color: Colors.white,
                onPressed: () => setState(() => _showFullPlayer = false),
              ),
              Text(
                'NOW PLAYING',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.3), fontSize: 9, letterSpacing: 4, fontFamily: 'monospace'),
              ),
              GestureDetector(
                onTap: () => _shareSong(song),
                child: Icon(Icons.share_outlined, color: Colors.white.withValues(alpha: 0.3), size: 20),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 8),
                _buildFullPlayerAlbumArt(song, albumSize),
                _buildFullPlayerSongInfo(song),
                _buildDesktopProgressSection(),
                const SizedBox(height: 8),
                _buildControlsSection(),
                const SizedBox(height: 20),
                _buildActionButtons(song, isLiked),
                const SizedBox(height: 20),
                Container(
                  margin: EdgeInsets.symmetric(horizontal: _responsivePadding),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.white.withValues(alpha: 0.3),
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
                    tabs: const [Tab(text: 'Lyrics'), Tab(text: 'Details')],
                  ),
                ),
                SizedBox(
                  height: _isTV ? 350 : _isDesktop ? 300 : 250,
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildLyricsTab(), _buildSongDetailsTab(song)],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFullPlayerAlbumArt(Song song, [double? size]) {
    final artSize = size ?? _albumArtSize;
    return Container(
      width: artSize,
      height: artSize,
      margin: const EdgeInsets.symmetric(horizontal: 40),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: song.imageUrl.isNotEmpty
            ? Image.network(song.imageUrl, fit: BoxFit.cover, cacheWidth: 560, errorBuilder: (_, __, ___) => Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.2), size: 80)))
            : Center(child: Icon(Icons.music_note, color: Colors.white.withValues(alpha: 0.2), size: 80)),
      ),
    );
  }

  Widget _buildFullPlayerSongInfo(Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 24, 40, 0),
      child: Column(
        children: [
          Text(
            song.title,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => _showArtistPage(song.artist),
            child: Text(
              song.artist,
              style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.4), fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }
}

class JioSaavnApi {
  static const String _apiUrl = 'https://saavnapi-nine.vercel.app';
  static const String _selfHostedUrl = 'https://sri-keyan-music-api.onrender.com';
  static bool _useSelfHosted = false;

  static List<String> getPlayableUrls(String audioUrl) {
    if (audioUrl.isEmpty) return [audioUrl];
    return [
      audioUrl,
      'https://corsproxy.io/?${Uri.encodeComponent(audioUrl)}',
      'https://api.allorigins.win/raw?url=${Uri.encodeComponent(audioUrl)}',
    ];
  }

  static Future<List<Song>> _fetchSongs(String endpoint, {String? singer}) async {
    final List<String> apiUrls = _useSelfHosted
        ? [_selfHostedUrl, _apiUrl]
        : [_apiUrl, _selfHostedUrl];

    for (var baseUrl in apiUrls) {
      try {
        final uri = Uri.parse('$baseUrl/$endpoint');
        final response = await http.get(uri, headers: {'Accept': 'application/json'}).timeout(
          const Duration(seconds: 10),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          List<dynamic> songsJson = [];
          if (data is List) {
            songsJson = data;
          } else if (data is Map) {
            if (data.containsKey('results')) songsJson = data['results'] as List? ?? [];
            else if (data.containsKey('songs')) songsJson = data['songs'] as List? ?? [];
          }
          if (songsJson.isNotEmpty) {
            _useSelfHosted = baseUrl == _selfHostedUrl;
            return songsJson.map((json) => Song.fromJson(json)).toList();
          }
        }
      } catch (e) {
        debugPrint('API $baseUrl failed: $e');
        continue;
      }
    }
    return [];
  }

  static Future<List<Song>> getHome({String? singer}) async {
    final query = singer ?? 'tamil songs';
    return _fetchSongs('result/?query=$query', singer: singer);
  }

  static Future<List<Song>> search(String query) async {
    return _fetchSongs('result/?query=${Uri.encodeComponent(query)}');
  }

  static Future<String> getLyrics(String songId) async {
    final List<String> apiUrls = _useSelfHosted
        ? [_selfHostedUrl, _apiUrl]
        : [_apiUrl, _selfHostedUrl];

    for (var baseUrl in apiUrls) {
      try {
        final response = await http.get(
          Uri.parse('$baseUrl/lyrics/?id=$songId'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['lyrics'] ?? '';
        }
      } catch (e) {
        continue;
      }
    }
    return '';
  }
}
