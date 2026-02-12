import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:mac_track/ui/theme.dart';

class FilterContainer extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const FilterContainer({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final splashColor = Color.lerp(color, Colors.white, 0.6)!;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30.0),
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: splashColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(30.0),
        child: Container(
          width: 120,
          height: 110,
          padding: const EdgeInsets.all(15), // <-- Back in business
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // <-- for balance
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundLight,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.backgroundLight,
                    size: 20,
                  ),
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundLight,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
