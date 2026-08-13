import React, { useEffect, useState } from 'react';
import { Sliders, ToggleLeft, ToggleRight, Trash2, Edit3, Plus, X, UploadCloud, Check, HelpCircle } from 'lucide-react';

interface DspConfig {
  reverb: number;
  delay: number;
  echo: number;
  vocalGain: number;
  compressor: number;
  limiter: number;
  noiseReduction: number;
  eqLow: number;
  eqMid: number;
  eqHigh: number;
  stereoWidth: number;
  presence: number;
  brightness: number;
}

interface AudioPreset {
  id: String;
  name: String;
  description: String;
  icon: String;
  enabled: boolean;
  dsp: DspConfig;
}

export default function AdminPresets() {
  const [presets, setPresets] = useState<AudioPreset[]>([]);
  const [loading, setLoading] = useState(true);
  const [editingPreset, setEditingPreset] = useState<AudioPreset | null>(null);
  const [isCreateModalOpen, setIsCreateModalOpen] = useState(false);

  // Form State
  const [formId, setFormId] = useState('');
  const [formName, setFormName] = useState('');
  const [formDescription, setFormDescription] = useState('');
  const [formIcon, setFormIcon] = useState('headphones');
  const [formEnabled, setFormEnabled] = useState(true);
  const [rawJsonText, setRawJsonText] = useState('');
  const [useRawJson, setUseRawJson] = useState(false);

  // DSP sliders states
  const [dspReverb, setDspReverb] = useState(0.20);
  const [dspDelay, setDspDelay] = useState(0.05);
  const [dspEcho, setDspEcho] = useState(0.00);
  const [dspVocalGain, setDspVocalGain] = useState(1.15);
  const [dspCompressor, setDspCompressor] = useState(0.35);
  const [dspLimiter, setDspLimiter] = useState(0.15);
  const [dspNoiseReduction, setDspNoiseReduction] = useState(0.10);
  const [dspEqLow, setDspEqLow] = useState(0.05);
  const [dspEqMid, setDspEqMid] = useState(0.10);
  const [dspEqHigh, setDspEqHigh] = useState(0.08);
  const [dspStereoWidth, setDspStereoWidth] = useState(0.20);
  const [dspPresence, setDspPresence] = useState(0.15);
  const [dspBrightness, setDspBrightness] = useState(0.10);

  const [message, setMessage] = useState({ text: '', type: 'success' });

  useEffect(() => {
    fetchPresets();
  }, []);

  const showToast = (text: string, type: 'success' | 'error' = 'success') => {
    setMessage({ text, type });
    setTimeout(() => setMessage({ text: '', type: 'success' }), 4000);
  };

  const fetchPresets = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/presets?all=true');
      const data = await res.json();
      if (data.presets) {
        setPresets(data.presets);
      }
    } catch (e) {
      console.error('Error fetching presets:', e);
      showToast('Gagal memuat daftar preset', 'error');
    } finally {
      setLoading(false);
    }
  };

  const togglePreset = async (preset: AudioPreset) => {
    try {
      const updatedEnabled = !preset.enabled;
      const res = await fetch(`/api/presets/${preset.id}`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ enabled: updatedEnabled }),
      });
      if (res.ok) {
        setPresets(presets.map(p => p.id === preset.id ? { ...p, enabled: updatedEnabled } : p));
        showToast(`Preset "${preset.name}" berhasil ${updatedEnabled ? 'diaktifkan' : 'dinonaktifkan'}`);
      }
    } catch (e) {
      showToast('Gagal mengubah status preset', 'error');
    }
  };

  const deletePreset = async (id: String) => {
    if (!window.confirm('Apakah Anda yakin ingin menghapus preset ini? Tindakan ini tidak dapat dibatalkan.')) return;
    try {
      const res = await fetch(`/api/presets/${id}`, { method: 'DELETE' });
      if (res.ok) {
        setPresets(presets.filter(p => p.id !== id));
        showToast('Preset berhasil dihapus');
      }
    } catch (e) {
      showToast('Gagal menghapus preset', 'error');
    }
  };

  const openEditModal = (preset: AudioPreset) => {
    setEditingPreset(preset);
    setFormId(preset.id as string);
    setFormName(preset.name as string);
    setFormDescription(preset.description as string);
    setFormIcon(preset.icon as string);
    setFormEnabled(preset.enabled);
    setUseRawJson(false);

    // Set dsp sliders
    const d = preset.dsp;
    setDspReverb(d.reverb ?? 0.0);
    setDspDelay(d.delay ?? 0.0);
    setDspEcho(d.echo ?? 0.0);
    setDspVocalGain(d.vocalGain ?? 1.0);
    setDspCompressor(d.compressor ?? 0.0);
    setDspLimiter(d.limiter ?? 0.0);
    setDspNoiseReduction(d.noiseReduction ?? 0.0);
    setDspEqLow(d.eqLow ?? 0.0);
    setDspEqMid(d.eqMid ?? 0.0);
    setDspEqHigh(d.eqHigh ?? 0.0);
    setDspStereoWidth(d.stereoWidth ?? 0.0);
    setDspPresence(d.presence ?? 0.0);
    setDspBrightness(d.brightness ?? 0.0);

    setRawJsonText(JSON.stringify(preset, null, 2));
    setIsCreateModalOpen(false);
  };

  const openCreateModal = () => {
    setEditingPreset(null);
    setFormId('');
    setFormName('');
    setFormDescription('');
    setFormIcon('headphones');
    setFormEnabled(true);
    setUseRawJson(false);

    setDspReverb(0.20);
    setDspDelay(0.05);
    setDspEcho(0.00);
    setDspVocalGain(1.15);
    setDspCompressor(0.35);
    setDspLimiter(0.15);
    setDspNoiseReduction(0.10);
    setDspEqLow(0.05);
    setDspEqMid(0.10);
    setDspEqHigh(0.08);
    setDspStereoWidth(0.20);
    setDspPresence(0.15);
    setDspBrightness(0.10);

    const initialTemplate = {
      name: "Preset Baru",
      description: "Deskripsi preset dsp audio",
      icon: "headphones",
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
    };
    setRawJsonText(JSON.stringify(initialTemplate, null, 2));
    setIsCreateModalOpen(true);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    let bodyData: any = {};

    if (useRawJson) {
      try {
        bodyData = JSON.parse(rawJsonText);
        if (!bodyData.name || !bodyData.dsp) {
          showToast('JSON harus berisi "name" dan objek "dsp"', 'error');
          return;
        }
      } catch (err) {
        showToast('Format JSON salah / tidak valid!', 'error');
        return;
      }
    } else {
      if (!formName.trim()) {
        showToast('Nama Preset wajib diisi!', 'error');
        return;
      }
      bodyData = {
        id: formId ? formId : undefined,
        name: formName,
        description: formDescription,
        icon: formIcon,
        enabled: formEnabled,
        dsp: {
          reverb: dspReverb,
          delay: dspDelay,
          echo: dspEcho,
          vocalGain: dspVocalGain,
          compressor: dspCompressor,
          limiter: dspLimiter,
          noiseReduction: dspNoiseReduction,
          eqLow: dspEqLow,
          eqMid: dspEqMid,
          eqHigh: dspEqHigh,
          stereoWidth: dspStereoWidth,
          presence: dspPresence,
          brightness: dspBrightness
        }
      };
    }

    try {
      const res = await fetch('/api/presets', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(bodyData),
      });

      if (res.ok) {
        showToast('Preset berhasil disimpan ke database!');
        setEditingPreset(null);
        setIsCreateModalOpen(false);
        fetchPresets();
      } else {
        showToast('Gagal menyimpan preset', 'error');
      }
    } catch (err) {
      showToast('Gagal menghubungi server', 'error');
    }
  };

  return (
    <div className="p-8 font-sans max-w-7xl mx-auto">
      {/* Toast Notification */}
      {message.text && (
        <div className={`fixed top-4 right-4 z-50 flex items-center px-4 py-3 rounded-xl shadow-lg border text-xs font-bold transition-all animate-bounce ${message.type === 'error' ? 'bg-red-50 border-red-200 text-red-600' : 'bg-green-50 border-green-200 text-green-600'
          }`}>
          {message.type === 'error' ? <X className="w-4 h-4 mr-2" /> : <Check className="w-4 h-4 mr-2" />}
          {message.text}
        </div>
      )}

      {/* Header section */}
      <div className="flex flex-col md:flex-row justify-between items-start md:items-center gap-4 mb-8">
        <div>
          <h1 className="text-2xl font-black text-gray-900 tracking-tight flex items-center">
            <Sliders className="w-6 h-6 mr-2 text-red-500" />
            Audio DSP Preset Management
          </h1>
          <p className="text-gray-500 text-sm mt-1">
            Konfigurasikan preset efek vokal dsp server untuk aplikasi karaoke Flutter secara dinamis tanpa perlu update berkala.
          </p>
        </div>
        <button
          onClick={openCreateModal}
          className="flex items-center px-4 py-2.5 rounded-xl bg-red-600 text-white font-bold text-xs hover:bg-red-700 active:scale-95 transition-all shadow-md shadow-red-600/10"
        >
          <Plus className="w-4 h-4 mr-1.5" />
          Tambah Preset
        </button>
      </div>

      {/* Main Presets Grid */}
      {loading ? (
        <div className="flex flex-col items-center justify-center py-20">
          <div className="w-8 h-8 border-4 border-red-600 border-t-transparent rounded-full animate-spin"></div>
          <span className="text-sm text-gray-500 font-bold mt-4">Memuat data preset...</span>
        </div>
      ) : (
        <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
          {presets.map((preset) => (
            <div
              key={preset.id as string}
              className={`bg-white rounded-2xl border transition-all hover:shadow-lg p-6 flex flex-col justify-between ${preset.enabled ? 'border-gray-200/80 shadow-sm' : 'border-gray-100 bg-gray-50/50 opacity-70'
                }`}
            >
              <div>
                {/* Preset Card Header */}
                <div className="flex justify-between items-start mb-4">
                  <div className="flex items-center">
                    <div className="w-10 h-10 rounded-xl bg-gray-100 flex items-center justify-center font-bold text-lg text-gray-700 capitalize">
                      {preset.name.charAt(0)}
                    </div>
                    <div className="ml-3">
                      <h3 className="font-bold text-gray-900 text-sm">{preset.name}</h3>
                      <span className="text-[10px] text-gray-400 uppercase tracking-widest font-bold">ID: {preset.id}</span>
                    </div>
                  </div>

                  <button
                    onClick={() => togglePreset(preset)}
                    className="text-gray-400 hover:text-red-500 transition-colors"
                  >
                    {preset.enabled ? (
                      <ToggleRight className="w-8 h-8 text-green-500" />
                    ) : (
                      <ToggleLeft className="w-8 h-8 text-gray-300" />
                    )}
                  </button>
                </div>

                {/* Description */}
                <p className="text-xs text-gray-500 leading-relaxed mb-4">{preset.description || 'Tidak ada deskripsi.'}</p>

                {/* Mini DSP indicators */}
                <div className="bg-gray-50 rounded-xl p-3 border border-gray-100 grid grid-cols-3 gap-2 text-[10px] font-bold text-gray-600 mb-4">
                  <div>Reverb: <span className="text-gray-900">{(preset.dsp?.reverb * 100).toFixed(0)}%</span></div>
                  <div>Delay: <span className="text-gray-900">{(preset.dsp?.delay * 100).toFixed(0)}%</span></div>
                  <div>VocalGain: <span className="text-gray-900">{preset.dsp?.vocalGain}x</span></div>
                  <div>Compressor: <span className="text-gray-900">{(preset.dsp?.compressor * 100).toFixed(0)}%</span></div>
                  <div>Limiter: <span className="text-gray-900">{(preset.dsp?.limiter * 100).toFixed(0)}%</span></div>
                  <div>Stereo: <span className="text-gray-900">{(preset.dsp?.stereoWidth * 100).toFixed(0)}%</span></div>
                </div>
              </div>

              {/* Card Actions */}
              <div className="flex border-t border-gray-100 pt-4 gap-2">
                <button
                  onClick={() => openEditModal(preset)}
                  className="flex-1 flex items-center justify-center px-3 py-2 border border-gray-200 hover:bg-gray-50 rounded-xl text-xs font-bold text-gray-700 active:scale-95 transition-all"
                >
                  <Edit3 className="w-3.5 h-3.5 mr-1" />
                  Edit DSP
                </button>
                <button
                  onClick={() => deletePreset(preset.id)}
                  className="flex items-center justify-center p-2 border border-red-100 hover:bg-red-50 text-red-500 rounded-xl active:scale-95 transition-all"
                >
                  <Trash2 className="w-4 h-4" />
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Create / Edit Modal */}
      {(editingPreset || isCreateModalOpen) && (
        <div className="fixed inset-0 z-50 bg-black/60 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
          <div className="bg-white rounded-3xl shadow-2xl w-full max-w-5xl border border-gray-100 max-h-[90vh] overflow-hidden flex flex-col">

            {/* Modal Header */}
            <div className="px-6 md:px-8 py-5 border-b border-gray-100 flex justify-between items-center bg-gray-50/50 flex-shrink-0">
              <div>
                <h2 className="text-base font-black text-gray-900">
                  {editingPreset ? `Edit Preset: ${editingPreset.name}` : 'Buat DSP Preset Baru'}
                </h2>
                <p className="text-xs text-gray-400 mt-0.5">Konfigurasi audio effects parameters</p>
              </div>
              <button
                type="button"
                onClick={() => {
                  setEditingPreset(null);
                  setIsCreateModalOpen(false);
                }}
                className="p-1.5 hover:bg-gray-100 rounded-lg text-gray-400 hover:text-gray-600 transition-colors"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSubmit} className="flex-1 flex flex-col min-h-0 overflow-hidden">
              {/* Scrollable Content Body */}
              <div className="flex-1 overflow-y-auto p-6 md:p-8">
                <div className="flex flex-col lg:flex-row gap-8">
                  {/* Left Side: Basic Info & Mode Selection */}
                  <div className="lg:w-1/2 space-y-4">
                    {/* Mode Selector */}
                    <div className="flex bg-gray-100 p-1 rounded-xl border border-gray-200 gap-1 text-xs font-bold">
                      <button
                        type="button"
                        onClick={() => setUseRawJson(false)}
                        className={`flex-1 py-2 rounded-lg transition-all ${!useRawJson ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
                      >
                        Form Inputs Sliders
                      </button>
                      <button
                        type="button"
                        onClick={() => setUseRawJson(true)}
                        className={`flex-1 py-2 rounded-lg transition-all ${useRawJson ? 'bg-white text-gray-900 shadow-sm' : 'text-gray-500 hover:text-gray-700'}`}
                      >
                        Raw JSON Upload / Paste
                      </button>
                    </div>

                    {!useRawJson ? (
                      <>
                        <div>
                          <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">Nama Preset *</label>
                          <input
                            type="text"
                            placeholder="Contoh: Ballad Concert"
                            value={formName}
                            onChange={(e) => setFormName(e.target.value)}
                            required
                            className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-xs text-gray-900 placeholder-gray-400 focus:outline-none focus:border-red-500 focus:bg-white transition-colors"
                          />
                        </div>

                        {!editingPreset && (
                          <div>
                            <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">ID Preset (Optional)</label>
                            <input
                              type="text"
                              placeholder="Contoh: ballad_concert (akan otomatis digenerate jika kosong)"
                              value={formId}
                              onChange={(e) => setFormId(e.target.value)}
                              className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-xs text-gray-900 placeholder-gray-400 focus:outline-none focus:border-red-500 focus:bg-white transition-colors"
                            />
                          </div>
                        )}

                        <div>
                          <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">Deskripsi Efek</label>
                          <textarea
                            placeholder="Deskripsikan output audio yang dihasilkan preset ini..."
                            value={formDescription}
                            onChange={(e) => setFormDescription(e.target.value)}
                            rows={3}
                            className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-xs text-gray-900 placeholder-gray-400 focus:outline-none focus:border-red-500 focus:bg-white resize-none transition-colors"
                          />
                        </div>

                        <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                          <div>
                            <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">Icon Nama</label>
                            <select
                              value={formIcon}
                              onChange={(e) => setFormIcon(e.target.value)}
                              className="w-full bg-gray-50 border border-gray-200 rounded-xl px-4 py-2.5 text-xs text-gray-900 focus:outline-none focus:border-red-500 focus:bg-white transition-colors"
                            >
                              <option value="headphones">Headphones</option>
                              <option value="warm">Warm Waveform</option>
                              <option value="bright">Sparkles / Bright</option>
                              <option value="pop">Microphone Pop</option>
                              <option value="ballad">Heart Ballad</option>
                              <option value="acoustic">Acoustic Guitar</option>
                              <option value="jazz">Music Notes Jazz</option>
                              <option value="rock">Flash Rock</option>
                              <option value="live">Concert Studio</option>
                              <option value="ktv">KTV Echo</option>
                            </select>
                          </div>

                          <div>
                            <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">Default Status</label>
                            <div className="flex items-center h-10 mt-1">
                              <label className="relative inline-flex items-center cursor-pointer">
                                <input
                                  type="checkbox"
                                  checked={formEnabled}
                                  onChange={(e) => setFormEnabled(e.target.checked)}
                                  className="sr-only peer"
                                />
                                <div className="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-green-500"></div>
                                <span className="ml-2.5 text-xs font-bold text-gray-700">{formEnabled ? 'Enabled / Active' : 'Disabled'}</span>
                              </label>
                            </div>
                          </div>
                        </div>

                        <div className="bg-yellow-50 border border-yellow-100 rounded-2xl p-4 text-[11px] text-yellow-800 leading-relaxed flex items-start">
                          <HelpCircle className="w-4 h-4 mr-2 text-yellow-600 flex-shrink-0 mt-0.5" />
                          <div>
                            <span className="font-bold">Info: </span>
                            Parameter dsp ini dikompilasi secara real-time ke mixer audio native di client Flutter. Nilai berkisar antara 0.0 (mati) hingga 1.0 (kekuatan penuh).
                          </div>
                        </div>
                      </>
                    ) : (
                      <div className="h-full flex flex-col">
                        <label className="block text-[11px] font-bold text-gray-500 mb-1 uppercase tracking-wider">Raw JSON Data</label>
                        <textarea
                          value={rawJsonText}
                          onChange={(e) => setRawJsonText(e.target.value)}
                          rows={15}
                          className="w-full font-mono text-xs bg-gray-900 text-green-400 border border-gray-800 rounded-xl p-4 focus:outline-none focus:border-red-500 focus:bg-gray-950 resize-none h-[350px]"
                        />
                        <span className="text-[10px] text-gray-400 mt-2">
                          Gunakan format schema dsp objek yang sesuai. Format: {"{ name, description, dsp: { reverb, delay... } }"}
                        </span>
                      </div>
                    )}
                  </div>

                  {/* Right Side: Interactive Sliders (Disabled in raw JSON mode) */}
                  {!useRawJson && (
                    <div className="lg:w-1/2 bg-gray-50/80 rounded-2xl border border-gray-100 p-6 space-y-4">
                      <h3 className="text-xs font-black text-gray-900 uppercase tracking-widest border-b border-gray-200/80 pb-3 flex items-center justify-between">
                        <span className="flex items-center">
                          <Sliders className="w-4 h-4 text-red-500 mr-2" />
                          DSP Slider Parameters
                        </span>
                        <span className="text-[10px] font-bold text-gray-400 lowercase">13 controls</span>
                      </h3>

                      <div className="grid grid-cols-1 sm:grid-cols-2 gap-x-5 gap-y-4">
                        {/* Reverb Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Reverb Mix</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspReverb * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspReverb}
                            onChange={(e) => setDspReverb(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Delay Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Spatial Delay</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspDelay * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspDelay}
                            onChange={(e) => setDspDelay(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Echo Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Feedback Echo</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspEcho * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspEcho}
                            onChange={(e) => setDspEcho(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Vocal Gain Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Vocal Gain</span>
                            <span className="text-red-600 font-mono font-extrabold">{dspVocalGain.toFixed(2)}x</span>
                          </div>
                          <input
                            type="range" min="0.5" max="2.0" step="0.05" value={dspVocalGain}
                            onChange={(e) => setDspVocalGain(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Compressor Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Compressor Rate</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspCompressor * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspCompressor}
                            onChange={(e) => setDspCompressor(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Limiter Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Limiter Threshold</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspLimiter * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspLimiter}
                            onChange={(e) => setDspLimiter(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Noise Reduction Slider */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Noise Gate Filter</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspNoiseReduction * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspNoiseReduction}
                            onChange={(e) => setDspNoiseReduction(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* EQ Low */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>EQ Bass (Low)</span>
                            <span className="text-red-600 font-mono font-extrabold">{dspEqLow >= 0 ? '+' : ''}{dspEqLow.toFixed(2)}</span>
                          </div>
                          <input
                            type="range" min="-0.5" max="0.5" step="0.01" value={dspEqLow}
                            onChange={(e) => setDspEqLow(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* EQ Mid */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>EQ Mid Range</span>
                            <span className="text-red-600 font-mono font-extrabold">{dspEqMid >= 0 ? '+' : ''}{dspEqMid.toFixed(2)}</span>
                          </div>
                          <input
                            type="range" min="-0.5" max="0.5" step="0.01" value={dspEqMid}
                            onChange={(e) => setDspEqMid(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* EQ High */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>EQ Treble (High)</span>
                            <span className="text-red-600 font-mono font-extrabold">{dspEqHigh >= 0 ? '+' : ''}{dspEqHigh.toFixed(2)}</span>
                          </div>
                          <input
                            type="range" min="-0.5" max="0.5" step="0.01" value={dspEqHigh}
                            onChange={(e) => setDspEqHigh(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Stereo Width */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Stereo Width</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspStereoWidth * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspStereoWidth}
                            onChange={(e) => setDspStereoWidth(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Presence */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Vocal Presence</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspPresence * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspPresence}
                            onChange={(e) => setDspPresence(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>

                        {/* Brightness */}
                        <div>
                          <div className="flex justify-between text-[11px] font-bold text-gray-600 mb-1">
                            <span>Vocal Brightness</span>
                            <span className="text-red-600 font-mono font-extrabold">{(dspBrightness * 100).toFixed(0)}%</span>
                          </div>
                          <input
                            type="range" min="0.0" max="1.0" step="0.01" value={dspBrightness}
                            onChange={(e) => setDspBrightness(parseFloat(e.target.value))}
                            className="w-full accent-red-500 h-1.5 bg-gray-200 rounded-lg appearance-none cursor-pointer"
                          />
                        </div>
                      </div>
                    </div>
                  )}
                </div>
              </div>

              {/* Form Controls Footer */}
              <div className="px-6 md:px-8 py-4 bg-gray-50/50 border-t border-gray-100 flex justify-end gap-3 flex-shrink-0">
                <button
                  type="button"
                  onClick={() => {
                    setEditingPreset(null);
                    setIsCreateModalOpen(false);
                  }}
                  className="px-5 py-2.5 rounded-xl border border-gray-200 font-bold text-xs text-gray-600 hover:bg-gray-50 transition-colors"
                >
                  Batal
                </button>
                <button
                  type="submit"
                  className="px-6 py-2.5 rounded-xl bg-red-600 text-white font-bold text-xs hover:bg-red-700 active:scale-95 transition-all shadow-md shadow-red-600/15"
                >
                  Simpan Konfigurasi
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
