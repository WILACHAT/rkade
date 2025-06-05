import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame/input.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';



class SpinningWheelGame extends FlameGame with TapDetector {
  // ───── Constants ──────────────────────────────────────────────────────────
  static const int    slots        = 24;
  static const double ringRadius   = 180;
  static const double targetRadius = 20;
  static const double needleWidth  = 12;
  static const double needleLength = 180;

  // ───── Components ─────────────────────────────────────────────────────────
  late CircleComponent    ring;
  late CircleComponent    target;
  late RectangleComponent needle;
  late TextPaint          scoreText;

  // ───── State ──────────────────────────────────────────────────────────────
  late Vector2 center;
  int    targetIndex = 0;
  double needleIndex = 0;
  double prevNeedleIndex = 0;         // track previous frame’s slot
  double speed       = 5.0;
  static const double baseSpeed  = 5.0;   // starting magnitude
  static const double speedStep  = 0.7; 
  int highScore = 0;                       // saved best score
  static const _hsKey = 'high_spinwheel';  // linear step size

  int    score       = 0;
  bool   gameOver    = false;
  bool overlapping = false;
  bool missJustOccurred = false;  

  @override
 Color backgroundColor() => const Color(0xFF1F1B24);

  // ───── Lifecycle ──────────────────────────────────────────────────────────
  @override
  Future<void> onLoad() async {
      await super.onLoad();                    // keep Flame happy

     final prefs = await SharedPreferences.getInstance();
  highScore   = prefs.getInt(_hsKey) ?? 0;
    scoreText = TextPaint(
      style: const TextStyle(
        fontSize: 32,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
      const double shiftUp = 50;                       // ← tune this
      center = Vector2(size.x / 2, size.y / 2 - shiftUp);
    _createRing();
    _createNeedle();
    _createTarget();   // also chooses first target
  }
  Future<void> _saveHighScore(int value) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setInt(_hsKey, value);
}
/// World-space position of the very tip of the needle
Vector2 _needleTip() {
  final double ang = 2 * pi * needleIndex / slots;
  return center + Vector2(cos(ang), sin(ang)) * needleLength;
}



  // ───── Component builders ────────────────────────────────────────────────
  void _createRing() {
    ring = CircleComponent(
      position: center,
      radius: ringRadius,
      paint: Paint()
        ..color = Colors.grey.shade800
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4,
      anchor: Anchor.center,
    );
    add(ring);
  }

  void _createNeedle() {
    needle = RectangleComponent(
      size: Vector2(needleWidth, needleLength),
      paint: Paint()..color = const Color(0xFFFF77FF),
      anchor: Anchor.topCenter,
    );
    add(needle);
  }

  void _createTarget() {
    target = CircleComponent(
      radius: targetRadius,

      paint: Paint()..color = const Color(0xFF00FFD1),
      anchor: Anchor.center,
    );
    add(target);
    _chooseNewTarget();   // initial placement only
  }

  // ───── Target selection (only after hit or reset) ────────────────────────
void _chooseNewTarget() {
  const int minOffset = 2;
  const int maxOffset = 8;
  final rng = Random();

  // Generate a valid offset: [2–8] or [-8 to -2]
  late int offset;
  if (rng.nextBool()) {
    offset = rng.nextInt(maxOffset - minOffset + 1) + minOffset;   // [2–8]
  } else {
    offset = -rng.nextInt(maxOffset - minOffset + 1) - minOffset;  // [-2 to -8]
  }

  // Compute new index
  targetIndex = (targetIndex + offset + slots) % slots;

  // Position green dot
  final angle = 2 * pi * targetIndex / slots;
  target.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;

  // Flip direction if needed
  final bool spinMatches =
      (speed < 0 && offset < 0) || (speed > 0 && offset > 0);
  if (!spinMatches) speed = -speed;
}

  // ───── Game loop ─────────────────────────────────────────────────────────
@override
void update(double dt) {
  super.update(dt);
  if (gameOver) return;

  // move needle
  needleIndex = (needleIndex + speed * dt) % slots;
  if (needleIndex < 0) needleIndex += slots;

  final angle = 2 * pi * needleIndex / slots;
  needle.position = center + Vector2(cos(angle), sin(angle)) * ringRadius;
  needle.angle    = angle + pi / 2;

  // overlap check
final dist    = _needleTip().distanceTo(target.position);
final bool nowOver = dist <= targetRadius;   // hit when tip touches dot


  // left the dot → tentative miss
  if (overlapping && !nowOver) {
    if (score > 0) score -= 1;
    HapticFeedback.heavyImpact(); // 🔔 subtle buzz on miss

    missJustOccurred = true;          // mark: we just deducted
  }

  // re-entering the dot => cancel the “pending refund” state
  if (nowOver) {
    missJustOccurred = false;
  }

  overlapping = nowOver;
}


// Helper: distance (in slots) from current needleIndex *clockwise* to target
double _aheadToTarget(double idx) =>
    (targetIndex - idx + slots) % slots;


  // Detect if needle crossed target between frames
  bool _crossedTarget(
      double from, double to, double spd, int tgt) {
    if (spd > 0) {
      if (to < from) to += slots;
      final double t = tgt >= from ? tgt.toDouble() : tgt + slots.toDouble();
      return t > from && t <= to;
    } else {
      if (to > from) to -= slots;
      final double t = tgt <= from ? tgt.toDouble() : tgt - slots.toDouble();
      return t < from && t >= to;
    }
  }

  // ───── Input ─────────────────────────────────────────────────────────────
 // ───── REPLACE only the body of onTap() (method signature is same) ─────────
@override
void onTap() {
  if (gameOver) {
    
    _resetGame();
    return;
  }

  // --------------- tap when NOT overlapping -------------------------------
  if (!overlapping) {
    if (missJustOccurred) {
      // player tapped too late; restore the point before ending game
      score += 1;
      missJustOccurred = false;
    }
    _triggerGameOver();
    return;
  }

  // --------------- successful hit -----------------------------------------
  score += 1;
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 40), () {
      HapticFeedback.mediumImpact();
    }); 

