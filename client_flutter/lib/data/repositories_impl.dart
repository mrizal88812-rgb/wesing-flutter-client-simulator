import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/config/app_config.dart';
import 'models/song.dart';
import 'models/recording.dart';
import 'models/user.dart';

class ApiRepository {
  String get baseUrl => AppConfig.apiUrl;

  Future<List<Song>> fetchSongs() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/songs')).timeout(const Duration(seconds: 5));
      final body = response.body.trim();
      if (response.statusCode == 200 && (body.startsWith('[') || body.startsWith('{'))) {
        final List<dynamic> data = json.decode(body);
        return data.map((e) => Song.fromJson(e)).toList();
      } else {
        print('Warning: Received non-JSON response from $baseUrl/songs: status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching songs from $baseUrl/songs: $e');
    }
    return _getFallbackSongs();
  }

  Future<List<Recording>> fetchFeed() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/feed')).timeout(const Duration(seconds: 5));
      final body = response.body.trim();
      if (response.statusCode == 200 && (body.startsWith('[') || body.startsWith('{'))) {
        final List<dynamic> data = json.decode(body);
        return data.map((e) => Recording.fromJson(e)).toList();
      } else {
        print('Warning: Received non-JSON response from $baseUrl/feed: status ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching feed from $baseUrl/feed: $e');
    }
    return _getFallbackFeed();
  }

  Future<String?> uploadAudioFile(String audioSource) async {
    try {
      Uint8List? bytes;
      String filename = 'recording_${DateTime.now().millisecondsSinceEpoch}.wav';

      if (audioSource.startsWith('blob:') || audioSource.startsWith('http://') || audioSource.startsWith('https://')) {
        final res = await http.get(Uri.parse(audioSource)).timeout(const Duration(seconds: 15));
        if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
          bytes = res.bodyBytes;
        }
      } else if (audioSource.startsWith('data:')) {
        final commaIdx = audioSource.indexOf(',');
        if (commaIdx != -1) {
          bytes = base64Decode(audioSource.substring(commaIdx + 1));
        }
      } else if (!kIsWeb) {
        String cleanPath = audioSource;
        if (cleanPath.startsWith('file://')) {
          cleanPath = Uri.parse(cleanPath).toFilePath();
        }
        final file = File(cleanPath);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        } else {
          print('[ApiRepository] File does not exist at path: $cleanPath');
        }
      }

      if (bytes == null || bytes.isEmpty) {
        print('[ApiRepository] Could not fetch bytes for audioSource: $audioSource');
        return null;
      }

      final uri = Uri.parse('$baseUrl/upload');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonRes = json.decode(response.body);
        if (jsonRes != null && jsonRes['url'] != null) {
          print('[ApiRepository] Audio file uploaded successfully: ${jsonRes['url']}');
          return jsonRes['url'].toString();
        }
      } else {
        print('[ApiRepository] Upload returned status ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      print('[ApiRepository] Failed to upload audio file: $e');
    }
    return null;
  }

  Future<bool> saveRecording(
    String songId, 
    String audioUrl, 
    int score, {
    String? caption,
    String? coverUrl,
    String? visibility,
    double songStart = 0.0,
    double songEnd = 0.0,
    double duration = 0.0,
  }) async {
    try {
      String finalAudioUrl = audioUrl;

      // Upload temporary blob or raw local device path to permanent server storage
      if (audioUrl.startsWith('blob:') || 
          audioUrl.startsWith('data:') || 
          audioUrl.startsWith('file://') || 
          audioUrl.startsWith('/data/') || 
          audioUrl.startsWith('/var/') || 
          audioUrl.startsWith('/Users/') ||
          audioUrl.startsWith('/sdcard/') ||
          audioUrl.startsWith('/storage/emulated/') ||
          (!audioUrl.startsWith('/storage/') && !audioUrl.startsWith('http://') && !audioUrl.startsWith('https://'))) {
        final uploaded = await uploadAudioFile(audioUrl);
        if (uploaded != null && uploaded.isNotEmpty) {
          finalAudioUrl = uploaded;
        }
      }

      final response = await http.post(
        Uri.parse('$baseUrl/recordings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'songId': songId,
          'audioUrl': finalAudioUrl,
          'score': score,
          'caption': caption ?? '',
          'coverUrl': coverUrl,
          'visibility': visibility ?? 'Public',
          'songStart': songStart,
          'songEnd': songEnd,
          'duration': duration,
        }),
      ).timeout(const Duration(seconds: 15));
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Error saving recording in repository: $e');
      return false;
    }
  }

  List<Song> _getFallbackSongs() {
    return [
      Song(
        id: "song-001",
        title: "Shape of You",
        artist: "Ed Sheeran",
        coverUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        playCount: 12500,
        tags: ["Pop", "Acoustic"],
        lyrics: [
          LyricLine(time: 0, text: "The club isn't the best place to find a lover"),
          LyricLine(time: 4, text: "So the bar is where I go"),
          LyricLine(time: 8, text: "Me and my friends at the table doing shots"),
          LyricLine(time: 12, text: "Drinking fast and then we talk slow"),
        ],
      ),
      Song(
        id: "song-002",
        title: "Sunset Serenade",
        artist: "Acoustic Vibes",
        coverUrl: "https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=400&h=400&fit=crop",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-2.mp3",
        playCount: 8400,
        tags: ["Pop", "Live"],
        lyrics: [
          LyricLine(time: 0, text: "Walking down the sunny shore"),
          LyricLine(time: 4, text: "Listening to the ocean wave"),
          LyricLine(time: 8, text: "Song of hope and melody"),
        ],
      ),
      Song(
        id: "song-003",
        title: "Picking up the Pieces",
        artist: "The Sunset Glow",
        coverUrl: "https://images.unsplash.com/photo-1493225457124-a3eb161ffa5f?w=400&h=400&fit=crop",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-3.mp3",
        playCount: 18400,
        tags: ["Acoustic", "Vocal"],
        lyrics: [
          LyricLine(time: 0, text: "Picking up the pieces"),
          LyricLine(time: 4, text: "Walking back into the light"),
          LyricLine(time: 8, text: "Into the sunset of your glory"),
          LyricLine(time: 12, text: "Where my heart and future lies"),
        ],
      ),
    ];
  }

  List<Recording> _getFallbackFeed() {
    final fallbackSong = _getFallbackSongs()[0];
    return [
      Recording(
        id: "feed_1",
        userId: "user_1",
        songId: "song-001",
        audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
        score: 92,
        createdAt: DateTime.now().toIso8601String(),
        likesCount: 245,
        commentsCount: 12,
        user: User(
          id: "user_1",
          username: "Nafisa",
          avatar: "https://i.pravatar.cc/150?u=nafisa",
          followersCount: 120,
          level: 5,
          coins: 1000,
        ),
        song: fallbackSong,
      ),
    ];
  }
  Future<List<dynamic>> fetchPresets() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/presets')).timeout(const Duration(seconds: 5));
      final body = response.body.trim();
      if (response.statusCode == 200 && (body.startsWith('[') || body.startsWith('{'))) {
        final Map<String, dynamic> data = json.decode(body);
        if (data['presets'] != null) {
          return data['presets'] as List<dynamic>;
        }
      }
    } catch (e) {
      print('Error fetching live presets, falling back to local: $e');
    }

    // Fallback list of 10 complete presets matching requirements
    return [
      {
        "id": "studio",
        "name": "Studio",
        "icon": "headphones",
        "description": "Professional studio vocal",
        "dsp": {
          "reverb": 0.20,
          "delay": 0.05,
          "echo": 0.00,
          "vocalGain": 1.15,
          "compressor": 0.35,
          "limiter": 0.15,
          "noiseReduction": 0.10,
          "eqLow": 0.05,
          "eqMid": 0.10,
          "eqHigh": 0.08,
          "stereoWidth": 0.20,
          "presence": 0.15,
          "brightness": 0.10
        }
      },
      {
        "id": "warm",
        "name": "Warm",
        "icon": "warm",
        "description": "Warm vocal tone",
        "dsp": {
          "reverb": 0.15,
          "delay": 0.0,
          "vocalGain": 1.1,
          "compressor": 0.3,
          "eqLow": 0.2,
          "eqMid": 0.1,
          "eqHigh": -0.05
        }
      },
      {
        "id": "bright",
        "name": "Bright",
        "icon": "bright",
        "description": "Crisp highs and presence",
        "dsp": {
          "reverb": 0.18,
          "delay": 0.02,
          "vocalGain": 1.12,
          "compressor": 0.28,
          "eqLow": -0.05,
          "eqMid": 0.08,
          "eqHigh": 0.22,
          "stereoWidth": 0.15,
          "presence": 0.25,
          "brightness": 0.20
        }
      },
      {
        "id": "pop",
        "name": "Pop",
        "icon": "pop",
        "description": "Pop style ready",
        "dsp": {
          "reverb": 0.30,
          "delay": 0.10,
          "vocalGain": 1.2,
          "compressor": 0.45,
          "eqLow": 0.0,
          "eqMid": 0.15,
          "eqHigh": 0.15
        }
      },
      {
        "id": "ballad",
        "name": "Ballad",
        "icon": "ballad",
        "description": "Ballad reverb",
        "dsp": {
          "reverb": 0.40,
          "delay": 0.15,
          "vocalGain": 1.1,
          "compressor": 0.3,
          "eqLow": 0.1,
          "eqMid": 0.0,
          "eqHigh": 0.1
        }
      },
      {
        "id": "acoustic",
        "name": "Acoustic",
        "icon": "acoustic",
        "description": "Acoustic guitar style",
        "dsp": {
          "reverb": 0.10,
          "delay": 0.0,
          "vocalGain": 1.0,
          "compressor": 0.2,
          "eqLow": 0.05,
          "eqMid": 0.1,
          "eqHigh": 0.05
        }
      },
      {
        "id": "jazz",
        "name": "Jazz",
        "icon": "jazz",
        "description": "Vintage lounge vibe",
        "dsp": {
          "reverb": 0.22,
          "delay": 0.08,
          "vocalGain": 1.05,
          "compressor": 0.25,
          "eqLow": 0.15,
          "eqMid": 0.05,
          "eqHigh": -0.02
        }
      },
      {
        "id": "rock",
        "name": "Rock",
        "icon": "rock",
        "description": "Aggressive high energy",
        "dsp": {
          "reverb": 0.25,
          "delay": 0.12,
          "vocalGain": 1.25,
          "compressor": 0.50,
          "eqLow": 0.10,
          "eqMid": 0.20,
          "eqHigh": 0.12
        }
      },
      {
        "id": "live",
        "name": "Live Concert",
        "icon": "live",
        "description": "Immersive live spatial",
        "dsp": {
          "reverb": 0.55,
          "delay": 0.22,
          "vocalGain": 1.10,
          "compressor": 0.35,
          "eqLow": 0.08,
          "eqMid": 0.05,
          "eqHigh": 0.15,
          "stereoWidth": 0.45,
          "presence": 0.18,
          "brightness": 0.15
        }
      },
      {
        "id": "ktv",
        "name": "KTV",
        "icon": "ktv",
        "description": "Classic karaoke echo room",
        "dsp": {
          "reverb": 0.45,
          "delay": 0.18,
          "vocalGain": 1.22,
          "compressor": 0.40,
          "eqLow": 0.05,
          "eqMid": 0.12,
          "eqHigh": 0.10
        }
      }
    ];
  }
}
