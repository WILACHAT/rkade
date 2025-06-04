import 'dart:math';

import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

/// A timing / reflex mini‑game that mimics an arcade "stop‑the‑light" wheel.
/// ────────────────────────────────────────────────────────────────────────────
/// • 24 windows are laid out around an outer ring.
/// • One of those windows is highlighted green (the target).
/// • A red indicator sweeps around the ring; tap when it sits on the target.
/// • After each hit the speed increases and the next target is chosen.
/// • A miss ends the game; tap again to restart.
class SpinningWheelGame extends FlameGame with TapDetector {
  // ----- Gameplay constants --------------------------------------------------
  static const int slots = 24;          // number of windows around the ring
  static const double ringRadius = 120; // visual radius in logical pixels
  static const double windowRadius = 10;
  static const double needleRadius = 12;

  // ----- Components ----------------------------------------------------------
  final List<CircleComponent> windows = [];
  late CircleComponent needle;
  late TextPaint scoreText;

  // ----- State ---------------------------------------------------------------
  late Vector2 center;
  int targetIndex = 0;
  double needleIndex = 0;               // can be fractional for smooth motion
  double speed = 4.0;                   // slots per second (± direction)
  int score = 0;
  bool gameOver = false;
  int lastDirectionFlipScore = -1;

  // ---------------------------------------------------------------------------
  @override
  Future<void> onLoad() async {
    scoreText = TextPaint(
      style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
    );

    center = size / 2;

    _createWindows();
    _chooseNewTarget();
    _createNeedle();
  }

  // Lay out grey windows around the ring
  void _createWindows() {
    for (int i = 0; i < slots; i++) {
      final angle = 2 * pi * i / slots;
      final pos = center + Vector2(cos(angle), sin(angle)) * ringRadius;
      final window = CircleComponent(
        position: pos,
        radius: windowRadius,
        paint: Paint()..color = Colors.grey.shade800,
        anchor: Anchor.center,
      );
      windows.add(window);
      add(window);
    }
  }

  void _createNeedle() {
    final angle = 2 * pi * needleIndex / slots;
    final pos = center + Vector2(cos(angle), sin(angle)) * ringRadius;
    needle = CircleComponent(
      position: pos,
      radius: needleRadius,
      paint: Paint()..color = Colors.red,
      anchor: Anchor.center,
    );
    add(needle);
  }

  // Choose a new green target window not equal to current target
  void _chooseNewTarget() {
    // reset previous target colour
    windows[targetIndex].paint.color = Colors.grey.shade800;

    int newIndex;
    do {
      newIndex = Random().nextInt(slots);
    } while (newIndex == targetIndex);
    targetIndex = newIndex;
    windows[targetIndex].paint.color = Colors.green;
  }

  // ---------------------------------------------------------------------------
  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    // advance the needle around the ring
    needleIndex = (needleIndex + speed * dt) % slots;
    if (needleIndex < 0) needleIndex += slots;

    final angle = 2 * pi * needleIndex / slots;
    needle.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    scoreText.render(
      canvas,
      'Score: $score',
      Vector2(size.x / 2, 50),
      anchor: Anchor.center,
    );

    if (gameOver) {
      scoreText.render(
        canvas,
        'Game Over\nTap to restart',
        size / 2,
        anchor: Anchor.center,
      );
    }
  }

  // ---------------------------------------------------------------------------


// ─────────────────────────────────────────────────────────────────────────────
// KEEP onTap(), but ensure it never runs when the game is over.
// ---------------------------------------------------------------------------
@override
void onTap() {
  // ─── 1. Restart if we just lost ───────────────────────────────────────────
  if (gameOver) {
    _resetGame();
    return;
  }

  // ─── 2. Overlap-based hit detection ───────────────────────────────────────
  // Get the target window component
  final targetWindow = windows[targetIndex];

  // Compute centre-to-centre distance
  final distance = needle.position.distanceTo(targetWindow.position);

  // Do the circles overlap?  (optionally add a few px of leniency)
  const double leniency = 0;          // set to e.g. 4 for a wider hit window
  final bool isHit = distance <= (needleRadius + windowRadius + leniency);

  if (isHit) {
    // ---- Hit! --------------------------------------------------------------
    score += 1;
    needle.paint.color = Colors.green;
    Future.delayed(const Duration(milliseconds: 120), () {
      needle.paint.color = Colors.red;
    });

    speed += 0.7;
    if (score % 2 == 0 && score != lastDirectionFlipScore) {
      if (Random().nextBool()) speed = -speed;
      lastDirectionFlipScore = score;
    }
    _chooseNewTarget();
  } else {
    // ---- Miss (no overlap) --------------------------------------------------
    _triggerGameOver();
  }
}



  void _triggerGameOver() {
    gameOver = true;
    needle.paint.color = Colors.red.withOpacity(0.4);
  }

 
  void _resetGame() {
  // 1. clear all window colours
  for (final win in windows) {
    win.paint.color = Colors.grey.shade800;
  }

  // 2. reset state
  score = 0;
  needleIndex = 0;
  speed = 4.0;
  lastDirectionFlipScore = -1;
  gameOver = false;

  // 3. restore needle visuals & position
  needle.paint.color = Colors.red;
  final angle = 0.0; // since needleIndex == 0
  needle.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;

  // 4. choose a fresh target
  _chooseNewTarget();
}
}
