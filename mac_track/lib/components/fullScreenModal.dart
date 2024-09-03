import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/toast.dart';
import '../config/constants.dart';
import '../services/firebaseService.dart';
import '../theme.dart';

class FullScreenModal extends StatefulWidget {
  const FullScreenModal({super.key});

  @override
  FullScreenModalState createState() => FullScreenModalState();
}

class FullScreenModalState extends State<FullScreenModal> {
  late Stream<Map<String, dynamic>> _bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  late Stream<Map<String, dynamic>> expenseTypeDataStream;
  late Stream<Map<String, dynamic>> salaryDataStream;
  late FocusNode _amountFocusNode;
  late FocusNode _expenseFocusNode;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _expenseController = TextEditingController();
  List<Map<String, dynamic>> userBanks = [];
  String? _selectedBankId; // Store the selected bank's document ID
  bool _isAmountValid = true;
  bool _isExpenseTypeValid = true;

  // Dropdown related variables
  String _selectedTransactionType = 'Withdraw';
  final List<String> _transactionTypes = ['Deposit', 'Withdraw', 'Transfer'];
  String _selectedExpenseCategory = AppConstants.expenseCategoryCustom;
  final List<String> _expenseCategory = [
    'Spotify',
    'Water Bill',
    'House Rent',
    'Electricity',
    AppConstants.expenseCategoryCustom
  ];

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode()
      ..addListener(() {
        if (!_amountFocusNode.hasFocus) {
          _formKey.currentState?.validate();
        }
      });
    _expenseFocusNode = FocusNode()
      ..addListener(() {
        if (!_expenseFocusNode.hasFocus) {
          _formKey.currentState?.validate();
        }
      });
    _bankDataStream = FirebaseService().streamBankData();
    initializeBankData();
  }

  // void getExpenseCategory() {
  //   expenseTypeDataStream.listen((expenseTypeData) async {
  //     // Fetch all banks from the master collection
  //     Map<String, dynamic> masterBanks = await bankDataStream.first;

  //     List<Map<String, dynamic>> updatedUserBanks = [];
  //     String? primaryBankId;

  //     expenseTypeData.entries.forEach((entry) {
  //       final bankId = entry.value['bankId'];
  //       final isPrimary = entry.value['isPrimary'];
  //       final bankDetails = masterBanks[bankId];

  //       if (bankDetails != null) {
  //         updatedUserBanks.add({
  //           'id': bankId,
  //           'name': bankDetails['name'],
  //           'image': bankDetails['image'],
  //           'isPrimary': isPrimary,
  //         });

  //         // Identify the primary bank ID
  //         if (isPrimary == true) {
  //           primaryBankId = bankId;
  //         }
  //       }
  //     });
  //   });
  // }

  void initializeBankData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      userBankDataStream = FirebaseService()
          .streamGetAllData(user.email!, FirebaseConstants.userBankCollection);

      userBankDataStream.listen((userBankData) async {
        // Fetch all banks from the master collection
        Map<String, dynamic> masterBanks = await _bankDataStream.first;

        List<Map<String, dynamic>> updatedUserBanks = [];

        userBankData.entries.forEach((entry) {
          final bankId = entry.value['bankId'];
          final isPrimary = entry.value['isPrimary'];
          final bankDetails = masterBanks[bankId];

          if (bankDetails != null) {
            updatedUserBanks.add({
              'id': bankId,
              'name': bankDetails['name'],
              'image': bankDetails['image'],
              'isPrimary': isPrimary,
            });
          }
        });

        setState(() {
          userBanks = updatedUserBanks;
        });
      });
    }
  }

  Future<Map<String, dynamic>> _getLatestSalaryData(
      String? selectedBankId) async {
    final salarySnapshot = await FirebaseService()
        .streamGetAllData(FirebaseAuth.instance.currentUser!.email!,
            FirebaseConstants.salaryCollection)
        .first; // Get the first snapshot

    // Filter the salary data by bankId
    final filteredSalaries = salarySnapshot.entries
        .where((entry) => entry.value['bankId'] == selectedBankId)
        .toList();

    // Sort the filtered salaries by timestamp in descending order
    filteredSalaries.sort((a, b) {
      final timestampA = a.value['timestamp'] as Timestamp;
      final timestampB = b.value['timestamp'] as Timestamp;
      return timestampB.compareTo(timestampA); // latest first
    });

    // Get the latest salary document and its currentAmount
    if (filteredSalaries.isNotEmpty) {
      final latestSalaryDoc = filteredSalaries.first;
      final currentAmount = latestSalaryDoc.value['currentAmount'] as double;
      return {
        'documentId': latestSalaryDoc.key,
        'currentAmount': currentAmount,
      };
    } else {
      return {
        'documentId': '',
        'currentAmount': 0.0,
      };
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBankId != null) {
      double amount = double.parse(_amountController.text);
      final expenseType = _expenseController.text;

      // Get the signed-in user's email
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        showToast('User not signed in.');
        return;
      }
      String userEmail = user.email ?? "";

      // Get the latest salary document ID and its current amount
      Map<String, dynamic> latestSalaryData =
          await _getLatestSalaryData(_selectedBankId);

      String latestSalaryDocumentId = latestSalaryData['documentId'];
      double currentAmount = latestSalaryData['currentAmount'];

      // Check if there is sufficient balance
      if (currentAmount < amount) {
        showToast('Insufficient balance in salary.');
        return;
      }

      // Generate a unique document ID using date, time, and amount
      DateTime now = DateTime.now();
      String documentId = "${now.toIso8601String()}_$amount";

      // Prepare the data to be stored
      Map<String, dynamic> expenseData = {
        'amount': amount,
        'bankId': _selectedBankId, // Store the selected bank's document ID
        'expense': expenseType,
        'transactionType': _selectedTransactionType,
        'expenseCategory': _selectedExpenseCategory,
        'timestamp': now,
        'salaryDocumentId':
            latestSalaryDocumentId, // Store the document ID of the latest salary
      };

      // Update the current amount in the salary document
      await FirebaseService().updateSalaryAmount(
        user.email,
        latestSalaryDocumentId,
        currentAmount - amount,
      );

      // Save the expense data to Firebase
      await FirebaseService().addData(userEmail, documentId, expenseData,
          FirebaseConstants.expenseCollection);

      // Optionally close the modal after submitting
      Navigator.of(context).pop();
    } else {
      if (_selectedBankId == null) {
        showToast('Please select a bank.');
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
                                focusNode: _amountFocusNode,
                                decoration: InputDecoration(
                                  labelText: 'Amount',
                                  labelStyle: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color),
                                  suffixIcon: Icon(
                                    FontAwesomeIcons.indianRupeeSign,
                                    color: _isAmountValid
                                        ? _amountFocusNode.hasFocus
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
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                dropdownColor: theme.scaffoldBackgroundColor,
                                icon: Icon(
                                  FontAwesomeIcons.moneyBillTransfer,
                                  color: theme.iconTheme.color,
                                ),
                                value: _selectedExpenseCategory,
                                items: _expenseCategory.map((String type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedExpenseCategory = newValue!;

                                    if (_selectedExpenseCategory !=
                                        AppConstants.expenseCategoryCustom) {
                                      _expenseController.text =
                                          _selectedExpenseCategory;
                                    }
                                  });
                                },
                                decoration: const InputDecoration(
                                    labelText: 'Expense Category',
                                    labelStyle: TextStyle(color: Colors.white),
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    )),
                              ),
                              const SizedBox(height: 30),
                              TextFormField(
                                enabled: _selectedExpenseCategory ==
                                    AppConstants.expenseCategoryCustom,
                                controller: _expenseController,
                                focusNode: _expenseFocusNode,
                                decoration: InputDecoration(
                                  labelText: 'Expense Type',
                                  labelStyle: TextStyle(
                                      color: theme.textTheme.bodyLarge?.color),
                                  suffixIcon: Icon(
                                    FontAwesomeIcons.indianRupeeSign,
                                    color: _isExpenseTypeValid
                                        ? _expenseFocusNode.hasFocus
                                            ? AppColors.secondary
                                            : theme.iconTheme.color
                                        : Colors.red,
                                  ),
                                  border: const OutlineInputBorder(),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: AppColors.secondary),
                                  ),
                                ),
                                cursorColor: AppColors.secondary,
                                onChanged: (value) {
                                  _formKey.currentState?.validate();
                                },
                                validator: (value) {
                                  if (_selectedExpenseCategory ==
                                          AppConstants.expenseCategoryCustom &&
                                      (value == null || value.isEmpty)) {
                                    setState(() {
                                      _isExpenseTypeValid = false;
                                    });
                                    return 'Please enter an expense type';
                                  }
                                  setState(() {
                                    _isExpenseTypeValid = true;
                                  });
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              DropdownButtonFormField<String>(
                                dropdownColor: theme.scaffoldBackgroundColor,
                                icon: Icon(
                                  FontAwesomeIcons.moneyBillTransfer,
                                  color: theme.iconTheme.color,
                                ),
                                value: _selectedTransactionType,
                                items: _transactionTypes.map((String type) {
                                  return DropdownMenuItem<String>(
                                    value: type,
                                    child: Text(
                                      type,
                                      style: theme.textTheme.bodyLarge,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedTransactionType = newValue!;
                                  });
                                },
                                decoration: const InputDecoration(
                                    labelText: 'Transaction Type',
                                    labelStyle: TextStyle(color: Colors.white),
                                    border: OutlineInputBorder(),
                                    focusedBorder: OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    )),
                              ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: userBanks
                                    .map<Widget>((entry) => ChoiceChip(
                                          showCheckmark: false,
                                          avatar: Image.network(entry['image']),
                                          label: Text(entry['name']),
                                          labelStyle: TextStyle(
                                            color:
                                                _selectedBankId == entry['id']
                                                    ? Colors.white
                                                    : theme.textTheme.bodyLarge!
                                                        .color,
                                          ),
                                          selectedColor: AppColors.secondary,
                                          backgroundColor:
                                              customTheme!.chipBackgroundColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(50.0),
                                          ),
                                          selected: _selectedBankId ==
                                              entry[
                                                  'id'], // Compare document ID
                                          onSelected: (selected) {
                                            setState(() {
                                              _selectedBankId = selected
                                                  ? entry['id']
                                                  // Store document ID
                                                  : null;
                                            });
                                          },
                                        ))
                                    .toList(),
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ),
                ),
                // Save Button
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.all(AppColors.secondaryGreen),
                      ),
                      child: Text('Save', style: theme.textTheme.bodyLarge),
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
