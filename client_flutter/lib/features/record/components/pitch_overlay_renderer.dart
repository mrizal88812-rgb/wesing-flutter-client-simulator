import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../data/models/pitch_data.dart';

class PitchOverlayRenderer extends StatelessWidget {
  final double currentTimeSec;
  final List<PitchTrailPoint> userPitchTrail;
  final double currentPitchHz;
  final double currentMidiNote;
  final double targetMidiNote;
  final bool isHit;
  final double centsError;
  final double minMidiNote;
  final double maxMidiNote;
  final double windowSeconds;
  final double height;

  const PitchOverlayRenderer({
    Key? key,
    required this.currentTimeSec,
    required this.userPitchTrail,
    required this.currentPitchHz,
    required this.currentMidiNote,
    this.targetMidiNote = 0.0,
    this.isHit = false,
    this.centsError = 0.0,
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
        painter: _PitchOverlayPainter(
          currentTimeSec: currentTimeSec,
          userPitchTrail: userPitchTrail,
          currentPitchHz: currentPitchHz,
          currentMidiNote: currentMidiNote,
          targetMidiNote: targetMidiNote,
          isHit: isHit,
          centsError: centsError,
          minMidiNote: minMidiNote,
          maxMidiNote: maxMidiNote,
          windowSeconds: windowSeconds,
        ),
      ),
    );
  }
}

class _PitchOverlayPainter extends CustomPainter {
  final double currentTimeSec;
  final List<PitchTrailPoint> userPitchTrail;
  final double currentPitchHz;
  final double currentMidiNote;
  final double targetMidiNote;
  final bool isHit;
  final double centsError;
  final double minMidiNote;
  final double maxMidiNote;
  final double windowSeconds;

  _PitchOverlayPainter({
    required this.currentTimeSec,
    required this.userPitchTrail,
    required this.currentPitchHz,
    required this.currentMidiNote,
    required this.targetMidiNote,
    required this.isHit,
    required this.centsError,
    required this.minMidiNote,
    required this.maxMidiNote,
    required this.windowSeconds,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double playheadX = width * 0.25; // 25% playhead position
    final double midiRange = maxMidiNote - minMidiNote;

    final bool isVocalActive = currentMidiNote > 0 && currentPitchHz > 10.0;

    // Calculate Y position of the user vocal cursor
    double cursorY;
    if (isVocalActive) {
      final double midiRatio = ((currentMidiNote - minMidiNote) / midiRange).clamp(0.0, 1.0);
      cursorY = height - (midiRatio * height);
    } else {
      // Default rest position (middle of canvas) when silent
      cursorY = height * 0.5;
    }

    // 1. Draw horizontal guide line for the cursor
    final guidePaint = Paint()
      ..color = isVocalActive
          ? (isHit ? const Color(0xFF10B981) : const Color(0xFF38BDF8)).withOpacity(0.2)
          : const Color(0xFF94A3B8).withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, cursorY), Offset(width, cursorY), guidePaint);

    // 2. Draw User Vocal Cursor Dot (Titik Bulat Cursor Vocal)
    // Breathing/Voice pulse animation based on time and pitch frequency
    final double breathPhase = math.sin(currentTimeSec * 12.0);
    final double voicePulse = isVocalActive ? 4.0 + (breathPhase * 2.5) : (breathPhase * 1.2);

    final double outerHaloRadius = (16.0 + voicePulse).clamp(8.0, 28.0);
    final double midRingRadius = (10.0 + (voicePulse * 0.6)).clamp(6.0, 18.0);
    final double coreDotRadius = (5.5 + (voicePulse * 0.3)).clamp(4.0, 10.0);

    // Dynamic color depending on vocal hit performance
    Color cursorBaseColor;
    if (!isVocalActive) {
      cursorBaseColor = const Color(0xFF64748B); // Slate gray when silent
    } else if (targetMidiNote > 0) {
      final double absError = centsError.abs();
      if (absError <= 18) {
        cursorBaseColor = const Color(0xFF10B981); // Emerald Green = Perfect
      } else if (absError <= 35) {
        cursorBaseColor = const Color(0xFF06B6D4); // Bright Cyan = Great
      } else if (absError <= 50) {
        cursorBaseColor = const Color(0xFFF59E0B); // Amber = Good
      } else {
        cursorBaseColor = const Color(0xFFEF4444); // Red = Miss/Off-key
      }
    } else {
      cursorBaseColor = const Color(0xFF00F2FE); // Bright Electric Cyan
    }

