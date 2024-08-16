import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../sign.dart';

class NavBar extends StatelessWidget {
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
              color: theme.primaryColor, // Use theme's primary color
            ),
            child: Text(
              'Menu',
              style: theme.textTheme.displayLarge,
            ),
          ),
          ListTile(
            leading: Icon(Icons.exit_to_app, color: theme.iconTheme.color),
            title: Text('Sign Out', style: theme.textTheme.bodyLarge),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }
}
