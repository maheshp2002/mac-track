import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'components/commonAppBar.dart';
import 'components/fullScreenModal.dart';
import 'components/navbar.dart';
import 'components/slideInAnimation.dart';
import 'components/themeManager.dart';
import 'services/firebaseService.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentIndex = 0;
  late Stream<Map<String, dynamic>> expenseDataStream;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // If the user is signed in, get their email
      expenseDataStream =
          FirebaseService().streamGetAllData(user.email!, 'expense');
      setState(() {});
    }
  }

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
            child: StreamBuilder<Map<String, dynamic>>(
                stream: expenseDataStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator(
                      color: AppColors.secondaryGreen,
                    ));
                  } else if (snapshot.hasError) {
                    return Center(
                        child: Text("An Error Occurred",
                            style: theme.textTheme.bodyLarge));
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                        child: Text(
                      "No expense data available.",
                      style: theme.textTheme.bodyLarge,
                    ));
                  } else {
                    // final expenseData = snapshot.data!.values.toList();

                    return Column(
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
                              activeFgColor:
                                  customTheme.toggleButtonSelectedColor,
                              inactiveBgColor:
                                  customTheme.toggleButtonBackgroundColor,
                              inactiveFgColor:
                                  customTheme.toggleButtonTextColor,
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
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.amber,
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.all(10),
                                        textStyle:
                                            const TextStyle(fontSize: 16),
                                        backgroundColor: const Color.fromARGB(
                                            96, 255, 251, 241),
                                      ).copyWith(
                                        shape: WidgetStateProperty.all(
                                          RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(100.0),
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
                                        color: const Color.fromARGB(
                                            96, 255, 251, 241),
                                        borderRadius:
                                            BorderRadius.circular(100),
                                      ),
                                      child: IconButton(
                                        icon: const Icon(
                                            FontAwesomeIcons.ellipsis,
                                            color: Colors.white),
                                        onPressed: () {},
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(
                                  height: 10,
                                ),
                                const Text(
                                  "Your Balance",
                                  style: AppTextStyles.bodyText,
                                ),
                                const Text(
                                  "data",
                                  style: AppTextStyles.headline,
                                )
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                          height: 10,
                        ),
                        SlideInAnimation(
                            delay: const Duration(milliseconds: 100),
                            startPosition: -0.5,
                            endPosition: 0.0,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                FilterContainer(
                                  icon: FeatherIcons.arrowDownLeft,
                                  text: "Deposit",
                                  color: AppColors.filterButtonBlack,
                                  onTap: () {
                                    // Handle the tap event here
                                    print('InkWell tapped!');
                                  },
                                ),
                                FilterContainer(
                                  icon: FeatherIcons.arrowUpRight,
                                  text: "Withdraw",
                                  color: Colors.purple,
                                  onTap: () {
                                    // Handle the tap event here
                                    print('InkWell tapped!');
                                  },
                                ),
                                FilterContainer(
                                  icon: FeatherIcons.arrowUp,
                                  text: "Transfer",
                                  color: AppColors.filterButtonGreen,
                                  onTap: () {
                                    // Handle the tap event here
                                    print('InkWell tapped!');
                                  },
                                ),
                              ],
                            )),
                      ],
                    );
                  }
                }),
          ),
        ));
  }
}

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
    return InkWell(
        onTap: onTap,
        child: Container(
          width: 105,
          height: 105,
          padding: const EdgeInsets.fromLTRB(15, 15, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            color: color,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 0.5 * 100,
                  child: Align(
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
                          size: 20, // Adjust icon size as needed
                        ),
                      ))),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundLight,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ));
  }
}
