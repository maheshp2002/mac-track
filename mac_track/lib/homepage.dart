import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'components/commonAppBar.dart';
import 'components/graph.dart';
import 'components/navbar.dart';
import 'components/themeManager.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CommonAppBar(
        title: 'MacTrack',
      ),
      drawer: NavBar(),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(themeMode),
        child: const Center(
          child: LineChartSample2(),
        ),
      ),
    );
  }
}
