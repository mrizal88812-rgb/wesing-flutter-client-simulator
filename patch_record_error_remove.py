import re

with open("client_flutter/lib/features/record/record_screen.dart", "r") as f:
    content = f.read()

catch_old = """    } catch (e) {
      print("Error initEngine: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal memuat musik: $e",
              style: const TextStyle(fontSize: 12),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }"""

catch_new = """    } catch (e) {
      print("Error initEngine: $e");
      try {
        final String resolvedUrl = AppConfig.resolveMediaUrl(widget.song.audioUrl);
        await AudioCacheManager.removeCache(resolvedUrl);
      } catch (_) {}
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Gagal memuat musik instrumental, mohon periksa file lagu Anda.",
              style: const TextStyle(fontSize: 12, color: Colors.white),
            ),
            backgroundColor: Colors.red[800],
          ),
        );
      }
    }"""

content = content.replace(catch_old, catch_new)

with open("client_flutter/lib/features/record/record_screen.dart", "w") as f:
    f.write(content)
