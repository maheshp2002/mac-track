import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/commonAppBar.dart';
import 'components/graph.dart';
import 'components/themeManager.dart';
import 'theme.dart';

class Insight extends StatefulWidget {
  @override
  _InsightState createState() => _InsightState();
}

class _InsightState extends State<Insight> {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CommonAppBar(
        title: 'MacTrack',
      ),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(themeMode),
        child: const Center(
          child: LineChartSample2(),
        ),
      ),
    );
  }
}