    // Outer Blur Halo
    final haloPaint = Paint()
      ..color = cursorBaseColor.withOpacity(isVocalActive ? 0.35 : 0.15)
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
    canvas.drawCircle(Offset(playheadX, cursorY), outerHaloRadius, haloPaint);

    // Mid Vibrant Ring
    final ringPaint = Paint()
      ..color = cursorBaseColor.withOpacity(isVocalActive ? 0.85 : 0.4)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(playheadX, cursorY), midRingRadius, ringPaint);

    // Core Solid Circle
    final corePaint = Paint()
      ..color = isVocalActive ? Colors.white : cursorBaseColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(playheadX, cursorY), coreDotRadius, corePaint);

    // Center crisp dot
    if (isVocalActive) {
      final centerPaint = Paint()
        ..color = cursorBaseColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(playheadX, cursorY), 2.2, centerPaint);
    }

    // 3. Draw Rating Feedback Badge Effect ("PERFECT!", "GREAT!", "GOOD!", "COOL!", "MISS")
    if (isVocalActive && targetMidiNote > 0) {
      String feedbackText;
      Color badgeBg;
      Color textColor;
      Color glowColor;

      final double absError = centsError.abs();

      if (absError <= 15) {
        feedbackText = "PERFECT!";
        badgeBg = const Color(0xFF10B981);
        textColor = Colors.white;
        glowColor = const Color(0xFF34D399);
      } else if (absError <= 30) {
        feedbackText = "GREAT!";
        badgeBg = const Color(0xFF06B6D4);
        textColor = Colors.white;
        glowColor = const Color(0xFF22D3EE);
      } else if (absError <= 45) {
        feedbackText = "GOOD!";
        badgeBg = const Color(0xFFF59E0B);
        textColor = Colors.black;
        glowColor = const Color(0xFFFBBF24);
      } else if (absError <= 60) {
        feedbackText = "COOL!";
        badgeBg = const Color(0xFF8B5CF6);
        textColor = Colors.white;
        glowColor = const Color(0xFFA78BFA);
      } else {
        feedbackText = "MISS!";
        badgeBg = const Color(0xFFEF4444);
        textColor = Colors.white;
        glowColor = const Color(0xFFF87171);
      }

      // Draw floating badge slightly above the cursor dot
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: feedbackText,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();

      final double badgePaddingH = 8.0;
      final double badgePaddingV = 3.0;
      final double badgeW = tp.width + (badgePaddingH * 2);
      final double badgeH = tp.height + (badgePaddingV * 2);

      // Position badge floating above cursor Y
      final double badgeX = playheadX - (badgeW / 2);
      final double badgeY = (cursorY - outerHaloRadius - badgeH - 4.0).clamp(2.0, height - badgeH - 2.0);

      final Rect badgeRect = Rect.fromLTWH(badgeX, badgeY, badgeW, badgeH);
      final RRect badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(10.0));

      // Glow behind badge
      final badgeGlowPaint = Paint()
        ..color = glowColor.withOpacity(0.5)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      canvas.drawRRect(badgeRRect, badgeGlowPaint);

      // Badge background pill
      final badgeBgPaint = Paint()
        ..color = badgeBg
        ..style = PaintingStyle.fill;
      canvas.drawRRect(badgeRRect, badgeBgPaint);

      // Badge border
      final badgeBorderPaint = Paint()
        ..color = Colors.white.withOpacity(0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRRect(badgeRRect, badgeBorderPaint);

      // Badge text
      tp.paint(canvas, Offset(badgeX + badgePaddingH, badgeY + badgePaddingV));

      // 4. Hit Sparkle Particles for PERFECT/GREAT/COOL
      if (absError <= 30) {
        final sparkPaint = Paint()
          ..color = glowColor
          ..style = PaintingStyle.fill;

        final double sparkDistance = outerHaloRadius + 4.0;
        final angles = [0.0, math.pi / 4, math.pi / 2, 3 * math.pi / 4, math.pi, 5 * math.pi / 4, 3 * math.pi / 2, 7 * math.pi / 4];

        for (int i = 0; i < angles.length; i++) {
          final double angle = angles[i] + (currentTimeSec * 4.0);
          final double sx = playheadX + math.cos(angle) * sparkDistance;
          final double sy = cursorY + math.sin(angle) * sparkDistance;
          canvas.drawCircle(Offset(sx, sy), 1.2, sparkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PitchOverlayPainter oldDelegate) {
    return oldDelegate.currentTimeSec != currentTimeSec ||
        oldDelegate.currentMidiNote != currentMidiNote ||
        oldDelegate.targetMidiNote != targetMidiNote ||
        oldDelegate.centsError != centsError ||
        oldDelegate.isHit != isHit;
  }
}
