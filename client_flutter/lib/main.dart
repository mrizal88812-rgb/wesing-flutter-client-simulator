import 'package:flutter/material.dart';
import 'features/discover/discover_screen.dart';
import 'features/feed/feed_screen.dart';
import 'services/audio/audio_manager.dart';
import 'data/models/song.dart';
import 'data/models/recording.dart';
import 'data/repositories_impl.dart';
import 'features/record/record_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'services/audio/audio_preload_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AudioManager().init();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeSing MVP',
      theme: ThemeData(
        primarySwatch: Colors.red,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
      ),
      builder: (context, child) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 480),
            child: child,
          ),
        );
      },
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainScreen extends StatefulWidget {
  final int initialIndex;
  const MainScreen({Key? key, this.initialIndex = 0}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
  }
  final List<Widget> _screens = [
    FeedScreen(),
    DiscoverScreen(),
    Container(), // Placeholder for center mic button (never selected directly)
    MessagesScreen(),
    ProfileScreen(),
  ];

  void _showQuickSingSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Color(0xFF0E0E10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        return QuickSingSheet();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border(top: BorderSide(color: Color(0xFF222222), width: 1)),
        ),
        child: Row(
          children: [
            // Tab 1: Browse (Feed)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AudioManager().currentPlayer?.stop();
                  setState(() => _currentIndex = 0);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home,
                        color: _currentIndex == 0 ? Color(0xFFEF4444) : Color(0xFF888888),
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Browse',
                        style: TextStyle(
                          color: _currentIndex == 0 ? Color(0xFFEF4444) : Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab 2: Discover
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AudioManager().currentPlayer?.stop();
                  setState(() => _currentIndex = 1);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.explore_outlined,
                        color: _currentIndex == 1 ? Color(0xFFEF4444) : Color(0xFF888888),
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Discover',
                        style: TextStyle(
                          color: _currentIndex == 1 ? Color(0xFFEF4444) : Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Middle: Mic Button
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -16,
                    child: GestureDetector(
                      onTap: () => _showQuickSingSheet(context),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFFEF4444).withOpacity(0.5),
                              blurRadius: 10,
                              spreadRadius: 1,
                            )
                          ],
                        ),
                        child: Icon(Icons.mic, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Tab 4: Messages
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AudioManager().currentPlayer?.stop();
                  setState(() => _currentIndex = 3);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: _currentIndex == 3 ? Color(0xFFEF4444) : Color(0xFF888888),
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Messages',
                        style: TextStyle(
                          color: _currentIndex == 3 ? Color(0xFFEF4444) : Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Tab 5: Me
            Expanded(
              child: GestureDetector(
                onTap: () {
                  AudioManager().currentPlayer?.stop();
                  setState(() => _currentIndex = 4);
                },
                child: Container(
                  color: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: _currentIndex == 4 ? Color(0xFFEF4444) : Color(0xFF888888),
                        size: 22,
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Me',
                        style: TextStyle(
                          color: _currentIndex == 4 ? Color(0xFFEF4444) : Color(0xFF888888),
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessagesScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _buildChatItem(
            avatarUrl: 'https://i.pravatar.cc/150?u=riana',
            name: 'Riana',
            time: '14:32',
            message: 'Wah, rekaman lagu barumu tadi suaranya merdu banget! 😍',
          ),
          Divider(color: Color(0xFF222222), height: 1),
          _buildChatItem(
            avatarUrl: 'https://i.pravatar.cc/150?u=budi',
            name: 'Budi',
            time: 'Kemarin',
            message: 'Ayo duet di lagu "Separuh Aku" nanti malam!',
          ),
          Divider(color: Color(0xFF222222), height: 1),
          _buildChatItem(
            avatarUrl: 'https://i.pravatar.cc/150?u=siti',
            name: 'Siti',
            time: 'Kemarin',
            message: '[Pemberitahuan] Kamu naik ke Level 5 Artist! 🎉',
            isSpecial: true,
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem({
    required String avatarUrl,
    required String name,
    required String time,
    required String message,
    bool isSpecial = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundImage: CachedNetworkImageProvider(avatarUrl),
            backgroundColor: Colors.grey[900],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      name,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      time,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    color: isSpecial ? Color(0xFFEF4444) : Colors.grey[400],
                    fontSize: 13,
                    fontWeight: isSpecial ? FontWeight.w500 : FontWeight.normal,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiRepository api = ApiRepository();
  List<Recording> userRecordings = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRecordings();
  }

  Future<void> _loadUserRecordings() async {
    try {
      final feed = await api.fetchFeed();
      if (mounted) {
        setState(() {
          userRecordings = feed.where((item) => item.userId == "user_1").toList();
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading user recordings: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          'Me',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 24),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: false,
      ),
      body: RefreshIndicator(
        onRefresh: _loadUserRecordings,
        color: Colors.red,
        child: ListView(
          physics: AlwaysScrollableScrollPhysics(),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Color(0xFFEF4444), width: 2),
                        ),
                        child: CircleAvatar(
                          radius: 40,
                          backgroundImage: CachedNetworkImageProvider('https://i.pravatar.cc/150?u=nafisa'),
                          backgroundColor: Colors.grey[900],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'LV.5',
                          style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Nafisa',
                    style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Text(
                      'Pecinta musik & karaoke setiap hari 🎤 • Level 5 Artist',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[400], fontSize: 12),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatItem('1.2K', 'Followers'),
                      _buildStatItem('48', 'Following'),
                      _buildStatItem('1,000', 'Coins'),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: Color(0xFF111111),
              width: double.infinity,
              child: Text(
                'MY RECORDINGS',
                style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ),
            isLoading
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Center(child: CircularProgressIndicator(color: Colors.red)),
                  )
                : userRecordings.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
                        child: Column(
                          children: [
                            Icon(Icons.mic, color: Colors.grey[800], size: 36),
                            SizedBox(height: 10),
                            Text(
                              'Kamu belum memiliki rekaman.',
                              style: TextStyle(color: Colors.grey[600], fontSize: 13),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        padding: EdgeInsets.all(16),
                        itemCount: userRecordings.length,
                        itemBuilder: (context, index) {
                          final item = userRecordings[index];
                          final cover = item.song?.coverUrl ?? '';
                          return Container(
                            margin: EdgeInsets.only(bottom: 12),
                            padding: EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Color(0xFF111111),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Color(0xFF1F1F23)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: cover.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: AudioPreloadManager.resolveUrl(cover),
                                          width: 48,
                                          height: 48,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(color: Colors.grey[900], width: 48, height: 48),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.song?.title ?? '',
                                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Score: ${item.score} pts',
                                        style: TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: Icon(Icons.play_circle_outline, color: Colors.white, size: 28),
                                  onPressed: () {
                                    if (item.song != null) {
                                      AudioManager().play(item.song!);
                                    }
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: TextStyle(color: Colors.grey[500], fontSize: 10, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class QuickSingSheet extends StatefulWidget {
  @override
  _QuickSingSheetState createState() => _QuickSingSheetState();
}

class _QuickSingSheetState extends State<QuickSingSheet> {
  final ApiRepository api = ApiRepository();
  List<Song> songs = [];
  List<Song> filteredSongs = [];
  bool isLoading = true;
  String query = '';

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    try {
      final data = await api.fetchSongs();
      if (mounted) {
        setState(() {
          songs = data;
          filteredSongs = data;
          isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading songs in quick sing sheet: $e');
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _filterSongs(String val) {
    setState(() {
      query = val;
      filteredSongs = songs.where((s) {
        return s.title.toLowerCase().contains(val.toLowerCase()) ||
               s.artist.toLowerCase().contains(val.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboardPadding = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.6 + keyboardPadding,
      padding: EdgeInsets.only(left: 16, right: 16, bottom: keyboardPadding + 16),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pilih Lagu untuk Bernyanyi',
                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.grey[400], size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Color(0xFF16161A),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey[900] ?? const Color(0xFF212121)),
            ),
            child: TextField(
              onChanged: _filterSongs,
              style: TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Cari lagu...",
                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500], size: 18),
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.red))
                : filteredSongs.isEmpty
                    ? Center(
                        child: Text(
                          "Lagu tidak ditemukan",
                          style: TextStyle(color: Colors.grey[600], fontSize: 13),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredSongs.length,
                        itemBuilder: (context, index) {
                          final song = filteredSongs[index];
                          final cover = song.coverUrl;
                          return Container(
                            margin: EdgeInsets.only(bottom: 10),
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Color(0xFF141416),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[900] ?? const Color(0xFF212121)),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: cover.isNotEmpty
                                      ? CachedNetworkImage(
                                          imageUrl: AudioPreloadManager.resolveUrl(cover),
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover,
                                        )
                                      : Container(color: Colors.grey[900], width: 40, height: 40),
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        song.title,
                                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        song.artist,
                                        style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(width: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF3B82F6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  ),
                                  onPressed: () {
                                    Navigator.pop(context);
                                    AudioManager().currentPlayer?.stop();
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => RecordScreen(song: song)),
                                    );
                                  },
                                  icon: Icon(Icons.mic, color: Colors.white, size: 12),
                                  label: Text(
                                    'Mulai',
                                    style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
