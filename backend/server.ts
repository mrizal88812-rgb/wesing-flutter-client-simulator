import express from "express";
import path from "path";
import fs from "fs";
import { createServer as createViteServer } from "vite";
import multer from "multer";
import crypto from "crypto";
import { initDb, pool } from "./db.js";

// Ensure storage directory exists
const storageDir = path.join(process.cwd(), "storage");
if (!fs.existsSync(storageDir)) {
  fs.mkdirSync(storageDir, { recursive: true });
}

const allowedExtensions = [".mp3", ".wav", ".m4a", ".aac", ".png", ".jpg", ".jpeg", ".webp", ".lrc"];

const diskStorage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, storageDir);
  },
  filename: (req, file, cb) => {
    // Sanitize file extension and original name elements to prevent traversal
    const baseExt = path.extname(file.originalname).toLowerCase();
    const cleanExt = allowedExtensions.includes(baseExt) ? baseExt : ".bin";
    const uniqueSuffix = Date.now() + '-' + crypto.randomBytes(6).toString('hex');
    cb(null, file.fieldname + '-' + uniqueSuffix + cleanExt);
  },
});

const fileFilter = (req: any, file: any, cb: any) => {
  const ext = path.extname(file.originalname).toLowerCase();
  if (allowedExtensions.includes(ext)) {
    cb(null, true);
  } else {
    cb(new Error("File type not allowed! Supported types: mp3, wav, m4a, aac, png, jpg, jpeg, webp, lrc"), false);
  }
};

const upload = multer({
  storage: diskStorage,
  limits: { fileSize: 25 * 1024 * 1024 }, // 25MB limit
  fileFilter: fileFilter
});

// Mock database
let songs: any[] = [
  {
    id: "song-001",
    title: "Shape of You",
    artist: "Ed Sheeran",
    coverUrl: "/storage/songs/song-001/cover.webp",
    audioUrl: "/storage/songs/song-001/instrumental.m4a",
    playCount: 12500,
    tags: ["Pop", "Acoustic"],
    lyrics: [
      { time: 0, text: "The club isn't the best place to find a lover" },
      { time: 4, text: "So the bar is where I go" },
      { time: 8, text: "Me and my friends at the table doing shots" },
      { time: 12, text: "Drinking fast and then we talk slow" }
    ]
  },
  {
    id: "song-002",
    title: "Song 2",
    artist: "Unknown Artist",
    coverUrl: "/storage/songs/song-002/cover.webp",
    audioUrl: "/storage/songs/song-002/instrumental.m4a",
    playCount: 500,
    tags: ["Live"],
    lyrics: []
  },
  {
    id: "song-003",
    title: "Picking up the Pieces",
    artist: "The Sunset Glow",
    coverUrl: "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop",
    audioUrl: "https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3",
    playCount: 18400,
    tags: ["Acoustic", "Vocal"],
    lyrics: [
      { time: 0, text: "Picking up the pieces" },
      { time: 4, text: "Walking back into the light" },
      { time: 8, text: "Into the sunset of your glory" },
      { time: 12, text: "Where my heart and future lies" },
      { time: 16, text: "There's nothing like that feeling" }
    ]
  }
];
let feed: any[] = [
  {
    id: "feed_1",
    userId: "user_1",
    songId: "song-001",
    audioUrl: "/storage/songs/song-001/instrumental.m4a",
    score: 92,
    createdAt: new Date().toISOString(),
    likesCount: 245,
    commentsCount: 12
  }
];
let users: any[] = [
  {
    id: "user_1",
    username: "Nafisa",
    avatar: "https://i.pravatar.cc/150?u=nafisa",
    followersCount: 120,
    level: 5,
    coins: 1000
  }
];

const presetsFilePath = path.join(storageDir, "presets.json");

