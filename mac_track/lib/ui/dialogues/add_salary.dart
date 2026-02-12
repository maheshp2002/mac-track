import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mac_track/components/toast.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/firebase_service.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';

class AddSalaryDialog extends StatefulWidget {
  final VoidCallback? onSalaryUpdated;
  final String email;
  const AddSalaryDialog({
    super.key,
    required this.email,
    this.onSalaryUpdated,
  });

  @override
  AddSalaryDialogState createState() => AddSalaryDialogState();
}

class AddSalaryDialogState extends State<AddSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isAmountValid = true;
  late FocusNode _amountFocusNode;
  final TextEditingController _amountController = TextEditingController();
  late Stream<Map<String, dynamic>> _bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  String? _selectedBankId; // Store the selected bank's document ID
  List<Map<String, dynamic>> userBanks = [];
  final firebaseService = FirebaseService();
  late Stream<Map<String, dynamic>> salaryDataStream = Stream.value({});
  StreamSubscription<Map<String, dynamic>>? _userBankSubscription;

  @override
  void initState() {
    super.initState();
    initializeBankData();
    _bankDataStream = firebaseService.streamBankData();
    _amountFocusNode = FocusNode();
    salaryDataStream = firebaseService.streamGetAllData(
      widget.email,
      FirebaseConstants.salaryCollection,
    );
  }

  @override
  void dispose() {
    _userBankSubscription?.cancel();
    _amountFocusNode.dispose();
    _amountController.dispose();
    super.dispose();
  }

  void initializeBankData() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    userBankDataStream = firebaseService.streamGetAllData(
      user.email!,
      FirebaseConstants.userBankCollection,
    );

    // CANCEL OLD LISTENER
    _userBankSubscription?.cancel();

    _userBankSubscription = userBankDataStream.listen((userBankData) async {
      if (!mounted) return;

      final Map<String, dynamic> masterBanks = await _bankDataStream.first;

      List<Map<String, dynamic>> updatedUserBanks = [];

      for (var entry in userBankData.entries) {
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
      }

      setState(() {
        userBanks = updatedUserBanks;
      });
    });
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBankId != null) {
      double amount = double.parse(_amountController.text);
      // Get the signed-in user's email
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        showToast('User not signed in.');
        return;
      }
      String userEmail = user.email ?? "";

      // Generate a unique document ID using date, time, and amount
      DateTime now = DateTime.now();
      String documentId = "${now.toIso8601String()}_$amount";

      // Prepare the data to be stored
      Map<String, dynamic> expenseData = {
        'totalAmount': amount,
        FirebaseConstants.currentAmountField: amount,
        FirebaseConstants.timestampField: now,
        FirebaseConstants.bankIdField: _selectedBankId
      };

      // Save the data to Firebase
      await firebaseService.addData(userEmail, documentId, expenseData,
          FirebaseConstants.salaryCollection);

      if (!mounted) return;

      // Optionally close the modal after submitting
      Navigator.of(context).pop(AppConstants.refresh);
    } else {
      if (_selectedBankId == null) {
        showToast('Please select a bank.');
      }
    }
  }

  Future<void> _openManageSalaryDialog(ThemeData theme) async {
    void showAlertDialog(BuildContext context, ThemeData theme, String title,
        String message, String buttonLabel, Future<void> Function() submit) {
      AlertDialog alert = AlertDialog(
        title: Text(
          title,
          style: theme.textTheme.headlineLarge,
        ),
        backgroundColor: theme.dialogTheme.backgroundColor,
        content: Text(message, style: theme.textTheme.bodyLarge),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context, 'Cancel'),
            child: Text('Cancel', style: theme.textTheme.bodyLarge),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await submit();
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.secondaryGreen,
            ),
            child: Text(buttonLabel,
                style: const TextStyle(color: AppColors.primaryGreen)),
          ),
        ],
      );

      showDialog(
        context: context,
        builder: (BuildContext context) => alert,
      );
    }

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommonDialog(
          title: 'Manage Salary',
          showCloseButton: true,
          body: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<Map<String, dynamic>>(
              stream: salaryDataStream,
              builder: (context, salarySnapshot) {
                if (salarySnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.secondaryGreen,
                    ),
                  );
                } else if (salarySnapshot.hasError) {
                  return Center(
                    child: Text(
                      "An Error Occurred",
                      style: theme.textTheme.bodyLarge,
                    ),
                  );
                } else if (!salarySnapshot.hasData ||
                    salarySnapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      "Salary not found!",
                      style: theme.textTheme.bodyLarge,
                    ),
                  );
                }

                final allSalaryDocs = salarySnapshot.data!;

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: allSalaryDocs.length,
                  itemBuilder: (context, index) {
                    final entry = allSalaryDocs.entries.elementAt(index);
                    final docId = entry.key;
                    final docData = entry.value;
                    final amount =
                        docData[FirebaseConstants.currentAmountField];

                    if (amount == null) return const SizedBox();

                    final Timestamp ts =
                        docData[FirebaseConstants.timestampField];
                    final DateTime date = ts.toDate();
                    final String formattedDate =
                        DateFormat('MMM dd').format(date);

                    final formattedAmount = NumberFormat.currency(
                      locale: 'en_IN',
                      symbol: '₹',
                      decimalDigits: 0,
                    ).format(amount);

                    bool isDeleting = false;

                    return StatefulBuilder(
                      builder: (context, setState) {
                        return ListTile(
                          key: ValueKey(docId),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          title: Text(
                            formattedDate,
                            style: TextStyle(
                              fontSize: theme.textTheme.titleLarge?.fontSize,
                              color: AppColors.primaryGreen,
                            ),
                          ),
                          subtitle: Text(
                            "$formattedAmount in ${docData[FirebaseConstants.bankIdField]}",
                            style: theme.textTheme.bodySmall,
                          ),
                          trailing: isDeleting
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : IconButton(
                                  icon: const Icon(
                                    FontAwesomeIcons.trash,
                                    color: AppColors.danger,
                                  ),
                                  onPressed: () {
                                    showAlertDialog(
                                      context,
                                      theme,
                                      'Delete Salary',
                                      'Are you sure you want to delete this salary and all related expenses?',
                                      'Delete',
                                      () async {
                                        setState(() => isDeleting = true);

                                        try {
                                          final expenseSnapshot =
                                              await FirebaseFirestore.instance
                                                  .collection('users')
                                                  .doc(widget.email)
                                                  .collection(
                                                    FirebaseConstants
                                                        .expenseCollection,
                                                  )
                                                  .get();

                                          for (var expenseDoc
                                              in expenseSnapshot.docs) {
                                            final data = expenseDoc.data();
                                            if (data['salaryDocumentId'] ==
                                                docId) {
                                              await firebaseService
                                                  .deleteExpenseData(
                                                widget.email,
                                                expenseDoc.id,
                                                FirebaseConstants
                                                    .expenseCollection,
                                              );
                                            }
                                          }

                                          await firebaseService
                                              .deleteExpenseData(
                                            widget.email,
                                            docId,
                                            FirebaseConstants.salaryCollection,
                                          );

                                          widget.onSalaryUpdated?.call();
                                        } catch (e) {
                                          showToast(
                                            "Delete failed!",
                                            isSuccess: false,
                                          );
                                        }
                                      },
                                    );
                                  },
                                ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();

    return CommonDialog(
      title: 'Add Salary',
      primaryActionText: 'Add',
      onPrimaryAction: _submit,
      cancelText: 'Cancel',
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: TextFormField(
                  controller: _amountController,
                  maxLength: 10,
                  focusNode: _amountFocusNode,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Amount',
                    labelStyle:
                        TextStyle(color: theme.textTheme.bodyLarge?.color),
                    suffixIcon: Icon(
                      FontAwesomeIcons.indianRupeeSign,
                      color: _isAmountValid
                          ? _amountFocusNode.hasFocus
                              ? AppColors.secondary
                              : theme.iconTheme.color
                          : Colors.red,
                    ),
                    border: const OutlineInputBorder(),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.secondary),
                    ),
                  ),
                  cursorColor: AppColors.secondary,
                  onChanged: (_) {
                    _formKey.currentState?.validate();
                  },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      setState(() => _isAmountValid = false);
                      return 'Please enter an amount';
                    }
                    final n = num.tryParse(value);
                    if (n == null) {
                      setState(() => _isAmountValid = false);
                      return 'Invalid amount';
                    }
                    setState(() => _isAmountValid = true);
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: userBanks.map<Widget>((entry) {
                  return ChoiceChip(
                    showCheckmark: false,
                    avatar: Image.network(entry['image']),
                    label: Text(entry['name']),
                    labelStyle: TextStyle(
                      color: _selectedBankId == entry['id']
                          ? Colors.white
                          : theme.textTheme.bodyLarge!.color,
                    ),
                    selectedColor: AppColors.secondary,
                    backgroundColor: customTheme!.chipBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    selected: _selectedBankId == entry['id'],
                    onSelected: (selected) {
                      setState(() {
                        _selectedBankId = selected ? entry['id'] : null;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              InkWell(
                splashColor: AppColors.secondaryGreen,
                onTap: () {
                  _openManageSalaryDialog(theme);
                },
                child: Row(
                  children: [
                    Text(
                      "Manage Salary",
                      style: theme.textTheme.bodyLarge!
                          .copyWith(color: AppColors.primaryGreen),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      FeatherIcons.arrowUpRight,
                      color: AppColors.primaryGreen,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
