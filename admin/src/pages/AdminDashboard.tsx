import { useEffect, useState } from 'react';
import { Users, Music, PlayCircle, Radio, Lock, Globe } from 'lucide-react';
import { Recording } from '../types';
import { Link } from 'react-router-dom';

export default function AdminDashboard() {
  const [stats, setStats] = useState({ songs: 0, users: 1, totalPlays: 0, recordings: 0 });
  const [recentRecordings, setRecentRecordings] = useState<Recording[]>([]);

  useEffect(() => {
    fetch('/api/songs')
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          const plays = data.reduce((acc: number, curr: any) => acc + (curr.playCount || 0), 0);
          setStats(s => ({ ...s, songs: data.length, totalPlays: plays }));
        }
      });

    fetch('/api/recordings?all=true')
      .then(res => res.json())
      .then(data => {
        if (Array.isArray(data)) {
          setStats(s => ({ ...s, recordings: data.length }));
          setRecentRecordings(data.slice(0, 5));
        }
      });
  }, []);

  return (
    <div className="p-8">
      <h1 className="text-2xl font-bold mb-6 text-gray-900">Overview Dashboard</h1>

      <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
        {[
          { label: 'Total Songs', value: stats.songs, icon: Music, color: 'text-blue-500', bg: 'bg-blue-500' },
          { label: 'User Posts', value: stats.recordings, icon: Radio, color: 'text-purple-500', bg: 'bg-purple-500' },
          { label: 'Total Plays', value: stats.totalPlays, icon: PlayCircle, color: 'text-amber-500', bg: 'bg-amber-500' },
          { label: 'Total Users', value: stats.users, icon: Users, color: 'text-green-500', bg: 'bg-green-500' },
        ].map(stat => (
          <div key={stat.label} className="bg-white rounded-xl shadow-sm border border-gray-100 p-6 flex items-center">
            <div className={`w-12 h-12 ${stat.bg} bg-opacity-10 rounded-lg flex items-center justify-center mr-4`}>
              <stat.icon className={`w-6 h-6 ${stat.color}`} />
            </div>
            <div>
              <p className="text-sm font-medium text-gray-500">{stat.label}</p>
              <p className="text-2xl font-bold text-gray-900">{stat.value}</p>
            </div>
          </div>
        ))}
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 p-6">
        <div className="flex items-center justify-between mb-4">
          <h2 className="text-lg font-bold text-gray-900">Postingan Terbaru User</h2>
          <Link to="/recordings" className="text-xs font-semibold text-red-600 hover:underline">
            Lihat Semua ({stats.recordings}) &rarr;
          </Link>
        </div>

        {recentRecordings.length === 0 ? (
          <div className="text-gray-500 text-sm py-4">Belum ada postingan dari user.</div>
        ) : (
          <div className="divide-y divide-gray-100">
            {recentRecordings.map(rec => (
              <div key={rec.id} className="py-3 flex items-center justify-between">
                <div className="flex items-center space-x-3">
                  <img
                    src={rec.coverUrl || rec.song?.coverUrl || 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?w=400&h=400&fit=crop'}
                    alt="Cover"
                    className="w-10 h-10 rounded-lg object-cover"
                  />
                  <div>
                    <p className="text-sm font-semibold text-gray-900 truncate max-w-md">
                      {rec.song?.title || 'Unknown Song'} <span className="font-normal text-gray-500">by {rec.user?.username || 'User'}</span>
                    </p>
                    <p className="text-xs text-gray-500 italic truncate max-w-md">
                      {rec.caption && rec.caption.trim().length > 0 ? `"${rec.caption}"` : 'Tanpa caption'}
                    </p>
                  </div>
                </div>
                <div className="flex items-center gap-3">
                  <span className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${rec.visibility === 'Private' ? 'bg-amber-100 text-amber-800' : 'bg-emerald-100 text-emerald-800'
                    }`}>
                    {rec.visibility === 'Private' ? <Lock className="w-3 h-3 mr-1" /> : <Globe className="w-3 h-3 mr-1" />}
                    {rec.visibility || 'Public'}
                  </span>
                  <span className="text-xs font-bold text-amber-600 bg-amber-50 px-2 py-0.5 rounded">
                    Score: {rec.score}%
                  </span>
                </div>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