function getPresets() {
  if (fs.existsSync(presetsFilePath)) {
    try {
      const content = fs.readFileSync(presetsFilePath, "utf8");
      return JSON.parse(content);
    } catch (e) {
      console.error("Error reading presets, resetting to default:", e);
    }
  }

  const defaultPresets = [
    {
      id: "studio",
      name: "Studio",
      icon: "headphones",
      description: "Professional studio vocal",
      enabled: true,
      dsp: {
        reverb: 0.20,
        delay: 0.05,
        echo: 0.00,
        vocalGain: 1.15,
        compressor: 0.35,
        limiter: 0.15,
        noiseReduction: 0.10,
        eqLow: 0.05,
        eqMid: 0.10,
        eqHigh: 0.08,
        stereoWidth: 0.20,
        presence: 0.15,
        brightness: 0.10
      }
    },
    {
      id: "warm",
      name: "Warm",
      icon: "warm",
      description: "Warm and cozy analog tone",
      enabled: true,
      dsp: {
        reverb: 0.15,
        delay: 0.00,
        echo: 0.00,
        vocalGain: 1.10,
        compressor: 0.30,
        limiter: 0.10,
        noiseReduction: 0.10,
        eqLow: 0.20,
        eqMid: 0.10,
        eqHigh: -0.05,
        stereoWidth: 0.10,
        presence: 0.10,
        brightness: 0.05
      }
    },
    {
      id: "bright",
      name: "Bright",
      icon: "bright",
      description: "Crisp highs and presence",
      enabled: true,
      dsp: {
        reverb: 0.18,
        delay: 0.02,
        echo: 0.00,
        vocalGain: 1.12,
        compressor: 0.28,
        limiter: 0.12,
        noiseReduction: 0.08,
        eqLow: -0.05,
        eqMid: 0.08,
        eqHigh: 0.22,
        stereoWidth: 0.15,
        presence: 0.25,
        brightness: 0.20
      }
    },
    {
      id: "pop",
      name: "Pop",
      icon: "pop",
      description: "Modern commercial radio ready",
      enabled: true,
      dsp: {
        reverb: 0.30,
        delay: 0.10,
        echo: 0.00,
        vocalGain: 1.20,
        compressor: 0.45,
        limiter: 0.20,
        noiseReduction: 0.15,
        eqLow: 0.00,
        eqMid: 0.15,
        eqHigh: 0.15,
        stereoWidth: 0.25,
        presence: 0.20,
        brightness: 0.15
      }
    },
    {
      id: "ballad",
      name: "Ballad",
      icon: "ballad",
      description: "Smooth reverb for emotional range",
      enabled: true,
      dsp: {
        reverb: 0.40,
        delay: 0.15,
        echo: 0.05,
        vocalGain: 1.10,
        compressor: 0.30,
        limiter: 0.15,
        noiseReduction: 0.10,
        eqLow: 0.10,
        eqMid: 0.00,
        eqHigh: 0.10,
        stereoWidth: 0.20,
        presence: 0.15,
        brightness: 0.12
      }
    },
    {
      id: "acoustic",
      name: "Acoustic",
      icon: "acoustic",
      description: "Intimate organic acoustic response",
      enabled: true,
      dsp: {
        reverb: 0.10,
        delay: 0.00,
        echo: 0.00,
        vocalGain: 1.00,
        compressor: 0.20,
        limiter: 0.08,
        noiseReduction: 0.05,
        eqLow: 0.05,
        eqMid: 0.10,
        eqHigh: 0.05,
        stereoWidth: 0.08,
        presence: 0.12,
        brightness: 0.08
      }
    },
    {
      id: "jazz",
      name: "Jazz",
      icon: "jazz",
      description: "Vintage lounge atmosphere",
      enabled: true,
      dsp: {
        reverb: 0.22,
        delay: 0.08,
        echo: 0.00,
        vocalGain: 1.05,
        compressor: 0.25,
        limiter: 0.10,
        noiseReduction: 0.12,
        eqLow: 0.15,
        eqMid: 0.05,
        eqHigh: -0.02,
        stereoWidth: 0.12,
        presence: 0.08,
        brightness: 0.02
      }
    },
    {
      id: "rock",
      name: "Rock",
      icon: "rock",
      description: "Aggressive, high intensity",
      enabled: true,
      dsp: {
        reverb: 0.25,
        delay: 0.12,
        echo: 0.00,
        vocalGain: 1.25,
        compressor: 0.50,
        limiter: 0.25,
        noiseReduction: 0.15,
        eqLow: 0.10,
        eqMid: 0.20,
        eqHigh: 0.12,
        stereoWidth: 0.30,
        presence: 0.22,
        brightness: 0.10
      }
    },
    {
      id: "live_concert",
      name: "Live Concert",
      icon: "live",
      description: "Immersive stadium spatial delay",
      enabled: true,
      dsp: {
        reverb: 0.55,
        delay: 0.22,
        echo: 0.15,
        vocalGain: 1.10,
        compressor: 0.35,
        limiter: 0.18,
        noiseReduction: 0.12,
        eqLow: 0.08,
        eqMid: 0.05,
        eqHigh: 0.15,
        stereoWidth: 0.45,
        presence: 0.18,
        brightness: 0.15
      }
    },
    {
      id: "ktv",
      name: "KTV",
      icon: "ktv",
      description: "Classic karaoke room echo",
      enabled: true,
      dsp: {
        reverb: 0.45,
        delay: 0.18,
        echo: 0.25,
        vocalGain: 1.22,
        compressor: 0.40,
        limiter: 0.22,
        noiseReduction: 0.15,
        eqLow: 0.05,
        eqMid: 0.12,
        eqHigh: 0.10,
        stereoWidth: 0.35,
        presence: 0.15,
        brightness: 0.12
      }
    }
  ];
  fs.writeFileSync(presetsFilePath, JSON.stringify({ presets: defaultPresets }, null, 2));
  return { presets: defaultPresets };
}

