import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:intl/intl.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/firebase_service.dart';
import 'package:mac_track/ui/components/full_screen_modal.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:share_plus/share_plus.dart';

class ExpenseDetailsDialog extends StatefulWidget {
  final String email;
  final String selectedExpenseId;

  const ExpenseDetailsDialog({
    super.key,
    required this.email,
    required this.selectedExpenseId,
  });

  @override
  ExpenseDetailsDialogState createState() => ExpenseDetailsDialogState();
}

class ExpenseDetailsDialogState extends State<ExpenseDetailsDialog> {
  final FirebaseService firebaseService = FirebaseService();

  late Stream<Map<String, dynamic>> expenseStream;
  late Stream<Map<String, dynamic>> bankMasterStream;

  Map<String, dynamic>? _expenseData;
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();

    expenseStream = firebaseService.streamGetDataInUserById(
      widget.email,
      FirebaseConstants.expenseCollection,
      widget.selectedExpenseId,
    );

    bankMasterStream = firebaseService.streamBankData();
  }

  Color _lighten(Color color, [double amount = .05]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _darken(Color color, [double amount = .15]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  Color _getBaseColor(String transactionType) {
    switch (transactionType) {
      case AppConstants.transactionTypeDeposit:
        return AppColors.filterButtonBlack;
      case AppConstants.transactionTypeWithdraw:
        return AppColors.purple;
      case AppConstants.transactionTypeTransfer:
        return _darken(AppColors.filterButtonGreen, 0.25);
      default:
        return AppColors.secondaryGreen;
    }
  }

  Future<void> _handleEdit() async {
    if (_expenseData == null) return;

    Navigator.of(context).pop();

    await openFullScreenModal(
      context,
      widget.selectedExpenseId,
      _expenseData,
    );
  }

  Future<void> _shareReminder() async {
    if (_expenseData == null) return;

    final transactionType =
        _expenseData![FirebaseConstants.transactionTypeField];

    // Only for withdraw (debit)
    if (transactionType != AppConstants.transactionTypeWithdraw) {
      return;
    }

    final amount =
        (_expenseData![FirebaseConstants.amountField] ?? 0).toDouble();

    final expenseName = _expenseData![FirebaseConstants.expenseField] ?? '';

    final Timestamp ts = _expenseData![FirebaseConstants.timestampField];

    final date = DateFormat('dd MMM yyyy').format(ts.toDate());

    final message = '''
  Reminder:

  Please send ₹${NumberFormat('#,##0.00').format(amount)} 
  for "$expenseName"

  Due date: $date

  Sent via MacTrack
  ''';

    await Share.share(message);
  }

  // ================= FRONT CARD =================

  Widget _buildFrontCard(
    ThemeData theme,
    String expenseName,
    double amount,
    String transactionType,
    String bankName,
    String createdDate,
    String? bankImage,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top row (bank + logo)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                bankName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: AppColors.white70,
                ),
              ),
            ),
            if (bankImage != null)
              Container(
                height: 48,
                width: 48,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.network(bankImage, fit: BoxFit.contain),
              ),
          ],
        ),

        const Spacer(),

        // Amount
        Text(
          "₹${NumberFormat('#,##0.00').format(amount)}",
          style: theme.textTheme.displayMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        // Expense name
        Text(
          expenseName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w600,
          ),
        ),

        const SizedBox(height: 20),

        // Bottom metadata row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              transactionType.toUpperCase(),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.white70),
            ),
            Text(
              createdDate,
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: AppColors.white70),
            ),
          ],
        ),

        const SizedBox(height: 8),

        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            "Tap to flip",
            style:
                theme.textTheme.labelSmall?.copyWith(color: AppColors.white70),
          ),
        ),
      ],
    );
  }

  // ================= BACK CARD =================

  Widget _buildBackCard(
    ThemeData theme,
    String category,
    String contactName,
    String contactPhone,
    String updatedDate,
  ) {
    Widget block(String label, String value) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style:
                theme.textTheme.labelSmall?.copyWith(color: AppColors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            value.isEmpty ? "-" : value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyLarge?.copyWith(color: AppColors.white),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        block("Category", category),
        const SizedBox(height: 20),
        GestureDetector(
            onTap: _expenseData?[FirebaseConstants.transactionTypeField] ==
                    AppConstants.transactionTypeWithdraw
                ? _shareReminder
                : null,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(children: [
                    block("Contact", contactName.isEmpty ? "-" : contactName),
                    Text(
                      contactName.isEmpty ? "" : "• $contactPhone",
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: AppColors.white70),
                    ),
                  ]),
                  const Icon(
                    FeatherIcons.arrowUpRight,
                    color: AppColors.primaryGreen,
                    size: 20,
                  ),
                ])),
        const Spacer(),
        const SizedBox(height: 8),
        block("Last Updated", updatedDate),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.bottomRight,
          child: Text(
            "Tap to flip",
            style:
                theme.textTheme.labelSmall?.copyWith(color: AppColors.white70),
          ),
        ),
      ],
    );
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return CommonDialog(
      title: 'Expense Details',
      cancelText: 'Cancel',
      primaryActionText: 'Edit',
      onPrimaryAction: _handleEdit,
      body: SizedBox(
        width: 520,
        child: StreamBuilder<Map<String, dynamic>>(
          stream: expenseStream,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryGreen,
                ),
              );
            }

            final data = snapshot.data!;
            _expenseData = data;

            final amount =
                (data[FirebaseConstants.amountField] ?? 0).toDouble();

            final transactionType =
                data[FirebaseConstants.transactionTypeField] ?? '';

            final expenseName = data[FirebaseConstants.expenseField] ?? '';

            final category = data[FirebaseConstants.expenseCategoryField] ?? '';

            final contactName = data['counterpartyName'] ?? '';

            final contactPhone = data['counterpartyPhone'] ?? '';

            final Timestamp createdTs = data[FirebaseConstants.timestampField];

            final Timestamp? updatedTs = data[FirebaseConstants.updatedAtField];

            final formattedCreated =
                DateFormat('MMM dd, yyyy').format(createdTs.toDate());

            final formattedUpdated = updatedTs != null
                ? DateFormat('MMM dd, yyyy').format(updatedTs.toDate())
                : "-";

            final baseColor = _getBaseColor(transactionType);
            final gradientStart = _darken(baseColor, 0.15);
            final gradientEnd = _lighten(baseColor, 0.05);

            return StreamBuilder<Map<String, dynamic>>(
              stream: bankMasterStream,
              builder: (context, bankSnapshot) {
                String bankName = "";
                String? bankImage;

                if (bankSnapshot.hasData) {
                  final master = bankSnapshot.data!;
                  final bankData = master[data[FirebaseConstants.bankIdField]];

                  if (bankData != null) {
                    bankName = bankData[FirebaseConstants.nameField] ?? '';
                    bankImage = bankData[FirebaseConstants.imageField];
                  }
                }

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _isFlipped = !_isFlipped;
                    });
                  },
                  child: TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 500),
                    tween: Tween<double>(begin: 0, end: _isFlipped ? 1 : 0),
                    builder: (context, value, child) {
                      final angle = value * 3.1416;
                      final isBack = angle > 1.5708;

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        alignment: Alignment.center,
                        child: Container(
                          height: 280,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              colors: [gradientStart, gradientEnd],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.3),
                                blurRadius: 18,
                                offset: const Offset(0, 10),
                              )
                            ],
                          ),
                          child: isBack
                              ? Transform(
                                  alignment: Alignment.center,
                                  transform: Matrix4.rotationY(3.1416),
                                  child: _buildBackCard(
                                    theme,
                                    category,
                                    contactName,
                                    contactPhone,
                                    formattedUpdated,
                                  ),
                                )
                              : _buildFrontCard(
                                  theme,
                                  expenseName,
                                  amount,
                                  transactionType,
                                  bankName,
                                  formattedCreated,
                                  bankImage,
                                ),
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
