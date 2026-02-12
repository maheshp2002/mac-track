import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/toast.dart';
import 'package:mac_track/services/csv_transaction_importer.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import '../config/constants.dart';
import '../services/firebase_service.dart';
import '../ui/theme.dart';

class FullScreenModal extends StatefulWidget {
  final Map<String, dynamic>? expense;
  final String? expenseId;
  const FullScreenModal(
      {super.key, required this.expense, required this.expenseId});

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
  bool iosStyle = true;
  StreamSubscription<Map<String, dynamic>>? _userBankSub;
  final FirebaseService _firebaseService = FirebaseService();

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
        if (!_amountFocusNode.hasFocus) {
          _formKey.currentState?.validate();
          _updateValidationState();
        }
      });
    _expenseFocusNode = FocusNode()
      ..addListener(() {
        if (!_expenseFocusNode.hasFocus) {
          _formKey.currentState?.validate();
          _updateValidationState();
        }
      });

    _bankDataStream = _firebaseService.streamBankData();
    initializeBankData();

    expenseTypeDataStream = _firebaseService.streamExpenseTypes();

    expenseTypeDataStream.first.then((typesData) {
      if (!mounted) return;

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
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    userBankDataStream = _firebaseService.streamGetAllData(
      user.email!,
      FirebaseConstants.userBankCollection,
    );

    // Cancel any previous subscription
    _userBankSub?.cancel();

    // Store the subscription so we can dispose it
    _userBankSub = userBankDataStream.listen((userBankData) async {
      // Fetch master banks only once per update
      final masterBanks = await _bankDataStream.first;

      final List<Map<String, dynamic>> updatedUserBanks = [];

      for (final entry in userBankData.entries) {
        final prevId = entry.value[FirebaseConstants.bankIdField];
        final bankId = prevId == AppConstants.otherCategory
            ? entry.value[FirebaseConstants.bankNameField]
            : entry.value[FirebaseConstants.bankIdField];

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
            'isPrimary': entry.value['isPrimary'],
          });
        }
      }

      if (!mounted) return; // prevent setState after dispose

      setState(() {
        userBanks = updatedUserBanks;
      });
    });
  }

  Future<Map<String, dynamic>> _getLatestSalaryData(
      String? selectedBankId) async {
    final salarySnapshot = await _firebaseService
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
          (latestSalaryDoc.value[FirebaseConstants.currentAmountField] as num?)
                  ?.toDouble() ??
              0.0;
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

  String? _validateAmount(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an amount';
    }
    final n = num.tryParse(value);
    if (n == null || n <= 0) {
      return 'Invalid amount';
    }
    return null;
  }

  String? _validateExpenseType(String? value) {
    if (_selectedExpenseCategory == AppConstants.otherCategory &&
        (value == null || value.trim().isEmpty)) {
      return 'Please enter an expense type';
    }
    return null;
  }

  void _updateValidationState() {
    final isAmountValid = _validateAmount(_amountController.text) == null;
    final isExpenseTypeValid =
        _validateExpenseType(_expenseController.text) == null;

    if (_isAmountValid == isAmountValid &&
        _isExpenseTypeValid == isExpenseTypeValid) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _isAmountValid = isAmountValid;
      _isExpenseTypeValid = isExpenseTypeValid;
    });
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    _updateValidationState();

    if (!isValid || _selectedBankId == null) {
      if (_selectedBankId == null) {
        showToast('Please select a bank.');
      }
      return;
    }

    final amount = num.tryParse(_amountController.text.trim())?.toDouble();
    if (amount == null || amount <= 0) {
      showToast('Please enter a valid amount.');
      return;
    }

    final customExpense = _expenseController.text.trim();
    final expenseType =
        customExpense.isNotEmpty ? customExpense : _selectedExpenseCategory;
    if (expenseType == null || expenseType.isEmpty) {
      showToast('Please enter an expense type.');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      showToast('User not signed in.');
      return;
    }
    final userEmail = user.email!;

    final isEditMode = widget.expenseId != null && widget.expense != null;

    String salaryDocumentId =
        widget.expense?[FirebaseConstants.salaryDocumentIdField] ?? '';
    final originalBankId = widget.expense?[FirebaseConstants.bankIdField];
    final hasBankChanged = isEditMode && originalBankId != _selectedBankId;

    if (!isEditMode || hasBankChanged) {
      final latestSalaryData = await _getLatestSalaryData(_selectedBankId);
      salaryDocumentId = latestSalaryData[FirebaseConstants.documentIdField];
    }

    if ((!isEditMode || hasBankChanged) && salaryDocumentId.isEmpty) {
      showToast('Please add salary for the selected bank first.');
      return;
    }

    final documentId = isEditMode
        ? widget.expenseId!
        : "${DateTime.now().toIso8601String()}_$amount";

    final expenseData = <String, dynamic>{
      FirebaseConstants.amountField: amount,
      FirebaseConstants.bankIdField: _selectedBankId,
      FirebaseConstants.expenseField: expenseType,
      FirebaseConstants.transactionTypeField: _selectedTransactionType,
      FirebaseConstants.expenseCategoryField:
          _selectedExpenseCategoryId ?? _selectedExpenseCategory?.toLowerCase(),
      FirebaseConstants.timestampField: DateTime.now(),
    };
    if (!isEditMode || hasBankChanged) {
      expenseData[FirebaseConstants.salaryDocumentIdField] = salaryDocumentId;
    }

    try {
      if (isEditMode) {
        await _firebaseService.updateExpenseWithSalaryUpdate(
          userEmail: userEmail,
          expenseDocumentId: documentId,
          updatedExpenseData: expenseData,
        );
      } else {
        await _firebaseService.addExpenseWithSalaryUpdate(
          userEmail: userEmail,
          salaryDocumentId: salaryDocumentId,
          expenseDocumentId: documentId,
          expenseData: expenseData,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(AppConstants.refresh);
    } on StateError catch (e) {
      showToast(e.message.toString());
    } catch (e) {
      showToast('Failed to save expense. Please try again.');
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

  Future<bool> _showImportConfirmation(int count) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return CommonDialog(
          title: 'Confirm CSV Import',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count transactions detected.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'This will update your salary balance.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Do you want to continue?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
          primaryActionText: 'Import',
          cancelText: 'Cancel',
          onPrimaryAction: () {
            Navigator.of(context).pop(true);
          },
        );
      },
    );

    return result ?? false;
  }

  @override
  void dispose() {
    // CANCEL STREAM SUBSCRIPTION
    _userBankSub?.cancel();

    _amountFocusNode.dispose();
    _expenseFocusNode.dispose();
    _amountController.dispose();
    _expenseController.dispose();
    super.dispose();
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
            child: ListView(
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
                SingleChildScrollView(
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
                                _updateValidationState();
                                checkFormChanged();
                              },
                              validator: _validateAmount,
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              dropdownColor: theme.scaffoldBackgroundColor,
                              icon: Icon(
                                FontAwesomeIcons.moneyBillTransfer,
                                color: theme.iconTheme.color,
                              ),
                              initialValue: _selectedExpenseCategory,
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
                                _formKey.currentState?.validate();
                                _updateValidationState();
                                checkFormChanged();
                              },
                              decoration: InputDecoration(
                                  labelText: 'Expense Category',
                                  labelStyle: theme.textTheme.labelSmall,
                                  border: const OutlineInputBorder(),
                                  focusedBorder: const OutlineInputBorder(
                                    borderSide:
                                        BorderSide(color: AppColors.secondary),
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
                                _updateValidationState();
                                checkFormChanged();
                              },
                              validator: _validateExpenseType,
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              dropdownColor: theme.scaffoldBackgroundColor,
                              icon: Icon(
                                FontAwesomeIcons.moneyBillTransfer,
                                color: theme.iconTheme.color,
                              ),
                              initialValue: _selectedTransactionType,
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
                                    borderSide:
                                        BorderSide(color: AppColors.secondary),
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
                                          color: _selectedBankId == entry['id']
                                              ? Colors.white
                                              : theme
                                                  .textTheme.bodyLarge!.color,
                                        ),
                                        selectedColor: AppColors.secondary,
                                        backgroundColor:
                                            customTheme!.chipBackgroundColor,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(50.0),
                                        ),
                                        selected: _selectedBankId ==
                                            entry['id'], // Compare document ID
                                        onSelected: (selected) {
                                          setState(() {
                                            _selectedBankId = selected
                                                ? entry['id']
                                                // Store document ID
                                                : null;
                                          });
                                          checkFormChanged();
                                        },
                                      ))
                                  .toList(),
                            )
                          ],
                        );
                      }
                    },
                  ),
                ),
                // Save Button
                Container(
                  width: 200,
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: ElevatedButton(
                    onPressed: _selectedBankId != null && _isFormChanged
                        ? _submit
                        : null,
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all(AppColors.secondaryGreen),
                    ),
                    child: Text('Add Expense',
                        style: TextStyle(
                            color: AppColors.white,
                            fontSize: theme.textTheme.bodyLarge!.fontSize)),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                ElevatedButton.icon(
                  icon: const Icon(FontAwesomeIcons.fileCsv),
                  label: const Text('Import CSV'),
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(AppColors.secondaryGreen),
                  ),
                  onPressed: _selectedBankId == null
                      ? null
                      : () async {
                          try {
                            final importer = CsvTransactionImporter();
                            final latestSalary =
                                await _getLatestSalaryData(_selectedBankId);
                            final salaryDocumentId =
                                latestSalary[FirebaseConstants.documentIdField]
                                    as String;

                            if (salaryDocumentId.isEmpty) {
                              showToast(
                                  'Please add salary for the selected bank first.');
                              return;
                            }

                            final imported = await importer.importCsv(
                              selectedBankId: _selectedBankId!,
                              expenseCategoryMap: _expenseCategoryMap,
                              salaryDocumentId: salaryDocumentId,
                            );

                            if (imported.isEmpty) {
                              showToast('No valid transactions found');
                              return;
                            }

                            final confirmed =
                                await _showImportConfirmation(imported.length);

                            if (!confirmed) return;

                            final user = FirebaseAuth.instance.currentUser;
                            if (user == null || user.email == null) {
                              showToast('User not signed in');
                              return;
                            }

                            await _firebaseService
                                .importExpensesWithSalaryUpdate(
                              userEmail: user.email!,
                              salaryDocumentId: salaryDocumentId,
                              expenses: imported,
                            );

                            showToast(
                                '${imported.length} transactions imported');

                            if (!context.mounted) return;
                            Navigator.of(context).pop(AppConstants.refresh);
                          } catch (e) {
                            showToast(e.toString());
                          }
                        },
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
