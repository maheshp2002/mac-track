import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/ui/components/set_reminder.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/ui/dialogues/add_bank.dart';
import 'package:mac_track/ui/dialogues/expense_details_dialog.dart';
import 'package:mac_track/ui/dialogues/manage_salary_dialog.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:mac_track/ui/widgets/filter_container.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'components/common_app_bar.dart';
import 'components/full_screen_modal.dart';
import 'components/list_card.dart';
import 'components/navbar.dart';
import 'components/slide_in_animation.dart';
import 'components/theme_manager.dart';
import 'components/toast.dart';
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
  bool _isFlipped = false;
  late Stream<Map<String, dynamic>> bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  late Stream<Map<String, dynamic>> expenseTypesStream;
  List<Map<String, dynamic>> userBanks = [];
  String? selectedBankId;
  String userEmail = "";
  String currentBalance = "";
  String? _selectedFilterType;
  bool _isSelectionMode = false;
  Set<String> _selectedExpenseIds = {};
  final firebaseService = FirebaseService();
  StreamSubscription<Map<String, dynamic>>? _userBankSubscription;
  int _bottomIndex = 0;
  bool _isSearchMode = false;
  String _searchQuery = '';
  String? _selectedCategory;
  DateTimeRange? _selectedDateRange;

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
            FirebaseConstants.imageField:
                bankDetails[FirebaseConstants.imageField],
            FirebaseConstants.isPrimaryField: isPrimary,
            FirebaseConstants.documentIdField: documentId,
          });

          if (isPrimary == true) {
            primaryBankId = bankId;
          }
        }
      }

      // Add "Add Bank" button
      updatedUserBanks.add({
        FirebaseConstants.primaryIdField: 'add',
        FirebaseConstants.nameField: AppConstants.addNewBankLabel,
        FirebaseConstants.imageField: '',
        FirebaseConstants.isPrimaryField: false,
        FirebaseConstants.documentIdField: '',
      });

      setState(() {
        userBanks = updatedUserBanks;

        final existingBankIds = updatedUserBanks
            .map((b) => b[FirebaseConstants.primaryIdField])
            .toList();

        if (!existingBankIds.contains(selectedBankId)) {
          selectedBankId = primaryBankId;
        }

        selectedBankId ??= primaryBankId;
      });

      if (callback != null) callback();
    });
  }

  void _changeBank(String bankId) {
    setState(() {
      selectedBankId = bankId;
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

              final filteredBanks = userBanks
                  .where(
                      (bank) => bank[FirebaseConstants.primaryIdField] != 'add')
                  .toList();

              return Stack(
                children: [
                  ListView.builder(
                    itemCount: filteredBanks.length,
                    itemBuilder: (context, index) {
                      final entry = filteredBanks[index];
                      final image = entry[FirebaseConstants.imageField] ?? '';
                      final name = entry[FirebaseConstants.nameField] ?? '';
                      final bool isPrimary =
                          entry[FirebaseConstants.isPrimaryField] == true;

                      return ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Slidable(
                          key: ValueKey(
                              entry[FirebaseConstants.documentIdField]),
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

                                        final String bankName =
                                            entry[FirebaseConstants.nameField];

                                        // 1. Fetch expenses
                                        final expenseSnapshot =
                                            await FirebaseFirestore.instance
                                                .collection(FirebaseConstants
                                                    .usersCollection)
                                                .doc(userEmail)
                                                .collection(FirebaseConstants
                                                    .expenseCollection)
                                                .get();

                                        for (final expenseDoc
                                            in expenseSnapshot.docs) {
                                          final data = expenseDoc.data();

                                          if (data[FirebaseConstants
                                                  .bankIdField] ==
                                              bankName) {
                                            await firebaseService
                                                .deleteExpenseData(
                                              userEmail,
                                              expenseDoc.id,
                                              FirebaseConstants
                                                  .expenseCollection,
                                            );
                                          }
                                        }

                                        await firebaseService.deleteExpenseData(
                                          userEmail,
                                          entry[FirebaseConstants
                                              .documentIdField],
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
                                        if (bank[FirebaseConstants
                                                .isPrimaryField] ==
                                            true) {
                                          await firebaseService
                                              .updateDocumentFieldString(
                                            userEmail,
                                            FirebaseConstants
                                                .userBankCollection,
                                            bank[FirebaseConstants
                                                .documentIdField],
                                            FirebaseConstants.isPrimaryField,
                                            false,
                                          );
                                          bank[FirebaseConstants
                                              .isPrimaryField] = false;
                                        }
                                      }

                                      await firebaseService
                                          .updateDocumentFieldString(
                                        userEmail,
                                        FirebaseConstants.userBankCollection,
                                        entry[
                                            FirebaseConstants.documentIdField],
                                        FirebaseConstants.isPrimaryField,
                                        true,
                                      );

                                      setStateDialog(() {
                                        entry[FirebaseConstants
                                            .isPrimaryField] = true;
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
                        value: bank[FirebaseConstants.primaryIdField],
                        child: Row(
                          children: [
                            Text(
                              bank[FirebaseConstants.nameField],
                              style: theme.textTheme.bodyLarge!.copyWith(
                                color: bank[FirebaseConstants.nameField] ==
                                        AppConstants.addNewBankLabel
                                    ? AppColors.primaryGreen
                                    : theme.textTheme.bodyLarge!.color,
                              ),
                            ),
                            if (bank[FirebaseConstants.nameField] ==
                                AppConstants.addNewBankLabel)
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
      await firebaseService.deleteExpenseData(
        userEmail,
        expenseId,
        FirebaseConstants.expenseCollection,
      );
    } on StateError catch (e) {
      showToast(e.message.toString());
    } catch (_) {
      showToast('Failed to delete expense. Please try again.');
    }
  }

  Future<void> _deleteSelectedExpenses() async {
    if (_selectedExpenseIds.isEmpty) return;
  
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      showToast('User not signed in.');
      return;
    }
  
    final userEmail = user.email!;
    final batch = FirebaseFirestore.instance.batch();
  
    for (final id in _selectedExpenseIds) {
      final docRef = FirebaseFirestore.instance
          .collection(FirebaseConstants.usersCollection)
          .doc(userEmail)
          .collection(FirebaseConstants.expenseCollection)
          .doc(id);
  
      batch.delete(docRef);
    }
  
    await batch.commit();
  
    _exitSelectionMode();
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

  Widget _buildTopRow(ThemeData theme) {
    final fallbackBank = {
      FirebaseConstants.imageField: 'assets/logo/black.png',
      FirebaseConstants.nameField: 'Select Bank',
    };

    final selectedBank = userBanks.firstWhere(
      (bank) => bank[FirebaseConstants.primaryIdField] == selectedBankId,
      orElse: () => fallbackBank,
    );

    final imagePath = selectedBank[FirebaseConstants.imageField] ?? '';
    final isNetworkImage = imagePath.toString().startsWith('http');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TextButton(
          onPressed: () {
            _showBankSelectionDialog(theme);
          },
          style: TextButton.styleFrom(
            padding: const EdgeInsets.all(10),
            backgroundColor: const Color.fromARGB(96, 255, 251, 241),
          ),
          child: Row(
            children: [
              isNetworkImage
                  ? Image.network(imagePath, width: 24, height: 24)
                  : Image.asset(imagePath, width: 24, height: 24),
              const SizedBox(width: 8),
              Text(
                selectedBank[FirebaseConstants.nameField] ?? '',
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
              await showDialog(
                context: context,
                builder: (BuildContext context) => ManageSalaryDialog(
                  email: userEmail,
                  isTransactionMode: _currentToggleIndex == 0,
                  selectedBankId: selectedBankId!,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBackCard(String amount, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopRow(theme),
        const SizedBox(height: 10),
        Text(
          _currentToggleIndex == 0 ? "Total Salary" : "Total Expense",
          style: AppTextStyles.bodyText,
        ),
        Text(
          amount,
          style: AppTextStyles.headline,
        ),
      ],
    );
  }

  Widget _buildFrontCard(String amount, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTopRow(theme),
        const SizedBox(height: 10),
        Text(
          _currentToggleIndex == 0 ? "Monthly Expense" : "Total Balance",
          style: AppTextStyles.bodyText,
        ),
        Text(
          amount,
          style: AppTextStyles.headline,
        ),
      ],
    );
  }

  Widget _buildSalaryWidget(String formattedSalaryAmount, ThemeData theme) {
    return SlideInAnimation(
      delay: const Duration(milliseconds: 100),
      startPosition: -0.5,
      endPosition: 0.0,
      child: GestureDetector(
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
                margin: const EdgeInsets.only(top: 20),
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.0),
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFFB74D), // soft orange
                      Color(0xFFFF9800), // mid
                      Color(0xFFF57C00), // deep
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withValues(alpha: 0.2),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(16),
                child: isBack
                    ? Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.rotationY(3.1416),
                        child: _buildBackCard(formattedSalaryAmount, theme),
                      )
                    : _buildFrontCard(formattedSalaryAmount, theme),
              ),
            );
          },
        ),
      ),
    );
  }

  String formatCompactIndian(double amount) {
    final absAmount = amount.abs();
  
    if (absAmount >= 10000000) {
      final value = (amount / 10000000);
      return '${(value * 10).truncate() / 10}Cr';
    } else if (absAmount >= 100000) {
      final value = (amount / 100000);
      return '${(value * 10).truncate() / 10}L';
    } else if (absAmount >= 1000) {
      final value = (amount / 1000);
      return '${(value * 10).truncate() / 10}k';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  String formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return DateFormat('dd MMM yyyy').format(date);
  }

  void _enterSelectionMode(String id) {
    setState(() {
      _isSelectionMode = true;
      _selectedExpenseIds.add(id);
    });
  }
  
  void _toggleSelection(String id) {
    setState(() {
      if (_selectedExpenseIds.contains(id)) {
        _selectedExpenseIds.remove(id);
        if (_selectedExpenseIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedExpenseIds.add(id);
      }
    });
  }
  
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false;
      _selectedExpenseIds.clear();
    });
  }

  Widget _buildNormalTile(
    MapEntry<String, dynamic> entry,
    Map<String, dynamic> expense,
    String categoryImage) {
    return GestureDetector(
      onLongPress: () => _enterSelectionMode(entry.key),
      onTap: () async {
        await showDialog(
          context: context,
          builder: (BuildContext context) => ExpenseDetailsDialog(
            email: userEmail,
            selectedExpenseId: entry.key,
          ),
        );
      },
      child: ListCard(
        image: categoryImage,
        title: expense[FirebaseConstants.expenseField] ?? '',
        subTitle: Text(
          expense[FirebaseConstants.transactionTypeField] ?? '',
        ),
        suffix: '₹${formatCompactIndian(
          (expense[FirebaseConstants.amountField] ?? 0).toDouble(),
        )}',
        footer: Text(
          formatTimestamp(
              expense[FirebaseConstants.timestampField]),
        ),
      ),
    );
  }

  Widget _buildSelectableTile(
    MapEntry<String, dynamic> entry,
    Map<String, dynamic> expense,
    String categoryImage) {
    final isSelected = _selectedExpenseIds.contains(entry.key);
  
    return GestureDetector(
      onTap: () => _toggleSelection(entry.key),
      child: Container(
        color: isSelected
            ? AppColors.secondaryGreen.withValues(alpha: 0.1)
            : Colors.transparent,
        child: ListCard(
          image: categoryImage,
          title: expense[FirebaseConstants.expenseField] ?? '',
          subTitle: Text(
            expense[FirebaseConstants.transactionTypeField] ?? '',
          ),
          suffix: Checkbox(
            value: isSelected,
            activeColor: AppColors.secondaryGreen,
            onChanged: (_) => _toggleSelection(entry.key),
          ),
          footer: Text(
            formatTimestamp(
                expense[FirebaseConstants.timestampField]),
          ),
        ),
      ),
    );
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
      appBar: appBar: CommonAppBar(
        title: 'MacTrack',
        isSelectionMode: _isSelectionMode,
        selectedCount: _selectedExpenseIds.length,
        totalFilteredCount: _currentFilteredCount,
      
        onExitSelection: _exitSelectionMode,
      
        onToggleSelectAll: () {
          setState(() {
            if (_selectedExpenseIds.length == _currentFilteredCount) {
              _selectedExpenseIds.clear();
            } else {
              _selectedExpenseIds = _currentFilteredIds.toSet();
            }
          });
        },
      
        onDeleteSelected: () {
          showAlertDialog(
            context,
            Theme.of(context),
            'Delete Expenses',
            'Delete selected expenses?',
            'Delete',
            _deleteSelectedExpenses,
          );
        },
      ),
      floatingActionButton: _isSelectionMode
      ? null
      : FloatingActionButton(
        onPressed: () async {
          await openFullScreenModal(context, null, null);
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
      bottomNavigationBar: FloatingBottomNav(
        currentIndex: _bottomIndex,
        onTap: (index) {
          if (index == _bottomIndex) return;
      
          if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const Insight()),
            );
          }
      
          setState(() {
            _bottomIndex = index;
          });
        },
      ),
      body: Container(
          decoration: AppTheme.getBackgroundDecoration(themeMode),
          padding: const EdgeInsets.only(top: kToolbarHeight + 50),
          child: Column(children: [
            Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(children: [
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
                            ? [AppConstants.transaction, '']
                            : ['', AppConstants.balance],
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
                            _isFlipped = false;
                          });
                        },
                      ),
                    ),
                  ),

                  //Salary card
                  StreamBuilder<Map<String, dynamic>>(
                    stream: firebaseService.streamGetAllData(
                      userEmail,
                      FirebaseConstants.expenseCollection,
                    ),
                    builder: (context, expenseSnapshot) {
                      if (!expenseSnapshot.hasData || selectedBankId == null) {
                        return _buildSalaryWidget("₹0", theme);
                      }

                      final expenses = expenseSnapshot.data!.entries
                          .where((e) =>
                              e.value[FirebaseConstants.bankIdField] ==
                              selectedBankId)
                          .toList();

                      final now = DateTime.now();

                      double totalDeposits = 0;
                      double totalWithdrawals = 0;
                      double currentMonthSalary = 0;
                      double currentMonthNet = 0;

                      for (final e in expenses) {
                        final amount =
                            (e.value[FirebaseConstants.amountField] ?? 0)
                                .toDouble();

                        final type =
                            e.value[FirebaseConstants.transactionTypeField];

                        final category =
                            e.value[FirebaseConstants.expenseCategoryField];

                        final ts = e.value[FirebaseConstants.timestampField]
                            as Timestamp;

                        final d = ts.toDate();

                        final isThisMonth =
                            d.month == now.month && d.year == now.year;

                        if (type == AppConstants.transactionTypeDeposit) {
                          totalDeposits += amount;

                          if (isThisMonth) {
                            currentMonthNet += amount;
                          }

                          if (category ==
                                  AppConstants.salaryCategory.toLowerCase() &&
                              isThisMonth) {
                            currentMonthSalary += amount;
                          }
                        } else {
                          totalWithdrawals += amount;

                          if (isThisMonth) {
                            currentMonthNet -= amount;
                          }
                        }
                      }

                      final totalBankBalance = totalDeposits - totalWithdrawals;

                      double valueToShow;

                      if (_currentToggleIndex == 0) {
                        // TRANSACTION MODE
                        valueToShow =
                            _isFlipped ? currentMonthSalary : currentMonthNet;
                      } else {
                        // BALANCE MODE
                        valueToShow =
                            _isFlipped ? totalWithdrawals : totalBankBalance;
                      }

                      final formatted = NumberFormat.currency(
                        locale: AppConstants.englishIndiaLocale,
                        symbol: AppConstants.rupeesSymbol,
                        decimalDigits: 0,
                      ).format(valueToShow);

                      return _buildSalaryWidget(formatted, theme);
                    },
                  ),
                  const SizedBox(height: 10),

                  SlideInAnimation(
                    delay: const Duration(milliseconds: 100),
                    startPosition: -0.5,
                    endPosition: 0.0,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final containerWidth = (constraints.maxWidth - 32) / 3;

                        return Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            SizedBox(
                              width: containerWidth,
                              child: FilterContainer(
                                icon: FeatherIcons.arrowDownLeft,
                                text: AppConstants.transactionTypeDeposit,
                                color: _selectedFilterType ==
                                            AppConstants
                                                .transactionTypeDeposit ||
                                        _selectedFilterType == null
                                    ? AppColors.filterButtonBlack
                                    : const Color(0xFF595A69),
                                onTap: () {
                                  setState(() {
                                    _selectedFilterType = _selectedFilterType ==
                                            AppConstants.transactionTypeDeposit
                                        ? null
                                        : AppConstants.transactionTypeDeposit;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: containerWidth,
                              child: FilterContainer(
                                icon: FeatherIcons.arrowUpRight,
                                text: AppConstants.transactionTypeWithdraw,
                                color: _selectedFilterType ==
                                            AppConstants
                                                .transactionTypeWithdraw ||
                                        _selectedFilterType == null
                                    ? AppColors.purple
                                    : const Color(0xFFA783AE),
                                onTap: () {
                                  setState(() {
                                    _selectedFilterType = _selectedFilterType ==
                                            AppConstants.transactionTypeWithdraw
                                        ? null
                                        : AppConstants.transactionTypeWithdraw;
                                  });
                                },
                              ),
                            ),
                            SizedBox(
                              width: containerWidth,
                              child: FilterContainer(
                                icon: FeatherIcons.arrowUp,
                                text: AppConstants.transactionTypeTransfer,
                                color: _selectedFilterType ==
                                            AppConstants
                                                .transactionTypeTransfer ||
                                        _selectedFilterType == null
                                    ? AppColors.filterButtonGreen
                                    : const Color(0xFF82B387),
                                onTap: () {
                                  setState(() {
                                    _selectedFilterType = _selectedFilterType ==
                                            AppConstants.transactionTypeTransfer
                                        ? null
                                        : AppConstants.transactionTypeTransfer;
                                  });
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ])),

            /// EXPENSE LIST SECTION (THIS MUST BE FLEXED)
            Flexible(
              fit: FlexFit.loose,
              child: SlideInAnimation(
                delay: const Duration(milliseconds: 100),
                startPosition: -0.5,
                endPosition: 0.0,
                child: StreamBuilder<Map<String, dynamic>>(
                  stream: firebaseService.streamGetAllData(
                    userEmail,
                    FirebaseConstants.expenseCollection,
                  ),
                  builder: (context, expenseSnapshot) {
                    if (!expenseSnapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.secondaryGreen,
                        ),
                      );
                    }

                    if (selectedBankId == null) {
                      return const SizedBox();
                    }

                    final expenseData = expenseSnapshot.data!;
                    final now = DateTime.now();

                    // FILTER LOGIC (THIS FIXES EVERYTHING)
                    final filteredExpenses = expenseData.entries.where((entry) {
                      final data = entry.value;
                      
                      // 1. Bank filter
                      if (data[FirebaseConstants.bankIdField] !=
                          selectedBankId) {
                        return false;
                      }

                      // 2. Transaction mode → current month only
                      if (_currentToggleIndex == 0) {
                        final ts =
                            data[FirebaseConstants.timestampField] as Timestamp;
                        final date = ts.toDate();

                        if (date.month != now.month || date.year != now.year) {
                          return false;
                        }
                      }

                      // 3. Chip filter
                      if (_selectedFilterType != null &&
                          data[FirebaseConstants.transactionTypeField] !=
                              _selectedFilterType) {
                        return false;
                      }

                      return true;
                    }).toList();

                    List<String> _currentFilteredIds = [];
                    int _currentFilteredCount = 0;

                    // 4. Sort newest first
                    filteredExpenses.sort((a, b) {
                      final tsA = a.value[FirebaseConstants.timestampField]
                          as Timestamp;
                      final tsB = b.value[FirebaseConstants.timestampField]
                          as Timestamp;
                      return tsB.compareTo(tsA);
                    });

                    _currentFilteredIds =
                        filteredExpenses.map((e) => e.key).toList();
                    _currentFilteredCount = _currentFilteredIds.length;

                    return StreamBuilder<Map<String, dynamic>>(
                      stream: expenseTypesStream,
                      builder: (context, typeSnapshot) {
                        if (!typeSnapshot.hasData) {
                          return const SizedBox();
                        }

                        final expenseTypes = typeSnapshot.data!;

                        return ListView(
                          padding: const EdgeInsets.only(bottom: 120),
                          children: filteredExpenses.map((entry) {
                            final expense = entry.value;
                            final categoryId =
                                expense[FirebaseConstants.expenseCategoryField];

                            final categoryInfo = expenseTypes[categoryId];
                            final categoryImage =
                                categoryInfo?[FirebaseConstants.imageField] ??
                                    'assets/images/other-expenses.png';

                            return _isSelectionMode
                              ? _buildSelectableTile(entry, expense, categoryImage)
                              : Slidable(
                              key: ValueKey(entry.key),
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                extentRatio: 0.4,
                                children: [
                                  SlidableAction(
                                    onPressed: (_) {
                                      final ts = expense?[FirebaseConstants
                                          .timestampField] as Timestamp?;
                                      if (ts != null) {
                                        final d = ts.toDate();
                                        final now = DateTime.now();
                                        final isOldMonth =
                                            d.month != now.month ||
                                                d.year != now.year;

                                        if (isOldMonth) {
                                          showToast(
                                              "Editing previous month is not allowed.");
                                          return;
                                        }

                                        openFullScreenModal(
                                            context, entry.key, expense);
                                      }
                                    },
                                    backgroundColor: AppColors.secondaryGreen,
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
                                        () => _onDeleteExpense(entry.key),
                                      );
                                    },
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: Colors.white,
                                    icon: FontAwesomeIcons.trash,
                                    label: 'Delete',
                                  ),
                                  SlidableAction(
                                    onPressed: (_) {
                                      showDialog(
                                        context: context,
                                        builder: (_) => SetReminderDialog(
                                          documentId: entry.key,
                                          reminderName: expense[
                                              FirebaseConstants
                                                  .expenseCategoryField],
                                        ),
                                      );
                                    },
                                    backgroundColor: AppColors.amber,
                                    foregroundColor: Colors.white,
                                    icon: FontAwesomeIcons.clock,
                                    label: 'Reminder',
                                  ),
                                ],
                              ),
                              child: GestureDetector(
                                  onTap: () async {
                                    await showDialog(
                                      context: context,
                                      builder: (BuildContext context) =>
                                          ExpenseDetailsDialog(
                                        email: userEmail,
                                        selectedExpenseId: entry.key,
                                      ),
                                    );
                                  },
                                  child: ListCard(
                                    image: categoryImage,
                                    title: expense[
                                            FirebaseConstants.expenseField] ??
                                        '',
                                    subTitle: Row(
                                      children: [
                                        Text(
                                          expense[FirebaseConstants
                                                  .transactionTypeField] ??
                                              '',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyLarge,
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
                                                : const Icon(
                                                    FeatherIcons.arrowUp,
                                                    color: AppColors.danger)
                                      ],
                                    ),
                                    suffix: '₹${formatCompactIndian(
                                      (expense[FirebaseConstants.amountField] ??
                                              0)
                                          .toDouble(),
                                    )}',
                                    footer: Text(
                                      formatTimestamp(expense[
                                          FirebaseConstants.timestampField]),
                                      style: TextStyle(
                                        fontSize: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.fontSize,
                                      ),
                                    ),
                                  )),
                            );
                          }).toList(),
                        );
                      },
                    );
                  },
                ),
              ),
            )
          ])),
    );
  }
}
