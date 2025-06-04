import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';

/// Timing / reflex mini-game: stop the light!
class SpinningWheelGame extends FlameGame with TapDetector {
  // ───── Constants ──────────────────────────────────────────────────────────
  static const int    slots        = 24;
  static const double ringRadius   = 180; 
  static const double targetRadius = 20;  
  static const double needleWidth  = 12; 
  static const double needleLength = 48;

  // ───── Components ─────────────────────────────────────────────────────────
  late CircleComponent    ring;      // outline
  late CircleComponent    target;    // green dot
  late RectangleComponent needle;    // white rectangular spinner
  late TextPaint          scoreText;

  // ───── State ──────────────────────────────────────────────────────────────
  late Vector2 center;
  int    targetIndex = 0;
  double needleIndex = 0;   // fractional slot index
  double speed       = 4.0; // slots/s   (sign = direction)
  int    score       = 0;
  bool   gameOver    = false;

  // ───── Lifecycle ──────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    scoreText = TextPaint(
      style: const TextStyle(
        fontSize: 32,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );

    center = size / 2;

    _createRing();
    _createNeedle();
    _createTarget();      // also calls _chooseNewTarget()
  }

  // ───── Component builders ────────────────────────────────────────────────
  void _createRing() {
    ring = CircleComponent(
      position: center,
      radius: ringRadius,
      paint: Paint()
        ..color       = Colors.grey.shade800
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 4,
      anchor: Anchor.center,
    );
    add(ring);
  }

  void _createNeedle() {
    needle = RectangleComponent(
      size: Vector2(needleWidth, needleLength),
      paint: Paint()..color = Colors.white,
      anchor: Anchor.center,
    );
    add(needle);
  }

  void _createTarget() {
    target = CircleComponent(
      radius: targetRadius,
      paint: Paint()..color = Colors.green,
      anchor: Anchor.center,
    );
    add(target);
    _chooseNewTarget();   // place it for the first time
  }

  // ───── Target selection & direction flip ─────────────────────────────────
  void _chooseNewTarget() {
    const int maxOffset = 6;              // ≤ 90° (±6 slots)
    final rng = Random();

    int offset = rng.nextInt(maxOffset * 2) - maxOffset; // [-6 … +5]
    if (offset >= 0) offset += 1;                        // skip 0

    targetIndex = (targetIndex + offset + slots) % slots;

    final angle = 2 * pi * targetIndex / slots;
    target.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;

    // flip direction if offset opposes current motion
    final bool spinMatches =
        (speed < 0 && offset < 0) || (speed > 0 && offset > 0);
    if (!spinMatches) speed = -speed;
  }

  // ───── Game loop ─────────────────────────────────────────────────────────
  @override
  void update(double dt) {
    super.update(dt);
    if (gameOver) return;

    // advance needle
    needleIndex = (needleIndex + speed * dt) % slots;
    if (needleIndex < 0) needleIndex += slots;

    final angle = 2 * pi * needleIndex / slots;
    needle.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;
    needle.angle    = angle + pi / 2;  // point outward (long edge along radius)
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    scoreText.render(canvas, 'Score: $score',
        Vector2(size.x / 2, 50), anchor: Anchor.center);

    if (gameOver) {
      scoreText.render(canvas, 'Game Over\nTap to restart',
          size / 2, anchor: Anchor.center);
    }
  }

  // ───── Input ─────────────────────────────────────────────────────────────
  @override
  void onTap() {
    if (gameOver) {
      _resetGame();
      return;
    }

    final dist  = needle.position.distanceTo(target.position);
    final isHit = dist <= (needleLength / 2 + targetRadius); // use half-length

    if (isHit) {
      score += 1;
      speed  = (speed.isNegative ? -1 : 1) * (speed.abs() + 0.5);

      // flash green
      needle.paint.color = Colors.green;
      Future.delayed(const Duration(milliseconds: 120), () {
        needle.paint.color = Colors.white;
      });

      _chooseNewTarget();
    } else {
      _triggerGameOver();
    }
  }

  // ───── Helpers ───────────────────────────────────────────────────────────
  void _triggerGameOver() {
    gameOver = true;
    needle.paint.color = Colors.white.withOpacity(0.4);
  }

  void _resetGame() {
    score       = 0;
    needleIndex = 0;
    speed       = 4.0;
    gameOver    = false;

    needle.paint.color = Colors.white;
    needle.position    = center + Vector2(ringRadius, 0);
    needle.angle       = pi / 2;

    _chooseNewTarget();
  }
}
