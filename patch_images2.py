import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

old_str = """                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF2A54), width: 1.5),
                          image: DecorationImage(
                            image: NetworkImage(AppConfig.resolveMediaUrl(widget.song.coverUrl)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),"""

new_str = """                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFFF2A54), width: 1.5),
                        ),
                        child: ClipOval(
                          child: widget.song.coverUrl.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: AppConfig.resolveMediaUrl(widget.song.coverUrl),
                                  fit: BoxFit.cover,
                                  errorWidget: (context, url, error) => Container(color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white54, size: 24)),
                                )
                              : Container(color: Colors.grey[900], child: const Icon(Icons.music_note, color: Colors.white54, size: 24)),
                        ),
                      ),"""

content = content.replace(old_str, new_str)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
