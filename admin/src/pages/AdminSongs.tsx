import { useEffect, useState } from 'react';
import { Song } from '../types';
import { Trash2, Edit2, Play } from 'lucide-react';

export default function AdminSongs() {
  const [songs, setSongs] = useState<Song[]>([]);

  const fetchSongs = () => {
    fetch('/api/songs')
      .then(res => res.json())
      .then(data => setSongs(data));
  };

  useEffect(() => {
    fetchSongs();
  }, []);

  const handleDelete = (id: string) => {
    if (confirm('Hapus lagu ini?')) {
      fetch(`/api/songs/${id}`, { method: 'DELETE' })
        .then(() => fetchSongs());
    }
  };

  return (
    <div className="p-8">
      <div className="flex justify-between items-center mb-6">
        <h1 className="text-2xl font-bold text-gray-900">Manage Songs</h1>
      </div>

      <div className="bg-white rounded-xl shadow-sm border border-gray-100 overflow-hidden">
        <table className="w-full text-left border-collapse">
          <thead>
            <tr className="bg-gray-50 border-b border-gray-200">
              <th className="px-6 py-4 text-xs font-semibold text-gray-500 uppercase">Song</th>
              <th className="px-6 py-4 text-xs font-semibold text-gray-500 uppercase">Tags</th>
              <th className="px-6 py-4 text-xs font-semibold text-gray-500 uppercase">Plays</th>
              <th className="px-6 py-4 text-xs font-semibold text-gray-500 uppercase text-right">Actions</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {songs.map(song => (
              <tr key={song.id} className="hover:bg-gray-50">
                <td className="px-6 py-4">
                  <div className="flex items-center">
                    <img src={song.coverUrl} className="w-10 h-10 rounded object-cover mr-3" />
                    <div>
                      <p className="font-medium text-gray-900">{song.title}</p>
                      <p className="text-sm text-gray-500">{song.artist}</p>
                    </div>
                  </div>
                </td>
                <td className="px-6 py-4">
                  <div className="flex gap-1 flex-wrap">
                    {(song.genre ? [song.genre] : (song as any).tags || []).map((tag: string) => (
                      <span key={tag} className="px-2 py-1 bg-gray-100 text-gray-600 text-xs rounded-full">
                        {tag}
                      </span>
                    ))}
                  </div>
                </td>
                <td className="px-6 py-4 text-sm text-gray-600">
                  {song.playCount || 0}
                </td>
                <td className="px-6 py-4 text-right space-x-2">
                  <button onClick={() => handleDelete(song.id)} className="p-2 text-gray-400 hover:text-red-600 hover:bg-red-50 rounded-lg transition-colors">
                    <Trash2 className="w-5 h-5" />
                  </button>
                </td>
              </tr>
            ))}
            {songs.length === 0 && (
              <tr>
                <td colSpan={4} className="px-6 py-12 text-center text-gray-500">
                  No songs available.
                </td>
              </tr>
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
