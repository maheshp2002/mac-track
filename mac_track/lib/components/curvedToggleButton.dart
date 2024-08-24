import 'package:flutter/material.dart';
import 'package:toggle_switch/toggle_switch.dart';
import '../theme.dart';

class CurvedToggleButton extends StatefulWidget {
  @override
  _CurvedToggleButtonState createState() => _CurvedToggleButtonState();
}

class _CurvedToggleButtonState extends State<CurvedToggleButton> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();

    return ToggleSwitch(
      minWidth: 90.0,
      cornerRadius: 20.0,
      activeBgColors: [
        [customTheme!.toggleButtonFillColor],
        [customTheme.toggleButtonFillColor],
        [customTheme.toggleButtonFillColor],
      ],
      activeFgColor: customTheme.toggleButtonSelectedColor,
      inactiveBgColor: customTheme.toggleButtonBackgroundColor,
      inactiveFgColor: customTheme.toggleButtonTextColor,
      initialLabelIndex: _currentIndex,
      totalSwitches: 3,
      labels: const ['Daily', 'Weekly', 'Monthly'],
      radiusStyle: true,
      onToggle: (index) {
        setState(() {
          _currentIndex = index!;
        });
      },
    );
  }
}
