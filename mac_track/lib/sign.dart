import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:mac_track/theme.dart';
import 'package:rive/rive.dart' hide Image;

import 'homepage.dart';

class SignInPage extends StatelessWidget {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final bool isShowSignInDialog = false;

  SignInPage({super.key});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth =
          await googleUser!.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);

      if (context.mounted) {
        // Check if the widget is still in the widget tree
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      // Handle errors here
      print('Error signing in with Google: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          Positioned(
            width: MediaQuery.of(context).size.width * 1.8,
            right: 100,
            top: 0,
            child: Image.asset(
              "assets/Backgrounds/Spline.png",
            ),
          ),
          Positioned(
            width: MediaQuery.of(context).size.width * 1.8,
            left: 100,
            bottom: 0,
            child: Image.asset(
              "assets/Backgrounds/Spline.png",
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 20),
              child: const SizedBox(),
            ),
          ),
          const RiveAnimation.asset(
            "assets/RiveAssets/shapes.riv",
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
              child: const SizedBox(),
            ),
          ),
          AnimatedPositioned(
            top: isShowSignInDialog ? -20 : 0,
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            duration: const Duration(milliseconds: 260),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    SizedBox(
                      width: 260,
                      child: Column(
                        children: [
                          Text(
                            "Track Your Expense",
                            style: TextStyle(
                                fontSize: 60,
                                fontWeight: FontWeight.w700,
                                fontFamily: "Poppins",
                                height: 1.2,
                                color: theme.textTheme.displayLarge?.color),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            "The smart way to manage expenses, budget better, and reach your financial goals.",
                            style: TextStyle(
                                fontFamily: "Poppins",
                                color: theme.textTheme.bodyLarge?.color),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(flex: 2),
                    Center(
                        child: ElevatedButton.icon(
                      onPressed: () => _signInWithGoogle(context),
                      icon: CircleAvatar(
                          radius: 13,
                          child: Image.asset(
                            "assets/logo/google-icon.png",
                          )),
                      label: Text(
                        "Sign in with Google",
                        style: TextStyle(
                            fontFamily: "Poppins",
                            color: theme.textTheme.bodyLarge?.color),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                        backgroundColor: AppColors.transparent,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(100)),
                      ),
                    )),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Text(
                        "Track your daily spending, analyze habits, and make informed decisions effortlessly. Simple, fast, and beautifully designed.",
                        style: TextStyle(
                            fontFamily: "Poppins",
                            color: theme.textTheme.bodyLarge?.color),
                      ),
                    )
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
