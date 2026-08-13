import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Upload, ChevronLeft, ChevronRight, Play, Pause, RotateCcw, Settings, Check } from 'lucide-react';

export default function AdminUpload() {
  const [currentStep, setCurrentStep] = useState(1);
  const navigate = useNavigate();

  // Form states
  const [audioFile, setAudioFile] = useState<File | null>(null);
  const [termsAccepted, setTermsAccepted] = useState(false);

  const [songName, setSongName] = useState('');
  const [artistName, setArtistName] = useState('');
  const [coverImage, setCoverImage] = useState<File | null>(null);
  const [tags, setTags] = useState<string[]>([]);

  const [lyricsText, setLyricsText] = useState('');
  const [lyricsLines, setLyricsLines] = useState<{ text: string, time: number }[]>([]);
  const [lyricsInputMode, setLyricsInputMode] = useState<'text' | 'file'>('text');
  const [lrcFile, setLrcFile] = useState<File | null>(null);

  // Timestamp states
  const [currentTime, setCurrentTime] = useState(0);
  const [duration, setDuration] = useState(0);
  const [isPlaying, setIsPlaying] = useState(false);
  const audioRef = useRef<HTMLAudioElement | null>(null);
  const [currentTimestampIndex, setCurrentTimestampIndex] = useState(0);

  // Parse lyrics when entering step 4
  useEffect(() => {
    if (currentStep === 4) {
      if (lyricsInputMode === 'text') {
        const lines = lyricsText.split('\n').filter(line => line.trim() !== '');
        setLyricsLines(lines.map(line => ({ text: line.trim(), time: -1 })));
      }
    }
  }, [currentStep, lyricsText, lyricsInputMode]);

  // Audio setup for step 4
  useEffect(() => {
    if (currentStep === 4) {
      const url = audioFile ? URL.createObjectURL(audioFile) : 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
      audioRef.current = new Audio(url);

      audioRef.current.addEventListener('timeupdate', () => {
        setCurrentTime(audioRef.current?.currentTime || 0);
      });
      audioRef.current.addEventListener('loadedmetadata', () => {
        setDuration(audioRef.current?.duration || 0);
      });
      audioRef.current.addEventListener('ended', () => {
        setIsPlaying(false);
      });

      return () => {
        audioRef.current?.pause();
        audioRef.current = null;
        if (audioFile) URL.revokeObjectURL(url);
      };
    }
  }, [currentStep, audioFile]);

  // Keyboard shortcut for timestamps
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (currentStep === 4 && e.code === 'Space' && e.target === document.body) {
        e.preventDefault();
        handleTimestamp();
      }
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [currentStep, currentTime, currentTimestampIndex, lyricsLines]);

  const togglePlay = () => {
    if (audioRef.current) {
      if (isPlaying) {
        audioRef.current.pause();
      } else {
        audioRef.current.play();
      }
      setIsPlaying(!isPlaying);
    }
  };

  const handleTimestamp = () => {
    if (currentTimestampIndex < lyricsLines.length) {
      const newLines = [...lyricsLines];
      newLines[currentTimestampIndex].time = currentTime;
      setLyricsLines(newLines);
      setCurrentTimestampIndex(currentTimestampIndex + 1);
    }
  };

  const formatTime = (seconds: number) => {
    const m = Math.floor(seconds / 60);
    const s = Math.floor(seconds % 60);
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`;
  };

  const [isUploading, setIsUploading] = useState(false);

  const uploadSingleFile = async (file: File): Promise<{ url: string | null; error?: string }> => {
    // 15MB file size safety check
    const maxMb = 15;
    if (file.size > maxMb * 1024 * 1024) {
      return {
        url: null,
        error: `Ukuran file "${file.name}" (${(file.size / (1024 * 1024)).toFixed(1)}MB) melebihi batas maksimal ${maxMb}MB. Mohon gunakan file MP3 yang lebih kecil.`
      };
    }

    const formData = new FormData();
    formData.append('file', file);
    try {
      const res = await fetch('/api/upload', {
        method: 'POST',
        body: formData,
      });
      if (res.ok) {
        const data = await res.json();
        return { url: data.url };
      } else if (res.status === 413) {
        return {
          url: null,
          error: `Gagal mengunggah "${file.name}": Ukuran file terlalu besar (413 Request Entity Too Large). Mohon gunakan file MP3 di bawah 15MB.`
        };
      } else {
        const errJson = await res.json().catch(() => null);
        return { url: null, error: errJson?.error || `Gagal mengunggah file (Status ${res.status}).` };
      }
    } catch (e: any) {
      console.error("File upload failed", e);
      return { url: null, error: "Gagal terhubung ke server saat mengunggah file." };
    }
  };

  const handleFinishAndUpload = async () => {
    if (!audioFile) {
      alert('Mohon pilih dan unggah file musik instrumental (MP3/WAV) di Langkah 1 terlebih dahulu.');
      return;
    }

    setIsUploading(true);
    let coverUrl = 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=200&h=200&fit=crop';
    if (coverImage) {
      const coverRes = await uploadSingleFile(coverImage);
      if (coverRes.url) {
        coverUrl = coverRes.url;
      } else if (coverRes.error) {
        alert(coverRes.error);
        setIsUploading(false);
        return;
      }
    }

    const audioRes = await uploadSingleFile(audioFile);
    if (!audioRes.url) {
      alert(audioRes.error || 'Gagal mengunggah file musik instrumental ke server. Pastikan format file audio (MP3/WAV) valid.');
      setIsUploading(false);
      return;
    }
    const uploadedAudio = audioRes.url;

    const validLyrics = lyricsLines
      .filter(l => l.text.trim() !== '' && l.time >= 0)
      .map(l => ({
        time: Math.round(l.time * 10) / 10,
        text: l.text
      }));

    const payload = {
      title: songName || audioFile.name.replace(/\.[^/.]+$/, ""),
      artist: artistName || 'Unknown Artist',
      coverUrl,
      audioUrl: uploadedAudio,
      lyrics: validLyrics,
      tags,
    };

    try {
      const res = await fetch('/api/songs', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });
      if (res.ok) {
        alert('Lagu dan lirik berhasil disimpan!');
        navigate('/songs');
      } else {
        alert('Gagal menyimpan lagu ke server.');
      }
    } catch (e) {
      console.error(e);
      alert('Terjadi kesalahan saat mengunggah lagu.');
    } finally {
      setIsUploading(false);
    }
  };

  const nextStep = () => setCurrentStep(prev => Math.min(prev + 1, 4));
  const prevStep = () => setCurrentStep(prev => Math.max(prev - 1, 1));

  return (
    <div className="min-h-screen bg-white text-zinc-900 font-sans">
      {/* Steps Indicator */}
      <div className="border-b border-zinc-200">
        <div className="max-w-4xl mx-auto py-8">
          <div className="flex items-center justify-center">
            {[1, 2, 3, 4].map((step, index) => (
              <React.Fragment key={step}>
                <div className={`w-10 h-10 rounded-full flex items-center justify-center font-bold border-2 
                  ${step === currentStep ? 'bg-[#f45142] border-[#f45142] text-white' :
                    step < currentStep ? 'bg-zinc-200 border-zinc-200 text-zinc-500' :
                      'bg-white border-zinc-300 text-zinc-400'}`}>
                  {step}
                </div>
                {index < 3 && (
                  <div className={`w-24 h-1 
                    ${step < currentStep ? 'bg-zinc-200' : 'bg-zinc-200'}`} />
                )}
              </React.Fragment>
            ))}
          </div>
        </div>
      </div>

      <div className="max-w-4xl mx-auto py-12 px-6">
        {/* Step 1: Upload */}
        {currentStep === 1 && (
          <div className="max-w-2xl mx-auto text-center">
            <h1 className="text-5xl mb-4 font-light text-black">Upload Files</h1>
            <p className="text-xl mb-12 text-zinc-700">Clear instrumental is preferred.</p>

            <div className="relative bg-zinc-100 p-4 mb-4 flex items-center justify-between text-left text-zinc-600 border border-dashed border-zinc-300 hover:border-[#f45142] cursor-pointer transition-colors">
              <input
                type="file"
                accept="audio/*"
                onChange={e => {
                  const file = e.target.files?.[0] || null;
                  if (file && file.size > 15 * 1024 * 1024) {
                    alert(`Ukuran file "${file.name}" (${(file.size / (1024 * 1024)).toFixed(1)}MB) terlalu besar! Maksimal ukuran file adalah 15MB agar tidak terjadi error "Request Entity Too Large". Mohon kompres atau pilih file MP3 yang lebih kecil.`);
                    e.target.value = '';
                    setAudioFile(null);
                    return;
                  }
                  setAudioFile(file);
                  if (file && !songName) {
                    setSongName(file.name.replace(/\.[^/.]+$/, ""));
                  }
                }}
                className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
              />
              <span className="truncate flex-1 font-medium">
                {audioFile ? `Selected: ${audioFile.name}` : "Click here to choose instrumental audio file (MP3/WAV)..."}
              </span>
              <span className="bg-zinc-200 text-xs px-2 py-1 rounded text-zinc-700">Browse</span>
            </div>

            <label className="flex items-center justify-center gap-2 mb-10 cursor-pointer">
              <input type="checkbox" checked={termsAccepted} onChange={e => setTermsAccepted(e.target.checked)} className="w-4 h-4 accent-[#f45142]" />
              <span className="text-zinc-500">I accept the terms and privacy policy.</span>
              <span className="text-zinc-800 underline hover:text-black">"Related Policies"</span>
            </label>

            <button
              onClick={() => {
                if (!audioFile) {
                  alert('Mohon pilih file musik instrumental (MP3/WAV) terlebih dahulu.');
                  return;
                }
                nextStep();
              }}
              disabled={!termsAccepted || !audioFile}
              className="bg-[#e96458] text-white px-16 py-3 rounded text-xl hover:bg-[#d8584c] disabled:opacity-50 transition-colors cursor-pointer"
            >
              Upload
            </button>

            <div className="mt-8 flex justify-between items-center px-4">
              <button className="bg-zinc-100 text-black px-8 py-2 rounded hover:bg-zinc-200 transition-colors">
                Back
              </button>

              <div className="relative">
                <input
                  type="file"
                  accept="audio/*"
                  onChange={e => setAudioFile(e.target.files?.[0] || null)}
                  className="absolute inset-0 w-full h-full opacity-0 cursor-pointer"
                />
                <button className="bg-zinc-600 text-white px-4 py-1.5 rounded text-sm hover:bg-zinc-700 transition-colors">
                  {audioFile ? 'Change file' : 'No file chosen'}
                </button>
              </div>
            </div>
          </div>
        )}

        {/* Step 2: Fill in the information */}
        {currentStep === 2 && (
          <div className="max-w-3xl mx-auto">
            <h1 className="text-5xl mb-12 font-light text-center text-black">Fill in the information</h1>

            <div className="border border-zinc-200 p-8 mb-6 flex gap-6">
              <div className="relative w-32 h-32 bg-zinc-100 flex items-center justify-center border border-zinc-200 cursor-pointer overflow-hidden">
                <input
                  type="file"
                  accept="image/*"
                  onChange={e => setCoverImage(e.target.files?.[0] || null)}
                  className="absolute inset-0 w-full h-full opacity-0 cursor-pointer z-10"
                />
                {coverImage ? (
                  <img src={URL.createObjectURL(coverImage)} alt="Cover" className="w-full h-full object-cover" />
                ) : (
                  <div className="text-center text-zinc-400">
                    <span className="text-6xl">♪</span>
                  </div>
                )}
                <div className="absolute bottom-0 left-0 right-0 bg-black/50 text-white text-xs py-1 text-center">
                  Add a cover
                </div>
              </div>
              <div className="flex-1 text-zinc-500 pt-4">
                Please fill in artist and song name. The lyrics will be matched automatically.
              </div>
            </div>

            <div className="space-y-6 mb-10">
              <input
                type="text"
                placeholder="Song name"
                value={songName}
                onChange={e => setSongName(e.target.value)}
                className="w-full border border-zinc-200 p-4 text-lg focus:outline-none focus:border-zinc-400"
              />
              <input
                type="text"
                placeholder="Artist name"
                value={artistName}
                onChange={e => setArtistName(e.target.value)}
                className="w-full border border-zinc-200 p-4 text-lg focus:outline-none focus:border-zinc-400"
              />
            </div>

            <div className="mb-12">
              <h3 className="text-lg mb-4 text-black">Choose a tag</h3>
              <div className="flex flex-wrap gap-3">
                {['LIVE', 'Unplugged', 'Acoustic', 'Remix'].map(tag => (
                  <button
                    key={tag}
                    onClick={() => {
                      if (tags.includes(tag)) setTags(tags.filter(t => t !== tag));
                      else setTags([...tags, tag]);
                    }}
                    className={`border px-6 py-2 rounded text-zinc-600 hover:border-zinc-400 ${tags.includes(tag) ? 'border-[#f45142] text-[#f45142]' : 'border-zinc-200'}`}
                  >
                    {tag}
                  </button>
                ))}
                <button className="border border-zinc-200 px-6 py-2 rounded text-[#f45142] flex items-center gap-1 hover:bg-red-50">
                  <span>+</span> add
                </button>
              </div>
            </div>

            <div className="flex gap-4 border-t border-zinc-100 pt-8">
              <button
                onClick={prevStep}
                className="bg-zinc-100 text-black px-12 py-3 rounded text-lg hover:bg-zinc-200 transition-colors"
              >
                Back
              </button>
              <button
                onClick={nextStep}
                className="bg-zinc-100 text-black px-12 py-3 rounded text-lg hover:bg-zinc-200 transition-colors"
              >
                Next
              </button>
            </div>
          </div>
        )}

        {/* Step 3: Lyrics */}
        {currentStep === 3 && (
          <div className="max-w-4xl mx-auto">
            <div className="flex border-b border-zinc-200 mb-8">
              <button
                onClick={() => setLyricsInputMode('text')}
                className={`px-8 py-4 text-2xl border-b-2 ${lyricsInputMode === 'text' ? 'border-black text-black' : 'border-transparent text-zinc-400 hover:text-zinc-600'}`}
              >
                Fill in lyrics
              </button>
              <button
                onClick={() => setLyricsInputMode('file')}
                className={`px-8 py-4 text-2xl border-b-2 ${lyricsInputMode === 'file' ? 'border-black text-black' : 'border-transparent text-zinc-400 hover:text-zinc-600'}`}
              >
                Select lyric file
              </button>
            </div>

            <div className="bg-zinc-50 border border-zinc-100 p-8 min-h-[500px] mb-8 relative flex flex-col justify-center">
              {lyricsInputMode === 'text' ? (
                <>
                  <textarea
                    value={lyricsText}
                    onChange={e => setLyricsText(e.target.value)}
                    placeholder="Paste your lyrics here..."
                    className="w-full h-[400px] bg-transparent resize-none focus:outline-none text-xl leading-relaxed text-black"
                    style={{ fontFamily: 'monospace' }}
                  />
                  <div className="absolute right-8 bottom-8 w-2 h-2 rounded-full bg-blue-500"></div>
                </>
              ) : (
                <div className="flex flex-col items-center justify-center">
                  <p className="text-zinc-500 mb-4 text-lg">Upload an .LRC file</p>
                  <label className="cursor-pointer bg-white border border-zinc-300 px-8 py-4 rounded text-black hover:bg-zinc-50 shadow-sm transition-all">
                    Choose .lrc File
                    <input
                      type="file"
                      accept=".lrc"
                      className="hidden"
                      onChange={e => {
                        const file = e.target.files?.[0];
                        if (file) {
                          setLrcFile(file);
                          const reader = new FileReader();
                          reader.onload = (evt) => {
                            const content = evt.target?.result as string;
                            if (content) {
                              const lines = content.split('\n');
                              const parsedLines: { text: string, time: number }[] = [];
                              const timeRegex = /\[(\d+):(\d+\.\d+)\]/;

                              lines.forEach(line => {
                                const match = timeRegex.exec(line);
                                if (match) {
                                  const minutes = parseInt(match[1]);
                                  const seconds = parseFloat(match[2]);
                                  const timeInSeconds = (minutes * 60) + seconds;
                                  const text = line.replace(timeRegex, '').trim();
                                  if (text) {
                                    parsedLines.push({ text, time: timeInSeconds });
                                  }
                                } else {
                                  const cleanText = line.trim();
                                  if (cleanText && !/^\[[a-zA-Z]+:.*\]$/.test(cleanText)) {
                                    parsedLines.push({ text: cleanText, time: -1 });
                                  }
                                }
                              });
                              setLyricsLines(parsedLines);
                            }
                          };
                          reader.readAsText(file);
                        }
                      }}
                    />
                  </label>
                  {lrcFile && <p className="mt-4 text-green-600 font-medium">Selected: {lrcFile.name}</p>}
                </div>
              )}
            </div>

            <div className="flex gap-4">
              <button
                onClick={prevStep}
                className="bg-zinc-100 text-black px-10 py-2 rounded hover:bg-zinc-200 transition-colors"
              >
                Back
              </button>
              <button
                onClick={nextStep}
                className="bg-zinc-100 text-black px-10 py-2 rounded hover:bg-zinc-200 transition-colors"
              >
                Next
              </button>
            </div>
          </div>
        )}

        {/* Step 4: Timestamps */}
        {currentStep === 4 && (
          <div className="max-w-4xl mx-auto border border-zinc-200 bg-white">
            <div className="text-center py-10 border-b border-zinc-200">
              <h1 className="text-5xl font-light text-black mb-4">Lyrics Timestamps</h1>
              <p className="text-zinc-800 text-lg flex items-center justify-center gap-2">
                <span className="w-5 h-5 rounded-full bg-yellow-400 text-white text-sm font-bold flex items-center justify-center">!</span>
                Make timestamps for each line. After finished, you can upload.
              </p>

              <div className="max-w-3xl mx-auto mt-12 flex items-center gap-6">
                <button
                  onClick={togglePlay}
                  className="w-12 h-12 rounded-full border-2 border-[#f45142] flex items-center justify-center text-[#f45142] hover:bg-red-50"
                >
                  {isPlaying ? <Pause className="fill-current w-5 h-5" /> : <Play className="fill-current w-5 h-5 ml-1" />}
                </button>
                <div className="flex-1 h-1 bg-zinc-300 relative">
                  <div
                    className="absolute left-0 top-0 bottom-0 bg-[#f45142]"
                    style={{ width: `${duration ? (currentTime / duration) * 100 : 0}%` }}
                  />
                  <div
                    className="absolute top-1/2 -translate-y-1/2 w-3 h-3 bg-[#f45142] rounded-full"
                    style={{ left: `${duration ? (currentTime / duration) * 100 : 0}%`, transform: `translate(-50%, -50%)` }}
                  />
                </div>
                <div className="text-zinc-500 font-mono text-sm">
                  {formatTime(currentTime)}/{formatTime(duration)}
                </div>
              </div>

              <div className="max-w-3xl mx-auto mt-6 flex justify-between items-center px-2">
                <button className="text-zinc-400 flex items-center gap-1 text-sm hover:text-zinc-600">
                  Timestamps <RotateCcw className="w-4 h-4" />
                </button>
                <button className="text-zinc-400 flex items-center gap-1 text-sm hover:text-zinc-600">
                  Duet Setting <Settings className="w-4 h-4" />
                </button>
              </div>
            </div>

            <div className="bg-white">
              {/* Active Tab Area */}
              <div
                className="bg-red-50 border-y border-red-200 py-8 px-12 flex items-center justify-between cursor-pointer"
                onClick={handleTimestamp}
              >
                <div className="text-zinc-600">
                  <div className="text-2xl mb-1">Start</div>
                  <div className="text-zinc-400">Tab to make timestamps.</div>
                </div>
                <div className="w-6 h-6 rounded-full border-2 border-zinc-400 flex items-center justify-center">
                  <div className="w-2 h-2 rounded-full bg-zinc-400" />
                </div>
              </div>

              {/* Lyrics List */}
              <div className="divide-y divide-zinc-200 max-h-[400px] overflow-y-auto">
                {lyricsLines.map((line, idx) => (
                  <div
                    key={idx}
                    className={`flex items-center px-12 py-6 text-xl 
                      ${idx === currentTimestampIndex ? 'bg-zinc-50' : ''}
                      ${line.time !== -1 ? 'text-[#f45142]' : 'text-zinc-500'}`}
                  >
                    <div className="w-32 font-mono text-lg text-zinc-400">
                      {line.time !== -1 ? formatTime(line.time) : '--:--'}
                    </div>
                    <div>{line.text}</div>
                  </div>
                ))}
                {lyricsLines.length === 0 && (
                  <div className="p-12 text-center text-zinc-400">
                    No lyrics found. Go back and paste some lyrics.
                  </div>
                )}
              </div>
            </div>

            <div className="p-6 border-t border-zinc-200 bg-zinc-50 flex justify-between">
              <button
                onClick={prevStep}
                className="bg-zinc-200 text-black px-10 py-2 rounded hover:bg-zinc-300 transition-colors"
              >
                Back
              </button>
              <button
                onClick={handleFinishAndUpload}
                disabled={isUploading}
                className="bg-[#f45142] text-white px-10 py-2 rounded hover:bg-[#d8584c] disabled:opacity-50 transition-colors font-bold flex items-center gap-2"
              >
                {isUploading ? 'Uploading...' : 'Finish & Upload'}
              </button>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
