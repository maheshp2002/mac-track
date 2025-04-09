import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/config/constants.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'components/commonAppBar.dart';
import 'components/fullScreenModal.dart';
import 'components/listCard.dart';
import 'components/navbar.dart';
import 'components/slideInAnimation.dart';
import 'components/themeManager.dart';
import 'components/toast.dart';
import 'services/firebaseService.dart';
import 'theme.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  int _currentToggleIndex = 0;
  late Stream<Map<String, dynamic>> expenseDataStream = Stream.value({});
  late Stream<Map<String, dynamic>> bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  late Stream<Map<String, dynamic>> expenseTypesStream;
  late Stream<Map<String, dynamic>> salaryDataStream = Stream.value({});
  List<Map<String, dynamic>> userBanks = [];
  String? selectedBankId;
  String userEmail = "";
  String currentBalance = "";
  String? _selectedFilterType;

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
    expenseTypesStream = FirebaseService().streamExpenseTypes();
  }

  void _initializeUser() async {
    bankDataStream = FirebaseService().streamBankData();

    userBankDataStream = FirebaseService()
        .streamGetAllData(userEmail, FirebaseConstants.userBankCollection);

    userBankDataStream.listen((userBankData) async {
      // Fetch all banks from the master collection
      Map<String, dynamic> masterBanks = await bankDataStream.first;

      List<Map<String, dynamic>> updatedUserBanks = [];
      String? primaryBankId;

      userBankData.entries.forEach((entry) {
        final bankId = entry.value[FirebaseConstants.bankIdField];
        final isPrimary = entry.value['isPrimary'];
        final bankDetails = masterBanks[bankId];

        if (bankDetails != null) {
          updatedUserBanks.add({
            'id': bankId,
            'name': bankDetails['name'],
            'image': bankDetails['image'],
            'isPrimary': isPrimary,
          });

          // Identify the primary bank ID
          if (isPrimary == true) {
            primaryBankId = bankId;
          }
        }
      });

      // Add the default option to add a new bank
      updatedUserBanks.add({
        'id': 'add',
        'name': AppConstants.addNewBankLabel,
        'image': '',
        'isPrimary': false
      });

      setState(() {
        userBanks = updatedUserBanks;

        // If there is a primary bank, change it
        if (primaryBankId != null && primaryBankId!.isNotEmpty) {
          _changeBank(primaryBankId!);
        }
      });
    });
  }

  void _updateSalaryStream() async {
    final email = FirebaseAuth.instance.currentUser!.email!;
    final stream = FirebaseService().streamGetAllData(
      email,
      FirebaseConstants.salaryCollection,
    );

    if (_currentToggleIndex != 0) {
      // Balance view – only show latest salary and its expenses
      stream.first.then((data) {
        final filtered = data.values
            .where(
                (doc) => doc[FirebaseConstants.bankIdField] == selectedBankId)
            .toList();

        filtered.sort((a, b) {
          final aTime = a[FirebaseConstants.timestampField]?.toDate();
          final bTime = b[FirebaseConstants.timestampField]?.toDate();
          return bTime.compareTo(aTime);
        });

        final latestSalary = filtered.isNotEmpty ? filtered.first : null;

        if (latestSalary != null) {
          final latestSalaryId = data.entries
              .firstWhere((entry) => entry.value == latestSalary)
              .key;

          _updateExpenseStream(selectedBankId!, latestSalaryId);
          // Update salaryDataStream for UI
          salaryDataStream = Stream.value(latestSalary);
        } else {
          // fallback
          salaryDataStream = Stream.value({});
        }
        setState(() {});
      });
    } else {
      // Transaction view – show all salaries + all expenses
      salaryDataStream = stream.map((data) {
        final filtered = data.values
            .where(
                (doc) => doc[FirebaseConstants.bankIdField] == selectedBankId)
            .toList();

        double totalSalary = 0;
        for (var entry in filtered) {
          totalSalary += (entry[FirebaseConstants.currentAmountField] ?? 0.0);
        }

        setState(() {
          currentBalance = NumberFormat.currency(
            locale: 'en_IN',
            symbol: '₹',
            decimalDigits: 0,
          ).format(totalSalary);
        });

        _updateExpenseStream(selectedBankId!);
        return {};
      });
    }
  }

  void _updateExpenseStream(String bankId, [String? salaryId]) {
    expenseDataStream = FirebaseService()
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

      return Map.fromEntries(filteredExpenses);
    });
  }

  void _changeBank(String bankId) {
    setState(() {
      selectedBankId = bankId;
      _updateSalaryStream();
    });
  }

  void _showAddBankDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AddBankDialog(
        userBanks: userBanks,
      ),
    );
  }

  void _showBankSelectionDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Select Bank',
            style: theme.textTheme.displayMedium,
          ),
          content: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Banks',
                labelStyle: theme.textTheme.labelSmall,
                border: const OutlineInputBorder(),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.secondary),
                ),
              ),
              dropdownColor: theme.scaffoldBackgroundColor,
              value: selectedBankId ?? 'add',
              hint: const Text('Select Bank'),
              icon: Icon(
                FontAwesomeIcons.caretDown,
                color: theme.iconTheme.color,
              ),
              items: userBanks.map((bank) {
                return DropdownMenuItem<String>(
                  value: bank['id'],
                  child: Row(
                    children: [
                      Text(
                        bank['name'],
                        style: theme.textTheme.bodyLarge!.copyWith(
                          color: bank['name'] == AppConstants.addNewBankLabel
                              ? AppColors.primaryGreen
                              : theme.textTheme.bodyLarge!.color,
                        ),
                      ),
                      bank['name'] == AppConstants.addNewBankLabel
                          ? const Icon(
                              FeatherIcons.arrowUpRight,
                              color: AppColors.primaryGreen,
                            )
                          : const SizedBox()
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value == 'add') {
                  Navigator.pop(context);
                  _showAddBankDialog();
                } else if (value != null) {
                  Navigator.pop(context);
                  _changeBank(value);
                }
              }),
        );
      },
    );
  }

  void _onDeleteExpense(String expenseId, String salaryId,
      String transactionType, double expenseAmount) async {
    print("Deleting expense: $expenseId");

    // Get the signed-in user's email
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      showToast('User not signed in.');
      return;
    }
    String userEmail = user.email!;

    // Fetch current salary document
    final salaryDoc = await FirebaseService()
        .streamGetDataInUserById(
          userEmail,
          FirebaseConstants.salaryCollection,
          salaryId,
        )
        .first;

    double currentAmount =
        salaryDoc[FirebaseConstants.currentAmountField] ?? 0.0;

    // Adjust the salary amount based on the expense being deleted
    if (transactionType == AppConstants.transactionTypeWithdraw ||
        transactionType == AppConstants.transactionTypeTransfer) {
      currentAmount += expenseAmount; // refund
    } else if (transactionType == AppConstants.transactionTypeDeposit) {
      currentAmount -= expenseAmount; // remove deposited amount
    }

    // Update the salary document
    await FirebaseService().updateSalaryAmount(
      userEmail,
      salaryId,
      currentAmount,
    );

    // Delete the expense document
    await FirebaseService().deleteExpenseData(
      userEmail,
      expenseId,
      FirebaseConstants.expenseCollection,
    );

    _updateSalaryStream();
  }

  showAlertDialog(BuildContext context, ThemeData theme, String title,
      String message, String buttonLabel, VoidCallback submit) {
    // set up the AlertDialog
    AlertDialog alert = AlertDialog(
      title: Text(
        title,
        style: theme.textTheme.headlineLarge,
      ),
      backgroundColor: theme.dialogBackgroundColor,
      content: Text(message, style: theme.textTheme.bodyLarge),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, 'Cancel'),
          child: Text(
            'Cancel',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            submit();
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryGreen,
          ),
          child: Text(
            buttonLabel,
            style: const TextStyle(color: AppColors.primaryGreen),
          ),
        ),
      ],
    );
    // show the dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  Widget _buildSalaryWidget(String formattedSalaryAmount, ThemeData theme) {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 100),
      startPosition: -0.5,
      endPosition: 0.0,
      child: Container(
        margin: const EdgeInsets.only(top: 20),
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: Colors.amber,
          borderRadius: BorderRadius.circular(16.0),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    _showBankSelectionDialog(theme);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.all(10),
                    textStyle: const TextStyle(fontSize: 16),
                    backgroundColor: const Color.fromARGB(96, 255, 251, 241),
                  ).copyWith(
                    shape: WidgetStateProperty.all(
                      RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100.0),
                      ),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      selectedBankId != null
                          ? Image.network(
                              userBanks.firstWhere(
                                  (bank) => bank['id'] == selectedBankId,
                                  orElse: () => {
                                        'image': 'assets/logo/black.png'
                                      })['image'],
                              width: 24,
                              height: 24,
                            )
                          : const SizedBox(width: 24, height: 24),
                      const SizedBox(width: 8),
                      Text(
                        userBanks.firstWhere(
                                (bank) => bank['id'] == selectedBankId,
                                orElse: () =>
                                    {'name': 'Select Bank'})['name'] ??
                            'Select Bank',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(96, 255, 251, 241),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      FontAwesomeIcons.ellipsis,
                      color: Colors.white,
                    ),
                    onPressed: () async {
                      final result = await showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            const AddSalaryDialog(),
                      );

                      if (result == AppConstants.refresh) {
                        _updateSalaryStream();
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            const Text(
              "Your Balance",
              style: AppTextStyles.bodyText,
            ),
            Text(
              formattedSalaryAmount,
              style: AppTextStyles.headline,
            ),
          ],
        ),
      ),
    );
  }

  String formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;
    final theme = Theme.of(context);
    final customTheme = theme.extension<AppThemeExtension>();
    Color iconColor = customTheme!.toggleButtonTextColor;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: const CommonAppBar(
        title: 'MacTrack',
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          String result = await openFullScreenModal(context, null, null);

          if (result == AppConstants.refresh) {
            _updateSalaryStream();
          }
        },
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        backgroundColor: AppColors.secondaryGreen,
        child: const Icon(
          FontAwesomeIcons.plus,
          color: AppColors.backgroundLight,
        ),
      ),
      drawer: const NavBar(),
      body: Container(
          decoration: AppTheme.getBackgroundDecoration(themeMode),
          padding: const EdgeInsets.only(top: kToolbarHeight + 50),
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  SlideInAnimation(
                    delay: const Duration(milliseconds: 150),
                    startPosition: -1.0,
                    endPosition: 0.0,
                    child: Center(
                      child: ToggleSwitch(
                        minWidth: 100.0,
                        cornerRadius: 20.0,
                        activeBgColors: [
                          [customTheme.toggleButtonFillColor],
                          [customTheme.toggleButtonFillColor],
                        ],
                        activeFgColor: customTheme.toggleButtonSelectedColor,
                        inactiveBgColor:
                            customTheme.toggleButtonBackgroundColor,
                        inactiveFgColor: customTheme.toggleButtonTextColor,
                        initialLabelIndex: _currentToggleIndex,
                        totalSwitches: 2,
                        labels: _currentToggleIndex == 0
                            ? ['Transaction', '']
                            : ['', 'Balance'],
                        customIcons: [
                          _currentToggleIndex == 0
                              ? null
                              : Icon(
                                  FontAwesomeIcons.rightLeft,
                                  color: iconColor,
                                  size: 20,
                                ),
                          _currentToggleIndex == 1
                              ? null
                              : Icon(
                                  FontAwesomeIcons.indianRupeeSign,
                                  color: iconColor,
                                  size: 20,
                                ),
                        ],
                        radiusStyle: true,
                        onToggle: (index) {
                          setState(() {
                            _currentToggleIndex = index!;
                            _updateSalaryStream();
                          });
                        },
                      ),
                    ),
                  ),
                  StreamBuilder<Map<String, dynamic>>(
                    stream: bankDataStream,
                    builder: (context, bankSnapshot) {
                      if (bankSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: AppColors.secondaryGreen,
                          ),
                        );
                      } else if (bankSnapshot.hasError) {
                        return Center(
                          child: Text(
                            "An Error Occurred",
                            style: theme.textTheme.bodyLarge,
                          ),
                        );
                      } else if (!bankSnapshot.hasData ||
                          bankSnapshot.data!.isEmpty) {
                        return Center(
                          child: Text(
                            "No bank data available.",
                            style: theme.textTheme.bodyLarge,
                          ),
                        );
                      } else {
                        return Column(
                          children: [
                            if (_currentToggleIndex == 0)
                              StreamBuilder<Map<String, dynamic>>(
                                stream: salaryDataStream,
                                builder: (context, snapshot) {
                                  return _buildSalaryWidget(
                                      currentBalance, theme);
                                },
                              )
                            else
                              StreamBuilder<Map<String, dynamic>>(
                                stream: salaryDataStream,
                                builder: (context, salarySnapshot) {
                                  if (salarySnapshot.connectionState ==
                                      ConnectionState.waiting) {
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
                                    return _buildSalaryWidget('₹0', theme);
                                  } else {
                                    final latestSalaryDoc =
                                        salarySnapshot.data!;
                                    final latestSalaryAmount = latestSalaryDoc[
                                        FirebaseConstants.currentAmountField];

                                    final formattedSalaryAmount =
                                        NumberFormat.currency(
                                      locale: 'en_IN',
                                      symbol: '₹',
                                      decimalDigits: 0,
                                    ).format(latestSalaryAmount);

                                    return _buildSalaryWidget(
                                        formattedSalaryAmount, theme);
                                  }
                                },
                              ),
                            const SizedBox(height: 10),
                            SlideInAnimation(
                              delay: const Duration(milliseconds: 100),
                              startPosition: -0.5,
                              endPosition: 0.0,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final containerWidth =
                                      (constraints.maxWidth - 32) /
                                          3; // subtracting total spacing

                                  return Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      SizedBox(
                                        width: containerWidth,
                                        child: FilterContainer(
                                          icon: FeatherIcons.arrowDownLeft,
                                          text: AppConstants
                                              .transactionTypeDeposit,
                                          color: _selectedFilterType ==
                                                      AppConstants
                                                          .transactionTypeDeposit ||
                                                  _selectedFilterType == null
                                              ? AppColors.filterButtonBlack
                                              : const Color(0xFF595A69),
                                          onTap: () {
                                            if (_selectedFilterType ==
                                                AppConstants
                                                    .transactionTypeDeposit) {
                                              setState(() {
                                                _selectedFilterType = null;
                                              });
                                            } else {
                                              setState(() {
                                                _selectedFilterType =
                                                    AppConstants
                                                        .transactionTypeDeposit;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: containerWidth,
                                        child: FilterContainer(
                                          icon: FeatherIcons.arrowUpRight,
                                          text: AppConstants
                                              .transactionTypeWithdraw,
                                          color: _selectedFilterType ==
                                                      AppConstants
                                                          .transactionTypeWithdraw ||
                                                  _selectedFilterType == null
                                              ? AppColors.purple
                                              : const Color(0xFFA783AE),
                                          onTap: () {
                                            if (_selectedFilterType ==
                                                AppConstants
                                                    .transactionTypeWithdraw) {
                                              setState(() {
                                                _selectedFilterType = null;
                                              });
                                            } else {
                                              setState(() {
                                                _selectedFilterType =
                                                    AppConstants
                                                        .transactionTypeWithdraw;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                      SizedBox(
                                        width: containerWidth,
                                        child: FilterContainer(
                                          icon: FeatherIcons.arrowUp,
                                          text: AppConstants
                                              .transactionTypeTransfer,
                                          color: _selectedFilterType ==
                                                      AppConstants
                                                          .transactionTypeTransfer ||
                                                  _selectedFilterType == null
                                              ? AppColors.filterButtonGreen
                                              : const Color(0xFF82B387),
                                          onTap: () {
                                            if (_selectedFilterType ==
                                                AppConstants
                                                    .transactionTypeTransfer) {
                                              setState(() {
                                                _selectedFilterType = null;
                                              });
                                            } else {
                                              setState(() {
                                                _selectedFilterType =
                                                    AppConstants
                                                        .transactionTypeTransfer;
                                              });
                                            }
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                            const SizedBox(
                              height: 20,
                            ),
                            Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Transactions",
                                  style: theme.textTheme.headlineLarge,
                                  textAlign: TextAlign.start,
                                )),
                          ],
                        );
                      }
                    },
                  ),
                ],
              ),
            ),
            Flexible(
                fit: FlexFit.loose,
                child: SlideInAnimation(
                  delay: const Duration(milliseconds: 100),
                  startPosition: -0.5,
                  endPosition: 0.0,
                  child: StreamBuilder<Map<String, dynamic>>(
                    stream: expenseDataStream,
                    builder: (context, expenseSnapshot) {
                      if (!expenseSnapshot.hasData) {
                        return const CircularProgressIndicator(
                          color: AppColors.secondaryGreen,
                        );
                      }

                      final expenseData = expenseSnapshot.data!;

                      return StreamBuilder<Map<String, dynamic>>(
                        stream: expenseTypesStream,
                        builder: (context, typeSnapshot) {
                          if (!typeSnapshot.hasData) {
                            return const SizedBox();
                          }

                          final expenseTypes = typeSnapshot.data!;

                          return ListView(
                            padding: EdgeInsets.zero,
                            children: (expenseData.entries.where((entry) {
                              if (_selectedFilterType == null) return true;
                              return entry.value[
                                      FirebaseConstants.transactionTypeField] ==
                                  _selectedFilterType;
                            }).toList()
                                  ..sort((a, b) {
                                    final tsA = a.value[FirebaseConstants
                                        .timestampField] as Timestamp;
                                    final tsB = b.value[FirebaseConstants
                                        .timestampField] as Timestamp;
                                    return tsB.compareTo(tsA); // Newest first
                                  }))
                                .map((entry) {
                              final expense = entry.value;
                              final categoryId = expense[
                                  FirebaseConstants.expenseCategoryField];
                              final categoryInfo = expenseTypes[categoryId];
                              final categoryImage = categoryInfo?['image'] ??
                                  'assets/images/other-expenses.png';

                              return Slidable(
                                  key: ValueKey(entry
                                      .key), // Make sure each slidable has a unique key
                                  endActionPane: ActionPane(
                                    motion:
                                        const DrawerMotion(), // You can use other motions too
                                    extentRatio:
                                        0.4, // Adjust how much space the actions take
                                    children: [
                                      SlidableAction(
                                        onPressed: (_) {
                                          // Implement your edit logic
                                          openFullScreenModal(
                                              context, entry.key, expense);
                                        },
                                        backgroundColor:
                                            AppColors.secondaryGreen,
                                        foregroundColor: Colors.white,
                                        icon: Icons.edit,
                                        label: 'Edit',
                                      ),
                                      SlidableAction(
                                        onPressed: (_) {
                                          showAlertDialog(
                                              context,
                                              Theme.of(context),
                                              'Delete Expense',
                                              'Are you sure you want to delete this expense?',
                                              'Delete',
                                              () => _onDeleteExpense(
                                                  entry.key,
                                                  expense[FirebaseConstants
                                                      .salaryDocumentIdField],
                                                  expense[FirebaseConstants
                                                      .transactionTypeField],
                                                  expense[FirebaseConstants
                                                      .amountField]));
                                        },
                                        backgroundColor: AppColors.danger,
                                        foregroundColor: AppColors.white,
                                        icon: Icons.delete,
                                        label: 'Delete',
                                      ),
                                    ],
                                  ),
                                  child: ListCard(
                                    image: categoryImage,
                                    title: expense[
                                            FirebaseConstants.expenseField] ??
                                        '',
                                    subTitle: Row(children: [
                                      Text(
                                        expense[FirebaseConstants
                                                .transactionTypeField] ??
                                            '',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                      expense[FirebaseConstants
                                                  .transactionTypeField] ==
                                              AppConstants
                                                  .transactionTypeDeposit
                                          ? const Icon(
                                              FeatherIcons.arrowDownLeft,
                                              color:
                                                  AppColors.filterButtonGreen)
                                          : expense[FirebaseConstants
                                                      .transactionTypeField] ==
                                                  AppConstants
                                                      .transactionTypeWithdraw
                                              ? const Icon(
                                                  FeatherIcons.arrowUpRight,
                                                  color: AppColors.danger)
                                              : const Icon(FeatherIcons.arrowUp,
                                                  color: AppColors.danger)
                                    ]),
                                    suffix:
                                        '₹${expense[FirebaseConstants.amountField]}',
                                    footer: Text(
                                        formatTimestamp(expense[
                                            FirebaseConstants.timestampField]),
                                        style: TextStyle(
                                            fontSize: theme
                                                .textTheme.labelSmall?.fontSize,
                                            color: themeMode == ThemeMode.dark
                                                ? AppColors.white70
                                                : AppColors.black87)),
                                  ));
                            }).toList(),
                          );
                        },
                      );
                    },
                  ),
                )),
          ])),
    );
  }
}

class FilterContainer extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final VoidCallback onTap;

  const FilterContainer({
    Key? key,
    required this.icon,
    required this.text,
    required this.color,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final splashColor = Color.lerp(color, Colors.white, 0.6)!;

    return Material(
      color: color,
      borderRadius: BorderRadius.circular(30.0),
      child: InkWell(
        onTap: onTap,
        splashColor: splashColor,
        highlightColor: splashColor.withOpacity(0.3),
        borderRadius: BorderRadius.circular(30.0),
        child: Container(
          width: 120,
          height: 110,
          padding: const EdgeInsets.all(15), // <-- Back in business
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment:
                MainAxisAlignment.spaceBetween, // <-- for balance
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.backgroundLight,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: AppColors.backgroundLight,
                    size: 20,
                  ),
                ),
              ),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundLight,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AddSalaryDialog extends StatefulWidget {
  const AddSalaryDialog({super.key});

  @override
  AddSalaryDialogState createState() => AddSalaryDialogState();
}

class AddSalaryDialogState extends State<AddSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _isAmountValid = true;
  late FocusNode _amountFocusNode;
  final TextEditingController _amountController = TextEditingController();
  late Stream<Map<String, dynamic>> _bankDataStream;
  String? _selectedBankId; // Store the selected bank's document ID

  @override
  void initState() {
    super.initState();
    _bankDataStream = FirebaseService().streamBankData();
    _amountFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _amountFocusNode.dispose();
    _amountController.dispose();
    super.dispose();
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
      await FirebaseService().addData(userEmail, documentId, expenseData,
          FirebaseConstants.salaryCollection);

      // Optionally close the modal after submitting
      Navigator.of(context).pop(AppConstants.refresh);
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

    return AlertDialog(
      title: Text(
        'Add Salary',
        style: theme.textTheme.headlineLarge,
      ),
      backgroundColor: theme.dialogBackgroundColor,
      content: SizedBox(
          height: 200,
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
                final bankData = snapshot.data!;
                return Form(
                    key: _formKey,
                    child: Column(children: [
                      Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: TextFormField(
                            controller: _amountController,
                            focusNode: _amountFocusNode,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
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
                                    : Colors.red, // Color when validation fails
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
                          )),
                      const SizedBox(height: 20),
                      Expanded(
                          child: SingleChildScrollView(
                              child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: bankData.entries
                            .map<Widget>((entry) => ChoiceChip(
                                  showCheckmark: false,
                                  avatar: Image.network(entry.value['image']),
                                  label: Text(entry.value['name']),
                                  labelStyle: TextStyle(
                                    color: _selectedBankId == entry.key
                                        ? Colors.white
                                        : theme.textTheme.bodyLarge!.color,
                                  ),
                                  selectedColor: AppColors.secondary,
                                  backgroundColor:
                                      customTheme!.chipBackgroundColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  selected: _selectedBankId ==
                                      entry.key, // Compare document ID
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedBankId = selected
                                          ? entry.key // Store document ID
                                          : null;
                                    });
                                  },
                                ))
                            .toList(),
                      )))
                    ]));
              }
            },
          )),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, 'Cancel'),
          child: Text(
            'Cancel',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryGreen,
          ),
          child: const Text(
            'Add',
            style: TextStyle(color: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }
}

