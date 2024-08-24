import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../services/firebaseService.dart';
import '../theme.dart';

class FullScreenModal extends StatefulWidget {
  @override
  _FullScreenModalState createState() => _FullScreenModalState();
}

class _FullScreenModalState extends State<FullScreenModal> {
  late Stream<Map<String, dynamic>> _bankDataStream;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _bankDataStream = FirebaseService().streamBankData();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: customTheme?.modalBackgroundColor ?? Colors.white,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close Button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: Icon(
                      FontAwesomeIcons.xmark,
                      color: theme.iconTheme.color ?? Colors.black,
                    ),
                    onPressed: () {
                      Navigator.of(context).pop(); // Close the popup
                    },
                  ),
                ),
              ),
              // Content of the Popup
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(
                    left: 16.0,
                    right: 16.0,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                  ),
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: _bankDataStream,
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
                          "No bank data available.",
                          style: theme.textTheme.bodyLarge,
                        ));
                      } else {
                        final bankData = snapshot.data!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Add Expense",
                              style: theme.textTheme.displayLarge,
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              focusNode: _focusNode,
                              decoration: InputDecoration(
                                labelText: 'Amount',
                                labelStyle: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color),
                                suffixIcon: Icon(
                                  FontAwesomeIcons.indianRupeeSign,
                                  color: _focusNode.hasFocus
                                      ? AppColors
                                          .secondary // Color when focused
                                      : theme.iconTheme
                                          .color, // Color when not focused
                                ),
                                border: const OutlineInputBorder(),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide:
                                      BorderSide(color: AppColors.secondary),
                                ),
                              ),
                              cursorColor: AppColors.secondary,
                            ),

                            const SizedBox(height: 20),

                            const SizedBox(height: 20),
                            // Add more text fields as needed
                          ],
                        );
                      }
                    },
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

void openFullScreenModal(BuildContext context) {
  Navigator.of(context).push(PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) {
      const begin = Offset(0, 1); // Start from bottom
      const end = Offset.zero; // End at the top
      const curve = Curves.easeIn;

      var tween = Tween<Offset>(begin: begin, end: end);
      var curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      var offsetAnimation = tween.animate(curvedAnimation);

      return SlideTransition(
        position: offsetAnimation,
        child: FullScreenModal(),
      );
    },
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0, 1); // Start from bottom
      const end = Offset.zero; // End at the top
      const curve = Curves.easeOut;

      var tween = Tween<Offset>(begin: begin, end: end);
      var curvedAnimation = CurvedAnimation(
        parent: animation,
        curve: curve,
      );

      var offsetAnimation = tween.animate(curvedAnimation);

      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
    transitionDuration:
        const Duration(milliseconds: 500), // Duration of the transition
    reverseTransitionDuration:
        const Duration(milliseconds: 500), // Duration of the reverse transition
  ));
}
