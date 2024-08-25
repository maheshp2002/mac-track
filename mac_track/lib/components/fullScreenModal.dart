import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../services/firebaseService.dart';
import '../theme.dart';

class FullScreenModal extends StatefulWidget {
  @override
  _FullScreenModalState createState() => _FullScreenModalState();
}

class _FullScreenModalState extends State<FullScreenModal> {
  late Stream<Map<String, dynamic>> _bankDataStream;
  late FocusNode _focusNode;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  int? _selectedChipIndex;
  bool _isAmountValid = true;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()
      ..addListener(() {
        if (!_focusNode.hasFocus) {
          // Trigger validation when the focus is lost
          _formKey.currentState?.validate();
        }
      });
    _bankDataStream = FirebaseService().streamBankData();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedChipIndex != null) {
      final amount = _amountController.text;
      final selectedBank = _selectedChipIndex;

      // Get the signed-in user's email
      GoogleSignInAccount? user = await _googleSignIn.signInSilently();
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not signed in.')),
        );
        return;
      }
      String userEmail = user.email;

      // Generate a unique document ID using date, time, and amount
      DateTime now = DateTime.now();
      String documentId = "${now.toIso8601String()}_$amount";

      // Prepare the data to be stored
      Map<String, dynamic> expenseData = {
        'amount': amount,
        'bankIndex': selectedBank,
        'timestamp': now,
      };

      // Save the data to Firebase
      await FirebaseService().addExpense(userEmail, documentId, expenseData);

      // Optionally close the modal after submitting
      Navigator.of(context).pop();
    } else {
      if (_selectedChipIndex == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select a bank.')),
        );
      }
    }
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
          child: Form(
            key: _formKey,
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
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: AppColors.secondaryGreen,
                          ));
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text("An Error Occurred",
                                  style: theme.textTheme.bodyLarge));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                              child: Text(
                            "No bank data available.",
                            style: theme.textTheme.bodyLarge,
                          ));
                        } else {
                          final bankData = snapshot.data!.values.toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Add Expense",
                                style: theme.textTheme.displayLarge,
                              ),
                              const SizedBox(height: 20),
                              TextFormField(
                                controller: _amountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                focusNode: _focusNode,
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  labelStyle: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color),
                                  suffixIcon: Icon(
                                    FontAwesomeIcons.indianRupeeSign,
                                    color: _isAmountValid
                                        ? _focusNode.hasFocus
                                            ? AppColors
                                                .secondary // Color when focused
                                            : theme.iconTheme
                                                .color // Color when not focused
                                        : Colors
                                            .red, // Color when validation fails
                                  ),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: AppColors.secondary),
                                  ),
                                ),
                                cursorColor: AppColors.secondary,
                                onChanged: (value) {
                                  // Validate on change
                                  _formKey.currentState?.validate();
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    setState(() {
                                      _isAmountValid = false;
                                    });
                                    return 'Please enter an amount';
                                  }
                                  final n = num.tryParse(value);
                                  if (n == null) {
                                    setState(() {
                                      _isAmountValid = false;
                                    });
                                    return 'Invalid amount';
                                  }
                                  setState(() {
                                    _isAmountValid = true;
                                  });
                                  return null;
                                },
                              ),
                              const SizedBox(height: 30),
                              Text("Bank",
                                  style: theme.textTheme.displayMedium),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8.0,
                                children: List<Widget>.generate(bankData.length,
                                    (int index) {
                                  final bank = bankData[index];
                                  final bankName = bank['name'] as String;
                                  final bankImageUrl = bank['image'] as String;

                                  return ChoiceChip(
                                    showCheckmark: false,
                                    avatar: Image.network(bankImageUrl),
                                    label: Text(bankName),
                                    selected: _selectedChipIndex == index,
                                    onSelected: (bool selected) {
                                      setState(() {
                                        _selectedChipIndex =
                                            selected ? index : null;
                                      });
                                    },
                                    checkmarkColor: AppColors.backgroundLight,
                                    selectedColor: AppColors.secondary,
                                    backgroundColor:
                                        customTheme!.chipBackgroundColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(50.0),
                                    ),
                                    labelStyle: TextStyle(
                                      color: _selectedChipIndex == index
                                          ? Colors.white
                                          : theme.textTheme.bodyLarge!.color,
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 20),
                              Center(
                                  child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all(
                                      AppColors.secondaryGreen),
                                  foregroundColor:
                                      WidgetStateProperty.all(Colors.white),
                                  shape: WidgetStateProperty.all(
                                      RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50.0),
                                  )),
                                ),
                                onPressed: _submit,
                                child: const Text('Submit'),
                              )),
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
        const Duration(milliseconds: 800), // Duration of the transition
    reverseTransitionDuration:
        const Duration(milliseconds: 800), // Duration of the reverse transition
  ));
}