class AddBankDialog extends StatefulWidget {
  final List<Map<String, dynamic>> userBanks;

  const AddBankDialog({super.key, required this.userBanks});

  @override
  AddBankDialogState createState() => AddBankDialogState();
}

class AddBankDialogState extends State<AddBankDialog> {
  final _formKey = GlobalKey<FormState>();
  late Stream<Map<String, dynamic>> _bankDataStream;
  String? _selectedBankId; // Store the selected bank's document ID
  bool _isPrimary = false;

  @override
  void initState() {
    super.initState();
    _bankDataStream = FirebaseService().streamBankData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasOnlyDefault =
          widget.userBanks.length == 1 && widget.userBanks.first['id'] == 'add';
      setState(() {
        _isPrimary = hasOnlyDefault;
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBankId != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        showToast('User not signed in.');
        return;
      }
      String userEmail = user.email ?? "";

      // Generate a unique document ID using date, time, and amount
      DateTime now = DateTime.now();
      String documentId = "${now.toIso8601String()}_$_selectedBankId";

      // Prepare the data to be stored
      Map<String, dynamic> expenseData = {
        'isPrimary': _isPrimary,
        FirebaseConstants.timestampField: now,
        FirebaseConstants.bankIdField: _selectedBankId
      };

      // Save the data to Firebase
      await FirebaseService().addData(userEmail, documentId, expenseData,
          FirebaseConstants.userBankCollection);

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

    return AlertDialog(
      title: Text(
        'Add Salary',
        style: theme.textTheme.headlineLarge,
      ),
      backgroundColor: theme.dialogBackgroundColor,
      content: SizedBox(
          height: 200,
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
                final bankData = snapshot.data!;
                return Form(
                    key: _formKey,
                    child: Column(children: [
                      if (widget.userBanks.length > 1)
                        Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: SwitchListTile(
                              inactiveTrackColor:
                                  customTheme!.chipBackgroundColor,
                              activeColor: AppColors.primaryGreen,
                              title: Text(
                                'Set as Primary Bank',
                                style: theme.textTheme.labelSmall,
                              ),
                              value: _isPrimary,
                              onChanged: (value) {
                                setState(() {
                                  _isPrimary = value;
                                });
                              },
                            )),
                      const SizedBox(height: 20),
                      Expanded(
                          child: SingleChildScrollView(
                              child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: bankData.entries
                            .map<Widget>((entry) => ChoiceChip(
                                  showCheckmark: false,
                                  avatar: Image.network(entry.value['image']),
                                  label: Text(entry.value['name']),
                                  labelStyle: TextStyle(
                                    color: _selectedBankId == entry.key
                                        ? Colors.white
                                        : theme.textTheme.bodyLarge!.color,
                                  ),
                                  selectedColor: AppColors.secondary,
                                  backgroundColor:
                                      customTheme!.chipBackgroundColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(50.0),
                                  ),
                                  selected: _selectedBankId ==
                                      entry.key, // Compare document ID
                                  onSelected: (selected) {
                                    setState(() {
                                      _selectedBankId = selected
                                          ? entry.key // Store document ID
                                          : null;
                                    });
                                  },
                                ))
                            .toList(),
                      )))
                    ]));
              }
            },
          )),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, 'Cancel'),
          child: Text(
            'Cancel',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.secondaryGreen,
          ),
          child: const Text(
            'OK',
            style: TextStyle(color: AppColors.primaryGreen),
          ),
        ),
      ],
    );
  }
}
