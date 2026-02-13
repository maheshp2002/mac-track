import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:mac_track/ui/components/toast.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/firebase_service.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';

class ManageSalaryDialog extends StatefulWidget {
  final String email;
  final String selectedBankId;
  /// true → Transaction mode (this month only)
  /// false → Balance mode (all salary entries)
  final bool isTransactionMode;

  const ManageSalaryDialog({
    super.key,
    required this.email,
    required this.isTransactionMode,
    required this.selectedBankId,
  });

  @override
  ManageSalaryDialogState createState() => ManageSalaryDialogState();
}

class ManageSalaryDialogState extends State<ManageSalaryDialog> {
  final FirebaseService firebaseService = FirebaseService();

  late Stream<Map<String, dynamic>> expenseStream;

  @override
  void initState() {
    super.initState();

    expenseStream = firebaseService.streamGetAllData(
      widget.email,
      FirebaseConstants.expenseCollection,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CommonDialog(
      title: 'Manage Salary',
      showCloseButton: true,
      body: SizedBox(
        width: double.maxFinite,
        child: StreamBuilder<Map<String, dynamic>>(
          stream: expenseStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryGreen,
                ),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Text(
                  "An Error Occurred",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "No salary records found!",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            final now = DateTime.now();

            // FILTER SALARY FROM expenseCollection
            final salaryEntries = snapshot.data!.entries.where((entry) {
              final data = entry.value;
              final category = data[FirebaseConstants.expenseCategoryField];
              final type = data[FirebaseConstants.transactionTypeField];
              final bankId = data[FirebaseConstants.bankIdField];

              // Must belong to selected bank
              if (bankId != widget.selectedBankId) {
                return false;
              }

              // Must be Salary category AND Deposit
              if (category != AppConstants.salaryCategory.toLowerCase() ||
                  type != AppConstants.transactionTypeDeposit) {
                return false;
              }

              // If in transaction mode, only show salary entries from current month  
              if (widget.isTransactionMode) {
                final ts =
                    data[FirebaseConstants.timestampField] as Timestamp;
                final d = ts.toDate();

                return d.month == now.month && d.year == now.year;
              }

              return true;
            }).toList();

            if (salaryEntries.isEmpty) {
              return Center(
                child: Text(
                  widget.isTransactionMode
                      ? "No salary added this month."
                      : "No salary records found.",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            // Newest first
            salaryEntries.sort((a, b) {
              final tsA =
                  a.value[FirebaseConstants.timestampField] as Timestamp;
              final tsB =
                  b.value[FirebaseConstants.timestampField] as Timestamp;
              return tsB.compareTo(tsA);
            });

            return ListView.builder(
              shrinkWrap: true,
              itemCount: salaryEntries.length,
              itemBuilder: (context, index) {
                final entry = salaryEntries[index];
                final docId = entry.key;
                final docData = entry.value;

                final amount =
                    (docData[FirebaseConstants.amountField] ?? 0)
                        .toDouble();

                final Timestamp ts =
                    docData[FirebaseConstants.timestampField];
                final DateTime date = ts.toDate();
                final String formattedDate =
                    DateFormat('MMM dd, yyyy').format(date);

                final formattedAmount = NumberFormat.currency(
                  locale: AppConstants.englishIndiaLocale,
                  symbol: AppConstants.rupeesSymbol,
                  decimalDigits: 0,
                ).format(amount);

                bool isDeleting = false;

                return StatefulBuilder(
                  builder: (context, setStateTile) {
                    return ListTile(
                      key: ValueKey(docId),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      title: Text(
                        formattedAmount,
                        style: TextStyle(
                          fontSize:
                              theme.textTheme.titleLarge?.fontSize,
                          color: AppColors.primaryGreen,
                        ),
                      ),
                      subtitle: Text(
                        formattedDate,
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
                                showDialog(
                                  context: context,
                                  builder: (ctx) => CommonDialog(
                                    title: 'Delete Salary',
                                    body: Text(
                                      'Are you sure you want to delete this salary entry?',
                                      style:
                                          theme.textTheme.bodyLarge,
                                    ),
                                    primaryActionText: 'Delete',
                                    cancelText: 'Cancel',
                                    onPrimaryAction: () async {
                                      Navigator.of(ctx).pop();

                                      setStateTile(
                                          () => isDeleting = true);

                                      try {
                                        await firebaseService
                                            .deleteExpenseData(
                                          widget.email,
                                          docId,
                                          FirebaseConstants
                                              .expenseCollection,
                                        );

                                        if (mounted) {
                                          Navigator.of(context).pop();
                                        }
                                      } catch (_) {
                                        showToast(
                                          "Delete failed!",
                                          isSuccess: false,
                                        );
                                      }
                                    },
                                  ),
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
  }
}
