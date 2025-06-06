// circle_tap_game.dart ── 24-circle game w/ dynamic max greens (Flame 1.17.x)

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';


class TapCircle extends CircleComponent {
  bool isGreen = false;

  TapCircle(Vector2 pos, double r)
      : super(
          position: pos,
          radius: r,
          paint: Paint()..color = Colors.red,
          anchor: Anchor.center,
        );

  void setGreen() {
    isGreen = true;
    paint..color = Colors.green..style = PaintingStyle.fill..strokeWidth = 0;
  }

  void setRed() {
    isGreen = false;
    paint..color = Colors.red..style = PaintingStyle.fill..strokeWidth = 0;
  }
}

class FourCircleGame extends FlameGame with MultiTouchTapDetector {
  // ── CONFIG ──────────────────────────────────────────────
  static const double r      = 32;
  static const double hGap   = 26;
  static const double vGap   = 30;
  static const spawnPeriod   = 0.6;
  static const greenLifetime = 1.0;
  static const _hsKey        = 'high_four_circle';

  // ── STATE ───────────────────────────────────────────────
  late List<TapCircle> circles;
  late TimerComponent spawnTimer;
  late TextComponent scoreLabel, bestLabel;
  int score      = 0;
  int highScore  = 0;
  bool gameOver  = false;
  final rng      = Random();

  @override
  Color backgroundColor() => const Color(0xFF222244);

  // ── UTILITY: current max greens based on score ──────────
  int get currentMaxGreens {
    if (score >= 60) return 4;
    if (score >= 30) return 3;
    if (score >= 10) return 2;
    return 1;
  }

  // ── LIFECYCLE ───────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    highScore =
        (await SharedPreferences.getInstance()).getInt(_hsKey) ?? 0;

    await Future.delayed(Duration.zero);
    _buildCircles();
    _buildLabels();
    _startSpawner();
  }

  // ── BUILD 24 CIRCLES (6 × 4) ────────────────────────────
  void _buildCircles() {
    final Vector2 centre = size / 2;
    const rows = 4;
    const cols = 4;

    final colOffsets =
        List<double>.generate(cols, (i) => (i - 1.5) * (2 * r + hGap));
final rowOffsets = List<double>.generate(
  rows,
  (j) => (j - 2.5) * (2 * r + vGap) + 180, // 👈 shift down by 40 pixels
);

    circles = [];
    for (final y in rowOffsets) {
      for (final x in colOffsets) {
        circles.add(TapCircle(centre + Vector2(x, y), r));
      }
    }
    addAll(circles);
  }

  // ── LABELS ──────────────────────────────────────────────
  void _buildLabels() {
    scoreLabel = TextComponent(
      text: 'Score: 0',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 18),
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 20, color: Colors.white)),
    );
    bestLabel = TextComponent(
      text: 'Best: $highScore',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 42),
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 16, color: Colors.grey)),
    );
    addAll([scoreLabel, bestLabel]);
  }

  // ── SPAWNER (now obeys currentMaxGreens) ────────────────
// ── SPAWNER (now obeys currentMaxGreens and deducts points) ─────────────
void _startSpawner() {
  spawnTimer = TimerComponent(
    period: spawnPeriod,
    repeat: true,
    onTick: () {
      if (gameOver) return;

      // Keep spawning until we reach the allowed max
      while (circles.where((c) => c.isGreen).length < currentMaxGreens) {
        // find red choices
        final redChoices = circles.where((c) => !c.isGreen).toList();
        if (redChoices.isEmpty) break;          // all green already

        final chosen = redChoices[rng.nextInt(redChoices.length)];
        chosen.setGreen();

        // schedule the revert + optional score penalty
        add(TimerComponent(
          period: greenLifetime,
          removeOnFinish: true,
          onTick: () {
            if (!gameOver && chosen.isGreen) {
              chosen.setRed();
              if (score > 0) {
                score--;
                scoreLabel.text = 'Score: $score';
                HapticFeedback.heavyImpact();

              }
            }
          },
        ));
      }
    },
  );
  add(spawnTimer);
}



  // ── INPUT ───────────────────────────────────────────────
  @override
  void onTapDown(int pointerId, TapDownInfo info) {
    if (gameOver) {
      _reset();
      return;
    }

    final tapPos = Vector2(
      info.eventPosition.widget.x,
      info.eventPosition.widget.y,
    );

    for (final c in circles) {
      if (tapPos.distanceTo(c.position) <= c.radius) {
        if (c.isGreen) {
          c.setRed();
          score++;
          scoreLabel.text = 'Score: $score';
          HapticFeedback.lightImpact();

          if (score > highScore) {
            highScore = score;
            bestLabel.text = 'Best: $highScore';
            SharedPreferences.getInstance()
                .then((p) => p.setInt(_hsKey, highScore));
          }
        } else {
            HapticFeedback.vibrate();

          _gameOver();
        }
        break;
      }
    }
  }

  // ── GAME OVER / RESET ──────────────────────────────────
  void _gameOver() {
    gameOver = true;
    circles.forEach((c) => c.setRed());
    spawnTimer.timer.stop();

    add(TextComponent(
      text: 'Game Over\nTap to restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 30, color: Colors.white)),
    ));
  }

  void _reset() {
    score = 0;
    scoreLabel.text = 'Score: 0';
    gameOver = false;

    children
        .where((e) =>
            e is TextComponent && e != scoreLabel && e != bestLabel)
        .toList()
        .forEach(remove);

    circles.forEach((c) => c.setRed());
    spawnTimer.timer.start();
  }
}

// ── FLUTTER SCREEN WRAPPER ───────────────────────────────
class GameScreenFourCircle extends StatelessWidget {
  const GameScreenFourCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Four Circle Tap'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GameWidget(game: FourCircleGame()),
    );
  }
}
