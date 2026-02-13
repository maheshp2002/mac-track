import 'package:flutter/material.dart';

class RotationYTransition extends AnimatedWidget {
  final Widget child;
  const RotationYTransition({super.key, 
    required Animation<double> turns,
    required this.child,
  }) : super(listenable: turns);

  @override
  Widget build(BuildContext context) {
    final animation = listenable as Animation<double>;
    final angle = animation.value * 3.1416;
    return Transform(
      transform: Matrix4.rotationY(angle),
      alignment: Alignment.center,
      child: child,
    );
  }
}
