import 'package:flutter/material.dart';
import 'package:flame/game.dart';

import 'spinning_wheel_game.dart';

class GameScreen extends StatelessWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spinning Wheel Game'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: GameWidget(
        game: SpinningWheelGame(),
      ),
    );
  }
}
