import React, { useState, useEffect, useRef } from 'react';
import { 
  Music, 
  Search, 
  Home, 
  Mic, 
  Play, 
  Pause, 
  ArrowLeft, 
  Heart, 
  MessageCircle, 
  Award,
  RefreshCw,
  Sparkles,
  Smartphone,
  Monitor,
  Volume2,
  Compass,
  User,
  MessageSquare,
  X,
  ChevronLeft,
  MoreHorizontal,
  Sliders,
  RotateCcw,
  CheckCircle,
  AlertTriangle,
  Headphones,
  UploadCloud,
  Plus,
  Trash2
} from 'lucide-react';
import { motion, AnimatePresence } from 'motion/react';
import PitchVisualizer from './components/PitchVisualizer';
import { WebAudioEngineService, AutoTuneMode } from './services/webAudioEngine';

// Interfaces matching backend and React Native client
interface LyricLine {
  time: number;
  endTime?: number;
  text: string;
}

interface Song {
  id: string;
  title: string;
  artist: string;
  coverUrl: string;
  audioUrl: string;
  playCount: number;
  tags: string[];
  lyrics: LyricLine[];
}

interface User {
  id: string;
  username: string;
  avatar: string;
  followersCount: number;
  level: number;
  coins: number;
}

interface Recording {
  id: string;
  userId: string;
  songId: string;
  audioUrl?: string;
  score: number;
  createdAt: string;
  user?: User;
  song?: Song;
  likesCount: number;
  commentsCount: number;
}

