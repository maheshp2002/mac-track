import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/set_reminder.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/ui/dialogues/add_bank.dart';
import 'package:mac_track/ui/dialogues/add_salary.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:mac_track/ui/widgets/filter_container.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import '../components/common_app_bar.dart';
import '../components/full_screen_modal.dart';
import '../components/list_card.dart';
import '../components/navbar.dart';
import '../components/slide_in_animation.dart';
import '../components/theme_manager.dart';
import '../components/toast.dart';
import '../services/firebase_service.dart';
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
  final firebaseService = FirebaseService();
  StreamSubscription<Map<String, dynamic>>? _userBankSubscription;

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

    // CANCEL OLD LISTENER BEFORE CREATING A NEW ONE
    _userBankSubscription?.cancel();

    // STORE SUBSCRIPTION SO IT CAN BE DISPOSED
    _userBankSubscription = userBankDataStream.listen((userBankData) async {
      if (!mounted) return;

      // Fetch master banks ONCE per update
      final masterBanks = await bankDataStream.first;
      if (!mounted) return;

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

      // Add "Add Bank" button
      updatedUserBanks.add({
        'id': 'add',
        'name': AppConstants.addNewBankLabel,
        'image': '',
        'isPrimary': false,
        'documentId': '',
      });

      setState(() {
        userBanks = updatedUserBanks;

        final existingBankIds = updatedUserBanks.map((b) => b['id']).toList();

        if (!existingBankIds.contains(selectedBankId)) {
          selectedBankId = primaryBankId;
        }

        if (selectedBankId != null) {
          _changeBank(selectedBankId!);
        }
      });

      if (callback != null) callback();
    });
  }

  void _updateSalaryStream() async {
    final email = FirebaseAuth.instance.currentUser!.email!;
    final stream = firebaseService.streamGetAllData(
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

      return Map.fromEntries(filteredExpenses);
    });
  }

  void _changeBank(String bankId) {
    setState(() {
      selectedBankId = bankId;
      _updateSalaryStream();
    });
  }

  void _showAddBankDialog() async {
    var response = await showDialog(
      context: context,
      builder: (BuildContext context) => AddBankDialog(
        userBanks: userBanks,
      ),
    );
    if (response == "Add") {
      _initializeUser();
    }
  }

  Future<void> _openManageBankDialog(ThemeData theme) async {
    bool isUpdating = false;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return CommonDialog(
          title: 'Manage Bank',
          height: 300,
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setStateDialog) {
              void refreshDialogBanks() {
                setStateDialog(() {});
              }

              final filteredBanks =
                  userBanks.where((bank) => bank['id'] != 'add').toList();

              return Stack(
                children: [
                  ListView.builder(
                    itemCount: filteredBanks.length,
                    itemBuilder: (context, index) {
                      final entry = filteredBanks[index];
                      final image = entry['image'] ?? '';
                      final name = entry['name'] ?? '';
                      final bool isPrimary = entry['isPrimary'] == true;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Slidable(
                          key: ValueKey(entry['documentId']),
                          endActionPane: ActionPane(
                            motion: const DrawerMotion(),
                            extentRatio: 0.3,
                            children: [
                              SlidableAction(
                                backgroundColor: AppColors.danger,
                                foregroundColor: AppColors.white,
                                icon: Icons.delete,
                                label: 'Delete',
                                onPressed: (_) async {
                                  final int totalBanks = filteredBanks.length;

                                  /// ❌ Primary bank delete not allowed
                                  if (isPrimary && totalBanks > 1) {
                                    showDialog(
                                      context: context,
                                      builder: (ctx) => CommonDialog(
                                        title: 'Action Not Allowed',
                                        body: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Icon(
                                              FontAwesomeIcons
                                                  .triangleExclamation,
                                              color: AppColors.amber,
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                'You cannot delete the primary bank while other banks exist. '
                                                'Please make another bank primary first.',
                                                style:
                                                    theme.textTheme.bodyLarge,
                                              ),
                                            ),
                                          ],
                                        ),
                                        primaryActionText: 'OK',
                                        cancelText: null,
                                        onPrimaryAction: () =>
                                            Navigator.of(ctx).pop(),
                                      ),
                                    );
                                    return;
                                  }

                                  /// Confirm delete
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => CommonDialog(
                                      title: 'Delete Bank',
                                      body: Text(
                                        'Are you sure you want to delete this bank and all related salary and expenses?',
                                        style: theme.textTheme.bodyLarge,
                                      ),
                                      primaryActionText: 'Delete',
                                      onPrimaryAction: () async {
                                        Navigator.of(ctx).pop();

                                        final String bankName = entry['name'];

                                        // 1. Fetch salaries
                                        final salarySnapshot =
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(userEmail)
                                                .collection(FirebaseConstants
                                                    .salaryCollection)
                                                .get();

                                        final salaryDocs =
                                            salarySnapshot.docs.where((doc) {
                                          return doc.data()['bankId'] ==
                                              bankName;
                                        }).toList();

                                        // 2. Fetch expenses
                                        final expenseSnapshot =
                                            await FirebaseFirestore.instance
                                                .collection('users')
                                                .doc(userEmail)
                                                .collection(FirebaseConstants
                                                    .expenseCollection)
                                                .get();

                                        for (final salaryDoc in salaryDocs) {
                                          for (final expenseDoc
                                              in expenseSnapshot.docs) {
                                            final data = expenseDoc.data();
                                            if (data['bankId'] == bankName &&
                                                data['salaryDocumentId'] ==
                                                    salaryDoc.id) {
                                              await firebaseService
                                                  .deleteExpenseData(
                                                userEmail,
                                                expenseDoc.id,
                                                FirebaseConstants
                                                    .expenseCollection,
                                              );
                                            }
                                          }

                                          await firebaseService
                                              .deleteExpenseData(
                                            userEmail,
                                            salaryDoc.id,
                                            FirebaseConstants.salaryCollection,
                                          );
                                        }

                                        await firebaseService.deleteExpenseData(
                                          userEmail,
                                          entry['documentId'],
                                          FirebaseConstants.userBankCollection,
                                        );

                                        _initializeUser(
                                          callback: refreshDialogBanks,
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                          child: ListTile(
                            minLeadingWidth: 40,
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 8),
                            leading: image.toString().startsWith('http')
                                ? Image.network(image, width: 40, height: 40)
                                : const Icon(Icons.account_balance),
                            title: Text(
                              name,
                              style: theme.textTheme.titleLarge,
                            ),
                            trailing: IconButton(
                              icon: isPrimary
                                  ? Text("Primary",
                                      style: theme.textTheme.bodySmall!
                                          .copyWith(
                                              color:
                                                  AppColors.filterButtonGreen))
                                  : Text(
                                      "Make primary",
                                      style: theme.textTheme.bodySmall!
                                          .copyWith(
                                              color: AppColors.gradientEnd),
                                    ),
                              onPressed: isUpdating
                                  ? null
                                  : () async {
                                      if (filteredBanks.length <= 1) {
                                        showToast(
                                          'Cannot remove primary when only one bank exists',
                                        );
                                        return;
                                      }

                                      setStateDialog(() {
                                        isUpdating = true;
                                      });

                                      for (final bank in filteredBanks) {
                                        if (bank['isPrimary'] == true) {
                                          await firebaseService
                                              .updateDocumentFieldString(
                                            userEmail,
                                            FirebaseConstants
                                                .userBankCollection,
                                            bank['documentId'],
                                            FirebaseConstants.isPrimaryField,
                                            false,
                                          );
                                          bank['isPrimary'] = false;
                                        }
                                      }

                                      await firebaseService
                                          .updateDocumentFieldString(
                                        userEmail,
                                        FirebaseConstants.userBankCollection,
                                        entry['documentId'],
                                        FirebaseConstants.isPrimaryField,
                                        true,
                                      );

                                      setStateDialog(() {
                                        entry['isPrimary'] = true;
                                        isUpdating = false;
                                      });

                                      _initializeUser(
                                        callback: refreshDialogBanks,
                                      );
                                    },
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  /// Blocking loader
                  if (isUpdating)
                    Container(
                      color: Colors.black.withValues(alpha: 0.3),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _showBankSelectionDialog(ThemeData theme) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return CommonDialog(
              title: 'Select Bank',
              height: 120,
              body: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'Banks',
                      labelStyle: theme.textTheme.labelSmall,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.secondary),
                      ),
                    ),
                    dropdownColor: theme.scaffoldBackgroundColor,
                    initialValue: selectedBankId ?? 'add',
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
                                color:
                                    bank['name'] == AppConstants.addNewBankLabel
                                        ? AppColors.primaryGreen
                                        : theme.textTheme.bodyLarge!.color,
                              ),
                            ),
                            if (bank['name'] == AppConstants.addNewBankLabel)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(
                                  FeatherIcons.arrowUpRight,
                                  color: AppColors.primaryGreen,
                                  size: 16,
                                ),
                              ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value == 'add') {
                        Navigator.of(context).pop();
                        _showAddBankDialog();
                      } else if (value != null) {
                        Navigator.of(context).pop();
                        _changeBank(value);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    splashColor: AppColors.secondaryGreen,
                    onTap: () {
                      Navigator.of(context).pop();
                      _openManageBankDialog(theme);
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Text(
                          'Manage Banks',
                          style: theme.textTheme.bodyLarge!.copyWith(
                            color: AppColors.primaryGreen,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          FeatherIcons.arrowUpRight,
                          color: AppColors.primaryGreen,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _onDeleteExpense(String expenseId) async {
    // Get the signed-in user's email
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      showToast('User not signed in.');
      return;
    }
    final userEmail = user.email!;

    try {
      await firebaseService.deleteExpenseWithSalaryUpdate(
        userEmail: userEmail,
        expenseDocumentId: expenseId,
      );
      _updateSalaryStream();
    } on StateError catch (e) {
      showToast(e.message.toString());
    } catch (_) {
      showToast('Failed to delete expense. Please try again.');
    }
  }

  showAlertDialog(BuildContext context, ThemeData theme, String title,
      String message, String buttonLabel, VoidCallback submit) {
    // set up the AlertDialog
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
    final fallbackBank = {
      'image': 'assets/logo/black.png',
      'name': 'Select Bank',
    };

    final selectedBank = userBanks.firstWhere(
      (bank) => bank['id'] == selectedBankId,
      orElse: () => fallbackBank,
    );

    final imagePath = selectedBank['image'] ?? '';
    final isNetworkImage = imagePath.toString().startsWith('http');

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
                      isNetworkImage
                          ? Image.network(imagePath, width: 24, height: 24)
                          : Image.asset(imagePath, width: 24, height: 24),
                      const SizedBox(width: 8),
                      Text(
                        selectedBank['name'] ?? 'Select Bank',
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
                        builder: (BuildContext context) => AddSalaryDialog(
                          email: userEmail,
                          onSalaryUpdated: _updateSalaryStream,
                        ),
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
            Text(
              _currentToggleIndex == 0 ? "Your Balance" : "Salary Balance",
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
  void dispose() {
    _userBankSubscription?.cancel();
    super.dispose();
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
                                        icon: FontAwesomeIcons.pencil,
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
                                              () =>
                                                  _onDeleteExpense(entry.key));
                                        },
                                        backgroundColor: AppColors.danger,
                                        foregroundColor: AppColors.white,
                                        icon: FontAwesomeIcons.trash,
                                        label: 'Delete',
                                      ),
                                      SlidableAction(
                                        onPressed: (_) {
                                          showDialog(
                                            context: context,
                                            builder: (_) => SetReminderDialog(
                                              documentId: expense[
                                                  FirebaseConstants
                                                      .salaryDocumentIdField],
                                              reminderName: expense[
                                                  FirebaseConstants
                                                      .expenseCategoryField],
                                            ),
                                          );
                                        },
                                        backgroundColor: AppColors.amber,
                                        foregroundColor: AppColors.white,
                                        icon: FontAwesomeIcons.clock,
                                        label: 'Reminder',
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