    final double newMag = _speedMagnitudeForScore(score);
    final double sign   = speed.isNegative ? -1 : 1;
    speed = sign * newMag;

  Color backgroundColor() => Colors.green;

  Future.delayed(const Duration(milliseconds: 120), () {
     Color backgroundColor() => const Color(0xFF1F1B24);
  });

  _chooseNewTarget();
  overlapping        = false;
  missJustOccurred   = false;
}



  // ───── Rendering ─────────────────────────────────────────────────────────
  @override
  void render(Canvas canvas) {
    super.render(canvas);
    scoreText.render(
        canvas, 'Score: $score', Vector2(size.x / 2, 50), anchor: Anchor.center);
        scoreText.render(canvas, 'Best: $highScore',
    Vector2(size.x / 2, 90), anchor: Anchor.center);


    if (gameOver) {
      scoreText.render(
          canvas, 'Game Over\nTap to restart', size / 2, anchor: Anchor.center);
    }
  }

  // ───── Helpers ───────────────────────────────────────────────────────────
  void _triggerGameOver() {
        if (score > highScore) {
  highScore = score;            // new record!
  _saveHighScore(highScore);    // persist it
} 
    HapticFeedback.vibrate();
  
    gameOver = true;
    
    needle.paint.color = Colors.white.withOpacity(0.4);

 
  }

  void _resetGame() {
    score = 0;
    needleIndex = 0;
    prevNeedleIndex = 0;
    speed = 4.0;
    gameOver = false;

    needle.paint.color = const Color(0xFFFF77FF);
    needle.position = center + Vector2(ringRadius, 0);
    needle.angle = pi / 2;

    _chooseNewTarget();  // fresh target on restart
  }
  
  double _speedMagnitudeForScore(int s) {
  // 0-4  →  flat
  if (s < 5) return baseSpeed;

  // 5-30 →  linear steps every 5 pts
  if (s <= 30) {
    int increments = ((s - 5) ~/ 5) + 1;   // 5,10,15,20,25,30 → 1…6
    return baseSpeed + increments * speedStep;
  }

  // >30  →  logarithmic growth on top of value at 30
  const int incrementsAt30 = ((30 - 5) ~/ 5) + 1; // 6
  final double magAt30 = baseSpeed + incrementsAt30 * speedStep;
  // log term (ln) grows slowly; shift so ln(1)=0 at score 31
  final double extra   = speedStep * log((s - 30) + 1);
  return magAt30 + extra;
}

}
