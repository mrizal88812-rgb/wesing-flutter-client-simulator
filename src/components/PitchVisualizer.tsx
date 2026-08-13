import React, { useMemo } from 'react';
import { motion } from 'motion/react';

interface PitchVisualizerProps {
  isPlaying: boolean;
  currentTime: number;
  duration: number;
}

export default function PitchVisualizer({ isPlaying, currentTime, duration }: PitchVisualizerProps) {
  // Speed of scrolling: pixels per second
  const pixelsPerSecond = 50;
  const playheadX = 120; // X position of the vertical playhead line in pixels

  // Procedural note generator (generates consistent note blocks based on time)
  const notes = useMemo(() => {
    const list = [];
    // Generate enough notes to cover a 5-minute song (300 seconds)
    for (let i = 0; i < 100; i++) {
      const start = i * 3.5 + 1; // start time in seconds
      const length = 2.0; // duration of note in seconds
      
      // Determine a nice pitch level (between y=30 and y=110)
      // We use a pseudo-random but deterministic pattern so it's always the same
      const pitchLevels = [45, 65, 80, 50, 75, 90, 60, 85];
      const y = pitchLevels[i % pitchLevels.length];
      
      list.push({
        id: i,
        start,
        end: start + length,
        y,
      });
    }
    return list;
  }, []);

  // Calculate the current active target Y value for the playhead
  const currentTargetY = useMemo(() => {
    // Find if playhead is currently on a note
    const activeNote = notes.find(n => currentTime >= n.start && currentTime <= n.end);
    if (activeNote) {
      return activeNote.y;
    }
    
    // If between notes, interpolate or find the nearest next note
    const nextNote = notes.find(n => n.start > currentTime);
    const prevNote = [...notes].reverse().find(n => n.end < currentTime);
    
    if (prevNote && nextNote) {
      const gapRatio = (currentTime - prevNote.end) / (nextNote.start - prevNote.end);
      // Smooth step interpolation between notes
      return prevNote.y + (nextNote.y - prevNote.y) * gapRatio;
    }
    
    return 65; // default center height
  }, [notes, currentTime]);

  // Wobble effect to simulate real human voice pitch adjustments
  const voiceWobble = isPlaying ? Math.sin(currentTime * 10) * 3 : 0;
  const currentVoiceY = currentTargetY + voiceWobble;

  // Generate the continuous curve path matching the notes
  const pathD = useMemo(() => {
    if (notes.length === 0) return '';
    
    let d = '';
    const scrollX = currentTime * pixelsPerSecond;

    // We'll draw a continuous line connecting the notes
    notes.forEach((note, index) => {
      const startX = note.start * pixelsPerSecond - scrollX + playheadX;
      const endX = note.end * pixelsPerSecond - scrollX + playheadX;
      const y = note.y;

      if (index === 0) {
        d += `M ${startX - 20} ${y} `;
      }

      // Draw a line to start of this note, then along the note
      d += `L ${startX} ${y} `;
      d += `L ${endX} ${y} `;

      // Draw a curve to the next note if it exists
      const next = notes[index + 1];
      if (next) {
        const nextStartX = next.start * pixelsPerSecond - scrollX + playheadX;
        const cpX1 = endX + (nextStartX - endX) / 2;
        const cpY1 = y;
        const cpX2 = endX + (nextStartX - endX) / 2;
        const cpY2 = next.y;
        
        d += `C ${cpX1} ${cpY1}, ${cpX2} ${cpY2}, ${nextStartX} ${next.y} `;
      }
    });

    return d;
  }, [notes, currentTime]);

  return (
    <div id="pitch_visualizer_container" className="w-full h-36 bg-black/40 border-b border-white/5 relative overflow-hidden select-none">
      {/* Background horizontal guide lines */}
      <div className="absolute inset-x-0 top-1/4 h-[1px] bg-white/5 pointer-events-none" />
      <div className="absolute inset-x-0 top-2/4 h-[1px] bg-white/5 pointer-events-none" />
      <div className="absolute inset-x-0 top-3/4 h-[1px] bg-white/5 pointer-events-none" />

      {/* Grid lines */}
      <div className="absolute inset-0 bg-[radial-gradient(#ffffff03_1px,transparent_1px)] [background-size:16px_16px] pointer-events-none" />

      <svg className="w-full h-full absolute inset-0">
        <defs>
          {/* Neon Glow Filter */}
          <filter id="pitch-glow" x="-20%" y="-20%" width="140%" height="140%">
            <feGaussianBlur stdDeviation="4" result="blur" />
            <feMerge>
              <feMergeNode in="blur" />
              <feMergeNode in="SourceGraphic" />
            </feMerge>
          </filter>
          
          {/* Orange/Yellow Gradient for the curve */}
          <linearGradient id="curve-gradient" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stopColor="#f39c12" />
            <stop offset="50%" stopColor="#f1c40f" />
            <stop offset="100%" stopColor="#e67e22" />
          </linearGradient>
        </defs>

        {/* 1. Playhead Vertical Guide Line */}
        <line
          x1={playheadX}
          y1={0}
          x2={playheadX}
          y2={144}
          stroke="rgba(255, 255, 255, 0.12)"
          strokeWidth="1.5"
          strokeDasharray="4 4"
        />

        {/* 2. Target Note Blocks (gray/orange pills in the background) */}
        {notes.map((note) => {
          const scrollX = currentTime * pixelsPerSecond;
          const x1 = note.start * pixelsPerSecond - scrollX + playheadX;
          const x2 = note.end * pixelsPerSecond - scrollX + playheadX;
          
          // Only render visible blocks to optimize performance
          if (x2 < -50 || x1 > 500) return null;

          return (
            <g key={note.id}>
              {/* Dull background target block */}
              <line
                x1={x1}
                y1={note.y}
                x2={x2}
                y2={note.y}
                stroke="rgba(230, 126, 34, 0.25)"
                strokeWidth="8"
                strokeLinecap="round"
              />
              {/* Inner template line */}
              <line
                x1={x1}
                y1={note.y}
                x2={x2}
                y2={note.y}
                stroke="rgba(255, 255, 255, 0.15)"
                strokeWidth="2"
                strokeLinecap="round"
              />
            </g>
          );
        })}

        {/* 3. Glowing Sung Melody Path */}
        <path
          d={pathD}
          fill="none"
          stroke="url(#curve-gradient)"
          strokeWidth="3.5"
          strokeLinecap="round"
          strokeLinejoin="round"
          filter="url(#pitch-glow)"
          opacity={isPlaying ? 1 : 0.4}
          className="transition-opacity duration-300"
        />

        {/* Past Progress Line at the bottom of the visualizer (the solid orange bar) */}
        <line
          x1={0}
          y1={140}
          x2={playheadX}
          y2={140}
          stroke="#e67e22"
          strokeWidth="3"
        />
        <line
          x1={playheadX}
          y1={140}
          x2={400}
          y2={140}
          stroke="rgba(255,255,255,0.1)"
          strokeWidth="2"
        />

        {/* 4. Real-time Pitch Cursor (White Glowing Circle) */}
        <g>
          {/* Pulse Outer Ring */}
          {isPlaying && (
            <circle
              cx={playheadX}
              cy={currentVoiceY}
              r="12"
              fill="rgba(255, 255, 255, 0.2)"
              className="animate-ping"
              style={{ transformOrigin: `${playheadX}px ${currentVoiceY}px` }}
            />
          )}
          {/* Inner solid white circle with subtle orange border */}
          <circle
            cx={playheadX}
            cy={currentVoiceY}
            r="6"
            fill="white"
            stroke="#e67e22"
            strokeWidth="2"
            className="shadow-md"
            filter="drop-shadow(0px 0px 4px rgba(255,255,255,0.8))"
          />
        </g>
      </svg>
    </div>
  );
}
