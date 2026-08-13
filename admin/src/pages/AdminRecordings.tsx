import { useEffect, useState } from 'react';
import { Recording } from '../types';
import { Trash2, Play, Pause, Search, Music, Eye, Lock, Globe, MessageSquare, Heart, Trophy, RefreshCw } from 'lucide-react';

export default function AdminRecordings() {
    const [recordings, setRecordings] = useState<Recording[]>([]);
    const [loading, setLoading] = useState(true);
    const [search, setSearch] = useState('');
    const [filterVisibility, setFilterVisibility] = useState<'All' | 'Public' | 'Private'>('All');
    const [playingId, setPlayingId] = useState<string | null>(null);
    const [audioElement, setAudioElement] = useState<HTMLAudioElement | null>(null);

    const fetchRecordings = () => {
        setLoading(true);
        fetch('/api/recordings?all=true')
            .then(res => res.json())
            .then(data => {
                if (Array.isArray(data)) {
                    setRecordings(data);
                }
            })
            .catch(err => console.error('Failed to fetch recordings:', err))
            .finally(() => setLoading(false));
    };

    useEffect(() => {
        fetchRecordings();
        return () => {
            if (audioElement) {
                audioElement.pause();
            }
        };
    }, []);

    const getAudioUrl = (rec: Recording) => {
        let url = rec.audioUrl || rec.song?.audioUrl || '';
        if (!url) return '';
        if (url.startsWith('/sdcard/') || url.startsWith('/data/') || url.startsWith('/var/') || url.startsWith('file:') || url.startsWith('blob:')) {
            return rec.song?.audioUrl || '';
        }
        return url;
    };

    const handlePlayToggle = (rec: Recording) => {
        const audioUrl = getAudioUrl(rec);
        if (!audioUrl) return;

        if (playingId === rec.id && audioElement) {
            if (audioElement.paused) {
                audioElement.play().catch(e => console.error('Play error:', e));
            } else {
                audioElement.pause();
                setPlayingId(null);
            }
            return;
        }

        if (audioElement) {
            audioElement.pause();
        }

        const audio = new Audio(audioUrl);
        audio.play().catch(e => console.error('Play error:', e));
        audio.onended = () => setPlayingId(null);
        setAudioElement(audio);
        setPlayingId(rec.id);
    };

    const handleDelete = async (id: string) => {
        if (!confirm('Apakah Anda yakin ingin menghapus postingan ini?')) return;

        try {
            const res = await fetch(`/api/recordings/${id}`, { method: 'DELETE' });
            if (res.ok) {
                if (playingId === id && audioElement) {
                    audioElement.pause();
                    setPlayingId(null);
                }
                setRecordings(prev => prev.filter(r => r.id !== id));
            } else {
                alert('Gagal menghapus postingan.');
            }
        } catch (err) {
            console.error(err);
            alert('Terjadi kesalahan saat menghapus postingan.');
        }
    };

    const filteredRecordings = recordings.filter(rec => {
        const matchesSearch =
            (rec.user?.username || '').toLowerCase().includes(search.toLowerCase()) ||
            (rec.song?.title || '').toLowerCase().includes(search.toLowerCase()) ||
            (rec.caption || '').toLowerCase().includes(search.toLowerCase());

        if (filterVisibility === 'All') return matchesSearch;
        return matchesSearch && (rec.visibility || 'Public') === filterVisibility;
    });

    return (
        <div className="p-8">
            <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between mb-6 gap-4">
                <div>
                    <h1 className="text-2xl font-bold text-gray-900">Postingan User (User Posts)</h1>
                    <p className="text-sm text-gray-500 mt-1">
                        Kelola dan pantau semua hasil rekaman audio, gambar cover, caption, dan status postingan dari user.
                    </p>
                </div>
                <button
                    onClick={fetchRecordings}
                    className="inline-flex items-center px-4 py-2 border border-gray-300 rounded-lg text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 shadow-sm"
                >
                    <RefreshCw className={`w-4 h-4 mr-2 ${loading ? 'animate-spin' : ''}`} />
                    Refresh
                </button>
            </div>

            {/* Filter and Search Bar */}
            <div className="bg-white p-4 rounded-xl shadow-sm border border-gray-100 mb-6 flex flex-col md:flex-row gap-4 justify-between items-center">
                <div className="relative w-full md:w-96">
                    <Search className="absolute left-3 top-2.5 h-4 w-4 text-gray-400" />
                    <input
                        type="text"
                        placeholder="Cari user, lagu, atau caption..."
                        value={search}
                        onChange={e => setSearch(e.target.value)}
                        className="pl-9 pr-4 py-2 w-full border border-gray-200 rounded-lg text-sm focus:outline-none focus:ring-2 focus:ring-red-500"
                    />
                </div>

                <div className="flex items-center gap-2 w-full md:w-auto">
                    <span className="text-xs font-semibold text-gray-500 uppercase tracking-wider mr-2">Status:</span>
                    {(['All', 'Public', 'Private'] as const).map(vis => (
                        <button
                            key={vis}
                            onClick={() => setFilterVisibility(vis)}
                            className={`px-3 py-1.5 rounded-lg text-xs font-medium transition-colors ${filterVisibility === vis
                                    ? 'bg-red-600 text-white'
                                    : 'bg-gray-100 text-gray-600 hover:bg-gray-200'
                                }`}
                        >
                            {vis === 'All' ? 'Semua' : vis}
                        </button>
                    ))}
                </div>
            </div>

            {/* Postings Table / Cards */}
            {loading ? (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center text-gray-500">
                    <RefreshCw className="w-8 h-8 animate-spin mx-auto text-red-500 mb-3" />
                    Memuat daftar postingan...
                </div>
            ) : filteredRecordings.length === 0 ? (
                <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-12 text-center text-gray-500">
                    <Music className="w-12 h-12 mx-auto text-gray-300 mb-3" />
                    Tidak ada postingan user yang ditemukan.
                </div>
            ) : (
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {filteredRecordings.map(rec => {
                        const isPlaying = playingId === rec.id;
                        const isPrivate = rec.visibility === 'Private';

                        return (
                            <div key={rec.id} className="bg-white rounded-xl shadow-sm border border-gray-200 overflow-hidden flex flex-col justify-between hover:shadow-md transition-shadow">
                                <div>
                                    {/* Cover Header */}
                                    <div className="relative h-48 bg-gray-900 group">
                                        <img
                                            src={rec.coverUrl || rec.song?.coverUrl || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop'}
                                            alt={rec.song?.title || 'Recording cover'}
                                            className="w-full h-full object-cover opacity-85 group-hover:opacity-100 transition-opacity"
                                        />

                                        {/* Visibility Badge */}
                                        <div className="absolute top-3 left-3">
                                            <span className={`inline-flex items-center px-2.5 py-1 rounded-full text-xs font-semibold shadow-sm ${isPrivate ? 'bg-gray-900/80 text-amber-300 backdrop-blur-md' : 'bg-emerald-600/90 text-white backdrop-blur-md'
                                                }`}>
                                                {isPrivate ? <Lock className="w-3 h-3 mr-1" /> : <Globe className="w-3 h-3 mr-1" />}
                                                {rec.visibility || 'Public'}
                                            </span>
                                        </div>

                                        {/* Score Badge */}
                                        <div className="absolute top-3 right-3">
                                            <span className="inline-flex items-center px-2.5 py-1 rounded-full text-xs font-bold bg-amber-400 text-gray-900 shadow-md">
                                                <Trophy className="w-3 h-3 mr-1 text-gray-900" />
                                                {rec.score}%
                                            </span>
                                        </div>

                                        {/* Play Audio Overlay Button */}
                                        {getAudioUrl(rec) && (
                                            <button
                                                onClick={() => handlePlayToggle(rec)}
                                                className="absolute inset-0 m-auto w-14 h-14 rounded-full bg-red-600/90 hover:bg-red-600 text-white flex items-center justify-center shadow-lg transform hover:scale-105 transition-all"
                                                title={isPlaying ? 'Pause Audio' : 'Play Audio'}
                                            >
                                                {isPlaying ? <Pause className="w-6 h-6" /> : <Play className="w-6 h-6 ml-0.5" />}
                                            </button>
                                        )}
                                    </div>

                                    {/* Body Info */}
                                    <div className="p-5">
                                        {/* User info */}
                                        <div className="flex items-center gap-3 mb-3">
                                            <img
                                                src={rec.user?.avatar || 'https://i.pravatar.cc/150'}
                                                alt={rec.user?.username || 'User'}
                                                className="w-8 h-8 rounded-full border border-gray-200"
                                            />
                                            <div>
                                                <h4 className="text-sm font-semibold text-gray-900">{rec.user?.username || 'User'}</h4>
                                                <p className="text-xs text-gray-400">
                                                    {new Date(rec.createdAt).toLocaleDateString('id-ID', {
                                                        day: 'numeric',
                                                        month: 'short',
                                                        year: 'numeric',
                                                        hour: '2-digit',
                                                        minute: '2-digit'
                                                    })}
                                                </p>
                                            </div>
                                        </div>

                                        {/* Song Details */}
                                        <div className="bg-gray-50 rounded-lg p-3 mb-3 border border-gray-100">
                                            <p className="text-xs text-gray-400 font-medium">Lagu</p>
                                            <p className="text-sm font-bold text-gray-800 truncate">{rec.song?.title || 'Unknown Song'}</p>
                                            <p className="text-xs text-gray-500 truncate">{rec.song?.artist || 'Unknown Artist'}</p>
                                        </div>

                                        {/* Caption */}
                                        <div className="mb-3">
                                            <p className="text-xs font-medium text-gray-400 mb-1">Caption / Catatan:</p>
                                            <p className="text-sm text-gray-700 bg-gray-50/50 p-2.5 rounded-lg border border-gray-100 italic">
                                                {rec.caption && rec.caption.trim().length > 0 ? `"${rec.caption}"` : <span className="text-gray-400 not-italic">Tidak ada caption</span>}
                                            </p>
                                        </div>

                                        {/* Audio Player Control Bar */}
                                        {getAudioUrl(rec) && (
                                            <div className="mt-3">
                                                <audio controls src={getAudioUrl(rec)} className="w-full h-8" />
                                            </div>
                                        )}
                                    </div>
                                </div>

                                {/* Footer Action Bar */}
                                <div className="px-5 py-3 bg-gray-50 border-t border-gray-100 flex items-center justify-between">
                                    <div className="flex items-center gap-4 text-xs text-gray-500">
                                        <span className="flex items-center gap-1">
                                            <Heart className="w-3.5 h-3.5 text-red-500 fill-red-500" />
                                            {rec.likesCount || 0}
                                        </span>
                                        <span className="flex items-center gap-1">
                                            <MessageSquare className="w-3.5 h-3.5 text-blue-500" />
                                            {rec.commentsCount || 0}
                                        </span>
                                    </div>

                                    <button
                                        onClick={() => handleDelete(rec.id)}
                                        className="inline-flex items-center px-2.5 py-1.5 rounded-md text-xs font-semibold text-red-600 hover:bg-red-50 transition-colors"
                                        title="Hapus Postingan"
                                    >
                                        <Trash2 className="w-3.5 h-3.5 mr-1" />
                                        Hapus
                                    </button>
                                </div>
                            </div>
                        );
                    })}
                </div>
            )}
        </div>
    );
}
