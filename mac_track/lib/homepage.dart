import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'components/commonAppBar.dart';
import 'components/fullScreenModal.dart';
import 'components/navbar.dart';
import 'components/slideInAnimation.dart';
import 'components/themeManager.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    Color iconColor = customTheme!.toggleButtonTextColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CommonAppBar(
        title: 'MacTrack',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          openFullScreenModal(context);
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: AppColors.secondaryGreen,
        child: const Icon(
          FontAwesomeIcons.plus,
          color: AppColors.backgroundLight,
        ),
      ),
      drawer: NavBar(),
      body: Container(
        decoration: AppTheme.getBackgroundDecoration(themeMode),
        padding: const EdgeInsets.only(top: kToolbarHeight + 50),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              SlideInAnimation(
                delay: const Duration(milliseconds: 150),
                startPosition: -1.0,
                endPosition: 0.0,
                child: Center(
                  child: ToggleSwitch(
                    minWidth: 100.0,
                    cornerRadius: 20.0,
                    activeBgColors: [
                      [customTheme.toggleButtonFillColor],
                      [customTheme.toggleButtonFillColor],
                    ],
                    activeFgColor: customTheme.toggleButtonSelectedColor,
                    inactiveBgColor: customTheme.toggleButtonBackgroundColor,
                    inactiveFgColor: customTheme.toggleButtonTextColor,
                    initialLabelIndex: _currentIndex,
                    totalSwitches: 2,
                    labels: _currentIndex == 0
                        ? ['Balance', '']
                        : ['', 'Transaction'],
                    customIcons: [
                      _currentIndex == 0
                          ? null
                          : Icon(
                              FontAwesomeIcons.indianRupeeSign,
                              color: iconColor,
                              size: 20,
                            ),
                      _currentIndex == 1
                          ? null
                          : Icon(
                              FontAwesomeIcons.rightLeft,
                              color: iconColor,
                              size: 20,
                            ),
                    ],
                    radiusStyle: true,
                    onToggle: (index) {
                      setState(() {
                        _currentIndex = index!;
                      });
                    },
                  ),
                ),
              ),
              SlideInAnimation(
                delay: const Duration(milliseconds: 100),
                startPosition: -0.5,
                endPosition: 0.0,
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  width: double.infinity,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(16.0),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.all(10),
                              textStyle: const TextStyle(fontSize: 16),
                              backgroundColor:
                                  const Color.fromARGB(96, 255, 251, 241),
                            ).copyWith(
                              shape: WidgetStateProperty.all(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(100.0),
                                ),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  "ICCI",
                                  style: AppTextStyles.labelTextWhite,
                                ),
                                const SizedBox(width: 8),
                                Image.asset(
                                  "assets/logo/black.png",
                                  width: 24,
                                  height: 24,
                                ),
                              ],
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: const Color.fromARGB(96, 255, 251, 241),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: IconButton(
                              icon: const Icon(FontAwesomeIcons.ellipsis,
                                  color: Colors.white),
                              onPressed: () {},
                            ),
                          )
                        ],
                      ),
                      const Column(
                        children: [
                          Text(
                            "data",
                            style: AppTextStyles.bodyText,
                          ),
                          Text(
                            "data",
                            style: AppTextStyles.headline,
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
