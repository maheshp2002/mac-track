import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mac_track/ui/homepage.dart';
import 'package:mac_track/ui/insight.dart';
import 'package:mac_track/ui/theme.dart';
import '../sign.dart';

class NavBar extends StatelessWidget {
  const NavBar({super.key});

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Drawer(
      backgroundColor: theme.drawerTheme.backgroundColor,
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[
          DrawerHeader(
              decoration: BoxDecoration(
                image: const DecorationImage(
                  image: AssetImage(
                      'assets/gifs/money-2.gif'),
                  fit: BoxFit.cover,
                ),
                color: theme.primaryColor,
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: Text(
                  'MacTrack',
                  style: TextStyle(fontSize: theme.textTheme.displayLarge?.fontSize, fontWeight: theme.textTheme.displayLarge?.fontWeight, color: AppColors.black87),
                ),
              )),
          ListTile(
            leading: Icon(FontAwesomeIcons.house, color: theme.iconTheme.color),
            title: Text('Home', style: theme.textTheme.bodyLarge),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const HomePage()),
            ),
          ),
          ListTile(
            leading:
                Icon(FontAwesomeIcons.chartLine, color: theme.iconTheme.color),
            title: Text('Insight', style: theme.textTheme.bodyLarge),
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const Insight()),
            ),
          ),
          ListTile(
            leading: Icon(FontAwesomeIcons.rightFromBracket,
                color: theme.iconTheme.color),
            title: Text('Sign Out', style: theme.textTheme.bodyLarge),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