function savePresets(presetsList: any[]) {
  fs.writeFileSync(presetsFilePath, JSON.stringify({ presets: presetsList }, null, 2));
}

async function startServer() {
  await initDb();
  const app = express();
  const PORT = 3000;

  app.use(express.json());

  // Serve storage statically
  app.use("/storage", express.static(storageDir));

  // --- API Routes ---

  // Preset Endpoints
  app.get("/api/presets", (req, res) => {
    const data = getPresets();
    const showAll = req.query.all === "true";
    if (showAll) {
      res.json(data);
    } else {
      const active = data.presets.filter((p: any) => p.enabled !== false);
      res.json({ presets: active });
    }
  });

  app.post("/api/presets", (req, res) => {
    const data = getPresets();
    const newPreset = req.body;
    if (!newPreset.id) {
      newPreset.id = "preset-" + Date.now();
    }
    if (newPreset.enabled === undefined) {
      newPreset.enabled = true;
    }

    // Check if preset already exists to update, otherwise insert
    const idx = data.presets.findIndex((p: any) => p.id === newPreset.id);
    if (idx !== -1) {
      data.presets[idx] = newPreset;
    } else {
      data.presets.push(newPreset);
    }

    savePresets(data.presets);
    res.json({ success: true, preset: newPreset });
  });

  app.put("/api/presets/:id", (req, res) => {
    const data = getPresets();
    const { id } = req.params;
    const idx = data.presets.findIndex((p: any) => p.id === id);
    if (idx !== -1) {
      data.presets[idx] = { ...data.presets[idx], ...req.body };
      savePresets(data.presets);
      res.json({ success: true, preset: data.presets[idx] });
    } else {
      res.status(404).json({ error: "Preset not found" });
    }
  });

  app.delete("/api/presets/:id", (req, res) => {
    const data = getPresets();
    const { id } = req.params;
    const filtered = data.presets.filter((p: any) => p.id !== id);
    savePresets(filtered);
    res.json({ success: true });
  });

  app.post("/api/upload", upload.single("file"), (req, res) => {
    if (!req.file) {
      return res.status(400).json({ error: "No file uploaded" });
    }
    try {
      const filePath = req.file.path;
      const fileBuffer = fs.readFileSync(filePath);
      const hash = crypto.createHash("sha256").update(fileBuffer).digest("hex");

      res.json({
        url: `/storage/${req.file.filename}`,
        filename: req.file.filename,
        size: req.file.size,
        checksum: hash,
        mimeType: req.file.mimetype
      });
    } catch (err: any) {
      res.status(500).json({ error: "Failed to generate file metadata: " + err.message });
    }
  });

  app.get("/api/songs", async (req, res) => {
    try {
      const result = await pool.query('SELECT * FROM songs');
      res.json(result.rows.map(row => ({
        id: row.id,
        title: row.title,
        artist: row.artist,
        coverUrl: row.cover_url,
        audioUrl: row.audio_url,
        playCount: row.play_count,
        tags: typeof row.tags === 'string' ? JSON.parse(row.tags) : row.tags,
        lyrics: typeof row.lyrics === 'string' ? JSON.parse(row.lyrics) : row.lyrics,
      })));
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  app.post("/api/songs", async (req, res) => {
    const songId = `song-${Date.now()}`;
    const song = {
      ...req.body,
      id: songId,
      playCount: 0
    };

    const songDir = path.join(storageDir, 'songs', songId);
    if (!fs.existsSync(songDir)) {
      fs.mkdirSync(songDir, { recursive: true });
    }

    const checkPathTraversal = (unsafeRelativePath: string): string => {
      // Resolve path
      const resolved = path.resolve(storageDir, unsafeRelativePath);
      // Ensure resolved path is strictly inside storageDir
      if (!resolved.startsWith(path.resolve(storageDir))) {
        throw new Error("Security Error: Path traversal attempt detected!");
      }
      return resolved;
    };

    try {
      if (song.audioUrl && song.audioUrl.startsWith('/storage/') && !song.audioUrl.startsWith('/storage/songs/')) {
        const relPath = song.audioUrl.replace(/^\/storage\//, '');
        const oldPath = checkPathTraversal(relPath);
        const ext = path.extname(oldPath).toLowerCase();
        if (!allowedExtensions.includes(ext)) {
          throw new Error("Invalid file extension!");
        }
        const fileName = 'instrumental' + ext;
        const newPath = path.join(songDir, fileName);
        if (fs.existsSync(oldPath)) {
          fs.renameSync(oldPath, newPath);
          song.audioUrl = `/storage/songs/${songId}/${fileName}`;
        }
      }

      if (song.coverUrl && song.coverUrl.startsWith('/storage/') && !song.coverUrl.startsWith('/storage/songs/')) {
        const relPath = song.coverUrl.replace(/^\/storage\//, '');
        const oldPath = checkPathTraversal(relPath);
        const ext = path.extname(oldPath).toLowerCase();
        if (!allowedExtensions.includes(ext)) {
          throw new Error("Invalid file extension!");
        }
        const fileName = 'cover' + ext;
        const newPath = path.join(songDir, fileName);
        if (fs.existsSync(oldPath)) {
          fs.renameSync(oldPath, newPath);
          song.coverUrl = `/storage/songs/${songId}/${fileName}`;
        }
      }
    } catch (err: any) {
      return res.status(400).json({ error: err.message });
    }

    if (song.lyrics && Array.isArray(song.lyrics)) {
      const lrcContent = song.lyrics.map((l: any) => {
        const min = Math.floor(l.time / 60);
        const sec = (l.time % 60).toFixed(3);
        if (l.endTime !== undefined && l.endTime !== null) {
          const endMin = Math.floor(l.endTime / 60);
          const endSec = (l.endTime % 60).toFixed(3);
          return `[${min.toString().padStart(2, '0')}:${sec.padStart(6, '0')} --> ${endMin.toString().padStart(2, '0')}:${endSec.padStart(6, '0')}] ${l.text}`;
        }
        return `[${min.toString().padStart(2, '0')}:${sec.padStart(6, '0')}] ${l.text}`;
      }).join('\n');
      fs.writeFileSync(path.join(songDir, 'lyrics.lrc'), lrcContent);
    }

    try {
      await pool.query(`
        INSERT INTO songs (id, title, artist, cover_url, audio_url, play_count, tags, lyrics)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
      `, [
        song.id,
        song.title,
        song.artist,
        song.coverUrl,
        song.audioUrl,
        song.playCount,
        JSON.stringify(song.tags || []),
        JSON.stringify(song.lyrics || [])
      ]);
      res.json(song);
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  app.delete("/api/songs/:id", async (req, res) => {
    try {
      const songId = req.params.id;
      // Delete recordings referencing this song first to avoid foreign key constraint violations
      await pool.query('DELETE FROM recordings WHERE song_id = $1', [songId]);
      // Then delete the song
      await pool.query('DELETE FROM songs WHERE id = $1', [songId]);
      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  app.get("/api/song/:id/pitch", (req, res) => {
    // Generate some mock pitch bars
    const bars = [];
    for (let i = 0; i < 20; i++) {
      bars.push({
        start: i * 2,
        duration: 1.5,
        pitch: 60 + Math.random() * 10,
        note_name: "C4"
      });
    }
    res.json({ bars });
  });

  app.get(["/api/feed", "/api/recordings"], async (req, res) => {
    try {
      const showAll = req.query.all === "true" || req.path === "/api/recordings";
      const whereClause = showAll ? "" : "WHERE COALESCE(r.visibility, 'Public') = 'Public'";

      const result = await pool.query(`
        SELECT r.*, u.username, u.avatar, u.followers_count, u.level, u.coins,
               s.title as song_title, s.artist, s.cover_url as song_cover_url, s.audio_url as song_audio_url
        FROM recordings r
        LEFT JOIN users u ON r.user_id = u.id
        LEFT JOIN songs s ON r.song_id = s.id
        ${whereClause}
        ORDER BY r.created_at DESC
      `);
      const populatedFeed = result.rows.map(row => {
        let audioUrl = row.audio_url || row.song_audio_url;
        if (audioUrl && (audioUrl.startsWith('/sdcard/') || audioUrl.startsWith('/data/') || audioUrl.startsWith('/var/') || audioUrl.startsWith('file:') || audioUrl.startsWith('blob:'))) {
          audioUrl = row.song_audio_url || '';
        }

        return {
          id: row.id,
          userId: row.user_id,
          songId: row.song_id,
          audioUrl: audioUrl,
          coverUrl: row.cover_url || row.song_cover_url,
          caption: row.caption || '',
          visibility: row.visibility || 'Public',
          score: row.score,
          createdAt: row.created_at,
          likesCount: row.likes_count,
          commentsCount: row.comments_count,
          songStart: row.song_start || 0.0,
          songEnd: row.song_end || 0.0,
          duration: (row.duration && row.duration > 0)
            ? row.duration
            : ((row.song_end > row.song_start) ? (row.song_end - row.song_start) : 0.0),
          user: {
            id: row.user_id,
            username: row.username,
            avatar: row.avatar,
            followersCount: row.followers_count,
            level: row.level,
            coins: row.coins
          },
          song: {
            id: row.song_id,
            title: row.song_title,
            artist: row.artist,
            coverUrl: row.song_cover_url,
            audioUrl: row.song_audio_url
          }
        };
      });
      res.json(populatedFeed);
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  app.post("/api/recordings", async (req, res) => {
    const {
      songId,
      audioUrl,
      score,
      caption,
      coverUrl,
      visibility,
      songStart,
      songEnd,
      duration
    } = req.body;

    try {
      const recordingId = crypto.randomUUID();
      const userId = 'user_1'; // Use our seeded user for now
      const vis = visibility || 'Public';

      let finalAudioUrl = audioUrl;
      if (!finalAudioUrl || finalAudioUrl.startsWith('/sdcard/') || finalAudioUrl.startsWith('/data/') || finalAudioUrl.startsWith('/var/') || finalAudioUrl.startsWith('file:') || finalAudioUrl.startsWith('blob:')) {
        if (songId) {
          const songRes = await pool.query('SELECT audio_url FROM songs WHERE id = $1', [songId]);
          if (songRes.rows.length > 0 && songRes.rows[0].audio_url) {
            finalAudioUrl = songRes.rows[0].audio_url;
          }
        }
      }

      const sStart = parseFloat(songStart) || 0.0;
      const sEnd = parseFloat(songEnd) || 0.0;
      let calcDuration = parseFloat(duration) || 0.0;
      if (sEnd > sStart) {
        calcDuration = sEnd - sStart;
      }

      await pool.query(`
        INSERT INTO recordings (id, user_id, song_id, audio_url, score, caption, cover_url, visibility, song_start, song_end, duration)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
      `, [recordingId, userId, songId, finalAudioUrl, score || 0, caption || '', coverUrl || null, vis, sStart, sEnd, calcDuration]);

      // Also increment song play count
      if (songId) {
        await pool.query(`
          UPDATE songs SET play_count = play_count + 1 WHERE id = $1
        `, [songId]);
      }

      res.json({ success: true, id: recordingId });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  app.delete(["/api/feed/:id", "/api/recordings/:id"], async (req, res) => {
    try {
      await pool.query('DELETE FROM recordings WHERE id = $1', [req.params.id]);
      res.json({ success: true });
    } catch (e) {
      console.error(e);
      res.status(500).json({ error: "Database error" });
    }
  });

  // Vite middleware for development
  if (process.env.NODE_ENV !== "production") {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: "custom",
    });
    app.use(vite.middlewares);

    app.use('*', async (req, res, next) => {
      const url = req.originalUrl;
      if (url.startsWith('/api') || url.startsWith('/storage')) {
        return next();
      }

      try {
        let templatePath = path.resolve(process.cwd(), 'index.html');
        if (url.startsWith('/admin')) {
          templatePath = path.resolve(process.cwd(), 'admin/index.html');
        }

        let template = fs.readFileSync(templatePath, 'utf-8');
        template = await vite.transformIndexHtml(url, template);
        res.status(200).set({ 'Content-Type': 'text/html' }).end(template);
      } catch (e) {
        vite.ssrFixStacktrace(e as Error);
        next(e);
      }
    });
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('/admin*', (req, res) => {
      res.sendFile(path.join(distPath, 'admin/index.html'));
    });
    app.get('*all', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, "0.0.0.0", () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
