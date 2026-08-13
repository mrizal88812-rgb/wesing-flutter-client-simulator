import re

with open('client_flutter/lib/features/record/record_screen.dart', 'r') as f:
    content = f.read()

# Replace _buildMixingView
old_view = re.search(r'Widget _buildMixingView\(\) \{.*?(?=Widget _buildSliderRow)', content, re.DOTALL)

if old_view:
    new_view = """Widget _buildMixingView() {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.song.title,
          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {},
          )
        ],
      ),
      body: Column(
        children: [
          // Visual Cover Art and Lyrics Overlay
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.1),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                      image: DecorationImage(
                        image: NetworkImage(AppConfig.resolveMediaUrl(widget.song.coverUrl)),
                        fit: BoxFit.cover,
                      ),
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.5),
                          ],
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "It's been a",
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "long and winding journey...",
                                style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 18, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // Progress bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 4,
                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                      activeTrackColor: Colors.white,
                      inactiveTrackColor: Colors.white.withOpacity(0.2),
                      thumbColor: Colors.white,
                    ),
                    child: Slider(
                      value: _currentTime.inMilliseconds.toDouble(),
                      min: 0.0,
                      max: math.max(100.0, _duration.inMilliseconds.toDouble()),
                      onChanged: (val) {
                        _audioEngine.seek(Duration(milliseconds: val.toInt()));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  "${_formatDuration(_currentTime)} / ${_formatDuration(_duration)}",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          
          // Presets Bar
          Container(
            height: 90,
            margin: const EdgeInsets.only(bottom: 24.0),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              children: [
                // Adjust Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showMixerControls = true;
                    });
                  },
                  child: Container(
                    width: 72,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A2A2A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.tune, color: Colors.white, size: 28),
                        SizedBox(height: 8),
                        Text("Adjust", style: TextStyle(color: Colors.white, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                // Dynamic Presets
                ..._availablePresets.map((preset) {
                  final isActive = _activePresetId == preset.id;
                  
                  // Generate a gradient based on the preset name/id for visual variety
                  List<Color> gradientColors;
                  switch (preset.id) {
                    case 'auto':
                      gradientColors = [const Color(0xFF2196F3), const Color(0xFF1976D2)];
                      break;
                    case 'analytics':
                      gradientColors = [const Color(0xFFE040FB), const Color(0xFFFF4081)];
                      break;
                    case 'warm':
                      gradientColors = [const Color(0xFFFF9800), const Color(0xFFF57C00)];
                      break;
                    case 'studio':
                      gradientColors = [const Color(0xFF4CAF50), const Color(0xFF388E3C)];
                      break;
                    case 'pop':
                      gradientColors = [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)];
                      break;
                    case 'ballad':
                      gradientColors = [const Color(0xFF00BCD4), const Color(0xFF0097A7)];
                      break;
                    default:
                      gradientColors = [const Color(0xFF607D8B), const Color(0xFF455A64)];
                  }

                  return GestureDetector(
                    onTap: () => _applyDynamicPreset(preset),
                    child: Container(
                      width: 72,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: gradientColors,
                              ),
                              border: isActive ? Border.all(color: Colors.white, width: 2) : null,
                            ),
                            child: Icon(
                              _getIconForPreset(preset.icon),
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            preset.name,
                            style: TextStyle(
                              color: isActive ? Colors.white : Colors.white70,
                              fontSize: 12,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          ),
          
          // Comment/Input Area & Buttons
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Let's listen to my solo!",
                  style: TextStyle(color: Colors.white54, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _buildActionButton(Icons.lock_outline, "Set to private"),
                    const SizedBox(width: 12),
                    _buildActionButton(Icons.copy_rounded, "Save a copy"),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Bottom Bar (Draft & Post)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Row(
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, color: Colors.white),
                    const SizedBox(height: 4),
                    const Text("Draft", style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE91E63), // Pinkish Red
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    onPressed: _exportAndSave,
                    child: _isSaving 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("Post", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  IconData _getIconForPreset(String iconName) {
    switch (iconName) {
      case 'auto': return Icons.mic;
      case 'ai': return Icons.psychology;
      case 'warm': return Icons.graphic_eq;
      case 'studio': return Icons.headphones;
      case 'pop': return Icons.music_note;
      case 'ballad': return Icons.favorite;
      case 'acoustic': return Icons.album;
      default: return Icons.mic;
    }
  }

  Widget _buildActionButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white54, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        ],
      ),
    );
  }

"""
    content = content.replace(old_view.group(0), new_view)

    with open('client_flutter/lib/features/record/record_screen.dart', 'w') as f:
        f.write(content)
    print("Updates applied to _buildMixingView.")
else:
    print("Could not find _buildMixingView in file.")
