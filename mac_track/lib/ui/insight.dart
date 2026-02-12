import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/curved_toggle_button.dart';
import 'package:provider/provider.dart';
import '../components/common_app_bar.dart';
import '../components/graph.dart';
import '../components/navbar.dart';
import '../components/theme_manager.dart';
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
            'documentId': documentId,
          });

          if (isPrimary == true) {
            primaryBankId = bankId;
          }
        }
      }

      updatedUserBanks.add({
        'id': AppConstants.allItem,
        'name': AppConstants.allItem,
        'image': '',
        'isPrimary': false,
        'documentId': '',
      });

      setState(() {
        userBanks = updatedUserBanks;

        // Ensure the selectedBankId exists in userBanks, else set it to primaryBankId
        final existingBankIds = updatedUserBanks.map((b) => b['id']).toList();
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
    final data = await firebaseService
        .streamGetAllDataForReport(email, FirebaseConstants.salaryCollection)
        .first;

    final filtered = data.entries
        .where((entry) =>
            entry.value[FirebaseConstants.bankIdField] == selectedBankId)
        .toList();

    filtered.sort((a, b) {
      final aTime = a.value[FirebaseConstants.timestampField]?.toDate();
      final bTime = b.value[FirebaseConstants.timestampField]?.toDate();
      return bTime.compareTo(aTime);
    });

    salaryData = filtered
        .map((e) => {...(e.value as Map<String, dynamic>), 'id': e.key})
        .toList();

    // Add "All" item last in the list
    salaryData.add({
      'id': AppConstants.allItem,
      FirebaseConstants.bankIdField: AppConstants.allItem,
      FirebaseConstants.currentAmountField: AppConstants.allItem,
      FirebaseConstants.timestampField: '',
      FirebaseConstants.totalAmountField: 0.0
    });

    // Use the newly passed value if available
    selectedSalaryItem = selectedValue ?? selectedSalaryItem;

    final isSelectedSalaryValid =
        salaryData.any((entry) => entry['id'] == selectedSalaryItem);

    if (!isSelectedSalaryValid) {
      selectedSalaryItem = salaryData.isNotEmpty ? salaryData.first['id'] : "";
    }

    if (selectedSalaryItem != AppConstants.allItem && salaryData.isNotEmpty) {
      final selected = salaryData.firstWhere(
        (e) => e['id'] == selectedSalaryItem,
        orElse: () => salaryData.first,
      );

      setState(() {
        currentBalance = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(selected[FirebaseConstants.currentAmountField]);
      });

      _updateExpenseStream(selectedBankId!, selectedSalaryItem);
    } else {
      // Exclude "All" item from totalSalary calculation
      double totalSalary = 0;
      for (var entry in salaryData) {
        if (entry['id'] != AppConstants.allItem) {
          // Skip "All" item
          totalSalary += (entry[FirebaseConstants.currentAmountField] ?? 0.0);
        }
      }

      setState(() {
        currentBalance = NumberFormat.currency(
          locale: 'en_IN',
          symbol: '₹',
          decimalDigits: 0,
        ).format(totalSalary);
      });

      _updateExpenseStream(selectedBankId!);
    }

    setState(() {});
  }

  void _updateExpenseStream(String bankId, [String? salaryId]) {

    expenseDataStream = firebaseService
        .streamGetAllData(userEmail, FirebaseConstants.expenseCollection)
        .map((expenseData) {

      final filteredExpenses = expenseData.entries
          .where((entry) {
            final data = entry.value;
            final matchesBank = data[FirebaseConstants.bankIdField] == bankId;
            final matchesSalary = salaryId == null ||
                data[FirebaseConstants.salaryDocumentIdField] == salaryId;
            return matchesBank && matchesSalary;
          })
          .map((e) => MapEntry(e.key, e.value))
          .toList();

          // Calculate the total expenses for the filtered list
          double totalExpenseAmount = 0;
          for (var entry in filteredExpenses) {
            if (entry.value[FirebaseConstants.transactionTypeField] != AppConstants.transactionTypeDeposit) 
            {
              totalExpenseAmount += (entry.value[FirebaseConstants.amountField] ?? 0.0);
            }
          }

          setState(() {
            totalExpense = NumberFormat.currency(
              locale: 'en_IN',
              symbol: '₹',
              decimalDigits: 0,
            ).format(totalExpenseAmount);
          });

      return Map.fromEntries(filteredExpenses);
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
      drawer: const NavBar(),
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
                                          value: bank['id'],
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
                                        ? salaryData.first['id']
                                        : selectedSalaryItem,
                                    salaryData.map((salary) {
                                      final salaryId =
                                          salary['id']; // use doc ID as value
                                      final displayAmount = salary[
                                              FirebaseConstants
                                                  .currentAmountField] ??
                                          0;

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
