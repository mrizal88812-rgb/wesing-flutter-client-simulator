import re

def patch_file(filepath):
    with open(filepath, "r") as f:
        content = f.read()
        
    if "import 'package:cached_network_image/cached_network_image.dart';" not in content:
        content = content.replace("import 'package:flutter/material.dart';", "import 'package:flutter/material.dart';\nimport 'package:cached_network_image/cached_network_image.dart';")

    old_img = """                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: const Color(0xFFFF2A54), width: 1.5),
                                image: DecorationImage(
                                  image: NetworkImage(AppConfig.resolveMediaUrl(widget.song.coverUrl)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),"""
                            
    new_img = """                              decoration: BoxDecoration(
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
                            
    content = content.replace(old_img, new_img)
    
    with open(filepath, "w") as f:
        f.write(content)

patch_file("client_flutter/lib/features/record/edit_recording_screen.dart")
patch_file("client_flutter/lib/features/record/record_screen.dart")
