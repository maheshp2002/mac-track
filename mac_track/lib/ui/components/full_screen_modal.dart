import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/ui/components/toast.dart';
import 'package:mac_track/services/csv_transaction_importer.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:toggle_switch/toggle_switch.dart';
import '../../config/constants.dart';
import '../../services/firebase_service.dart';
import '../theme.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

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
  late Stream<Map<String, dynamic>> counterpartyStream;
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
  Map<String, String> _expenseCategoryMap = {}; // name -> document ID
  List<String> _expenseCategoryNames = [];
  String? _selectedExpenseCategory;
  String? _selectedExpenseCategoryId;
  int _entryModeIndex = 0;
  bool _isImporting = false;
  PlatformFile? _pickedFile;
  String? _selectedContactName;
  String? _selectedContactPhone;
  // Dropdown related variables
  String _selectedTransactionType = AppConstants.transactionTypeWithdraw;
  final List<String> _transactionTypes = [
    AppConstants.transactionTypeDeposit,
    AppConstants.transactionTypeWithdraw,
    AppConstants.transactionTypeTransfer
  ];

  // Getter
  bool get _isCsvValid {
    return _selectedBankId != null && _pickedFile != null;
  }
  bool get _isSalaryCategorySelected =>
      _selectedExpenseCategory == AppConstants.salaryCategory;
  bool get _isEditMode =>
      widget.expenseId != null && widget.expense != null;
  bool get _isCurrentFormValid {
    return _validateAmount(_amountController.text) == null &&
        _validateExpenseType(_expenseController.text) == null &&
        _selectedBankId != null;
  }

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
        final name = data[FirebaseConstants.nameField] as String?;
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
    final expense = widget.expense;

    if (expense == null) return;

    setState(() {
      _amountController.text =
          expense[FirebaseConstants.amountField]?.toString() ?? '';

      _expenseController.text =
          expense[FirebaseConstants.expenseField] ?? '';

      _selectedBankId =
          expense[FirebaseConstants.bankIdField];

      _selectedTransactionType =
          expense[FirebaseConstants.transactionTypeField] ??
              AppConstants.transactionTypeWithdraw;

      _selectedExpenseCategoryId =
          expense[FirebaseConstants.expenseCategoryField];

      final selectedCategoryId =
          expense[FirebaseConstants.expenseCategoryField];

      _selectedExpenseCategory = _expenseCategoryMap.entries
          .firstWhere(
            (entry) => entry.value == selectedCategoryId,
            orElse: () => const MapEntry('', ''),
          )
          .key;

      // Restore contact in edit mode
      _selectedContactName = expense['counterpartyName'];
      _selectedContactPhone = expense['counterpartyPhone'];
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
            FirebaseConstants.primaryIdField: bankId,
            FirebaseConstants.nameField: prevId == AppConstants.otherCategory
                ? entry.value[FirebaseConstants.bankNameField]
                : bankDetails[FirebaseConstants.nameField],
            FirebaseConstants.imageField:
                bankDetails[FirebaseConstants.imageField],
            FirebaseConstants.isPrimaryField:
                entry.value[FirebaseConstants.isPrimaryField],
          });
        }
      }

      if (!mounted) return; // prevent setState after dispose

      setState(() {
        userBanks = updatedUserBanks;
      });
    });
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
      FirebaseConstants.timestampField: isEditMode
        ? widget.expense![FirebaseConstants.timestampField]
        : DateTime.now(),
      FirebaseConstants.updatedAtField:  DateTime.now(),
    };

    if (_selectedContactPhone != null && _selectedContactName != null) {
      expenseData['counterpartyName'] = _selectedContactName;
      expenseData['counterpartyPhone'] = _selectedContactPhone;
    }

    try {
      if (isEditMode) {
        await _firebaseService.updatedExpenseData(
          userEmail,
          documentId,
          expenseData,
          FirebaseConstants.expenseCollection,
        );
      } else {
        await _firebaseService.addData(
          userEmail,
          documentId,
          expenseData,
          FirebaseConstants.expenseCollection,
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

    if (original == null) {
      setState(() => _isFormChanged = true);
      return;
    }

    final isChanged =
        _amountController.text !=
                (original[FirebaseConstants.amountField]?.toString() ?? '') ||
        _expenseController.text !=
                (original[FirebaseConstants.expenseField] ?? '') ||
        _selectedTransactionType !=
                (original[FirebaseConstants.transactionTypeField] ??
                    AppConstants.transactionTypeWithdraw) ||
        _selectedBankId !=
                original[FirebaseConstants.bankIdField] ||
        _selectedExpenseCategoryId !=
                original[FirebaseConstants.expenseCategoryField] ||
        _selectedContactName != original['counterpartyName'] ||
        _selectedContactPhone != original['counterpartyPhone'];

    setState(() {
      _isFormChanged = isChanged;
    });
  }

  void _handleCsvImport() async {
    if (_isImporting) return;
    if (_pickedFile == null || _pickedFile!.path == null) {
      showToast('Please select a CSV file.');
      return;
    }

    setState(() => _isImporting = true);

    try {
      final importer = CsvTransactionImporter();

      final imported = await importer.importCsv(
          filePath: _pickedFile!.path!,
          selectedBankId: _selectedBankId!,
          expenseCategoryMap: _expenseCategoryMap);

      if (imported.isEmpty) {
        showToast('No valid transactions found.');
        return;
      }

      final confirmed = await _showImportConfirmation(imported.length);

      if (!confirmed) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) return;

      for (final expense in imported) {
        await _firebaseService.addData(
          user.email!,
          expense[FirebaseConstants.documentIdField],
          expense,
          FirebaseConstants.expenseCollection,
        );
      }

      showToast('${imported.length} transactions imported');

      if (!mounted) return;
      Navigator.of(context).pop(AppConstants.refresh);
    } catch (e) {
      showToast(e.toString());
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
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

  Future<void> _pickContact() async {
    final permission = await Permission.contacts.request();
    final theme = Theme.of(context);

    if (!permission.isGranted) {
      showToast('Contacts permission denied');
      return;
    }

    final contacts = await FlutterContacts.getContacts(
      withProperties: true,
      withPhoto: false,
    );

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      builder: (context) {
        List<Contact> filtered = contacts;
        final searchController = TextEditingController();

        return StatefulBuilder(builder: (context, setModalState) {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.8,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Select Contact",
                        style: theme.textTheme.titleLarge,
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: theme.iconTheme.color),
                        onPressed: () => Navigator.pop(context),
                      )
                    ],
                  ),
                ),

                // ===== SEARCH FIELD =====
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: searchController,
                    style: theme.textTheme.bodyLarge,
                    decoration: InputDecoration(
                      labelText: "Search Contact",
                      labelStyle: theme.textTheme.labelSmall,
                      border: const OutlineInputBorder(),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.secondary),
                      ),
                    ),
                    onChanged: (value) {
                      setModalState(() {
                        filtered = contacts
                            .where((c) => c.displayName
                                .toLowerCase()
                                .contains(value.toLowerCase()))
                            .toList();
                      });
                    },
                  ),
                ),

                // ===== CONTACT LIST =====
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final contact = filtered[index];

                      if (contact.phones.isEmpty) return const SizedBox();

                      final phone = contact.phones.first.number
                          .replaceAll(RegExp(r'\s+'), '');

                      return ListTile(
                        title: Text(contact.displayName,
                            style: theme.textTheme.bodyLarge),
                        subtitle: Text(phone, style: theme.textTheme.bodySmall),
                        onTap: () {
                          setState(() {
                            _selectedContactName = contact.displayName;
                            _selectedContactPhone = phone;
                          });

                          Navigator.pop(context);
                          checkFormChanged();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        });
      },
    );
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
            child: Column(
              children: [
                // Close Button
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Add Expense",
                        style: theme.textTheme.displayLarge,
                      ),
                      IconButton(
                        icon: Icon(
                          FontAwesomeIcons.xmark,
                          color: theme.iconTheme.color,
                        ),
                        onPressed: () {
                          Navigator.of(context).pop(AppConstants.refresh);
                        },
                      ),
                    ],
                  ),
                ),
                // Content of the Popup
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      left: 16.0,
                      right: 16.0,
                      bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
                    ),
                    child: StreamBuilder<Map<String, dynamic>>(
                      stream: _bankDataStream,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                              child: CircularProgressIndicator(
                            color: AppColors.secondaryGreen,
                          ));
                        } else if (snapshot.hasError) {
                          return Center(
                              child: Text("An Error Occurred",
                                  style: theme.textTheme.bodyLarge));
                        } else if (!snapshot.hasData ||
                            snapshot.data!.isEmpty) {
                          return Center(
                              child: Text(
                            "No bank data available.",
                            style: theme.textTheme.bodyLarge,
                          ));
                        } else {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_isEditMode)
                                Center(
                                  child: ToggleSwitch(
                                    minWidth: 100.0,
                                    cornerRadius: 20.0,
                                    activeBgColors: [
                                      [customTheme!.toggleButtonFillColor],
                                      [customTheme.toggleButtonFillColor],
                                    ],
                                    activeFgColor:
                                        customTheme.toggleButtonSelectedColor,
                                    inactiveBgColor:
                                        customTheme.toggleButtonBackgroundColor,
                                    inactiveFgColor:
                                        customTheme.toggleButtonTextColor,
                                    initialLabelIndex: _entryModeIndex,
                                    totalSwitches: 2,
                                    labels: const [
                                      AppConstants.manualToggle,
                                      AppConstants.csvToggle
                                    ],
                                    radiusStyle: true,
                                    onToggle: (index) {
                                      setState(() {
                                        _entryModeIndex = index!;
                                      });
                                    },
                                  ),
                                ),
                              const SizedBox(height: 20),
                              if (_entryModeIndex == 0) ...[
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
                                        color:
                                            theme.textTheme.bodyLarge?.color),
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
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    ),
                                  ),
                                  cursorColor: AppColors.secondary,
                                  onChanged: (value) {
                                    checkFormChanged();
                                  },
                                  validator: _validateAmount,
                                ),
                                const SizedBox(height: 20),
                                DropdownButtonFormField<String>(
                                  dropdownColor: theme.scaffoldBackgroundColor,
                                  icon: Icon(
                                    FontAwesomeIcons.moneyBillTrendUp,
                                    color: theme.iconTheme.color,
                                  ),
                                  initialValue: _selectedExpenseCategory,
                                  items:
                                      _expenseCategoryNames.map((String name) {
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

                                      if (selectedName ==
                                          AppConstants.salaryCategory) {
                                        // Force deposit
                                        _selectedTransactionType =
                                            AppConstants.transactionTypeDeposit;

                                        // CLEAR CONTACT SELECTION (salary should not have counterparty)
                                        _selectedContactName = null;
                                        _selectedContactPhone = null;
                                      } else {
                                        _selectedTransactionType = AppConstants
                                            .transactionTypeWithdraw;
                                      }
                                    });
                                    checkFormChanged();
                                  },
                                  decoration: InputDecoration(
                                      labelText: 'Expense Category',
                                      labelStyle: theme.textTheme.labelSmall,
                                      border: const OutlineInputBorder(),
                                      focusedBorder: const OutlineInputBorder(
                                        borderSide: BorderSide(
                                            color: AppColors.secondary),
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
                                        color:
                                            theme.textTheme.bodyLarge?.color),
                                    suffixIcon: Icon(
                                      FontAwesomeIcons.receipt,
                                      color: _isExpenseTypeValid
                                          ? _expenseFocusNode.hasFocus
                                              ? AppColors.secondary
                                              : theme.iconTheme.color
                                          : Colors.red,
                                    ),
                                    border: const OutlineInputBorder(),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
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
                                    color: _isSalaryCategorySelected
                                        ? Colors.grey
                                        : theme.iconTheme.color,
                                  ),
                                  initialValue: _selectedTransactionType,
                                  items: _transactionTypes.map((String type) {
                                    return DropdownMenuItem<String>(
                                      value: type,
                                      child: Text(
                                        type,
                                        style: _isSalaryCategorySelected
                                            ? theme.textTheme.bodyLarge
                                                ?.copyWith(color: Colors.grey)
                                            : theme.textTheme.bodyLarge,
                                      ),
                                    );
                                  }).toList(),

                                  // Disable editing if Salary category selected
                                  onChanged: _isSalaryCategorySelected
                                      ? null
                                      : (newValue) {
                                          setState(() {
                                            _selectedTransactionType =
                                                newValue!;
                                          });
                                          checkFormChanged();
                                        },
                                  decoration: InputDecoration(
                                    labelText: 'Transaction Type',
                                    labelStyle: _isSalaryCategorySelected
                                        ? theme.textTheme.labelSmall
                                            ?.copyWith(color: Colors.grey)
                                        : theme.textTheme.labelSmall,
                                    border: const OutlineInputBorder(),
                                    focusedBorder: const OutlineInputBorder(
                                      borderSide: BorderSide(
                                          color: AppColors.secondary),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Select Contact (Optional)",
                                      style: _isSalaryCategorySelected
                                          ? theme.textTheme.labelSmall
                                              ?.copyWith(color: Colors.grey)
                                          : theme.textTheme.labelSmall,
                                    ),
                                    const SizedBox(height: 10),
                                    if (_selectedContactName == null)
                                      OutlinedButton.icon(
                                        onPressed: _isSalaryCategorySelected
                                            ? null
                                            : _pickContact,
                                        icon: Icon(
                                          Icons.person_add,
                                          color: _isSalaryCategorySelected
                                              ? Colors.grey
                                              : AppColors.secondaryGreen,
                                        ),
                                        label: Text(
                                          "Choose Contact",
                                          style: theme.textTheme.bodyLarge!
                                              .copyWith(
                                            color: _isSalaryCategorySelected
                                                ? Colors.grey
                                                : AppColors.secondaryGreen,
                                          ),
                                        ),
                                      )
                                    else
                                      Opacity(
                                        opacity:
                                            _isSalaryCategorySelected ? 0.5 : 1,
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: _isSalaryCategorySelected
                                                  ? Colors.grey
                                                  : AppColors.secondaryGreen,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _selectedContactName!,
                                                    style: theme
                                                        .textTheme.bodyLarge,
                                                  ),
                                                  Text(
                                                    _selectedContactPhone!,
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                ],
                                              ),
                                              if (!_isSalaryCategorySelected)
                                                IconButton(
                                                  icon: const Icon(Icons.close),
                                                  onPressed: () {
                                                    setState(() {
                                                      _selectedContactName =
                                                          null;
                                                      _selectedContactPhone =
                                                          null;
                                                    });
                                                    checkFormChanged();
                                                  },
                                                )
                                            ],
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                              if (_entryModeIndex == 1)
                                GestureDetector(
                                  onTap: () async {
                                    final result =
                                        await FilePicker.platform.pickFiles(
                                      type: FileType.custom,
                                      allowedExtensions: ['csv'],
                                    );

                                    if (result != null) {
                                      setState(() {
                                        _pickedFile = result.files.first;
                                      });
                                    }
                                  },
                                  child: SizedBox(
                                      width: double.infinity,
                                      child: Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                          border: Border.all(
                                              color: AppColors.secondaryGreen),
                                        ),
                                        child: _pickedFile == null
                                            ? Column(
                                                children: [
                                                  const Icon(
                                                      FontAwesomeIcons.fileCsv,
                                                      size: 40),
                                                  const SizedBox(height: 10),
                                                  Text(
                                                    "Tap to select CSV",
                                                    style: theme
                                                        .textTheme.bodySmall,
                                                  ),
                                                ],
                                              )
                                            : Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                          FontAwesomeIcons
                                                              .fileCsv),
                                                      const SizedBox(width: 10),
                                                      SizedBox(
                                                        width: 150,
                                                        child: Text(
                                                          _pickedFile!.name,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style: theme.textTheme.bodyLarge,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  IconButton(
                                                    icon:
                                                        const Icon(Icons.close),
                                                    onPressed: () {
                                                      setState(() {
                                                        _pickedFile = null;
                                                      });
                                                    },
                                                  )
                                                ],
                                              ),
                                      )),
                                ),
                              const SizedBox(height: 20),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: userBanks
                                    .map<Widget>((entry) => ChoiceChip(
                                          showCheckmark: false,
                                          avatar: Image.network(entry[
                                              FirebaseConstants.imageField]),
                                          label: Text(entry[
                                              FirebaseConstants.nameField]),
                                          labelStyle: TextStyle(
                                            color: _selectedBankId ==
                                                    entry[FirebaseConstants
                                                        .primaryIdField]
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
                                              entry[FirebaseConstants
                                                  .primaryIdField], // Compare document ID
                                          onSelected: (selected) {
                                            setState(() {
                                              _selectedBankId = selected
                                                  ? entry[FirebaseConstants
                                                      .primaryIdField]
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
                ),
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Builder(
                      builder: (context) {
                        final isEnabled = _isEditMode
                          ? (_isCurrentFormValid && _isFormChanged)
                          : (_entryModeIndex == 0
                              ? (_isCurrentFormValid && _isFormChanged)
                              : _isCsvValid);

                        return ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondaryGreen,
                            foregroundColor: AppColors.white,
                            disabledBackgroundColor:
                                AppColors.secondaryGreen.withValues(alpha: 0.6),
                            disabledForegroundColor: AppColors.white,
                          ),
                          onPressed: isEnabled
                              ? (_entryModeIndex == 0
                                  ? _submit
                                  : _handleCsvImport)
                              : null,
                          child: Text(
                            _entryModeIndex == 0 ? 'Save' : 'Import CSV',
                            style: TextStyle(
                              fontSize: theme.textTheme.bodyLarge!.fontSize,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(
                  height: 10,
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
