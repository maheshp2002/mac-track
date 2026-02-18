import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/ui/components/curved_toggle_button.dart';
import 'package:provider/provider.dart';
import 'components/common_app_bar.dart';
import 'components/graph.dart';
import 'components/floating_bottom_nav.dart';
import 'components/theme_manager.dart';
import 'theme.dart';
import '../../config/constants.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Insight extends StatefulWidget {
  const Insight({super.key});

  @override
  InsightState createState() => InsightState();
}

class InsightState extends State<Insight> {
  late Stream<Map<String, dynamic>> expenseDataStream = Stream.value({});
  late Stream<Map<String, dynamic>> bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  late Stream<Map<String, dynamic>> expenseTypesStream;
  late Stream<Map<String, dynamic>> salaryDataStream;
  String selectedSalaryItem = "";
  final firebaseService = FirebaseService();
  String userEmail = "";
  String currentBalance = "";
  String totalExpense = "";
  String? selectedBankId;
  List<Map<String, dynamic>> userBanks = [];
  List<Map<String, dynamic>> salaryData = [];

  @override
  void initState() {
    super.initState();
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      setState(() {
        userEmail = user.email ?? "";
      });
    }

    _initializeUser();
    expenseTypesStream = firebaseService.streamExpenseTypes();
  }

  void _initializeUser({VoidCallback? callback}) async {
    bankDataStream = firebaseService.streamBankData();

    userBankDataStream = firebaseService.streamGetAllData(
      userEmail,
      FirebaseConstants.userBankCollection,
    );

    userBankDataStream.listen((userBankData) async {
      Map<String, dynamic> masterBanks = await bankDataStream.first;

      List<Map<String, dynamic>> updatedUserBanks = [];
      String? primaryBankId;

      for (var entry in userBankData.entries) {
        final documentId = entry.key;
        final prevId = entry.value[FirebaseConstants.bankIdField];
        final bankId = prevId == AppConstants.otherCategory
            ? entry.value[FirebaseConstants.bankNameField]
            : entry.value[FirebaseConstants.bankIdField];
        final isPrimary = entry.value[FirebaseConstants.isPrimaryField];
        final bankDetails = prevId == AppConstants.otherCategory
            ? masterBanks[prevId]
            : masterBanks[bankId];

        if (bankDetails != null) {
          updatedUserBanks.add({
            FirebaseConstants.primaryIdField: bankId,
            FirebaseConstants.nameField: prevId == AppConstants.otherCategory
                ? entry.value[FirebaseConstants.bankNameField]
                : bankDetails[FirebaseConstants.nameField],
            FirebaseConstants.imageField: bankDetails[FirebaseConstants.imageField],
            FirebaseConstants.isPrimaryField: isPrimary,
            FirebaseConstants.documentIdField: documentId,
          });

          if (isPrimary == true) {
            primaryBankId = bankId;
          }
        }
      }

      updatedUserBanks.add({
        FirebaseConstants.primaryIdField: AppConstants.allItem,
        FirebaseConstants.nameField: AppConstants.allItem,
        FirebaseConstants.imageField: '',
        FirebaseConstants.isPrimaryField: false,
        FirebaseConstants.documentIdField: '',
      });

      setState(() {
        userBanks = updatedUserBanks;

        // Ensure the selectedBankId exists in userBanks, else set it to primaryBankId
        final existingBankIds = updatedUserBanks.map((b) => b[FirebaseConstants.primaryIdField]).toList();
        if (!existingBankIds.contains(selectedBankId)) {
          selectedBankId = primaryBankId;
        }

        // Update UI only if we have a valid selected bank
        if (selectedBankId != null && selectedBankId!.isNotEmpty) {
          _changeBank(selectedBankId!);
        }
      });

      // Trigger dialog refresh if passed
      if (callback != null) callback();
    });
  }

  void _updateSalaryStream([String? selectedValue]) async {
    final email = FirebaseAuth.instance.currentUser!.email!;

    final expenseDataRaw = await firebaseService
        .streamGetAllData(email, FirebaseConstants.expenseCollection)
        .first;

    // Add ALL option
    salaryData.add({
      FirebaseConstants.primaryIdField: AppConstants.allItem,
      FirebaseConstants.totalAmountField: 0.0
    });

    selectedSalaryItem = selectedValue ?? selectedSalaryItem;

    if (!salaryData.any((e) =>
        e[FirebaseConstants.primaryIdField] ==
        selectedSalaryItem)) {
      selectedSalaryItem = salaryData.isNotEmpty
          ? salaryData.first[FirebaseConstants.primaryIdField]
          : "";
    }

    double calculatedBalance = 0;
    double calculatedExpense = 0;

    // for (final salary in filteredSalaries) {
    //   final salaryId = salary.key;
    //   final baseAmount =
    //       (salary.value[FirebaseConstants.totalAmountField] ?? 0)
    //           .toDouble();

    //   bool includeThisSalary = false;

    //   if (selectedSalaryItem == AppConstants.allItem) {
    //     includeThisSalary = true;
    //   } else if (selectedSalaryItem == salaryId) {
    //     includeThisSalary = true;
    //   }

    //   if (!includeThisSalary) continue;

    //   calculatedBalance += baseAmount;

    //   for (final expense in expenseDataRaw.values) {
    //     final matchesBank = selectedBankId ==
    //             AppConstants.allItem ||
    //         selectedBankId == null ||
    //         expense[FirebaseConstants.bankIdField] ==
    //             selectedBankId;

    //     final matchesSalary =
    //         expense[FirebaseConstants.salaryDocumentIdField] ==
    //             salaryId;

    //     if (matchesBank && matchesSalary) {
    //       final type =
    //           expense[FirebaseConstants.transactionTypeField];
    //       final amount =
    //           (expense[FirebaseConstants.amountField] ?? 0)
    //               .toDouble();

    //       if (type == AppConstants.transactionTypeDeposit) {
    //         calculatedBalance += amount;
    //       } else {
    //         calculatedBalance -= amount;
    //         calculatedExpense += amount;
    //       }
    //     }
    //   }
    // }

    setState(() {
      currentBalance = NumberFormat.currency(
        locale: AppConstants.englishIndiaLocale,
        symbol: AppConstants.rupeesSymbol,
        decimalDigits: 0,
      ).format(calculatedBalance);

      totalExpense = NumberFormat.currency(
        locale: AppConstants.englishIndiaLocale,
        symbol: AppConstants.rupeesSymbol,
        decimalDigits: 0,
      ).format(calculatedExpense);
    });

    _updateExpenseStream(
      selectedBankId ?? AppConstants.allItem,
      selectedSalaryItem == AppConstants.allItem
          ? null
          : selectedSalaryItem,
    );
  }

  void _updateExpenseStream(String bankId, [String? salaryId]) {
    expenseDataStream = firebaseService
        .streamGetAllData(userEmail, FirebaseConstants.expenseCollection)
        .map((expenseData) {
      final filtered = expenseData.entries.where((entry) {
        final data = entry.value;

        final matchesBank = bankId == AppConstants.allItem ||
            data[FirebaseConstants.bankIdField] == bankId;

        final matchesSalary =
            salaryId == null ||
                data[AppConstants.salaryCategory] ==
                    salaryId;

        return matchesBank && matchesSalary;
      }).toList();

      return Map.fromEntries(filtered);
    });
  }

  void _changeBank(String bankId) {
    setState(() {
      selectedBankId = bankId;
      _updateSalaryStream();
    });
  }

  Widget dropDownSelect(
    ThemeData theme,
    String dropDownValue,
    List<DropdownMenuItem<String>>? dropDownItems,
    void Function(String?) onChangeFunction,
  ) {
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: dropDownValue,
        icon: Icon(
          FontAwesomeIcons.caretDown,
          color: theme.iconTheme.color,
          size: 16,
        ),
        dropdownColor: theme.scaffoldBackgroundColor,
        isExpanded: true,
        items: dropDownItems,
        onChanged: onChangeFunction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CommonAppBar(
        title: 'Insight',
      ),
      drawer: const FloatingBottomNav(),
      body: Container(
          decoration: AppTheme.getBackgroundDecoration(themeMode),
          padding: const EdgeInsets.only(top: kToolbarHeight + 50),
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: StreamBuilder<Map<String, dynamic>>(
                  stream: expenseDataStream,
                  builder: (context, expenseSnapshot) {
                    if (expenseSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.secondaryGreen,
                        ),
                      );
                    } else if (expenseSnapshot.hasError) {
                      return Center(
                        child: Text(
                          "An Error Occurred",
                          style: theme.textTheme.bodyLarge,
                        ),
                      );
                    } else {
                      return Column(children: [
                        SizedBox(
                            width: double.infinity,
                            height: 80,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Total Expense",
                                    style: theme.textTheme.bodyLarge),
                                Text("Rs. ${totalExpense.isEmpty ? 0.0 : totalExpense}",
                                    style: theme.textTheme.displayLarge)
                              ],
                            )),
                        const CurvedToggleButton(),
                        const ExpenseGraph(),
                        const SizedBox(height: 10),
                        Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: customTheme!.toggleButtonFillColor,
                                  width: 2),
                              color: theme.dialogTheme.backgroundColor,
                            ),
                            child: Row(children: [
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: dropDownSelect(
                                    theme,
                                    selectedBankId ?? "",
                                    userBanks.map((bank) {
                                      return DropdownMenuItem<String>(
                                          value: bank[FirebaseConstants.primaryIdField],
                                          child: Text(
                                            bank['name'],
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.bodyLarge!
                                                .copyWith(
                                              color: theme
                                                  .textTheme.bodyLarge!.color,
                                            ),
                                          ));
                                    }).toList(),
                                    (value) {
                                      if (value == AppConstants.allItem) return;
                                      _changeBank(value!);
                                    },
                                  ),
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: customTheme.toggleButtonFillColor,
                              ),
                              Expanded(
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 8),
                                  child: dropDownSelect(
                                    theme,
                                    selectedSalaryItem.isEmpty &&
                                            salaryData.isNotEmpty
                                        ? salaryData.first[FirebaseConstants.primaryIdField]
                                        : selectedSalaryItem,
                                    salaryData.map((salary) {
                                      final salaryId =
                                          salary[FirebaseConstants.primaryIdField]; // use doc ID as value
                                      final displayAmount =
                                          salary[FirebaseConstants.totalAmountField] ?? 0;

                                      return DropdownMenuItem<String>(
                                        value: salaryId,
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                displayAmount !=
                                                        AppConstants.allItem
                                                    ? "₹${salary[FirebaseConstants.totalAmountField]}"
                                                    : displayAmount,
                                                overflow: TextOverflow.ellipsis,
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                    (value) {
                                      if (value == null) return;

                                      setState(() {
                                        selectedSalaryItem = value;
                                      });
                                      _updateSalaryStream(value);
                                    },
                                  ),
                                ),
                              ),
                            ]))
                      ]);
                    }
                  }))),
    );
  }
}
