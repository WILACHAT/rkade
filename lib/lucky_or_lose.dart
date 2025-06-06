import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GameScreenLuckyOrLose extends StatefulWidget {
  const GameScreenLuckyOrLose({super.key});

  @override
  State<GameScreenLuckyOrLose> createState() => _GameScreenLuckyOrLoseState();
}

class _GameScreenLuckyOrLoseState extends State<GameScreenLuckyOrLose> {
  final _rng = Random();

  // ── Round state ──────────────────────────────────────────
  late int totalCircles;           // 6-12 circles each round
  late int losingIndex;            // index of the single bomb
  final Set<int> _selectedSafe = {};
  int roundsCleared = 0;

  // High-score
  static const _hsKey = 'lucky_or_lose_high';
  int highScore = 0;

  // How many safe taps to beat a round
  static const int safeNeeded = 3;

  @override
  void initState() {
    super.initState();
    _loadHighScore();
    _startNewRound();
  }

  Future<void> _loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => highScore = prefs.getInt(_hsKey) ?? 0);
  }

  Future<void> _saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hsKey, highScore);
  }

  void _startNewRound() {
    setState(() {
      totalCircles = _rng.nextInt(7) + 6; // 6–12
      losingIndex  = _rng.nextInt(totalCircles);
      _selectedSafe.clear();
    });
  }

  void _handleTap(int index) {
    if (index == losingIndex) {
      _showGameOver();
      return;
    }
    if (_selectedSafe.contains(index)) return; // already tapped

    setState(() => _selectedSafe.add(index));
    HapticFeedback.lightImpact();

    if (_selectedSafe.length >= safeNeeded) {
      roundsCleared++;
      if (roundsCleared > highScore) {
        setState(() => highScore = roundsCleared);
        _saveHighScore();
      }
      _showRoundCleared();
    }
  }

  void _showRoundCleared() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Round Cleared!'),
        content: Text('Score: $roundsCleared'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startNewRound();
            },
            child: const Text('Next Round'),
          )
        ],
      ),
    );
  }

  void _showGameOver() {
    HapticFeedback.vibrate();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('💥 You hit the losing circle!'),
        content: Text('Rounds cleared: $roundsCleared'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => roundsCleared = 0);
              _startNewRound();
            },
            child: const Text('Try Again'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final int crossAxisCount = (totalCircles <= 8) ? 3 : 4;

    return Scaffold(
      appBar: AppBar(title: const Text('Lucky or Lose')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          Text('Score: $roundsCleared',
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold)),
          Text('High score: $highScore',
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 12),

          // ── Info panel ─────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              children: [
                Text(
                  'There is 1 losing circle out of $totalCircles.',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  'Select $safeNeeded circles to survive.',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // ──────────────────────────────────────────────────

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
              ),
              itemCount: totalCircles,
              itemBuilder: (_, index) {
                final bool isSelected = _selectedSafe.contains(index);
                return GestureDetector(
                  onTap: () => _handleTap(index),
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.green
                          : Colors.grey.shade400,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
