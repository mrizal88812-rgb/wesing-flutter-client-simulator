import 'package:flutter/material.dart';
import '../../../data/models/pitch_data.dart';

class PitchGuideRenderer extends StatelessWidget {
  final double currentTimeSec;
  final List<PitchNoteBar> guideNotes;
  final double minMidiNote;
  final double maxMidiNote;
  final double windowSeconds;
  final double height;

  const PitchGuideRenderer({
    Key? key,
    required this.currentTimeSec,
    required this.guideNotes,
    this.minMidiNote = 55.0, // G3
    this.maxMidiNote = 77.0, // F5
    this.windowSeconds = 4.0,
    this.height = 160.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(double.infinity, height),
        painter: _PitchGuidePainter(
          currentTimeSec: currentTimeSec,
          guideNotes: guideNotes,
          minMidiNote: minMidiNote,
          maxMidiNote: maxMidiNote,
          windowSeconds: windowSeconds,
        ),
      ),
    );
  }
}

class _PitchGuidePainter extends CustomPainter {
  final double currentTimeSec;
  final List<PitchNoteBar> guideNotes;
  final double minMidiNote;
  final double maxMidiNote;
  final double windowSeconds;

  _PitchGuidePainter({
    required this.currentTimeSec,
    required this.guideNotes,
    required this.minMidiNote,
    required this.maxMidiNote,
    required this.windowSeconds,
  });

  String _midiToNoteName(int midi) {
    const notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
    final int octave = (midi ~/ 12) - 1;
    final int noteIndex = midi % 12;
    return '${notes[noteIndex]}$octave';
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double playheadX = width * 0.25; // 25% from left for active cursor

    final midiRange = maxMidiNote - minMidiNote;

    // 1. Draw DAW-style background horizontal grid lines
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      maxLines: 1,
    );

    for (int midi = minMidiNote.toInt(); midi <= maxMidiNote.toInt(); midi++) {
      final double y = height - ((midi - minMidiNote) / midiRange * height);
      final int noteInOctave = midi % 12;
      final bool isC = noteInOctave == 0;
      final bool isMajor = noteInOctave == 0 || noteInOctave == 4 || noteInOctave == 7 || noteInOctave == 11;

      // Draw background row stripes or lines
      final gridPaint = Paint()
        ..color = isC
            ? const Color(0xFF334155).withOpacity(0.25)
            : isMajor
                ? const Color(0xFF1E293B).withOpacity(0.18)
                : const Color(0xFF0F172A).withOpacity(0.1);
      
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint..strokeWidth = isC ? 1.5 : 0.8);

      // Draw note label on the far left with a premium clean dark background block
      if (isMajor && y > 10 && y < height - 10) {
        textPainter.text = TextSpan(
          text: _midiToNoteName(midi),
          style: TextStyle(
            color: isC ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            fontSize: 8,
            fontWeight: isC ? FontWeight.bold : FontWeight.w500,
            fontFamily: 'monospace',
          ),
        );
        textPainter.layout();
        
        // Dark pill background for text readability
        final rect = Rect.fromLTWH(4, y - 6, textPainter.width + 6, 12);
        final pillPaint = Paint()
          ..color = const Color(0xFF0B0F19).withOpacity(0.8)
          ..style = PaintingStyle.fill;
        canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(3)), pillPaint);
        
        textPainter.paint(canvas, Offset(7, y - textPainter.height / 2));
      }
    }

    // 2. Draw vertical time-grid lines
    final timePaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.1)
      ..strokeWidth = 0.8;
    final double pixelsPerSecond = width / windowSeconds;
    final double viewStartTime = currentTimeSec - (windowSeconds * 0.25);
    
    // Grid every 0.5 seconds
    final double startSec = (viewStartTime * 2).floor() / 2.0;
    for (double sec = startSec; sec < viewStartTime + windowSeconds; sec += 0.5) {
      final double x = playheadX + ((sec - currentTimeSec) * pixelsPerSecond);
      if (x >= 0 && x <= width) {
        canvas.drawLine(Offset(x, 0), Offset(x, height), timePaint);
      }
    }

    // 3. Draw playhead vertical line with subtle ambient outer glow
    final playheadGlow = Paint()
      ..color = const Color(0xFF00F2FE).withOpacity(0.1)
      ..strokeWidth = 6.0;
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, height), playheadGlow);

    final playheadPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(playheadX, 0), Offset(playheadX, height), playheadPaint);

    if (guideNotes.isEmpty) return;

    // 4. Draw Target Note Bars with gorgeous gradients & glow
    final barPaint = Paint()..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final note in guideNotes) {
      // Skip if outside viewport
      if (note.endTime < viewStartTime || note.startTime > (currentTimeSec + windowSeconds)) {
        continue;
      }

      final double xStart = playheadX + ((note.startTime - currentTimeSec) * pixelsPerSecond);
      final double xEnd = playheadX + ((note.endTime - currentTimeSec) * pixelsPerSecond);
      final double barWidth = (xEnd - xStart).clamp(6.0, width * 2);

      final double midiRatio = (note.midiNote - minMidiNote) / midiRange;
      final double yCenter = height - (midiRatio * height);
      const double barHeight = 12.0;
      final Rect barRect = Rect.fromLTWH(xStart, yCenter - (barHeight / 2), barWidth, barHeight);

      final bool isPast = note.endTime < currentTimeSec;
      final bool isActive = currentTimeSec >= note.startTime && currentTimeSec <= note.endTime;

      // Premium Neon Gradient shaders
      final Gradient gradient;
      final Color borderColor;

      if (isActive) {
        gradient = const LinearGradient(
          colors: [Color(0xFF00F2FE), Color(0xFF4FACFE)], // Cyan/Neon Blue active
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderColor = const Color(0xFF22D3EE);
        
        // Draw real background bloom glow under the active note bar
        final glowPaint = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..color = const Color(0xFF00F2FE).withOpacity(0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawRRect(RRect.fromRectAndRadius(barRect, const Radius.circular(6.0)), glowPaint);
      } else if (isPast) {
        gradient = LinearGradient(
          colors: [
            const Color(0xFF334155).withOpacity(0.2), 
            const Color(0xFF1E293B).withOpacity(0.2)
          ], // Darker transparent past note
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderColor = const Color(0xFF475569).withOpacity(0.4);
      } else {
        gradient = const LinearGradient(
          colors: [Color(0xFF818CF8), Color(0xFF6366F1)], // Premium Royal Purple-Indigo
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        borderColor = const Color(0xFF818CF8).withOpacity(0.7);
      }

      barPaint.shader = gradient.createShader(barRect);
      borderPaint.color = borderColor;

      final RRect rrect = RRect.fromRectAndRadius(barRect, const Radius.circular(6.0));
      canvas.drawRRect(rrect, barPaint);
      canvas.drawRRect(rrect, borderPaint);

      // Draw word label inside bar if space permits
      if (note.text.isNotEmpty && barWidth > 18) {
        textPainter.text = TextSpan(
          text: note.text,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.white70.withOpacity(0.8),
            fontSize: 8.5,
            fontWeight: isActive ? FontWeight.w900 : FontWeight.bold,
            letterSpacing: -0.2,
          ),
        );
        textPainter.layout(maxWidth: barWidth - 4);
        textPainter.paint(
          canvas,
          Offset(xStart + 3, yCenter - (textPainter.height / 2)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PitchGuidePainter oldDelegate) {
    return oldDelegate.currentTimeSec != currentTimeSec ||
        oldDelegate.guideNotes != guideNotes;
  }
}