export default function App() {
  // Navigation & Frame settings
  const [activeTab, setActiveTab] = useState<'browse' | 'discover' | 'messages' | 'me'>('browse');
  const [currentScreen, setCurrentScreen] = useState<'main' | 'record' | 'mixing'>('main');
  const [selectedSong, setSelectedSong] = useState<Song | null>(null);
  const [usePhoneFrame, setUsePhoneFrame] = useState<boolean>(true);
  const [isSingDrawerOpen, setIsSingDrawerOpen] = useState<boolean>(false);
  const [drawerSearch, setDrawerSearch] = useState<string>('');

  // Upload Song Modal & Admin Panel states
  const [isUploadSongModalOpen, setIsUploadSongModalOpen] = useState<boolean>(false);
  const [adminTab, setAdminTab] = useState<'upload' | 'songs'>('upload');
  const [uploadTitle, setUploadTitle] = useState<string>('');
  const [uploadArtist, setUploadArtist] = useState<string>('');
  const [uploadAudioFile, setUploadAudioFile] = useState<File | null>(null);
  const [uploadCoverFile, setUploadCoverFile] = useState<File | null>(null);
  const [uploadLyricsText, setUploadLyricsText] = useState<string>('');
  const [isUploading, setIsUploading] = useState<boolean>(false);

  // Core Data states
  const [songs, setSongs] = useState<Song[]>([]);
  const [feed, setFeed] = useState<Recording[]>([]);
  const [isLoadingSongs, setIsLoadingSongs] = useState(true);
  const [isLoadingFeed, setIsLoadingFeed] = useState(true);

  // Audio control states
  const [playingSongId, setPlayingSongId] = useState<string | null>(null);
  const [playingFeedId, setPlayingFeedId] = useState<string | null>(null);
  const [currentTime, setCurrentTime] = useState<number>(0);
  const [duration, setDuration] = useState<number>(0);
  const [isPlaying, setIsPlaying] = useState<boolean>(false);

  // Like tracking state
  const [likedIds, setLikedIds] = useState<Set<String>>(new Set());

  // Recording Screen states
  const [activeLyricIndex, setActiveLyricIndex] = useState<number>(-1);
  const [score, setScore] = useState<number>(0);
  const [recordingSaved, setRecordingSaved] = useState<boolean>(false);
  const [isSaving, setIsSaving] = useState<boolean>(false);

  // Senior Audio Mobile Programming states
  const [isEarphoneConnected, setIsEarphoneConnected] = useState<boolean>(false);
  const [vocalVolume, setVocalVolume] = useState<number>(100);       // raw voice volume (0-100)
  const [musicVolume, setMusicVolume] = useState<number>(85);        // backing track instrument volume (0-100)
  const [latencyOffset, setLatencyOffset] = useState<number>(45);    // default 45ms latency compensation
  const [showSingerModal, setShowSingerModal] = useState<boolean>(false);
  const [showAdjustmentDrawer, setShowAdjustmentDrawer] = useState<boolean>(false);

  // Mixing Screen states
  const [selectedPreset, setSelectedPreset] = useState<string>('Warm');
  const [showAdjustSettings, setShowAdjustSettings] = useState<boolean>(true);
  const [autoTuneMode, setAutoTuneMode] = useState<AutoTuneMode>('OFF');
  const [reverbMix, setReverbMix] = useState<number>(0.25);
  const [delayMix, setDelayMix] = useState<number>(0.15);
  const [isProTuningActive, setIsProTuningActive] = useState<boolean>(false);
  const [captionText, setCaptionText] = useState<string>("Let's listen to my solo!");
  const [isPrivate, setIsPrivate] = useState<boolean>(false);
  const [saveACopy, setSaveACopy] = useState<boolean>(false);
  const [selectedTemplateIndex, setSelectedTemplateIndex] = useState<number>(0);
  const [addedStickers, setAddedStickers] = useState<{ id: string; type: string; label: string; color: string; x: number; y: number }[]>([
    { id: 'sticker-1', type: 'sun', label: '☀️', color: '#f39c12', x: 70, y: 30 },
    { id: 'sticker-2', type: 'music', label: '🎵', color: '#2ecc71', x: 25, y: 70 }
  ]);
  const [showStickerDrawer, setShowStickerDrawer] = useState<boolean>(false);

  // Live Microphone Recording states
  const mediaRecorderRef = useRef<MediaRecorder | null>(null);
  const micStreamRef = useRef<MediaStream | null>(null);
  const recordedChunksRef = useRef<Blob[]>([]);
  const [recordedVocalBlob, setRecordedVocalBlob] = useState<Blob | null>(null);
  const [isMicRecording, setIsMicRecording] = useState<boolean>(false);
  const [micStatusText, setMicStatusText] = useState<string>('Meminta akses mikrofon...');

  // Refs
  const audioPlayerRef = useRef<HTMLAudioElement | null>(null);
  const lyricsScrollRef = useRef<HTMLDivElement | null>(null);

  // Time formatting helper
  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = Math.floor(seconds % 60);
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  };

  // Load songs & feed from real server APIs
  const loadData = async () => {
    try {
      setIsLoadingSongs(true);
      const resSongs = await fetch('/api/songs');
      if (resSongs.ok) {
        const dataSongs = await resSongs.json();
        setSongs(dataSongs);
      }
    } catch (e) {
      console.error('Error fetching songs:', e);
    } finally {
      setIsLoadingSongs(false);
    }

    try {
      setIsLoadingFeed(true);
      const resFeed = await fetch('/api/feed');
      if (resFeed.ok) {
        const dataFeed = await resFeed.json();
        setFeed(dataFeed);
      }
    } catch (e) {
      console.error('Error fetching feed:', e);
    } finally {
      setIsLoadingFeed(false);
    }
  };

  const handleUploadSong = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!uploadTitle.trim() || !uploadAudioFile) {
      alert('Harap isi Judul Lagu dan pilih File Audio Instrumen (.mp3, .m4a, .wav)!');
      return;
    }

    try {
      setIsUploading(true);

      // 1. Upload audio file
      const audioFormData = new FormData();
      audioFormData.append('file', uploadAudioFile);
      const audioRes = await fetch('/api/upload', {
        method: 'POST',
        body: audioFormData,
      });
      const audioData = await audioRes.json();
      if (!audioRes.ok || !audioData.url) {
        throw new Error('Gagal mengunggah file audio.');
      }

      // 2. Upload cover image if provided
      let coverUrl = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop';
      if (uploadCoverFile) {
        const coverFormData = new FormData();
        coverFormData.append('file', uploadCoverFile);
        const coverRes = await fetch('/api/upload', {
          method: 'POST',
          body: coverFormData,
        });
        const coverData = await coverRes.json();
        if (coverRes.ok && coverData.url) {
          coverUrl = coverData.url;
        }
      }

      // 3. Parse optional lyrics text
      const parseTimestamp = (timeStr: string): number => {
        const cleaned = timeStr.trim().replace(',', '.');
        const parts = cleaned.split(':');
        if (parts.length === 3) {
          const hrs = parseInt(parts[0], 10);
          const mins = parseInt(parts[1], 10);
          const secs = parseFloat(parts[2]);
          return hrs * 3600 + mins * 60 + secs;
        } else if (parts.length === 2) {
          const mins = parseInt(parts[0], 10);
          const secs = parseFloat(parts[1]);
          return mins * 60 + secs;
        } else if (parts.length === 1) {
          return parseFloat(parts[0]) || 0;
        }
        return 0;
      };

      const lyricsLines = uploadLyricsText
        .split('\n')
        .map((line) => line.trim())
        .filter(Boolean)
        .map((line, idx) => {
          // 1. Try to match the range format [MM:SS.SSS --> MM:SS.SSS] or similar
          const rangeMatch = line.match(/^\[?\s*([^\]\-]+?)\s*-->\s*([^\]\-]+?)\s*\]?\s*(.*)/);
          if (rangeMatch) {
            const startTime = parseTimestamp(rangeMatch[1]);
            const endTime = parseTimestamp(rangeMatch[2]);
            return { time: startTime, endTime, text: rangeMatch[3] || '...' };
          }

          // 2. Try simple LRC match: [MM:SS.SS] text or [MM:SS] text
          const simpleMatch = line.match(/^\[?\s*([^\]]+?)\s*\]\s*(.*)/);
          if (simpleMatch) {
            const startTime = parseTimestamp(simpleMatch[1]);
            return { time: startTime, text: simpleMatch[2] || '...' };
          }

          // 3. Fallback
          return { time: idx * 4, text: line };
        });

      // 4. Save song metadata via API
      const newSongPayload = {
        title: uploadTitle.trim(),
        artist: uploadArtist.trim() || 'Artis Saya',
        coverUrl,
        audioUrl: audioData.url,
        tags: ['Instrumen Real', 'Custom'],
        lyrics: lyricsLines.length > 0 ? lyricsLines : [
          { time: 0, text: `${uploadTitle.trim()} - ${uploadArtist.trim() || 'Artis Saya'}` },
          { time: 4, text: 'Nikmati musik instrumen Anda!' }
        ],
      };

      const songRes = await fetch('/api/songs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(newSongPayload),
      });

      if (!songRes.ok) {
        throw new Error('Gagal menyimpan data lagu.');
      }

      const createdSong = await songRes.json();

      // Reset form & close modal
      setUploadTitle('');
      setUploadArtist('');
      setUploadAudioFile(null);
      setUploadCoverFile(null);
      setUploadLyricsText('');
      setIsUploadSongModalOpen(false);

      await loadData();
      alert(`Lagu "${createdSong.title}" berhasil diunggah dan disimpan ke Storage Admin!`);
    } catch (err: any) {
      alert(err.message || 'Terjadi kesalahan saat mengunggah lagu.');
    } finally {
      setIsUploading(false);
    }
  };

  const handleDeleteSong = async (songId: string, songTitle: string) => {
    if (!confirm(`Hapus lagu "${songTitle}" dari katalog storage?`)) return;
    try {
      const res = await fetch(`/api/songs/${songId}`, { method: 'DELETE' });
      if (res.ok) {
        await loadData();
        alert('Lagu berhasil dihapus.');
      } else {
        alert('Gagal menghapus lagu.');
      }
    } catch (e) {
      console.error(e);
      alert('Terjadi kesalahan saat menghapus lagu.');
    }
  };

  useEffect(() => {
    loadData();
  }, []);

  // Audio setup for both playbacks
  const stopAllAudio = () => {
    if (audioPlayerRef.current) {
      audioPlayerRef.current.pause();
      audioPlayerRef.current = null;
    }
    WebAudioEngineService.getInstance().stop();
    setPlayingSongId(null);
    setPlayingFeedId(null);
    setIsPlaying(false);
  };

  const handlePlayPauseSong = (song: Song) => {
    if (playingSongId === song.id) {
      if (isPlaying) {
        audioPlayerRef.current?.pause();
        setIsPlaying(false);
      } else {
        audioPlayerRef.current?.play();
        setIsPlaying(true);
      }
    } else {
      stopAllAudio();
      const audioUrl = song.audioUrl;
      const audio = new Audio(audioUrl);
      audioPlayerRef.current = audio;
      setPlayingSongId(song.id);
      setIsPlaying(true);

      audio.addEventListener('timeupdate', () => {
        setCurrentTime(audio.currentTime);
      });
      audio.addEventListener('loadedmetadata', () => {
        setDuration(audio.duration || 180);
      });
      audio.addEventListener('ended', () => {
        setIsPlaying(false);
        setPlayingSongId(null);
      });

      audio.play().catch(e => console.error("Error playing audio:", e));
    }
  };

  const handlePlayPauseFeed = (recording: Recording) => {
    const audioSrc = recording.audioUrl || recording.song?.audioUrl;
    if (!audioSrc) return;

    if (playingFeedId === recording.id) {
      if (isPlaying) {
        audioPlayerRef.current?.pause();
        setIsPlaying(false);
      } else {
        audioPlayerRef.current?.play();
        setIsPlaying(true);
      }
    } else {
      stopAllAudio();
      const audio = new Audio(audioSrc);
      audioPlayerRef.current = audio;
      setPlayingFeedId(recording.id);
      setIsPlaying(true);

      audio.addEventListener('ended', () => {
        setIsPlaying(false);
        setPlayingFeedId(null);
      });

      audio.play().catch(e => console.error("Error playing feed item:", e));
    }
  };

  // Recording actions
  const startRecordingScreen = async (song: Song) => {
    stopAllAudio();
    setSelectedSong(song);
    setCurrentScreen('record');
    setRecordingSaved(false);
    setScore(0);
    setCurrentTime(0);
    setActiveLyricIndex(-1);
    recordedChunksRef.current = [];
    setRecordedVocalBlob(null);

    // 1. Immediately initialize and start playing instrumental audio in user gesture context
    const audio = new Audio(song.audioUrl);
    audio.volume = musicVolume / 100;
    audioPlayerRef.current = audio;
    setPlayingSongId(song.id);
    setIsPlaying(true);

    audio.addEventListener('timeupdate', () => {
      if (!audioPlayerRef.current) return;
      const current = audio.currentTime;
      setCurrentTime(current);

      // Match synced lyrics
      if (song.lyrics && song.lyrics.length > 0) {
        let matchIndex = -1;
        for (let i = 0; i < song.lyrics.length; i++) {
          if (song.lyrics[i].time <= current) {
            matchIndex = i;
          } else {
            break;
          }
        }
        if (matchIndex !== -1) {
          setActiveLyricIndex(matchIndex);
        }
      }

      // Calculate singing score progression
      const calculatedScore = Math.floor((current / (audio.duration || 180)) * 100);
      setScore(Math.min(calculatedScore, 100));
    });

    audio.addEventListener('loadedmetadata', () => {
      setDuration(audio.duration || 120);
    });

    audio.addEventListener('ended', () => {
      setIsPlaying(false);
      handleEndRecording(audio.duration || 120);
    });

    // Play instrumental track immediately
    audio.play().catch(e => {
      console.warn("Autoplay deferred or error starting record audio:", e);
    });

    // 2. Request real microphone stream & initialize MediaRecorder
    try {
      if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
        setMicStatusText('Menghubungkan mikrofon...');
        const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
        micStreamRef.current = stream;

        let mimeType = '';
        if (MediaRecorder.isTypeSupported('audio/webm;codecs=opus')) mimeType = 'audio/webm;codecs=opus';
        else if (MediaRecorder.isTypeSupported('audio/webm')) mimeType = 'audio/webm';
        else if (MediaRecorder.isTypeSupported('audio/mp4')) mimeType = 'audio/mp4';

        const recorder = new MediaRecorder(stream, mimeType ? { mimeType } : undefined);
        mediaRecorderRef.current = recorder;

        recorder.ondataavailable = (e) => {
          if (e.data && e.data.size > 0) {
            recordedChunksRef.current.push(e.data);
          }
        };

        recorder.start(100);
        setIsMicRecording(true);
        setMicStatusText('🎙️ Mikrofon Aktif - Merekam Suara Anda!');
      } else {
        setMicStatusText('⚠️ Mikrofon tidak didukung browser ini');
        setIsMicRecording(false);
      }
    } catch (err) {
      console.warn("Akses mikrofon tidak diizinkan atau tidak ditemukan:", err);
      setMicStatusText('⚠️ Mikrofon tidak diizinkan / tidak ada mic');
      setIsMicRecording(false);
    }
  };

  const handleEndRecording = async (forcedDuration?: number) => {
    // Save final recording progress score
    const finalScore = score > 10 ? score : Math.floor(72 + Math.random() * 25);
    setScore(finalScore);

    const recDuration = forcedDuration && forcedDuration > 0 ? forcedDuration : (currentTime > 0 ? currentTime : 120);

    // Stop MediaRecorder and close mic stream
    let vocalBlob: Blob | null = null;
    if (mediaRecorderRef.current && mediaRecorderRef.current.state !== 'inactive') {
      try {
        mediaRecorderRef.current.stop();
      } catch (e) {
        console.warn(e);
      }
    }
    if (micStreamRef.current) {
      micStreamRef.current.getTracks().forEach(track => track.stop());
      micStreamRef.current = null;
    }
    setIsMicRecording(false);

    if (recordedChunksRef.current.length > 0) {
      const type = recordedChunksRef.current[0].type || 'audio/webm';
      vocalBlob = new Blob(recordedChunksRef.current, { type });
      setRecordedVocalBlob(vocalBlob);
      console.log(`[APP] Mic recorded vocal Blob ready! Size: ${(vocalBlob.size / 1024).toFixed(1)} KB`);
    }

    // Stop current recorder-mode audio
    stopAllAudio();
    setIsPlaying(false);
    
    // Transition viewport to the Mixing page
    setCurrentScreen('mixing');
    
    // Initialize Web Audio Engine for the mixing screen
    if (selectedSong) {
      setPlayingSongId(selectedSong.id);
      setCurrentTime(0);

      const engine = WebAudioEngineService.getInstance();
      const dur = await engine.loadAudioFromUrl(selectedSong.audioUrl);

      // Attach microphone recording if available
      if (vocalBlob && vocalBlob.size > 0) {
        await engine.loadRecordedVocalFromBlob(vocalBlob, recDuration);
      }

      const finalDur = recDuration > 0 ? recDuration : (dur || 120);
      engine.setTotalDuration(finalDur);
      setDuration(finalDur);

      engine.setVocalVolume(vocalVolume);
      engine.setMusicVolume(musicVolume);
      engine.setLatencyOffset(latencyOffset);
      engine.setPreset(selectedPreset);
      engine.setAutoTuneMode(autoTuneMode);
      engine.setProTuningActive(isProTuningActive);
      engine.setReverbMix(reverbMix);
      engine.setDelayMix(delayMix);

      engine.setOnTimeUpdate((current, d) => {
        setCurrentTime(current);
        if (d > 0) setDuration(d);
      });

      engine.setOnEnded(() => {
        setIsPlaying(false);
      });

      await engine.play(0);
      setIsPlaying(true);
    }
  };

  const handleRestartRecording = async () => {
    setCurrentTime(0);
    setActiveLyricIndex(-1);
    setScore(0);
    if (currentScreen === 'mixing') {
      const engine = WebAudioEngineService.getInstance();
      await engine.resumeContext();
      engine.seek(0);
      if (!engine.getIsPlaying()) {
        await engine.play(0);
        setIsPlaying(true);
      }
    } else if (audioPlayerRef.current) {
      audioPlayerRef.current.currentTime = 0;
      audioPlayerRef.current.volume = musicVolume / 100;
      if (!isPlaying) {
        audioPlayerRef.current.play().catch(e => console.error(e));
        setIsPlaying(true);
      }
    }
  };

  const handleRecordPlayPause = async () => {
    if (currentScreen === 'mixing') {
      const engine = WebAudioEngineService.getInstance();
      await engine.resumeContext();
      if (engine.getIsPlaying()) {
        engine.pause();
        setIsPlaying(false);
      } else {
        await engine.play();
        setIsPlaying(true);
      }
      return;
    }

    if (!audioPlayerRef.current) return;
    if (isPlaying) {
      audioPlayerRef.current.pause();
      if (mediaRecorderRef.current && mediaRecorderRef.current.state === 'recording') {
        try {
          mediaRecorderRef.current.pause();
        } catch (e) { console.warn(e); }
      }
      setIsPlaying(false);
    } else {
      audioPlayerRef.current.volume = musicVolume / 100;
      audioPlayerRef.current.play().catch(e => console.error(e));
      if (mediaRecorderRef.current) {
        if (mediaRecorderRef.current.state === 'paused') {
          try {
            mediaRecorderRef.current.resume();
          } catch (e) { console.warn(e); }
        } else if (mediaRecorderRef.current.state === 'inactive' && micStreamRef.current) {
          try {
            mediaRecorderRef.current.start(100);
          } catch (e) { console.warn(e); }
        }
      }
      setIsPlaying(true);
    }
  };

  // Submit recorded song back to server from the mixing screen
  const finishAndSaveRecording = async (isDraftMode = false) => {
    if (!selectedSong) return;
    setIsSaving(true);

    try {
      const finalScore = score > 10 ? score : Math.floor(75 + Math.random() * 20);
      
      let finalAudioUrl = selectedSong.audioUrl;
      try {
        const exportedWavBlobUrl = await WebAudioEngineService.getInstance().exportMix();
        
        // Upload the mixed audio blob to backend server storage
        const resBlob = await fetch(exportedWavBlobUrl);
        const wavBlob = await resBlob.blob();
        const file = new File([wavBlob], `recording_${Date.now()}.wav`, { type: 'audio/wav' });

        const formData = new FormData();
        formData.append('file', file);
        const uploadRes = await fetch('/api/upload', {
          method: 'POST',
          body: formData,
        });
        const uploadData = await uploadRes.json();
        if (uploadRes.ok && uploadData.url) {
          finalAudioUrl = uploadData.url;
        } else {
          finalAudioUrl = exportedWavBlobUrl;
        }
      } catch (e) {
        console.warn('Offline export fallback to original:', e);
      }

      const payload = {
        songId: selectedSong.id,
        audioUrl: finalAudioUrl,
        score: finalScore,
        vocalVolume,
        musicVolume,
        latencyOffset,
        selectedPreset,
        autoTuneMode,
        isProTuningActive,
        captionText,
        isPrivate,
        isDraft: isDraftMode
      };

      const res = await fetch('/api/recordings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(payload)
      });

      if (res.ok) {
        setRecordingSaved(true);
        await loadData();
        
        stopAllAudio();
        setIsPlaying(false);
        setCurrentScreen('main');
        setActiveTab('browse');
      }
    } catch (e) {
      console.error("Error submitting recording:", e);
    } finally {
      setIsSaving(false);
    }
  };

  // Like recording interaction
  const handleLike = (id: string) => {
    setLikedIds(prev => {
      const next = new Set(prev);
      if (next.has(id)) {
        next.delete(id);
      } else {
        next.add(id);
      }
      return next;
    });

    setFeed(prev => prev.map(item => {
      if (item.id === id) {
        const hasLiked = likedIds.has(id);
        return { 
          ...item, 
          likesCount: hasLiked ? item.likesCount - 1 : item.likesCount + 1 
        };
      }
      return item;
    }));
  };

  // Automatic scroll on lyric container
  useEffect(() => {
    if (lyricsScrollRef.current && activeLyricIndex !== -1) {
      const lyricElement = lyricsScrollRef.current.children[activeLyricIndex] as HTMLElement;
      if (lyricElement) {
        lyricsScrollRef.current.scrollTo({
          top: lyricElement.offsetTop - lyricsScrollRef.current.clientHeight / 2 + lyricElement.clientHeight / 2,
          behavior: 'smooth'
        });
      }
    }
  }, [activeLyricIndex]);

  return (
    <div className="min-h-screen bg-[#09090b] text-white flex flex-col items-center justify-start p-0 md:p-6 select-none font-sans">
      
      {/* Simulation Toggle and Action Bar */}
      <div className="w-full max-w-lg hidden md:flex items-center justify-between gap-4 mb-4 px-4 py-2 border border-neutral-800 rounded-xl bg-neutral-950/80 backdrop-blur-md">
        <div className="flex items-center gap-2">
          <div className="w-6 h-6 rounded-md bg-red-600 flex items-center justify-center">
            <Music className="w-3.5 h-3.5 text-white" />
          </div>
          <span className="text-xs font-semibold text-neutral-300">WeSing Flutter Client Simulator</span>
        </div>
        
        <button
          onClick={() => setUsePhoneFrame(!usePhoneFrame)}
          className="flex items-center gap-1.5 px-2.5 py-1 bg-neutral-900 hover:bg-neutral-800 rounded-lg text-[11px] font-medium border border-neutral-800 transition-all cursor-pointer"
        >
          {usePhoneFrame ? (
            <>
              <Monitor className="w-3 h-3 text-neutral-400" />
              <span>Full Width View</span>
            </>
          ) : (
            <>
              <Smartphone className="w-3 h-3 text-red-500" />
              <span>Phone Frame View</span>
            </>
          )}
        </button>
      </div>

      {/* Main Container */}
      <div className={`w-full transition-all duration-300 flex items-center justify-center ${usePhoneFrame ? 'max-w-md' : 'max-w-xl'}`}>
        
        {/* Device Frame */}
        <div className={`w-full relative bg-black shadow-2xl transition-all duration-300 ${
          usePhoneFrame 
            ? 'rounded-[44px] overflow-hidden border-[10px] border-neutral-900 aspect-[9/19] h-[820px]' 
            : 'rounded-none md:rounded-2xl border-0 md:border md:border-neutral-800 min-h-screen md:min-h-[750px] md:h-[750px]'
        } flex flex-col`}>
          
          {/* Virtual Notch & Status bar for mobile mockup */}
          {usePhoneFrame && (
            <div className="h-10 bg-black z-40 flex items-center justify-between px-8 text-[11px] font-medium text-neutral-400 shrink-0 select-none">
              <span>19:45</span>
              <div className="w-24 h-4 bg-neutral-950 rounded-full border border-neutral-900 absolute left-1/2 -translate-x-1/2 top-2 flex items-center justify-center">
                <span className="w-1.5 h-1.5 rounded-full bg-neutral-800" />
              </div>
              <div className="flex items-center gap-1.5">
                <span className="text-[9px]">5G</span>
                <div className="w-4 h-2.5 border border-neutral-700 rounded-sm p-0.5 flex items-center">
                  <div className="h-full w-2.5 bg-red-500 rounded-2xs" />
                </div>
              </div>
            </div>
          )}

          {/* Core Viewport area matching the client look */}
          <div className="flex-1 bg-black flex flex-col relative overflow-hidden">
            <AnimatePresence mode="wait">
              
              {currentScreen === 'main' ? (
                // MAIN APP TABS SCREEN
                <motion.div
                  key="main-screen"
                  initial={{ opacity: 0 }}
                  animate={{ opacity: 1 }}
                  exit={{ opacity: 0 }}
                  className="flex-1 flex flex-col h-full"
                >
                  
                  {/* Feed Tab View */}
                  {activeTab === 'browse' && (
                    <div className="flex-1 flex flex-col h-full overflow-hidden">
                      {/* Pure Black Header */}
                      <div className="h-14 px-4 border-b border-[#222] bg-black flex items-center justify-between shrink-0">
                        <button
                          onClick={() => {
                            setAdminTab('upload');
                            setIsUploadSongModalOpen(true);
                          }}
                          className="px-2.5 py-1 rounded-full bg-neutral-900 border border-[#e67e22]/50 text-[#e67e22] text-[10px] font-extrabold flex items-center gap-1 hover:bg-[#e67e22]/20 transition-all cursor-pointer shadow-sm active:scale-95"
                          title="Panel Admin untuk upload & kelola lagu"
                        >
                          <UploadCloud className="w-3.5 h-3.5" />
                          <span>Admin</span>
                        </button>
                        <span className="text-base font-bold text-white text-center">WeSing MVP</span>
                        <button onClick={loadData} className="p-1 text-neutral-400 hover:text-white transition-all cursor-pointer" title="Refresh Feed">
                          <RefreshCw className="w-4 h-4" />
                        </button>
                      </div>

                      {/* Scrollable Feed List */}
                      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-6 custom-scrollbar bg-black">
                        {isLoadingFeed ? (
                          <div className="py-24 flex flex-col items-center justify-center gap-3">
                            <div className="w-6 h-6 border-2 border-red-500 border-t-transparent rounded-full animate-spin" />
                            <span className="text-xs text-neutral-500">Memuat rekaman feed...</span>
                          </div>
                        ) : feed.length === 0 ? (
                          <div className="py-24 text-center text-neutral-500">
                            <Mic className="w-12 h-12 text-neutral-800 mx-auto mb-3 opacity-50" />
                            <p className="text-sm px-6 leading-relaxed">Belum ada rekaman yang diposting. Mulai bernyanyi di menu Discover!</p>
                          </div>
                        ) : (
                          feed.map((item) => {
                            const isPlayingFeed = playingFeedId === item.id;
                            const isLiked = likedIds.has(item.id);
                            return (
                              <div key={item.id} className="border-b border-[#222] pb-6 last:border-b-0">
                                {/* User Info Row */}
                                <div className="flex items-center mb-3">
                                  <img 
                                    src={item.user?.avatar || "https://i.pravatar.cc/150?u=user"} 
                                    alt="avatar" 
                                    className="w-10 h-10 rounded-full mr-3 border border-neutral-800"
                                    referrerPolicy="no-referrer"
                                  />
                                  <div className="text-left">
                                    <h4 className="text-sm font-bold text-white leading-tight">
                                      {item.user?.username || 'Pengguna'}
                                    </h4>
                                    <p className="text-[11px] text-[#888] mt-0.5">
                                      Level {item.user?.level || 1} Artist
                                    </p>
                                  </div>
                                </div>

                                {/* 1:1 Aspect Ratio Cover Card */}
                                <div className="relative w-full aspect-square rounded-2xl overflow-hidden bg-[#111] mb-3 group">
                                  <img 
                                    src={item.song?.coverUrl || "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop"} 
                                    alt="song-cover" 
                                    className="w-full h-full object-cover opacity-60 group-hover:scale-102 transition-transform duration-500"
                                    referrerPolicy="no-referrer"
                                  />
                                  
                                  {/* Center Translucent Play Button */}
                                  <div className="absolute inset-0 flex items-center justify-center">
                                    <button
                                      onClick={() => handlePlayPauseFeed(item)}
                                      className="w-16 h-16 rounded-full bg-white/30 hover:bg-white/40 border border-white/20 flex items-center justify-center transition-all cursor-pointer backdrop-blur-sm shadow-xl active:scale-95"
                                    >
                                      {isPlayingFeed && isPlaying ? (
                                        <Pause className="w-7 h-7 text-white fill-white" />
                                      ) : (
                                        <Play className="w-7 h-7 text-white fill-white ml-1" />
                                      )}
                                    </button>
                                  </div>

                                  {/* Bottom Absolute Title and Score */}
                                  <div className="absolute bottom-4 left-4 right-4 text-left">
                                    <h5 className="text-lg font-bold text-white truncate shadow-sm leading-snug">
                                      {item.song?.title}
                                    </h5>
                                    <p className="text-[#ef4444] font-bold text-sm mt-1">
                                      {item.score} Score
                                    </p>
                                  </div>
                                </div>

                                {/* Interactivity row below card */}
                                <div className="flex items-center">
                                  <button 
                                    onClick={() => handleLike(item.id)}
                                    className={`flex items-center mr-6 text-sm cursor-pointer transition-colors ${
                                      isLiked ? 'text-red-500' : 'text-white hover:text-red-500'
                                    }`}
                                  >
                                    <Heart className={`w-6 h-6 mr-2 ${isLiked ? 'fill-current' : ''}`} />
                                    <span>{item.likesCount}</span>
                                  </button>

                                  <div className="flex items-center text-white text-sm">
                                    <MessageCircle className="w-6 h-6 mr-2" />
                                    <span>{item.commentsCount}</span>
                                  </div>
                                </div>

                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
                  )}

                  {/* Discover Tab View */}
                  {activeTab === 'discover' && (
                    <div className="flex-1 flex flex-col h-full overflow-hidden bg-black">
                      {/* Left Aligned Big Title Header */}
                      <div className="px-4 py-4 border-b border-[#222] bg-black shrink-0">
                        <h2 className="text-2xl font-bold text-white text-left">Discover</h2>
                      </div>

                      {/* Song Catalog List */}
                      <div className="flex-1 overflow-y-auto px-4 py-4 space-y-3 custom-scrollbar bg-black">
                        {isLoadingSongs ? (
                          <div className="py-24 flex flex-col items-center justify-center gap-3">
                            <div className="w-6 h-6 border-2 border-red-500 border-t-transparent rounded-full animate-spin" />
                            <span className="text-xs text-neutral-500">Memuat daftar lagu...</span>
                          </div>
                        ) : (
                          songs.map((song) => {
                            const isPlayingSong = playingSongId === song.id;
                            return (
                              <div 
                                key={song.id} 
                                className="flex items-center bg-[#111] p-3 rounded-xl border border-transparent hover:border-neutral-800 transition-all"
                              >
                                {/* Cover art (50x50) */}
                                <img 
                                  src={song.coverUrl} 
                                  alt={song.title} 
                                  className="w-[50px] h-[50px] rounded-lg object-cover border border-neutral-800 shrink-0"
                                  referrerPolicy="no-referrer"
                                />

                                {/* Song Info block */}
                                <div className="flex-1 ml-3 min-w-0 text-left">
                                  <h4 className="text-base font-semibold text-white truncate leading-tight">
                                    {song.title}
                                  </h4>
                                  <p className="text-sm text-[#888] mt-1 truncate">
                                    {song.artist}
                                  </p>
                                </div>

                                {/* Action Buttons */}
                                <div className="flex items-center gap-2 shrink-0">
                                  {/* Play/Pause Button */}
                                  <button
                                    onClick={() => handlePlayPauseSong(song)}
                                    className={`w-10 h-10 rounded-full flex items-center justify-center transition-all cursor-pointer ${
                                      isPlayingSong && isPlaying 
                                        ? 'bg-[#ef4444] text-white' 
                                        : 'bg-[#333] text-white hover:bg-neutral-700'
                                    }`}
                                  >
                                    {isPlayingSong && isPlaying ? (
                                      <Pause className="w-4 h-4 text-white fill-white" />
                                    ) : (
                                      <Play className="w-4 h-4 text-white fill-white ml-0.5" />
                                    )}
                                  </button>

                                  {/* Sing Mic Button */}
                                  <button
                                    onClick={() => startRecordingScreen(song)}
                                    className="w-10 h-10 rounded-full bg-[#3b82f6] hover:bg-blue-500 transition-all text-white flex items-center justify-center cursor-pointer active:scale-95 shadow-md shadow-blue-900/10"
                                  >
                                    <Mic className="w-4 h-4 text-white" />
                                  </button>
                                </div>

                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
                  )}

                  {/* Messages Tab View */}
                  {activeTab === 'messages' && (
                    <div className="flex-1 flex flex-col h-full overflow-hidden bg-black">
                      {/* Left Aligned Big Title Header */}
                      <div className="px-4 py-4 border-b border-[#222] bg-black shrink-0">
                        <h2 className="text-2xl font-bold text-white text-left">Messages</h2>
                      </div>

                      {/* Chat List */}
                      <div className="flex-1 overflow-y-auto px-4 py-2 space-y-4 custom-scrollbar bg-black divide-y divide-[#222]">
                        <div className="flex items-center gap-3 pt-3 cursor-pointer hover:bg-neutral-900/40 p-2 rounded-xl transition-all">
                          <img src="https://i.pravatar.cc/150?u=riana" alt="Riana" className="w-12 h-12 rounded-full border border-neutral-800" referrerPolicy="no-referrer" />
                          <div className="flex-1 text-left">
                            <div className="flex justify-between items-center">
                              <h4 className="text-sm font-bold text-white">Riana</h4>
                              <span className="text-[10px] text-neutral-500">14:32</span>
                            </div>
                            <p className="text-xs text-neutral-400 mt-1 truncate">Wah, rekaman lagu barumu tadi suaranya merdu banget! 😍</p>
                          </div>
                        </div>

                        <div className="flex items-center gap-3 pt-3 cursor-pointer hover:bg-neutral-900/40 p-2 rounded-xl transition-all">
                          <img src="https://i.pravatar.cc/150?u=budi" alt="Budi" className="w-12 h-12 rounded-full border border-neutral-800" referrerPolicy="no-referrer" />
                          <div className="flex-1 text-left">
                            <div className="flex justify-between items-center">
                              <h4 className="text-sm font-bold text-white">Budi</h4>
                              <span className="text-[10px] text-neutral-500">Kemarin</span>
                            </div>
                            <p className="text-xs text-neutral-400 mt-1 truncate">Ayo duet di lagu "Separuh Aku" nanti malam!</p>
                          </div>
                        </div>

                        <div className="flex items-center gap-3 pt-3 cursor-pointer hover:bg-neutral-900/40 p-2 rounded-xl transition-all">
                          <img src="https://i.pravatar.cc/150?u=siti" alt="Siti" className="w-12 h-12 rounded-full border border-neutral-800" referrerPolicy="no-referrer" />
                          <div className="flex-1 text-left">
                            <div className="flex justify-between items-center">
                              <h4 className="text-sm font-bold text-white">Siti</h4>
                              <span className="text-[10px] text-neutral-500">Kemarin</span>
                            </div>
                            <p className="text-xs text-[#ef4444] mt-1 truncate font-medium">[Pemberitahuan] Kamu naik ke Level 5 Artist! 🎉</p>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Me (Profile) Tab View */}
                  {activeTab === 'me' && (
                    <div className="flex-1 flex flex-col h-full overflow-hidden bg-black">
                      {/* Left Aligned Header */}
                      <div className="px-4 py-4 border-b border-[#222] bg-black shrink-0">
                        <h2 className="text-2xl font-bold text-white text-left">Me</h2>
                      </div>

                      <div className="flex-1 overflow-y-auto custom-scrollbar bg-black">
                        {/* Profile Info Card */}
                        <div className="p-5 flex flex-col items-center text-center border-b border-[#222]">
                          <div className="relative">
                            <img 
                              src="https://i.pravatar.cc/150?u=nafisa" 
                              alt="Nafisa" 
                              className="w-20 h-20 rounded-full border-2 border-[#ef4444] object-cover shadow-lg"
                              referrerPolicy="no-referrer"
                            />
                            <div className="absolute -bottom-1 -right-1 bg-[#ef4444] text-white text-[9px] px-2 py-0.5 rounded-full font-bold uppercase tracking-wider">
                              Lv.5
                            </div>
                          </div>
                          
                          <h3 className="text-lg font-bold text-white mt-3">Nafisa</h3>
                          <p className="text-xs text-neutral-400 mt-1 px-4 leading-relaxed">
                            Pecinta musik & karaoke setiap hari 🎤 • Level 5 Artist
                          </p>

                          {/* Stats Grid */}
                          <div className="grid grid-cols-3 gap-8 mt-5 w-full max-w-xs">
                            <div className="flex flex-col items-center">
                              <span className="text-base font-bold text-white">1.2K</span>
                              <span className="text-[10px] text-neutral-500 uppercase font-semibold">Followers</span>
                            </div>
                            <div className="flex flex-col items-center">
                              <span className="text-base font-bold text-white">48</span>
                              <span className="text-[10px] text-neutral-500 uppercase font-semibold">Following</span>
                            </div>
                            <div className="flex flex-col items-center">
                              <span className="text-base font-bold text-white">1,000</span>
                              <span className="text-[10px] text-neutral-500 uppercase font-semibold">Coins</span>
                            </div>
                          </div>

                          {/* Admin Dashboard Action Button */}
                          <div className="w-full max-w-xs mt-5 pt-3 border-t border-neutral-900">
                            <button
                              onClick={() => {
                                setAdminTab('upload');
                                setIsUploadSongModalOpen(true);
                              }}
                              className="w-full py-2.5 px-3 rounded-xl bg-gradient-to-r from-[#e67e22]/20 via-amber-500/10 to-[#e67e22]/20 border border-[#e67e22]/50 text-[#e67e22] text-xs font-bold flex items-center justify-center gap-2 hover:bg-[#e67e22]/30 transition-all cursor-pointer shadow-md active:scale-98"
                            >
                              <UploadCloud className="w-4 h-4" />
                              <span>Panel Admin (Upload & Kelola Lagu)</span>
                            </button>
                          </div>
                        </div>

                        {/* My Recordings Title */}
                        <div className="px-4 py-3 bg-neutral-950 text-left border-b border-[#222]">
                          <span className="text-xs font-bold text-neutral-400 uppercase tracking-wider">My Recordings</span>
                        </div>

                        {/* Filtered recordings of Nafisa/user_1 */}
                        <div className="p-4 space-y-4">
                          {feed.filter(item => item.userId === "user_1").length === 0 ? (
                            <div className="py-12 text-center text-neutral-600">
                              <Mic className="w-8 h-8 mx-auto mb-2 opacity-50" />
                              <p className="text-xs">Kamu belum memiliki rekaman.</p>
                            </div>
                          ) : (
                            feed.filter(item => item.userId === "user_1").map(item => {
                              const isPlayingFeed = playingFeedId === item.id;
                              return (
                                <div key={item.id} className="flex items-center gap-3 bg-[#111] p-2.5 rounded-xl border border-neutral-900">
                                  <img 
                                    src={item.song?.coverUrl || "https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=100&h=100&fit=crop"} 
                                    alt="song-cover" 
                                    className="w-12 h-12 rounded-lg object-cover"
                                    referrerPolicy="no-referrer"
                                  />
                                  <div className="flex-1 text-left min-w-0">
                                    <h4 className="text-sm font-bold text-white truncate">{item.song?.title}</h4>
                                    <p className="text-[11px] text-[#ef4444] font-semibold mt-1">Score: {item.score} pts</p>
                                  </div>
                                  <button
                                    onClick={() => handlePlayPauseFeed(item)}
                                    className="w-9 h-9 rounded-full bg-neutral-800 hover:bg-neutral-700 flex items-center justify-center cursor-pointer"
                                  >
                                    {isPlayingFeed && isPlaying ? (
                                      <Pause className="w-3.5 h-3.5 text-white fill-white" />
                                    ) : (
                                      <Play className="w-3.5 h-3.5 text-white fill-white ml-0.5" />
                                    )}
                                  </button>
                                </div>
                              );
                            })
                          )}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* Bottom Navigation Tabs */}
                  <div className="h-16 border-t border-[#222] bg-black px-2 py-2 flex items-center justify-between shrink-0 select-none relative z-30">
                    {/* Tab: Browse */}
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setActiveTab('browse');
                      }}
                      className={`flex-1 flex flex-col items-center justify-center gap-1 transition-all cursor-pointer ${
                        activeTab === 'browse' ? 'text-[#ef4444]' : 'text-[#888] hover:text-neutral-300'
                      }`}
                    >
                      <Home className="w-5 h-5" />
                      <span className="text-[10px] font-medium">Browse</span>
                    </button>

                    {/* Tab: Discover */}
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setActiveTab('discover');
                      }}
                      className={`flex-1 flex flex-col items-center justify-center gap-1 transition-all cursor-pointer ${
                        activeTab === 'discover' ? 'text-[#ef4444]' : 'text-[#888] hover:text-neutral-300'
                      }`}
                    >
                      <Compass className="w-5 h-5" />
                      <span className="text-[10px] font-medium">Discover</span>
                    </button>

                    {/* Center Button: Red Mic Button */}
                    <div className="flex-1 flex items-center justify-center -mt-6">
                      <button
                        onClick={() => setIsSingDrawerOpen(true)}
                        className="w-12 h-12 rounded-full bg-[#ef4444] shadow-[0_0_15px_rgba(239,68,68,0.6)] flex items-center justify-center hover:scale-105 active:scale-95 transition-all cursor-pointer z-40"
                      >
                        <Mic className="w-5 h-5 text-white fill-white" />
                      </button>
                    </div>

                    {/* Tab: Messages */}
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setActiveTab('messages');
                      }}
                      className={`flex-1 flex flex-col items-center justify-center gap-1 transition-all cursor-pointer ${
                        activeTab === 'messages' ? 'text-[#ef4444]' : 'text-[#888] hover:text-neutral-300'
                      }`}
                    >
                      <MessageSquare className="w-5 h-5" />
                      <span className="text-[10px] font-medium">Messages</span>
                    </button>

                    {/* Tab: Me */}
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setActiveTab('me');
                      }}
                      className={`flex-1 flex flex-col items-center justify-center gap-1 transition-all cursor-pointer ${
                        activeTab === 'me' ? 'text-[#ef4444]' : 'text-[#888] hover:text-neutral-300'
                      }`}
                    >
                      <User className="w-5 h-5" />
                      <span className="text-[10px] font-medium">Me</span>
                    </button>
                  </div>

                  {/* Quick Sing Drawer */}
                  <AnimatePresence>
                    {isSingDrawerOpen && (
                      <>
                        {/* Backdrop */}
                        <motion.div
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 0.5 }}
                          exit={{ opacity: 0 }}
                          onClick={() => setIsSingDrawerOpen(false)}
                          className="absolute inset-0 bg-black z-45"
                        />
                        {/* Drawer Sheet */}
                        <motion.div
                          initial={{ y: "100%" }}
                          animate={{ y: 0 }}
                          exit={{ y: "100%" }}
                          transition={{ type: "spring", damping: 25, stiffness: 200 }}
                          className="absolute bottom-0 left-0 right-0 h-[60%] bg-[#0e0e10] border-t border-[#222] rounded-t-3xl z-50 flex flex-col overflow-hidden"
                        >
                          {/* Handle bar */}
                          <div className="w-12 h-1.5 bg-neutral-800 rounded-full mx-auto my-3 shrink-0" />
                          
                          {/* Header */}
                          <div className="px-4 pb-3 flex justify-between items-center shrink-0">
                            <span className="text-sm font-bold text-white truncate">Pilih Lagu Bernyanyi</span>
                            <button
                              onClick={() => setIsSingDrawerOpen(false)}
                              className="p-1.5 text-neutral-400 hover:text-white hover:bg-neutral-900 rounded-full transition-all"
                            >
                              <X className="w-4 h-4" />
                            </button>
                          </div>

                          {/* Quick Search */}
                          <div className="px-4 pb-3 shrink-0">
                            <div className="relative">
                              <Search className="absolute left-3 top-2.5 w-4 h-4 text-neutral-500" />
                              <input
                                type="text"
                                placeholder="Cari lagu..."
                                value={drawerSearch}
                                onChange={(e) => setDrawerSearch(e.target.value)}
                                className="w-full bg-[#16161a] border border-neutral-800 rounded-lg py-1.5 pl-9 pr-4 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-red-500 transition-colors"
                              />
                            </div>
                          </div>

                          {/* Scrollable list */}
                          <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-2.5 custom-scrollbar">
                            {songs.filter(s => s.title.toLowerCase().includes(drawerSearch.toLowerCase()) || s.artist.toLowerCase().includes(drawerSearch.toLowerCase())).length === 0 ? (
                              <div className="py-12 text-center text-neutral-600">
                                <span className="text-xs">Lagu tidak ditemukan</span>
                              </div>
                            ) : (
                              songs.filter(s => s.title.toLowerCase().includes(drawerSearch.toLowerCase()) || s.artist.toLowerCase().includes(drawerSearch.toLowerCase())).map((song) => (
                                <div 
                                  key={song.id} 
                                  className="flex items-center justify-between p-2.5 bg-[#141416] border border-neutral-900 hover:border-neutral-800 rounded-xl transition-all"
                                >
                                  <div className="flex items-center gap-3 min-w-0">
                                    <img src={song.coverUrl} alt={song.title} className="w-10 h-10 rounded-lg object-cover" referrerPolicy="no-referrer" />
                                    <div className="text-left min-w-0">
                                      <h4 className="text-xs font-bold text-white truncate">{song.title}</h4>
                                      <p className="text-[10px] text-neutral-400 truncate mt-0.5">{song.artist}</p>
                                    </div>
                                  </div>
                                  <button
                                    onClick={() => {
                                      setIsSingDrawerOpen(false);
                                      stopAllAudio();
                                      startRecordingScreen(song);
                                    }}
                                    className="px-3.5 py-1.5 rounded-full bg-[#3b82f6] hover:bg-blue-500 text-white text-[10px] font-bold flex items-center gap-1 cursor-pointer active:scale-95"
                                  >
                                    <Mic className="w-3 h-3 text-white" />
                                    <span>Mulai</span>
                                  </button>
                                </div>
                              ))
                            )}
                          </div>
                        </motion.div>
                      </>
                    )}
                  </AnimatePresence>

                </motion.div>
              ) : currentScreen === 'record' ? (
                // RECORDING SCREEN
                <motion.div
                  key="record-screen"
                  initial={{ opacity: 0, x: 100 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -100 }}
                  className="flex-1 flex flex-col h-full bg-gradient-to-b from-[#180a22] via-[#0b0617] to-[#04020a] relative text-white overflow-hidden select-none"
                >
                  {/* Sunset glowing flare overlay in top right */}
                  <div className="absolute top-[-10%] right-[-10%] w-[65%] h-[40%] bg-[radial-gradient(circle_at_center,rgba(230,126,34,0.18)_0%,transparent_70%)] blur-3xl pointer-events-none z-0" />
                  
                  {/* Header */}
                  <div className="h-14 px-4 bg-transparent flex items-center justify-between shrink-0 z-10 relative">
                    {/* Back Button */}
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setCurrentScreen('main');
                      }}
                      className="p-1.5 text-white/90 hover:text-white hover:bg-white/10 rounded-full transition-all cursor-pointer"
                    >
                      <ChevronLeft className="w-6 h-6" />
                    </button>

                    {/* Score / Grade Pills in center */}
                    <div className="flex items-center rounded-full bg-white/10 backdrop-blur-md border border-white/10 px-2 py-0.5 select-none overflow-hidden text-[11px] font-bold">
                      {/* Gold Disc Music icon */}
                      <div className="w-5 h-5 rounded-full bg-gradient-to-b from-yellow-300 to-amber-500 flex items-center justify-center shadow-sm shrink-0 mr-1.5">
                        <Music className="w-2.5 h-2.5 text-black" />
                      </div>
                      
                      {/* Small Waveform */}
                      <div className="flex items-center gap-[1px] h-3 mr-2">
                        <div className="w-[1.5px] h-2 bg-yellow-400 rounded-full animate-pulse" />
                        <div className="w-[1.5px] h-3 bg-yellow-300 rounded-full animate-pulse delay-75" />
                        <div className="w-[1.5px] h-1.5 bg-yellow-500 rounded-full animate-pulse delay-150" />
                      </div>

                      {/* Divider */}
                      <div className="w-[1px] h-3 bg-white/20 mr-2" />

                      {/* Grades segment */}
                      <div className="flex items-center gap-[2px]">
                        {['C', 'B', 'A', 'S', 'SS', 'SSS'].map((grade) => {
                          const activeGrade = score >= 90 ? 'SSS' : score >= 80 ? 'SS' : score >= 65 ? 'S' : score >= 50 ? 'A' : score >= 30 ? 'B' : 'C';
                          const isCurrent = grade === activeGrade;
                          return (
                            <div
                              key={grade}
                              className={`px-1.5 py-0.5 rounded-sm text-[9px] transition-all duration-300 ${
                                isCurrent
                                  ? 'bg-[#e67e22] text-white shadow-[0_0_6px_rgba(230,126,34,0.8)] font-black scale-110'
                                  : 'text-neutral-500 font-medium'
                              }`}
                            >
                              {grade}
                            </div>
                          );
                        })}
                      </div>
                    </div>

                    {/* More Button */}
                    <button className="p-1.5 text-white/90 hover:text-white hover:bg-white/10 rounded-full transition-all cursor-pointer">
                      <MoreHorizontal className="w-6 h-6" />
                    </button>
                  </div>

                  {/* Earphone Status Indicator & Warning Banner */}
                  <div className="mx-4 mb-2 z-10 shrink-0 relative">
                    {!isEarphoneConnected ? (
                      <div className="bg-amber-500/10 border border-amber-500/30 rounded-xl p-3 flex flex-col gap-2 shadow-lg backdrop-blur-md">
                        <div className="flex items-start gap-2">
                          <AlertTriangle className="w-4.5 h-4.5 text-amber-500 shrink-0 mt-0.5" />
                          <div className="flex-1">
                            <h4 className="text-xs font-bold text-amber-400">Earphone Tidak Terdeteksi</h4>
                            <p className="text-[10px] text-neutral-300 leading-relaxed mt-0.5">
                              Harap gunakan earphone untuk menghindari feedback mic dan kebocoran suara musik (bleeding) ke rekaman vokal mentah Anda, serta agar kompensasi latency offset berfungsi.
                            </p>
                          </div>
                        </div>
                        <button
                          onClick={() => setIsEarphoneConnected(true)}
                          className="w-full bg-amber-500 hover:bg-amber-600 text-black text-[10px] font-bold py-1.5 rounded-lg transition-all flex items-center justify-center gap-1.5 cursor-pointer active:scale-95 shadow-md"
                        >
                          <Headphones className="w-3.5 h-3.5" />
                          Simulasikan Hubungkan Earphone
                        </button>
                      </div>
                    ) : (
                      <div className="bg-emerald-500/15 border border-emerald-500/30 rounded-xl p-2.5 flex items-center justify-between shadow-lg backdrop-blur-md">
                        <div className="flex items-center gap-2">
                          <Headphones className="w-4.5 h-4.5 text-emerald-400 shrink-0" />
                          <div>
                            <span className="text-[10px] font-bold text-emerald-400 block">Earphone Terhubung (Mode Multi-Track Aktif)</span>
                            <span className="text-[9px] text-neutral-300 block leading-tight">Rekaman terpisah aktif • Latency Offset otomatis dikompensasi ({latencyOffset}ms)</span>
                          </div>
                        </div>
                        <button
                          onClick={() => setIsEarphoneConnected(false)}
                          className="bg-white/5 hover:bg-white/10 text-white border border-white/10 text-[9px] px-2 py-1 rounded-md transition-all cursor-pointer"
                        >
                          Lepas
                        </button>
                      </div>
                    )}
                  </div>

                  {/* Live Microphone Status Banner */}
                  <div className="mx-4 mb-2 z-10 shrink-0 relative">
                    <div className={`rounded-xl px-3 py-2 flex items-center justify-between border backdrop-blur-md transition-all ${
                      isMicRecording
                        ? 'bg-red-500/15 border-red-500/40 text-red-300 shadow-lg'
                        : 'bg-white/5 border-white/10 text-neutral-400'
                    }`}>
                      <div className="flex items-center gap-2">
                        <div className={`w-2.5 h-2.5 rounded-full ${isMicRecording ? 'bg-red-500 animate-pulse' : 'bg-neutral-500'}`} />
                        <span className="text-[11px] font-bold">{micStatusText}</span>
                      </div>
                      {isMicRecording && (
                        <span className="text-[9px] bg-red-500/30 text-red-300 border border-red-500/50 px-2 py-0.5 rounded-full font-black animate-pulse">
                          MEREKAM SUARA
                        </span>
                      )}
                    </div>
                  </div>

                  {/* High-Fidelity Scrolling Pitch Visualizer */}
                  <div className="shrink-0 relative z-10">
                    <PitchVisualizer 
                      isPlaying={isPlaying} 
                      currentTime={currentTime} 
                      duration={duration} 
                    />
                  </div>

                  {/* Progress details & pager dots */}
                  <div className="px-5 py-2.5 flex items-center justify-between text-neutral-400 shrink-0 z-10 relative">
                    <div className="flex items-center gap-2 text-xs font-bold text-[#f39c12]">
                      <span className="w-2 h-2 rounded-full bg-[#f39c12] animate-pulse" />
                      <span>{formatTime(currentTime)} / {formatTime(duration || 120)}</span>
                    </div>
                    
                    {/* Slide indicator dots */}
                    <div className="flex gap-1.5">
                      <div className="w-2 h-2 rounded-full bg-white" />
                      <div className="w-2 h-2 rounded-full bg-white/20" />
                    </div>
                  </div>

                  {/* Active Lyrics Block with Image-Matched Styling */}
                  <div className="flex-1 flex flex-col relative overflow-hidden px-6 py-2 z-10">
                    {/* Fading Gradients */}
                    <div className="absolute top-0 left-0 right-0 h-10 bg-gradient-to-b from-[#0b0617] to-transparent z-10 pointer-events-none" />
                    <div className="absolute bottom-0 left-0 right-0 h-10 bg-gradient-to-t from-[#04020a] to-transparent z-10 pointer-events-none" />

                    <div 
                      ref={lyricsScrollRef}
                      className="flex-1 overflow-y-auto py-16 px-2 text-center custom-scrollbar flex flex-col justify-center space-y-4"
                    >
                      {selectedSong?.lyrics && selectedSong.lyrics.length > 0 ? (
                        selectedSong.lyrics.map((line, idx) => {
                          const isActive = idx === activeLyricIndex;
                          const isPast = idx < activeLyricIndex;
                          const isNext = idx > activeLyricIndex && idx <= activeLyricIndex + 3;
                          const isFarFuture = idx > activeLyricIndex + 3;

                          let textColorClass = 'text-white/20 text-sm font-medium';
                          let transformClass = 'scale-95 opacity-50';

                          if (isActive) {
                            textColorClass = 'text-white text-xl md:text-2xl font-black drop-shadow-[0_2px_12px_rgba(255,255,255,0.65)]';
                            transformClass = 'scale-105 opacity-100 py-1';
                          } else if (isNext) {
                            textColorClass = 'text-[#f5a65b] text-base md:text-lg font-bold';
                            transformClass = 'scale-100 opacity-90';
                          } else if (isPast) {
                            textColorClass = 'text-white/25 text-xs md:text-sm font-semibold line-through decoration-white/10';
                            transformClass = 'scale-90 opacity-40';
                          } else if (isFarFuture) {
                            textColorClass = 'text-white/10 text-xs font-semibold';
                            transformClass = 'scale-90 opacity-20';
                          }

                          return (
                            <div 
                              key={idx} 
                              className={`flex items-center justify-center transition-all duration-500 ease-out ${transformClass}`}
                            >
                              <p className={`text-center tracking-wide leading-relaxed transition-all duration-500 ${textColorClass}`}>
                                {line.text}
                              </p>
                            </div>
                          );
                        })
                      ) : (
                        <p className="text-[#888] text-center mt-12">Tidak ada lirik tersedia</p>
                      )}
                    </div>
                  </div>

                  {/* Save feedback panel */}
                  {recordingSaved && (
                    <motion.div
                      initial={{ opacity: 0, y: 10 }}
                      animate={{ opacity: 1, y: 0 }}
                      className="mx-4 mb-2 p-3 bg-neutral-900/90 backdrop-blur border border-neutral-800 rounded-xl text-center shadow-xl z-20"
                    >
                      <p className="text-xs text-emerald-400 font-bold flex items-center justify-center gap-1">
                        <span>🎉 Rekaman berhasil disimpan!</span>
                      </p>
                      <p className="text-[10px] text-neutral-400 mt-1">Lagu rekaman Anda telah diunggah ke Community Feed.</p>
                      <button
                        onClick={() => {
                          stopAllAudio();
                          setCurrentScreen('main');
                          setActiveTab('me');
                        }}
                        className="mt-2 text-[10px] font-bold bg-[#ef4444] hover:bg-red-600 text-white px-3.5 py-1.5 rounded-full transition-all cursor-pointer"
                      >
                        Lihat di Community Feed
                      </button>
                    </motion.div>
                  )}

                  {/* Bottom Image-Matched Control Bar */}
                  <div className="h-28 px-6 bg-[#04020a]/80 backdrop-blur-md border-t border-white/5 flex items-center justify-between shrink-0 z-10 relative">
                    
                    {/* Penyanyi Button (Placeholder for new Singer feature) */}
                    <button 
                      onClick={() => setShowSingerModal(true)}
                      className="flex flex-col items-center justify-center gap-1 text-white/75 hover:text-white transition-colors cursor-pointer active:scale-95"
                    >
                      <div className={`w-11 h-11 rounded-full border flex items-center justify-center transition-colors ${showSingerModal ? 'bg-[#e67e22]/20 border-[#e67e22]' : 'bg-white/5 border-white/10 hover:bg-white/10'}`}>
                        <User className={`w-5 h-5 ${showSingerModal ? 'text-[#e67e22]' : 'text-white'}`} />
                      </div>
                      <span className="text-[10px] font-semibold text-neutral-400 tracking-wider">Penyanyi</span>
                    </button>

                    {/* Adjust Button (Mixer Trigger) */}
                    <button 
                      onClick={() => setShowAdjustmentDrawer(!showAdjustmentDrawer)}
                      className="flex flex-col items-center justify-center gap-1 text-white/75 hover:text-white transition-colors cursor-pointer active:scale-95"
                    >
                      <div className={`w-11 h-11 rounded-full border flex items-center justify-center transition-colors ${showAdjustmentDrawer ? 'bg-[#e67e22]/20 border-[#e67e22]' : 'bg-white/5 border-white/10 hover:bg-white/10'}`}>
                        <Sliders className={`w-5 h-5 ${showAdjustmentDrawer ? 'text-[#e67e22]' : 'text-white'}`} />
                      </div>
                      <span className="text-[10px] font-semibold text-neutral-400 tracking-wider">Adjust</span>
                    </button>

                    {/* Giant Recording Red Circle Button */}
                    <div className="flex items-center justify-center">
                      <button
                        onClick={handleRecordPlayPause}
                        className="w-[72px] h-[72px] rounded-full border-4 border-white/95 flex items-center justify-center p-1 cursor-pointer hover:scale-105 active:scale-95 transition-all shadow-[0_0_15px_rgba(239,68,68,0.4)] bg-transparent"
                      >
                        <div className="w-full h-full rounded-full bg-red-600 flex items-center justify-center hover:bg-red-500 transition-colors relative">
                          {isPlaying ? (
                            <Pause className="w-5 h-5 text-white fill-white" />
                          ) : (
                            <div className="w-5 h-5 rounded-full bg-white shadow-sm" />
                          )}
                        </div>
                      </button>
                    </div>

                    {/* Restart Button */}
                    <button 
                      onClick={handleRestartRecording}
                      className="flex flex-col items-center justify-center gap-1 text-white/75 hover:text-white transition-colors cursor-pointer active:scale-95"
                    >
                      <div className="w-11 h-11 rounded-full bg-white/5 border border-white/10 flex items-center justify-center hover:bg-white/10 transition-colors">
                        <RotateCcw className="w-5 h-5 text-white" />
                      </div>
                      <span className="text-[10px] font-semibold text-neutral-400 tracking-wider">Restart</span>
                    </button>

                    {/* End / Submit Button */}
                    <button 
                      onClick={() => handleEndRecording(currentTime)}
                      disabled={isSaving || recordingSaved}
                      className="flex flex-col items-center justify-center gap-1 text-white/75 hover:text-white transition-colors cursor-pointer active:scale-95 disabled:opacity-50"
                    >
                      <div className="w-11 h-11 rounded-full bg-white/5 border border-white/10 flex items-center justify-center hover:bg-white/10 transition-colors">
                        <CheckCircle className="w-5 h-5 text-white" />
                      </div>
                      <span className="text-[10px] font-semibold text-neutral-400 tracking-wider">End</span>
                    </button>

                  </div>

                  {/* Singer Feature Placeholder Modal */}
                  <AnimatePresence>
                    {showSingerModal && (
                      <>
                        <motion.div
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 0.5 }}
                          exit={{ opacity: 0 }}
                          onClick={() => setShowSingerModal(false)}
                          className="absolute inset-0 bg-black z-30 pointer-events-auto"
                        />
                        <motion.div
                          initial={{ scale: 0.9, opacity: 0 }}
                          animate={{ scale: 1, opacity: 1 }}
                          exit={{ scale: 0.9, opacity: 0 }}
                          className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-[#0c0817] border border-white/10 rounded-2xl p-5 z-40 w-[85%] max-w-sm text-center shadow-2xl space-y-4"
                        >
                          <div className="w-12 h-12 rounded-full bg-[#e67e22]/20 border border-[#e67e22] flex items-center justify-center mx-auto text-[#e67e22]">
                            <User className="w-6 h-6" />
                          </div>
                          <div>
                            <h3 className="text-sm font-extrabold text-white">Fitur Penyanyi</h3>
                            <p className="text-xs text-neutral-400 mt-1">
                              Fitur Penyanyi baru dalam tahap pengembangan. Pengaturan suara & volume dapat dilakukan langsung via tombol <strong>Adjust</strong>.
                            </p>
                          </div>
                          <button
                            onClick={() => setShowSingerModal(false)}
                            className="w-full py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white font-bold text-xs transition-colors cursor-pointer"
                          >
                            Mengerti
                          </button>
                        </motion.div>
                      </>
                    )}
                  </AnimatePresence>

                  {/* Multi-Track Audio Mixer Drawer */}
                  <AnimatePresence>
                    {showAdjustmentDrawer && (
                      <>
                        {/* Backdrop blur */}
                        <motion.div
                          initial={{ opacity: 0 }}
                          animate={{ opacity: 0.5 }}
                          exit={{ opacity: 0 }}
                          onClick={() => setShowAdjustmentDrawer(false)}
                          className="absolute inset-0 bg-black z-30 pointer-events-auto"
                        />

                        {/* Drawer body */}
                        <motion.div
                          initial={{ y: "100%" }}
                          animate={{ y: 0 }}
                          exit={{ y: "100%" }}
                          transition={{ type: "spring", damping: 25, stiffness: 220 }}
                          className="absolute bottom-0 inset-x-0 bg-[#0c0817] border-t border-white/10 rounded-t-3xl p-5 z-40 pointer-events-auto shadow-2xl flex flex-col gap-5 text-white"
                        >
                          {/* Close indicator/handle */}
                          <div className="flex justify-between items-center pb-2 border-b border-white/5">
                            <div>
                              <h3 className="text-sm font-bold text-neutral-100 flex items-center gap-2">
                                <Sliders className="w-4 h-4 text-[#e67e22]" />
                                Audio Mixer (Volume Real-Time)
                              </h3>
                              <p className="text-[9px] text-neutral-400 mt-0.5 leading-normal">
                                Pengaturan volume diperbarui secara langsung saat slider digeser.
                              </p>
                            </div>
                            <button
                              onClick={() => setShowAdjustmentDrawer(false)}
                              className="p-1 rounded-full hover:bg-white/10 text-neutral-400 hover:text-white transition-all cursor-pointer"
                            >
                              <X className="w-5 h-5" />
                            </button>
                          </div>

                          {/* 1. Raw Vocal Volume Slider */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-200 flex items-center gap-1.5">
                                <Volume2 className="w-3.5 h-3.5 text-neutral-400" />
                                Volume Rekaman Vokal Mentah (Raw Voice)
                              </span>
                              <span className="font-bold text-[#e67e22]">{vocalVolume}%</span>
                            </div>
                            <input
                              type="range"
                              min="0"
                              max="150"
                              value={vocalVolume}
                              onChange={(e) => {
                                const val = parseInt(e.target.value);
                                setVocalVolume(val);
                                WebAudioEngineService.getInstance().setVocalVolume(val);
                              }}
                              className="w-full h-1.5 rounded-full bg-white/10 appearance-none cursor-pointer accent-[#e67e22]"
                            />
                            <p className="text-[8px] text-neutral-400 leading-none">
                              Volume track mikrofon vokal murni tanpa background musik.
                            </p>
                          </div>

                          {/* 2. Instrument Background Track Volume Slider */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-200 flex items-center gap-1.5">
                                <Music className="w-3.5 h-3.5 text-neutral-400" />
                                Volume Musik / Instrumen Pengiring
                              </span>
                              <span className="font-bold text-[#e67e22]">{musicVolume}%</span>
                            </div>
                            <input
                              type="range"
                              min="0"
                              max="120"
                              value={musicVolume}
                              onChange={(e) => {
                                const val = parseInt(e.target.value);
                                setMusicVolume(val);
                                WebAudioEngineService.getInstance().setMusicVolume(val);
                              }}
                              className="w-full h-1.5 rounded-full bg-white/10 appearance-none cursor-pointer accent-[#e67e22]"
                            />
                            <p className="text-[8px] text-neutral-400 leading-none">
                              Volume backtrack instrument pengiring lagu WeSing.
                            </p>
                          </div>

                          {/* Close / Done Action */}
                          <div className="flex gap-2 pt-1">
                            <button
                              onClick={() => {
                                setVocalVolume(100);
                                setMusicVolume(85);
                                WebAudioEngineService.getInstance().setVocalVolume(100);
                                WebAudioEngineService.getInstance().setMusicVolume(85);
                              }}
                              className="flex-1 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-bold text-neutral-300 transition-colors cursor-pointer active:scale-98"
                            >
                              Reset Default
                            </button>
                            <button
                              onClick={() => setShowAdjustmentDrawer(false)}
                              className="flex-1 py-2.5 rounded-xl bg-white/10 hover:bg-white/20 text-white border border-white/10 text-xs font-extrabold transition-colors cursor-pointer active:scale-98"
                            >
                              Tutup
                            </button>
                          </div>
                        </motion.div>
                      </>
                    )}
                  </AnimatePresence>

                </motion.div>
              ) : (
                // EDIT RECORDING / AUDIO MIXING SCREEN (WeSing style matching the screenshot)
                <motion.div
                  key="mixing-screen"
                  initial={{ opacity: 0, x: 100 }}
                  animate={{ opacity: 1, x: 0 }}
                  exit={{ opacity: 0, x: -100 }}
                  className="flex-1 flex flex-col h-full bg-[#05020c] text-white overflow-hidden select-none"
                >
                  {/* Glowing background elements to look ultra-premium */}
                  <div className="absolute top-0 left-0 w-full h-[50%] bg-gradient-to-b from-[#18082c] via-[#05020c] to-transparent opacity-50 z-0 pointer-events-none" />

                  {/* HEADER */}
                  <div className="h-14 px-4 bg-transparent flex items-center justify-between shrink-0 z-10 relative">
                    <button
                      onClick={() => {
                        stopAllAudio();
                        setIsPlaying(false);
                        setCurrentScreen('record');
                      }}
                      className="p-1.5 text-white/90 hover:text-white hover:bg-white/10 rounded-full transition-all cursor-pointer"
                    >
                      <ChevronLeft className="w-6 h-6" />
                    </button>

                    <div className="flex flex-col items-center">
                      <span className="text-[13px] font-extrabold tracking-wide text-white truncate max-w-[160px]">
                        {selectedSong ? selectedSong.title : 'Angels Brought Me Here'}
                      </span>
                      <div className="flex items-center gap-1 mt-0.5">
                        <span className="text-[10px] font-black text-[#e74c3c] bg-red-500/10 px-1.5 py-0.2 rounded border border-red-500/10">S</span>
                        <span className="text-[9px] font-bold text-neutral-400">Score: {score}</span>
                      </div>
                    </div>

                    <button className="p-1.5 text-white/95 hover:text-white hover:bg-white/10 rounded-full transition-all">
                      <MoreHorizontal className="w-5 h-5" />
                    </button>
                  </div>

                  {/* BODY AREA - Scrollable */}
                  <div className="flex-1 overflow-y-auto px-4 pb-6 space-y-4 z-10 relative custom-scrollbar">
                    {/* GALLERY / THEME CAROUSEL */}
                    <div className="pt-2">
                      <div className="flex gap-3 overflow-x-auto pb-2 snap-x px-1 scrollbar-none">
                        {/* Slide Templates */}
                        {[
                          { name: 'Warm Sunset', bg: 'bg-gradient-to-b from-orange-500/30 to-[#120822] border-orange-500/25', sticker: '☀️' },
                          { name: 'Neon City', bg: 'bg-gradient-to-b from-purple-500/30 to-[#040108] border-purple-500/25', sticker: '⚡' },
                          { name: 'Retro Vinyl', bg: 'bg-gradient-to-b from-teal-500/30 to-[#02050c] border-teal-500/25', sticker: '🎵' }
                        ].map((tpl, idx) => (
                          <div
                            key={idx}
                            onClick={() => setSelectedTemplateIndex(idx)}
                            className={`w-[210px] h-[190px] shrink-0 rounded-2xl border flex-col flex justify-between p-3.5 relative overflow-hidden transition-all snap-center cursor-pointer ${
                              selectedTemplateIndex === idx 
                                ? `${tpl.bg} ring-2 ring-[#ef4444] scale-[1.02]` 
                                : 'bg-[#121115]/80 border-[#222] hover:border-neutral-700 opacity-60'
                            }`}
                          >
                            {/* Overlay image/pattern background based on selected style */}
                            <div className="absolute inset-0 bg-black/10 z-0" />
                            
                            {/* Inner lyrics overlay */}
                            <div className="z-10 text-left">
                              <span className="text-[8px] uppercase tracking-wider text-white/40 font-bold">Preview Lyric Card</span>
                              <p className="text-sm font-extrabold text-white mt-1.5 leading-snug drop-shadow-md">
                                {idx === 0 && "It's been a long and winding journey..."}
                                {idx === 1 && "Shining like stars in the neon night..."}
                                {idx === 2 && "Feel the beat spinning in your heart..."}
                              </p>
                            </div>

                            {/* Stickers display inside current card if selected */}
                            <div className="absolute inset-0 z-20 pointer-events-none">
                              {selectedTemplateIndex === idx && addedStickers.map(st => (
                                <motion.div 
                                  key={st.id} 
                                  className="absolute text-2xl filter drop-shadow-lg select-none"
                                  style={{ left: `${st.x}%`, top: `${st.y}%` }}
                                  animate={{ scale: [1, 1.05, 1], rotate: [0, 5, -5, 0] }}
                                  transition={{ repeat: Infinity, duration: 4, ease: "easeInOut" }}
                                >
                                  {st.label}
                                </motion.div>
                              ))}
                            </div>

                            <div className="z-10 flex justify-between items-center mt-auto">
                              <span className="text-[9px] font-semibold text-white/50">{tpl.name}</span>
                              <div className="w-6 h-6 rounded-full bg-white/10 flex items-center justify-center hover:bg-white/20">
                                <span className="text-[10px]">📷</span>
                              </div>
                            </div>
                          </div>
                        ))}
                      </div>

                      {/* Customize Sticker Action Buttons */}
                      <div className="flex items-center justify-center gap-1.5 mt-2">
                        <span className="text-[10px] text-neutral-400">Click to add stickers:</span>
                        {['☀️', '🎵', '🔥', '🎤', '🌟'].map((stIcon, sIdx) => {
                          const hasSticker = addedStickers.some(s => s.label === stIcon);
                          return (
                            <button
                              key={sIdx}
                              onClick={() => {
                                if (hasSticker) {
                                  setAddedStickers(prev => prev.filter(s => s.label !== stIcon));
                                } else {
                                  const id = `sticker-${Date.now()}-${sIdx}`;
                                  const x = Math.floor(15 + Math.random() * 65);
                                  const y = Math.floor(25 + Math.random() * 50);
                                  setAddedStickers(prev => [...prev, { id, type: 'custom', label: stIcon, color: '#ffea00', x, y }]);
                                }
                              }}
                              className={`w-6 h-6 rounded-md flex items-center justify-center text-xs transition-all border ${
                                hasSticker ? 'bg-orange-500/20 border-orange-500 text-white' : 'bg-neutral-900 border-neutral-800 text-neutral-400 hover:border-neutral-700'
                              }`}
                            >
                              {stIcon}
                            </button>
                          );
                        })}
                      </div>
                    </div>

                    {/* TIMELINE / SEEK BAR SCRUBBER (WeSing Style) */}
                    <div className="py-2 px-1 space-y-2">
                      {/* Seek Bar Slider */}
                      <div className="relative group flex items-center h-5 w-full">
                        {/* Background track */}
                        <div className="absolute left-0 right-0 h-1 bg-white/10 rounded-full" />
                        
                        {/* Active Track Highlight */}
                        <div 
                          className="absolute left-0 h-1 bg-gradient-to-r from-red-600 to-[#e74c3c] rounded-full pointer-events-none"
                          style={{ width: `${duration > 0 ? (currentTime / duration) * 100 : 0}%` }}
                        />

                        {/* Interactive HTML5 slider superimposed perfectly */}
                        <input
                          type="range"
                          min={0}
                          max={duration || 100}
                          step={0.1}
                          value={currentTime}
                          onChange={(e) => {
                            const val = parseFloat(e.target.value);
                            setCurrentTime(val);
                            if (currentScreen === 'mixing') {
                              WebAudioEngineService.getInstance().seek(val);
                            } else if (audioPlayerRef.current) {
                              audioPlayerRef.current.currentTime = val;
                            }
                          }}
                          className="absolute left-0 right-0 w-full h-5 opacity-0 cursor-pointer z-10"
                        />

                        {/* Slider Handle (Thumb representation) */}
                        <div 
                          className="absolute w-3.5 h-3.5 bg-white rounded-full border-2 border-[#e74c3c] shadow-md transform -translate-x-1/2 pointer-events-none transition-transform group-hover:scale-125"
                          style={{ left: `${duration > 0 ? (currentTime / duration) * 100 : 0}%` }}
                        />
                      </div>

                      {/* Control Bar - matching WeSing capsule exactly */}
                      <div className="flex items-center justify-between mt-1">
                        {/* Floating Time Capsule */}
                        <div className="flex items-center gap-2.5 bg-[#120f18]/90 border border-white/5 rounded-full py-1.5 px-4 shadow-lg text-[11px] font-mono select-none">
                          <button
                            onClick={handleRecordPlayPause}
                            className="p-0.5 hover:scale-110 active:scale-90 transition-transform cursor-pointer"
                          >
                            {isPlaying ? (
                              <Pause className="w-3.5 h-3.5 text-white fill-white" />
                            ) : (
                              <Play className="w-3.5 h-3.5 text-white fill-white translate-x-0.5" />
                            )}
                          </button>
                          
                          <span className="text-white font-bold">
                            {Math.floor(currentTime / 60).toString().padStart(2, '0')}:{(Math.floor(currentTime % 60)).toString().padStart(2, '0')}
                          </span>
                          <span className="text-white/30 font-sans">/</span>
                          <span className="text-neutral-400">
                            {Math.floor(duration / 60).toString().padStart(2, '0')}:{(Math.floor(duration % 60)).toString().padStart(2, '0')}
                          </span>
                        </div>

                        {/* Quick Seek Buttons */}
                        <div className="flex items-center gap-1.5">
                          <button
                            onClick={() => {
                              const newTime = Math.max(0, currentTime - 10);
                              setCurrentTime(newTime);
                              if (currentScreen === 'mixing') {
                                WebAudioEngineService.getInstance().seek(newTime);
                              } else if (audioPlayerRef.current) {
                                audioPlayerRef.current.currentTime = newTime;
                              }
                            }}
                            className="text-[10px] font-black bg-[#120f18] hover:bg-neutral-800 border border-white/5 text-neutral-400 hover:text-white px-2.5 py-1.5 rounded-xl transition-all active:scale-95 cursor-pointer"
                          >
                            -10s
                          </button>
                          <button
                            onClick={() => {
                              const newTime = Math.min(duration, currentTime + 10);
                              setCurrentTime(newTime);
                              if (currentScreen === 'mixing') {
                                WebAudioEngineService.getInstance().seek(newTime);
                              } else if (audioPlayerRef.current) {
                                audioPlayerRef.current.currentTime = newTime;
                              }
                            }}
                            className="text-[10px] font-black bg-[#120f18] hover:bg-neutral-800 border border-white/5 text-neutral-400 hover:text-white px-2.5 py-1.5 rounded-xl transition-all active:scale-95 cursor-pointer"
                          >
                            +10s
                          </button>
                        </div>
                      </div>
                    </div>

                    {/* PRO-TUNING BANNER */}
                    <div className="bg-gradient-to-r from-amber-500/10 to-orange-500/10 border border-amber-500/20 rounded-2xl p-3.5 flex items-center justify-between shadow-lg">
                      <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-gradient-to-b from-amber-400 to-orange-500 flex items-center justify-center text-black shadow-md shrink-0">
                          <span className="font-black text-xs">VIP</span>
                        </div>
                        <div className="text-left">
                          <div className="flex items-center gap-1.5">
                            <span className="text-xs font-black text-white">Pro-tuning</span>
                            <span className="text-[8px] bg-amber-500/20 text-amber-400 px-1 rounded font-bold uppercase tracking-wider">Active</span>
                          </div>
                          <p className="text-[10px] text-neutral-400 mt-0.5">Vocal boost, compressor, and acoustic reverb room model</p>
                        </div>
                      </div>
                      <button 
                        onClick={() => {
                          const next = !isProTuningActive;
                          setIsProTuningActive(next);
                          WebAudioEngineService.getInstance().setProTuningActive(next);
                        }}
                        className={`text-[10px] font-black px-4 py-1.5 rounded-full transition-all border ${
                          isProTuningActive 
                            ? 'bg-amber-500 text-black border-amber-500 font-black' 
                            : 'bg-transparent text-white border-white/20 hover:border-white'
                        }`}
                      >
                        {isProTuningActive ? 'Active' : 'Use'}
                      </button>
                    </div>

                    {/* FILTER / PRESETS HORIZONTAL ROW */}
                    <div className="space-y-2">
                      <div className="flex items-center justify-between">
                        <span className="text-[10px] uppercase font-extrabold text-neutral-400 tracking-wider">Sound Effects Presets</span>
                        <button 
                          onClick={() => setShowAdjustSettings(!showAdjustSettings)}
                          className={`flex items-center gap-1.5 px-3 py-1 rounded-full text-[11px] font-extrabold border transition-all cursor-pointer active:scale-95 ${
                            showAdjustSettings 
                              ? 'bg-[#e74c3c] text-white border-[#e74c3c] shadow-[0_0_12px_rgba(231,76,60,0.4)]' 
                              : 'bg-[#110f15] border-white/10 text-neutral-400 hover:text-white hover:border-white/20'
                          }`}
                        >
                          <Sliders className="w-3.5 h-3.5" />
                          <span>Adjust</span>
                        </button>
                      </div>

                      <div className="flex gap-2.5 overflow-x-auto pb-1.5 snap-x px-0.5 scrollbar-none">
                        {[
                          { id: 'Warm', label: 'Warm', icon: Volume2, color: 'text-red-400' },
                          { id: 'Auto', label: 'Auto', icon: Music, color: 'text-blue-400' },
                          { id: 'AI Analytics', label: 'AI Analytics', icon: Sparkles, color: 'text-purple-400', vip: true },
                          { id: 'Talented', label: 'Talented', icon: Award, color: 'text-emerald-400' },
                          { id: 'Professional', label: 'Professional', icon: Play, color: 'text-cyan-400' },
                        ].map((preset) => {
                          const isActive = selectedPreset === preset.id;
                          const PresetIcon = preset.icon;
                          return (
                            <button
                              key={preset.id}
                              onClick={() => {
                                setSelectedPreset(preset.id);
                                WebAudioEngineService.getInstance().setPreset(preset.id);
                                if (preset.id === 'Warm') {
                                  setVocalVolume(95);
                                  setMusicVolume(80);
                                } else if (preset.id === 'Auto') {
                                  setVocalVolume(100);
                                  setMusicVolume(85);
                                  setAutoTuneMode('NATURAL');
                                } else if (preset.id === 'AI Analytics') {
                                  setVocalVolume(110);
                                  setMusicVolume(75);
                                  setIsProTuningActive(true);
                                  setAutoTuneMode('STRONG');
                                } else if (preset.id === 'Talented') {
                                  setVocalVolume(115);
                                  setMusicVolume(82);
                                  setAutoTuneMode('NATURAL');
                                } else if (preset.id === 'Professional') {
                                  setVocalVolume(100);
                                  setMusicVolume(90);
                                  setAutoTuneMode('OFF');
                                }
                              }}
                              className={`w-[85px] h-[85px] shrink-0 rounded-2xl flex flex-col justify-between p-3 text-left transition-all border snap-center ${
                                isActive 
                                  ? 'bg-[#e74c3c]/15 border-[#e74c3c] text-white ring-1 ring-[#e74c3c]/30' 
                                  : 'bg-[#110f15] border-[#222] text-neutral-400 hover:border-neutral-800'
                              }`}
                            >
                              <div className="flex justify-between items-start">
                                <PresetIcon className={`w-5 h-5 ${isActive ? 'text-[#e74c3c]' : 'text-neutral-400'}`} />
                                {preset.vip && (
                                  <span className="text-[7px] bg-purple-500 text-white font-extrabold px-1 rounded">VIP</span>
                                )}
                              </div>
                              <span className="text-[10px] font-bold tracking-tight truncate mt-auto">
                                {preset.label}
                              </span>
                            </button>
                          );
                        })}
                      </div>
                    </div>

                    {/* EXPANDABLE MIXING SLIDERS (CONTROLLED BY ADJUST BUTTON TOGGLE) */}
                    <AnimatePresence>
                      {showAdjustSettings && (
                        <motion.div
                          initial={{ opacity: 0, height: 0 }}
                          animate={{ opacity: 1, height: 'auto' }}
                          exit={{ opacity: 0, height: 0 }}
                          className="bg-[#110f15] border border-white/5 rounded-2xl p-4 space-y-4 text-left overflow-hidden"
                        >
                          {/* 1. Vocal Volume Slider */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-300 flex items-center gap-1.5">
                                <Mic className="w-3.5 h-3.5 text-[#e74c3c]" />
                                Volume Rekaman Vokal Mentah
                              </span>
                              <span className="font-bold text-[#e74c3c]">{vocalVolume}%</span>
                            </div>
                            <input
                              type="range"
                              min="0"
                              max="150"
                              value={vocalVolume}
                              onChange={(e) => {
                                const val = parseInt(e.target.value);
                                setVocalVolume(val);
                                WebAudioEngineService.getInstance().setVocalVolume(val);
                              }}
                              className="w-full h-1 rounded-full bg-white/10 appearance-none cursor-pointer accent-[#e74c3c]"
                            />
                            <p className="text-[8px] text-neutral-400 leading-none">
                              Volume track mikrofon vokal murni tanpa background musik.
                            </p>
                          </div>

                          {/* 2. Music Volume Slider */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-300 flex items-center gap-1.5">
                                <Music className="w-3.5 h-3.5 text-[#e74c3c]" />
                                Volume Musik / Instrumen Pengiring
                              </span>
                              <span className="font-bold text-[#e74c3c]">{musicVolume}%</span>
                            </div>
                            <input
                              type="range"
                              min="0"
                              max="120"
                              value={musicVolume}
                              onChange={(e) => {
                                const val = parseInt(e.target.value);
                                setMusicVolume(val);
                                WebAudioEngineService.getInstance().setMusicVolume(val);
                              }}
                              className="w-full h-1 rounded-full bg-white/10 appearance-none cursor-pointer accent-[#e74c3c]"
                            />
                            <p className="text-[8px] text-neutral-400 leading-none">
                              Volume backtrack instrument pengiring lagu WeSing.
                            </p>
                          </div>

                          {/* 3. AutoTune Mode Selector */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-300 flex items-center gap-1.5">
                                <Sparkles className="w-3.5 h-3.5 text-[#e74c3c]" />
                                AutoTune Mode (Pitch Correction)
                              </span>
                              <span className="font-bold text-[#e74c3c]">{autoTuneMode}</span>
                            </div>
                            <div className="flex gap-2">
                              {(['OFF', 'NATURAL', 'STRONG'] as AutoTuneMode[]).map((mode) => (
                                <button
                                  key={mode}
                                  onClick={() => {
                                    setAutoTuneMode(mode);
                                    WebAudioEngineService.getInstance().setAutoTuneMode(mode);
                                  }}
                                  className={`flex-1 py-1.5 rounded-lg text-[10px] font-bold border transition-all cursor-pointer ${
                                    autoTuneMode === mode
                                      ? 'bg-[#e74c3c] text-white border-[#e74c3c]'
                                      : 'bg-white/5 border-white/10 text-neutral-400 hover:text-white'
                                  }`}
                                >
                                  {mode}
                                </button>
                              ))}
                            </div>
                          </div>

                          {/* 5. Reverb Slider */}
                          <div className="flex flex-col gap-1.5">
                            <div className="flex justify-between items-center text-xs">
                              <span className="font-bold text-neutral-300 flex items-center gap-1.5">
                                <Volume2 className="w-3.5 h-3.5 text-[#e74c3c]" />
                                Reverb Echo / Acoustic Room
                              </span>
                              <span className="font-bold text-[#e74c3c]">{Math.round(reverbMix * 100)}%</span>
                            </div>
                            <input
                              type="range"
                              min="0"
                              max="1"
                              step="0.05"
                              value={reverbMix}
                              onChange={(e) => {
                                const val = parseFloat(e.target.value);
                                setReverbMix(val);
                                WebAudioEngineService.getInstance().setReverbMix(val);
                              }}
                              className="w-full h-1 rounded-full bg-white/10 appearance-none cursor-pointer accent-[#e74c3c]"
                            />
                          </div>


                        </motion.div>
                      )}
                    </AnimatePresence>

                    {/* CAPTION AND IMAGE PREVIEW SECTION */}
                    <div className="bg-[#110f15]/80 border border-white/5 rounded-2xl p-3.5 flex items-center gap-3">
                      <div className="w-[52px] h-[52px] rounded-xl bg-neutral-900 border border-neutral-800 relative overflow-hidden shrink-0">
                        {selectedSong ? (
                          <img src={selectedSong.coverUrl} className="w-full h-full object-cover" referrerPolicy="no-referrer" />
                        ) : (
                          <div className="w-full h-full bg-neutral-800" />
                        )}
                        <div className="absolute inset-0 bg-black/45 flex items-center justify-center">
                          <span className="text-sm">📷</span>
                        </div>
                      </div>

                      <div className="flex-1 text-left">
                        <span className="text-[8px] font-black tracking-wider text-white/40 uppercase">Caption</span>
                        <input
                          type="text"
                          value={captionText}
                          onChange={(e) => setCaptionText(e.target.value)}
                          placeholder="Tulis deskripsi nyanyian solomu..."
                          className="w-full bg-transparent border-none text-xs text-white placeholder-neutral-500 focus:outline-none mt-0.5"
                        />
                      </div>
                    </div>

                    {/* LOCK & COPY ACTIONS */}
                    <div className="grid grid-cols-2 gap-3 pt-1">
                      <button
                        onClick={() => setIsPrivate(!isPrivate)}
                        className={`p-3.5 rounded-2xl border flex items-center justify-between transition-all ${
                          isPrivate 
                            ? 'bg-neutral-800/40 border-neutral-700 text-white font-extrabold shadow-inner' 
                            : 'bg-[#110f15]/50 border-white/5 text-neutral-400 hover:border-neutral-800'
                        }`}
                      >
                        <div className="flex items-center gap-2 text-left">
                          <span className="text-sm">🔒</span>
                          <span className="text-[11px] font-bold leading-none">
                            {isPrivate ? 'Set to Private' : 'Set to Public'}
                          </span>
                        </div>
                        <span className="text-[10px] text-neutral-500">{isPrivate ? 'On' : 'Off'}</span>
                      </button>

                      <button
                        onClick={() => setSaveACopy(!saveACopy)}
                        className={`p-3.5 rounded-2xl border flex items-center justify-between transition-all ${
                          saveACopy 
                            ? 'bg-neutral-800/40 border-neutral-700 text-white font-extrabold shadow-inner' 
                            : 'bg-[#110f15]/50 border-white/5 text-neutral-400 hover:border-neutral-800'
                        }`}
                      >
                        <div className="flex items-center gap-2 text-left">
                          <span className="text-sm">📥</span>
                          <span className="text-[11px] font-bold leading-none">
                            Save local copy
                          </span>
                        </div>
                        <span className="text-[10px] text-neutral-500">{saveACopy ? 'On' : 'Off'}</span>
                      </button>
                    </div>
                  </div>

                  {/* BOTTOM ACTION BUTTON BAR */}
                  <div className="h-20 px-4 bg-[#0a0614] border-t border-white/5 flex items-center gap-3 shrink-0 z-10 relative">
                    <button
                      onClick={() => finishAndSaveRecording(true)}
                      disabled={isSaving}
                      className="h-12 w-14 rounded-2xl bg-[#14121a] hover:bg-[#1a1722] border border-white/5 flex flex-col items-center justify-center text-neutral-400 hover:text-white transition-all cursor-pointer"
                    >
                      <span className="text-xs">📄</span>
                      <span className="text-[9px] font-bold mt-0.5">Draft</span>
                    </button>

                    <button
                      onClick={() => finishAndSaveRecording(false)}
                      disabled={isSaving}
                      className="flex-1 h-12 rounded-2xl bg-gradient-to-r from-red-600 to-pink-600 hover:from-red-500 hover:to-pink-500 text-white font-extrabold text-sm flex items-center justify-center transition-all cursor-pointer shadow-lg shadow-red-600/20 active:scale-[0.98] disabled:opacity-50"
                    >
                      {isSaving ? (
                        <div className="w-5 h-5 border-2 border-white border-t-transparent rounded-full animate-spin" />
                      ) : (
                        'Post'
                      )}
                    </button>
                  </div>
                </motion.div>
              )}
              
            </AnimatePresence>

            {/* ADMIN PANEL MODAL */}
            <AnimatePresence>
              {isUploadSongModalOpen && (
                <>
                  <motion.div
                    initial={{ opacity: 0 }}
                    animate={{ opacity: 0.6 }}
                    exit={{ opacity: 0 }}
                    onClick={() => !isUploading && setIsUploadSongModalOpen(false)}
                    className="absolute inset-0 bg-black z-50 pointer-events-auto"
                  />
                  <motion.div
                    initial={{ scale: 0.9, opacity: 0, y: 20 }}
                    animate={{ scale: 1, opacity: 1, y: 0 }}
                    exit={{ scale: 0.9, opacity: 0, y: 20 }}
                    className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 bg-[#0d0915] border border-[#e67e22]/30 rounded-2xl p-5 z-50 w-[92%] max-w-sm max-h-[88vh] overflow-y-auto shadow-2xl text-white custom-scrollbar space-y-4"
                  >
                    {/* Header Admin */}
                    <div className="flex justify-between items-center border-b border-white/10 pb-3">
                      <div className="flex items-center gap-2">
                        <div className="w-8 h-8 rounded-full bg-[#e67e22]/20 border border-[#e67e22] flex items-center justify-center text-[#e67e22]">
                          <UploadCloud className="w-4 h-4" />
                        </div>
                        <div>
                          <h3 className="text-sm font-extrabold text-white">Panel Admin WeSing</h3>
                          <p className="text-[10px] text-neutral-400">Pengelolaan Lagu & Storage</p>
                        </div>
                      </div>
                      <button
                        onClick={() => !isUploading && setIsUploadSongModalOpen(false)}
                        className="p-1 text-neutral-400 hover:text-white rounded-full transition-colors cursor-pointer"
                      >
                        <X className="w-4 h-4" />
                      </button>
                    </div>

                    {/* Admin Switcher Tabs */}
                    <div className="flex bg-white/5 p-1 rounded-xl border border-white/10 gap-1 text-xs">
                      <button
                        type="button"
                        onClick={() => setAdminTab('upload')}
                        className={`flex-1 py-1.5 rounded-lg font-bold transition-all ${
                          adminTab === 'upload'
                            ? 'bg-[#e67e22] text-black shadow'
                            : 'text-neutral-400 hover:text-white'
                        }`}
                      >
                        Upload Lagu
                      </button>
                      <button
                        type="button"
                        onClick={() => setAdminTab('songs')}
                        className={`flex-1 py-1.5 rounded-lg font-bold transition-all ${
                          adminTab === 'songs'
                            ? 'bg-[#e67e22] text-black shadow'
                            : 'text-neutral-400 hover:text-white'
                        }`}
                      >
                        Katalog ({songs.length})
                      </button>
                    </div>

                    {/* Standalone Web Portal Link */}
                    <a
                      href="/admin"
                      target="_blank"
                      rel="noopener noreferrer"
                      className="block text-center py-1.5 px-3 rounded-lg bg-white/5 hover:bg-white/10 border border-white/10 text-[11px] text-amber-300 font-medium transition-colors"
                    >
                      🌐 Buka Portal Web Admin Terpisah (/admin)
                    </a>

                    {adminTab === 'upload' ? (
                      <form onSubmit={handleUploadSong} className="space-y-3.5">
                        {/* Judul Lagu */}
                        <div>
                          <label className="block text-[11px] font-bold text-neutral-300 mb-1">Judul Lagu *</label>
                          <input
                            type="text"
                            placeholder="Contoh: Bintang di Surga (Karaoke)"
                            value={uploadTitle}
                            onChange={(e) => setUploadTitle(e.target.value)}
                            required
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-3 py-2 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-[#e67e22]"
                          />
                        </div>

                        {/* Nama Artis */}
                        <div>
                          <label className="block text-[11px] font-bold text-neutral-300 mb-1">Nama Artis / Penyanyi</label>
                          <input
                            type="text"
                            placeholder="Contoh: Noah"
                            value={uploadArtist}
                            onChange={(e) => setUploadArtist(e.target.value)}
                            className="w-full bg-white/5 border border-white/10 rounded-xl px-3 py-2 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-[#e67e22]"
                          />
                        </div>

                        {/* File Audio Instrumental */}
                        <div>
                          <label className="block text-[11px] font-bold text-neutral-300 mb-1">
                            File Audio Instrumen Real (.mp3, .m4a, .wav) *
                          </label>
                          <input
                            type="file"
                            accept="audio/*,.mp3,.m4a,.wav"
                            onChange={(e) => setUploadAudioFile(e.target.files?.[0] || null)}
                            required
                            className="w-full text-xs text-neutral-300 file:mr-3 file:py-1.5 file:px-3 file:rounded-xl file:border-0 file:text-xs file:font-extrabold file:bg-[#e67e22] file:text-black hover:file:bg-[#d35400] cursor-pointer"
                          />
                          {uploadAudioFile && (
                            <p className="text-[10px] text-amber-400 mt-1 font-medium truncate">
                              ✓ Terpilih: {uploadAudioFile.name} ({(uploadAudioFile.size / (1024 * 1024)).toFixed(2)} MB)
                            </p>
                          )}
                        </div>

                        {/* Cover Image (Optional) */}
                        <div>
                          <label className="block text-[11px] font-bold text-neutral-300 mb-1">
                            Cover Gambar (Opsional)
                          </label>
                          <input
                            type="file"
                            accept="image/*"
                            onChange={(e) => setUploadCoverFile(e.target.files?.[0] || null)}
                            className="w-full text-xs text-neutral-300 file:mr-3 file:py-1.5 file:px-3 file:rounded-xl file:border-0 file:text-xs file:font-extrabold file:bg-white/10 file:text-white hover:file:bg-white/20 cursor-pointer"
                          />
                        </div>

                        {/* Lyrics text (Optional) */}
                        <div>
                          <label className="block text-[11px] font-bold text-neutral-300 mb-1">
                            Lirik Lagu (Opsional - Per baris)
                          </label>
                          <textarea
                            rows={3}
                            placeholder="Ketik lirik per baris...&#10;Contoh: [00:04] Masih ku merasa angkuh&#10;Contoh: [00:08] Terbang tinggi di awan"
                            value={uploadLyricsText}
                            onChange={(e) => setUploadLyricsText(e.target.value)}
                            className="w-full bg-white/5 border border-white/10 rounded-xl p-2.5 text-xs text-white placeholder-neutral-500 focus:outline-none focus:border-[#e67e22] custom-scrollbar"
                          />
                        </div>

                        <div className="pt-2 flex gap-2">
                          <button
                            type="button"
                            onClick={() => setIsUploadSongModalOpen(false)}
                            disabled={isUploading}
                            className="flex-1 py-2.5 rounded-xl bg-white/5 hover:bg-white/10 border border-white/10 text-xs font-bold text-neutral-300 transition-colors cursor-pointer"
                          >
                            Batal
                          </button>
                          <button
                            type="submit"
                            disabled={isUploading}
                            className="flex-1 py-2.5 rounded-xl bg-[#e67e22] hover:bg-[#d35400] text-black text-xs font-black transition-all flex items-center justify-center gap-1.5 shadow-lg cursor-pointer active:scale-95 disabled:opacity-50"
                          >
                            {isUploading ? (
                              <>
                                <div className="w-3.5 h-3.5 border-2 border-black border-t-transparent rounded-full animate-spin" />
                                <span>Mengunggah...</span>
                              </>
                            ) : (
                              <>
                                <UploadCloud className="w-4 h-4" />
                                <span>Simpan Storage</span>
                              </>
                            )}
                          </button>
                        </div>
                      </form>
                    ) : (
                      /* KATALOG STORAGE SONGS MANAGER */
                      <div className="space-y-3">
                        <div className="flex justify-between items-center text-xs text-neutral-400">
                          <span>Daftar Lagu Tersimpan</span>
                          <span className="font-bold text-white">{songs.length} Lagu</span>
                        </div>

                        <div className="space-y-2 max-h-[300px] overflow-y-auto pr-1 custom-scrollbar">
                          {songs.length === 0 ? (
                            <p className="text-center text-xs text-neutral-500 py-6">
                              Belum ada lagu di katalog storage.
                            </p>
                          ) : (
                            songs.map((s) => (
                              <div
                                key={s.id}
                                className="flex items-center justify-between p-2 rounded-xl bg-white/5 border border-white/10 hover:border-white/20 transition-all"
                              >
                                <div className="flex items-center gap-2.5 min-w-0">
                                  <img
                                    src={s.coverUrl || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=100&h=100&fit=crop'}
                                    alt={s.title}
                                    className="w-10 h-10 rounded-lg object-cover shrink-0"
                                  />
                                  <div className="min-w-0">
                                    <h4 className="text-xs font-bold text-white truncate">{s.title}</h4>
                                    <p className="text-[10px] text-neutral-400 truncate">{s.artist}</p>
                                  </div>
                                </div>

                                <button
                                  type="button"
                                  onClick={() => handleDeleteSong(s.id, s.title)}
                                  className="p-1.5 text-neutral-400 hover:text-red-400 hover:bg-red-500/10 rounded-lg transition-all cursor-pointer shrink-0"
                                  title="Hapus lagu ini"
                                >
                                  <Trash2 className="w-4 h-4" />
                                </button>
                              </div>
                            ))
                          )}
                        </div>

                        <button
                          type="button"
                          onClick={() => setAdminTab('upload')}
                          className="w-full py-2 rounded-xl bg-[#e67e22]/20 hover:bg-[#e67e22]/30 border border-[#e67e22]/50 text-[#e67e22] text-xs font-bold transition-all flex items-center justify-center gap-1.5 cursor-pointer mt-2"
                        >
                          <Plus className="w-4 h-4" />
                          <span>Tambah Lagu Baru</span>
                        </button>
                      </div>
                    )}
                  </motion.div>
                </>
              )}
            </AnimatePresence>
          </div>

        </div>
      </div>

    </div>
  );
}
