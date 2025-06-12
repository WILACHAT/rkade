import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

class MiniCircleTapGame extends FlameGame with TapDetector {
  // ── Layout ────────────────────────────────────────────────
  static const double r     = 70;
  static const double hGap  = 40;
  static const double vGap  = 40;

  // ── Timing – initial values, will shrink in play ─────────
  double spawnPeriod   = 0.60;
  double greenLifetime = 0.80;

  static const _hsKey = 'high_mini_circle';

  late final List<TapCircle> circles;
  late TimerComponent        _spawnTimer;
  late TextComponent         scoreLabel;
  late TextComponent         bestLabel;

  int  score      = 0;
  int  highScore  = 0;
  bool gameOver   = false;
  final rng       = Random();
  final Set<TapCircle> _greenCooldown = {};
  int _missStreak = 0;
  int get _currentMissPenalty => pow(2, _missStreak).toInt();

  @override
  Color backgroundColor() => const Color(0xFF222244);

  // ── Difficulty ramp (number of simultaneous greens) ──────
  int get currentMaxGreens {
    if (score >= 60) return 4;
    if (score >= 40) return 3;
    if (score >= 20) return 2;
    return 1;
  }

  // ── Lifecycle ─────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    highScore =
        (await SharedPreferences.getInstance()).getInt(_hsKey) ?? 0;

    await Future.delayed(Duration.zero);  // ensure size is ready
    _buildCircles();
    _buildLabels();
    _startSpawner();
  }

  // ── Build helpers ────────────────────────────────────────
  void _buildCircles() {
    final center = size / 2;
    const rows = 2, cols = 2;

    final colOffsets =
        List.generate(cols, (i) => (i - 0.5) * (2 * r + hGap));
    final rowOffsets =
        List.generate(rows, (j) => (j - 0.5) * (2 * r + vGap) + 100);

    circles = [
      for (final y in rowOffsets)
        for (final x in colOffsets) TapCircle(center + Vector2(x, y), r)
    ];
    addAll(circles);
  }

  void _buildLabels() {
    scoreLabel = TextComponent(
      text: 'Score: 0',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 20),
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 20, color: Colors.white)),
    );

    bestLabel = TextComponent(
      text: 'Best: $highScore',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 45),
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 16, color: Colors.grey)),
    );

    addAll([scoreLabel, bestLabel]);
  }

  // ── Spawner ───────────────────────────────────────────────
  void _startSpawner() {
    _spawnTimer = TimerComponent(
      period: spawnPeriod,
      repeat: true,
      onTick: _spawnGreens,
    );
    add(_spawnTimer);
  }

  void _spawnGreens() {
    if (gameOver) return;

    // Respect max-greens rule
    final activeGreens = _greenCooldown.length;
    if (activeGreens >= currentMaxGreens) return;

    // Eligible reds not cooling down
    final eligible = circles
        .where((c) => !c.isGreen && !_greenCooldown.contains(c))
        .toList();
    if (eligible.isEmpty) return;

    final chosen = eligible[rng.nextInt(eligible.length)];
    chosen.setGreen();
    _greenCooldown.add(chosen);

    // Schedule auto-revert
   // ── inside _spawnGreens() – replace the old TimerComponent ──
add(TimerComponent(
  period: greenLifetime,
  removeOnFinish: true,
  onTick: () {
    if (chosen.isGreen) {
      chosen.setRed();

      // 🔴 Exponential miss penalty
      score = max(0, score - _currentMissPenalty);
      _missStreak++; // increase the penalty streak

      scoreLabel.text = 'Score: $score';
      HapticFeedback.heavyImpact();
    }

    _greenCooldown.remove(chosen);
  },
));


  }

  // ── Tap handling ──────────────────────────────────────────
  @override
  void onTapDown(TapDownInfo info) {
    if (gameOver) {
      _reset();
      return;
    }

    final tapPos = info.eventPosition.widget;

    for (final c in circles) {
      if (tapPos.distanceTo(c.position) <= c.radius) {
        if (c.isGreen) {
          // ✔ Correct tap
          c.setRed();          // visual flip
          score++;
          _missStreak = 0; 
          scoreLabel.text = 'Score: $score';
          _updateSpeedIfNeeded();
          HapticFeedback.lightImpact();

          if (score > highScore) {
            highScore = score;
            bestLabel.text = 'Best: $highScore';
            SharedPreferences.getInstance()
                .then((p) => p.setInt(_hsKey, highScore));
          }
        } else {
          // ✖ Wrong tap
          HapticFeedback.vibrate();
          _gameOver();
        }
        break;
      }
    }
  }

  // ── Difficulty ramp ──────────────────────────────────────
  void _updateSpeedIfNeeded() {
    double newPeriod, newLifetime;

    if (score >= 150)       { newPeriod = 0.20; newLifetime = 0.25; }
    else if (score >= 100)  { newPeriod = 0.25; newLifetime = 0.35; }
    else if (score >= 60)  { newPeriod = 0.30; newLifetime = 0.45; }
    else if (score >= 30)  { newPeriod = 0.40; newLifetime = 0.60; }
    else if (score >= 20)  { newPeriod = 0.55; newLifetime = 0.80; }
    else if (score >= 10)  { newPeriod = 0.58; newLifetime = 0.8; }
else { newPeriod = 0.60; newLifetime = 0.80; }  // Match top-level init

    if (newPeriod != spawnPeriod) {
      spawnPeriod   = newPeriod;
      greenLifetime = newLifetime;
      // Swap timer but keep the same onTick logic
      remove(_spawnTimer);
      _spawnTimer = TimerComponent(
        period: spawnPeriod,
        repeat: true,
        onTick: _spawnGreens,
      );
      add(_spawnTimer);
    }
  }

  // ── Game over / reset ────────────────────────────────────
  void _gameOver() {
    gameOver = true;
    circles.forEach((c) => c.setRed());
    _spawnTimer.timer.stop();

    add(TextComponent(
      text: 'Game Over\nTap to restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 28, color: Colors.white)),
    ));
  }

  void _reset() {
    score = 0;
    gameOver = false;
    _greenCooldown.clear();

    scoreLabel.text = 'Score: 0';
    children
        .where((e) => e is TextComponent && e != scoreLabel && e != bestLabel)
        .toList()
        .forEach(remove);

    circles.forEach((c) => c.setRed());
    _spawnTimer.timer.start();
  }
}

// ── Embedding widget ───────────────────────────────────────
class GameScreenMiniCircle extends StatelessWidget {
  const GameScreenMiniCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mini Circle Tap'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GameWidget(game: MiniCircleTapGame()),
    );
  }
}
