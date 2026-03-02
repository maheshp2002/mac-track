import 'package:flutter/material.dart';

class NavClipper extends CustomClipper<Path> {
  final double borderRadius;
  final double fabRadius;
  final double notchMargin; // controls visible gap

  NavClipper({
    required this.borderRadius,
    required this.fabRadius,
    required this.notchMargin,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    final double w = size.width;
    final double h = size.height;
    final double r = borderRadius;
    final double cx = w / 2;

    final double notchRadius = fabRadius + notchMargin;

    // Start from top-left rounded corner
    path.moveTo(r, 0);

    // Line to left notch start
    path.lineTo(cx - notchRadius, 0);

    // Draw smooth concave arc
    path.arcToPoint(
      Offset(cx + notchRadius, 0),
      radius: Radius.circular(notchRadius),
      clockwise: false,
    );

    // Continue to top-right corner
    path.lineTo(w - r, 0);

    // Top-right rounded corner
    path.arcToPoint(
      Offset(w, r),
      radius: Radius.circular(r),
    );

    // Right side
    path.lineTo(w, h - r);

    // Bottom-right rounded corner
    path.arcToPoint(
      Offset(w - r, h),
      radius: Radius.circular(r),
    );

    // Bottom
    path.lineTo(r, h);

    // Bottom-left rounded corner
    path.arcToPoint(
      Offset(0, h - r),
      radius: Radius.circular(r),
    );

    // Left side
    path.lineTo(0, r);

    // Top-left rounded corner
    path.arcToPoint(
      Offset(r, 0),
      radius: Radius.circular(r),
    );

    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}