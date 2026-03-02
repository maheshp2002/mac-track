import 'package:flutter/material.dart';
import 'package:mac_track/ui/components/floating_bottom_nav.dart';
import 'package:mac_track/ui/components/full_screen_modal.dart';
import 'package:mac_track/ui/homepage.dart';
import 'package:mac_track/ui/insight.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _index = 0;

  final List<Widget> _pages = const [
    HomePage(),
    Insight(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _pages[_index],
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _index,
        onAdd: () async {
          await openFullScreenModal(context, null, null);
        },
        onTap: (i) {
          setState(() {
            _index = i;
          });
        },
      ),
    );
  }
}