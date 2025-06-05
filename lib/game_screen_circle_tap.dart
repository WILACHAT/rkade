// circle_tap_game.dart  ──  Single-circle reaction game (Flame 1.17.x)

import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';
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
    paint
      ..color = Colors.green
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
  }

  void setRed() {
    isGreen = false;
    paint
      ..color = Colors.red
      ..style = PaintingStyle.fill
      ..strokeWidth = 0;
  }
}

class SingleCircleGame extends FlameGame with TapDetector {
  // ── CONFIG ──────────────────────────────────────────────
  static const double r = 60;        // circle radius
  static const spawnPeriod   = 2.0;  // seconds between green flashes
  static const greenLifetime = 1.2;  // how long it stays green
  static const _hsKey = 'high_single_circle';

  // ── STATE ───────────────────────────────────────────────
  late TapCircle circle;
  late TimerComponent spawnTimer;
  late TextComponent scoreLabel, bestLabel;

  int score = 0;
  int highScore = 0;
  bool gameOver = false;

  @override
  Color backgroundColor() => const Color(0xFF222244);

  // ── LIFECYCLE ───────────────────────────────────────────
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    highScore =
        (await SharedPreferences.getInstance()).getInt(_hsKey) ?? 0;

    // wait a frame so size is available
    await Future.delayed(Duration.zero);

    _buildCircle();
    _buildLabels();
    _startSpawner();
  }

  void _buildCircle() {
    circle = TapCircle(size / 2, r);
    add(circle);
  }

  void _buildLabels() {
    scoreLabel = TextComponent(
      text: 'Score: 0',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 20),
      textRenderer: TextPaint(
          style: const TextStyle(fontSize: 22, color: Colors.white)),
    );
    bestLabel = TextComponent(
      text: 'Best: $highScore',
      anchor: Anchor.topCenter,
      position: Vector2(size.x / 2, 48),
      textRenderer: TextPaint(
          style: const TextStyle(fontSize: 18, color: Colors.grey)),
    );
    addAll([scoreLabel, bestLabel]);
  }

  // ── SPAWNER ─────────────────────────────────────────────
  void _startSpawner() {
    spawnTimer = TimerComponent(
      period: spawnPeriod,
      repeat: true,
      onTick: () {
        if (gameOver) return;
        if (circle.isGreen) return; // already green → skip
        circle.setGreen();

        // schedule the return to red after greenLifetime
        add(TimerComponent(
          period: greenLifetime,
          removeOnFinish: true,
          onTick: () {
            if (!gameOver) circle.setRed();
          },
        ));
      },
    );
    add(spawnTimer);
  }

  // ── INPUT ───────────────────────────────────────────────
@override
void onTapDown(TapDownInfo info) {
  if (gameOver) {
    _reset();
    return;
  }

  // use coordinates relative to the GameWidget, not the whole screen
  final Vector2 tapPos = Vector2(
    info.eventPosition.widget.x,
    info.eventPosition.widget.y,
  );

  if (tapPos.distanceTo(circle.position) <= circle.radius) {
    if (circle.isGreen) {
      circle.setRed();
      score++;
      scoreLabel.text = 'Score: $score';

      if (score > highScore) {
        highScore = score;
        bestLabel.text = 'Best: $highScore';
        SharedPreferences.getInstance()
            .then((p) => p.setInt(_hsKey, highScore));
      }
    } else {
      _gameOver();
    }
  }
}


  // ── GAME-OVER / RESET ──────────────────────────────────
  void _gameOver() {
    gameOver = true;
    circle.setRed();
    spawnTimer.timer.stop();

    add(TextComponent(
      text: 'Game Over\nTap to restart',
      anchor: Anchor.center,
      position: size / 2,
      textRenderer:
          TextPaint(style: const TextStyle(fontSize: 32, color: Colors.white)),
    ));
  }

  void _reset() {
    score = 0;
    scoreLabel.text = 'Score: 0';
    gameOver = false;

    // remove “Game Over” text components
    children
        .where((e) => e is TextComponent && e != scoreLabel && e != bestLabel)
        .toList()
        .forEach(remove);

    circle.setRed();
    spawnTimer.timer.start();
  }
}

// ── FLUTTER SCREEN WRAPPER ───────────────────────────────
class GameScreenSingleCircle extends StatelessWidget {
  const GameScreenSingleCircle({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Single Circle Tap'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GameWidget(game: SingleCircleGame()),
    );
  }
}
