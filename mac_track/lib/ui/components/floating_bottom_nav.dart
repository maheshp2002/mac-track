import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/ui/widgets/nav_clipper.dart';
import '../theme.dart';

class FloatingBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback onAdd;

  const FloatingBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Tunable geometry:
    const double navHeight = 60;
    const double navHorizontalMargin = 28;
    const double fabSize = 60; // diameter of add button
    const double fabBottomOffset = 28; // move FAB upwards for visible gap
    const double borderRadius = 22; // rounded corners of navbar
    const double notchHalfWidth = 30; // half width of the V-notch
    const double notchGap = 6; // visible gap

    const double centerSpace = notchHalfWidth * 2 + 10;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Stack(
        alignment: Alignment.bottomCenter,
        clipBehavior: Clip.none,
        children: [
          // Soft shadow layer behind the nav (not clipped)
          Positioned(
            bottom: navHeight - (fabSize / 2) - 8, // align shadow with FAB position
            child: Container(
              height: navHeight + 10,
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  )
                ],
              ),
            ),
          ),

          Positioned(
            left: navHorizontalMargin,
            right: navHorizontalMargin,
            bottom: 2,
            child: ClipPath(
              clipper: NavClipper(
                borderRadius: borderRadius,
                fabRadius: fabSize / 2,
                notchMargin: notchGap,
              ),
              child: Container(
                height: navHeight,
                color: theme.scaffoldBackgroundColor,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Left icon
                    _buildItem(context, FontAwesomeIcons.house, 0),
                    // space reserved for FAB / notch
                    const SizedBox(width: centerSpace),
                    // Right icon
                    _buildItem(context, FontAwesomeIcons.chartLine, 1),
                  ],
                ),
              ),
            ),
          ),

          // Floating add button, raised above the notch for visible gap
          Positioned(
            bottom: navHeight - fabBottomOffset, // raised above the nav
            child: GestureDetector(
              onTap: onAdd,
              child: Container(
                height: fabSize,
                width: fabSize,
                decoration: BoxDecoration(
                  color: AppColors.secondaryGreen,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryGreen.withValues(alpha: 0.42),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.add,
                  color: AppColors.white,
                  size: 32,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, IconData icon, int index) {
    final isSelected = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Icon(
        icon,
        size: 22,
        color: isSelected ? AppColors.secondaryGreen : Theme.of(context).iconTheme.color,
      ),
    );
  }
}