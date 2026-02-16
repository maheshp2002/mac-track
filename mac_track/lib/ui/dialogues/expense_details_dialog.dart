import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/firebase_service.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';

class ExpenseDetailsDialog extends StatefulWidget {
  final String email;
  final String selectedExpenseId;

  const ExpenseDetailsDialog({
    super.key,
    required this.email,
    required this.selectedExpenseId,
  });

  @override
  ExpenseDetailsDialogState createState() =>
      ExpenseDetailsDialogState();
}

class ExpenseDetailsDialogState
    extends State<ExpenseDetailsDialog> {
  final FirebaseService firebaseService = FirebaseService();

  late Stream<Map<String, dynamic>> expenseStream;

  @override
  void initState() {
    super.initState();

    expenseStream = firebaseService.streamGetDataInUserById(
      widget.email,
      FirebaseConstants.expenseCollection,
      widget.selectedExpenseId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CommonDialog(
      title: 'Expense Details',
      showCloseButton: true,
      body: SizedBox(
        width: 500,
        child: StreamBuilder<Map<String, dynamic>>(
          stream: expenseStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState ==
                ConnectionState.waiting) {
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

            if (!snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "No expense found!",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            final data = snapshot.data!;

            final amount =
                (data[FirebaseConstants.amountField] ?? 0)
                    .toDouble();

            final transactionType =
                data[FirebaseConstants
                        .transactionTypeField] ??
                    '';

            final expenseName =
                data[FirebaseConstants.expenseField] ??
                    'Expense';

            final bankId =
                data[FirebaseConstants.bankIdField] ??
                    'Unknown Bank';

            final Timestamp ts =
                data[FirebaseConstants.timestampField];

            final DateTime date = ts.toDate();

            final formattedDate =
                DateFormat('MMM dd, yyyy • hh:mm a')
                    .format(date);

            final isDeposit =
                transactionType ==
                    AppConstants
                        .transactionTypeDeposit;

            return Container(
              padding:
                  const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius:
                    BorderRadius.circular(24),
                gradient: LinearGradient(
                  colors: isDeposit
                      ? [
                          Colors.green.shade700,
                          Colors.green.shade400
                        ]
                      : [
                          Colors.deepPurple.shade700,
                          Colors.deepPurple.shade400
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  // Top Row
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment
                            .spaceBetween,
                    children: [
                      Text(
                        expenseName,
                        style: theme
                            .textTheme.titleLarge
                            ?.copyWith(
                          color: Colors.white,
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration:
                            BoxDecoration(
                          color: Colors.white
                              .withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius
                                  .circular(20),
                        ),
                        child: Text(
                          transactionType
                              .toUpperCase(),
                          style:
                              const TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),

                  // Amount
                  Text(
                    "₹${NumberFormat('#,##0.00').format(amount)}",
                    style: theme
                        .textTheme.displayMedium
                        ?.copyWith(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Bottom Info
                  Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,
                    children: [
                      Text(
                        "Bank",
                        style: theme
                            .textTheme.labelSmall
                            ?.copyWith(
                                color: Colors
                                    .white70),
                      ),
                      Text(
                        bankId,
                        style: theme
                            .textTheme.bodyLarge
                            ?.copyWith(
                                color:
                                    Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Date",
                        style: theme
                            .textTheme.labelSmall
                            ?.copyWith(
                                color: Colors
                                    .white70),
                      ),
                      Text(
                        formattedDate,
                        style: theme
                            .textTheme.bodyLarge
                            ?.copyWith(
                                color:
                                    Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
