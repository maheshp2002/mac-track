import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/toast.dart';
import '../config/constants.dart';
import '../services/firebaseService.dart';
import '../theme.dart';

class FullScreenModal extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final String? expenseId;
  FullScreenModal({super.key, required this.expense, required this.expenseId});

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
  bool _isFormChanged = false;

  // Dropdown related variables
  String _selectedTransactionType = AppConstants.transactionTypeWithdraw;
  final List<String> _transactionTypes = [
    AppConstants.transactionTypeDeposit,
    AppConstants.transactionTypeWithdraw,
    AppConstants.transactionTypeTransfer
  ];

  Map<String, String> _expenseCategoryMap = {}; // name -> document ID
  List<String> _expenseCategoryNames = [];
  String? _selectedExpenseCategory;
  String? _selectedExpenseCategoryId;

  @override
  void initState() {
    super.initState();
    _amountFocusNode = FocusNode()
      ..addListener(() {
        if (!_amountFocusNode.hasFocus) _formKey.currentState?.validate();
      });
    _expenseFocusNode = FocusNode()
      ..addListener(() {
        if (!_expenseFocusNode.hasFocus) _formKey.currentState?.validate();
      });

    _bankDataStream = FirebaseService().streamBankData();
    initializeBankData();

    expenseTypeDataStream = FirebaseService().streamExpenseTypes();

    expenseTypeDataStream.first.then((typesData) {
      final categoryMap = <String, String>{};
      final categoryNames = <String>[];

      typesData.forEach((docId, data) {
        final name = data['name'] as String?;
        if (name != null && name.isNotEmpty) {
          categoryMap[name] = docId;
          categoryNames.add(name);
        }
      });

      setState(() {
        _expenseCategoryMap = categoryMap;
        _expenseCategoryNames = categoryNames;
        if (categoryNames.isNotEmpty) {
          _selectedExpenseCategory = categoryNames.first;
          _selectedExpenseCategoryId = categoryMap[categoryNames.first];
          _expenseController.text = categoryNames.first;
        }
      });

      // Move setModalData() here
      if (widget.expense != null && widget.expenseId != null) {
        setModalData();
      }
    });
  }

  void setModalData() {
    setState(() {
      _amountController.text =
          widget.expense?[FirebaseConstants.amountField].toString() ?? '';
      _expenseController.text =
          widget.expense?[FirebaseConstants.expenseField] ?? '';
      _selectedBankId = widget.expense?[FirebaseConstants.bankIdField];
      _selectedTransactionType =
          widget.expense?[FirebaseConstants.transactionTypeField];
      _selectedExpenseCategoryId =
          widget.expense?[FirebaseConstants.expenseCategoryField];

      final selectedCategoryId =
          widget.expense?[FirebaseConstants.expenseCategoryField];
      _selectedExpenseCategory = _expenseCategoryMap.entries
          .firstWhere((entry) => entry.value == selectedCategoryId,
              orElse: () => const MapEntry('', ''))
          .key;
    });
  }

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
          final prevId = entry.value[FirebaseConstants.bankIdField];
          final bankId = prevId == AppConstants.otherCategory
              ? entry.value[FirebaseConstants.bankNameField]
              : entry.value[FirebaseConstants.bankIdField];
          final isPrimary = entry.value['isPrimary'];
          final bankDetails = prevId == AppConstants.otherCategory
              ? masterBanks[prevId]
              : masterBanks[bankId];

          if (bankDetails != null) {
            updatedUserBanks.add({
              'id': bankId,
              'name': prevId == AppConstants.otherCategory
                  ? entry.value[FirebaseConstants.bankNameField]
                  : bankDetails['name'],
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
        .where((entry) =>
            entry.value[FirebaseConstants.bankIdField] == selectedBankId)
        .toList();

    // Sort the filtered salaries by timestamp in descending order
    filteredSalaries.sort((a, b) {
      final timestampA = a.value[FirebaseConstants.timestampField] as Timestamp;
      final timestampB = b.value[FirebaseConstants.timestampField] as Timestamp;
      return timestampB.compareTo(timestampA); // latest first
    });

    // Get the latest salary document and its currentAmount
    if (filteredSalaries.isNotEmpty) {
      final latestSalaryDoc = filteredSalaries.first;
      final currentAmount =
          latestSalaryDoc.value[FirebaseConstants.currentAmountField] as double;
      return {
        FirebaseConstants.documentIdField: latestSalaryDoc.key,
        FirebaseConstants.currentAmountField: currentAmount,
      };
    } else {
      return {
        FirebaseConstants.documentIdField: '',
        FirebaseConstants.currentAmountField: 0.0,
      };
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBankId != null) {
      double amount = double.parse(_amountController.text);
      final expenseType = _expenseController.text.isNotEmpty
          ? _expenseController.text
          : _selectedExpenseCategory;

      // Get the signed-in user's email
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        showToast('User not signed in.');
        return;
      }
      String userEmail = user.email ?? "";

      final isEditMode = widget.expenseId != null && widget.expense != null;

      String salaryDocumentId;
      double currentAmount;

      if (isEditMode) {
        // Get salary document used in the previous expense
        salaryDocumentId =
            widget.expense![FirebaseConstants.salaryDocumentIdField];

        final salaryDoc = await FirebaseService()
            .streamGetDataInUserById(
              userEmail,
              FirebaseConstants.salaryCollection,
              salaryDocumentId,
            )
            .first;

        currentAmount =
            salaryDoc[FirebaseConstants.currentAmountField] as double;

        // Restore previous expense impact before applying new one
        double previousAmount =
            widget.expense![FirebaseConstants.amountField] as double;
        String previousTransactionType =
            widget.expense![FirebaseConstants.transactionTypeField];

        if (previousTransactionType == AppConstants.transactionTypeWithdraw ||
            previousTransactionType == AppConstants.transactionTypeTransfer) {
          currentAmount += previousAmount; // refund
        } else if (previousTransactionType ==
            AppConstants.transactionTypeDeposit) {
          currentAmount -= previousAmount; // deduct deposit
        }
      } else {
        // Get the latest salary document for new expense
        Map<String, dynamic> latestSalaryData =
            await _getLatestSalaryData(_selectedBankId);

        salaryDocumentId = latestSalaryData[FirebaseConstants.documentIdField];
        currentAmount = latestSalaryData[FirebaseConstants.currentAmountField];
      }

      // Apply new transaction impact on salary (common for both edit and add)
      double updatedAmount = currentAmount;
      if (_selectedTransactionType == AppConstants.transactionTypeWithdraw ||
          _selectedTransactionType == AppConstants.transactionTypeTransfer) {
        if (currentAmount < amount) {
          showToast('Insufficient balance in salary.');
          return;
        }
        updatedAmount -= amount;
      } else if (_selectedTransactionType ==
          AppConstants.transactionTypeDeposit) {
        updatedAmount += amount;
      }

      // Use existing document ID in edit mode
      final documentId = isEditMode
          ? widget.expenseId!
          : "${DateTime.now().toIso8601String()}_$amount";

      // Prepare the data to be stored
      Map<String, dynamic> expenseData = {
        FirebaseConstants.amountField: amount,
        FirebaseConstants.bankIdField: _selectedBankId,
        FirebaseConstants.expenseField: expenseType,
        FirebaseConstants.transactionTypeField: _selectedTransactionType,
        FirebaseConstants.expenseCategoryField: _selectedExpenseCategoryId ??
            _selectedExpenseCategory?.toLowerCase(),
        FirebaseConstants.timestampField: DateTime.now(),
        FirebaseConstants.salaryDocumentIdField: salaryDocumentId,
      };

      // ✅ Update the salary document amount
      await FirebaseService().updateSalaryAmount(
        userEmail,
        salaryDocumentId,
        updatedAmount,
      );

      // Add or update expense document
      if (isEditMode) {
        await FirebaseService().updatedExpenseData(
          userEmail,
          documentId,
          expenseData,
          FirebaseConstants.expenseCollection,
        );
      } else {
        await FirebaseService().addData(
          userEmail,
          documentId,
          expenseData,
          FirebaseConstants.expenseCollection,
        );
      }

      Navigator.of(context).pop(AppConstants.refresh);
    } else {
      if (_selectedBankId == null) {
        showToast('Please select a bank.');
      }
    }
  }

  void checkFormChanged() {
    final original = widget.expense;

    final isChanged = (_amountController.text !=
            (original?[FirebaseConstants.amountField]?.toString() ?? '')) ||
        (_expenseController.text !=
            (original?[FirebaseConstants.expenseField] ?? '')) ||
        (_selectedTransactionType !=
            (original?[FirebaseConstants.transactionTypeField] ??
                AppConstants.transactionTypeWithdraw)) ||
        (_selectedBankId != (original?[FirebaseConstants.bankIdField])) ||
        (_selectedExpenseCategoryId !=
            (original?[FirebaseConstants.expenseCategoryField]));

    setState(() {
      _isFormChanged = isChanged;
    });
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
                        Navigator.of(context)
                            .pop(AppConstants.refresh); // Close the popup
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
                                maxLength: 10,
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
                                  checkFormChanged();
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
                                items: _expenseCategoryNames.map((String name) {
                                  return DropdownMenuItem<String>(
                                    value: name,
                                    child: Text(name,
                                        style: theme.textTheme.bodyLarge),
                                  );
                                }).toList(),
                                onChanged: (selectedName) {
                                  setState(() {
                                    _selectedExpenseCategory = selectedName!;
                                    _selectedExpenseCategoryId =
                                        _expenseCategoryMap[selectedName];

                                    if (_selectedExpenseCategory !=
                                        AppConstants.otherCategory) {
                                      _expenseController.text =
                                          _selectedExpenseCategory!;
                                    }
                                  });
                                  checkFormChanged();
                                },
                                decoration: InputDecoration(
                                    labelText: 'Expense Category',
                                    labelStyle: theme.textTheme.labelSmall,
                                    border: const OutlineInputBorder(),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    )),
                              ),
                              const SizedBox(height: 30),
                              TextFormField(
                                enabled: _selectedExpenseCategory ==
                                    AppConstants.otherCategory,
                                controller: _expenseController,
                                maxLength: 15,
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
                                  checkFormChanged();
                                },
                                validator: (value) {
                                  if (_selectedExpenseCategory ==
                                          AppConstants.otherCategory &&
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
                                  checkFormChanged();
                                },
                                decoration: InputDecoration(
                                    labelText: 'Transaction Type',
                                    labelStyle: theme.textTheme.labelSmall,
                                    border: const OutlineInputBorder(),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    )),
                              ),
                              const SizedBox(height: 20),
                              if (widget.expense == null ||
                                  widget.expenseId == null)
                                Wrap(
                                  spacing: 8.0,
                                  runSpacing: 4.0,
                                  children: userBanks
                                      .map<Widget>((entry) => ChoiceChip(
                                            showCheckmark: false,
                                            avatar:
                                                Image.network(entry['image']),
                                            label: Text(entry['name']),
                                            labelStyle: TextStyle(
                                              color:
                                                  _selectedBankId == entry['id']
                                                      ? Colors.white
                                                      : theme.textTheme
                                                          .bodyLarge!.color,
                                            ),
                                            selectedColor: AppColors.secondary,
                                            backgroundColor: customTheme!
                                                .chipBackgroundColor,
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
                      onPressed: (_formKey.currentState?.validate() ?? false) &&
                              _isFormChanged
                          ? _submit
                          : null,
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

Future<String> openFullScreenModal(BuildContext context, String? expenseId,
    Map<String, dynamic>? expense) async {
  final result = await Navigator.of(context).push(PageRouteBuilder(
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
        child: FullScreenModal(expense: expense, expenseId: expenseId),
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

  return result ?? '';
}
