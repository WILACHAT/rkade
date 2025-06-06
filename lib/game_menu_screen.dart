import 'package:flutter/material.dart';
import 'game_screen_spinning_wheel.dart';
import 'game_screen_circle_tap.dart';
import 'lucky_or_lose.dart'; // 👈 Import your new game screen

class GameMenuScreen extends StatelessWidget {
  const GameMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('RKade Games'), centerTitle: true),
      body: Column(
        children: [
          const SizedBox(height: 32),
          const Text('Select a Game',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(16),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              children: [
                _buildGameCard(
                  context,
                  title: 'Spinning Wheel',
                  screen: const GameScreenSpinningWheel(),
                ),
                _buildGameCard(
                  context,
                  title: 'Circle Tap',
                  screen: const GameScreenFourCircle(),
                ),
                _buildGameCard(
                  context,
                  title: 'Lucky or Lose',
                  screen: const GameScreenLuckyOrLose(), // 👈 Update with correct widget class name
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGameCard(BuildContext context,
      {required String title, required Widget screen}) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 100,
              width: 100,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Icon(Icons.gamepad, size: 48, color: Colors.blue),
              ),
            ),
            const SizedBox(height: 8),
            Text(title,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
