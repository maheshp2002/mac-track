import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/config/constants.dart';
import 'package:provider/provider.dart';
import 'package:toggle_switch/toggle_switch.dart';
import 'components/commonAppBar.dart';
import 'components/fullScreenModal.dart';
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
  int _currentIndex = 0;
  late Stream<Map<String, dynamic>> expenseDataStream;
  late Stream<Map<String, dynamic>> bankDataStream;
  late Stream<Map<String, dynamic>> userBankDataStream;
  late Stream<Map<String, dynamic>> salaryDataStream = Stream.value({});
  List<Map<String, dynamic>> userBanks = [];
  String? selectedBankId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  void _initializeUser() async {
    bankDataStream = FirebaseService().streamBankData();
    User? user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      userBankDataStream = FirebaseService()
          .streamGetAllData(user.email!, FirebaseConstants.userBankCollection);

      userBankDataStream.listen((userBankData) async {
        // Fetch all banks from the master collection
        Map<String, dynamic> masterBanks = await bankDataStream.first;

        List<Map<String, dynamic>> updatedUserBanks = [];
        String? primaryBankId;

        userBankData.entries.forEach((entry) {
          final bankId = entry.value['bankId'];
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
  }

  void _updateSalaryStream() {
    if (selectedBankId != null) {
      salaryDataStream = FirebaseService()
          .streamGetAllData(FirebaseAuth.instance.currentUser!.email!,
              FirebaseConstants.salaryCollection)
          .map((salaryData) {
        final filteredSalaries = salaryData.values
            .where((doc) => doc['bankId'] == selectedBankId)
            .toList();
        filteredSalaries.sort((a, b) {
          final timestampA = a['timestamp'] as Timestamp;
          final timestampB = b['timestamp'] as Timestamp;
          return timestampB.compareTo(timestampA);
        });
        return filteredSalaries.isNotEmpty ? filteredSalaries.first : {};
      });
    }
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
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) =>
                            const AddSalaryDialog(),
                      );
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
        onPressed: () {
          openFullScreenModal(context);
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
        child: Padding(
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
                    inactiveBgColor: customTheme.toggleButtonBackgroundColor,
                    inactiveFgColor: customTheme.toggleButtonTextColor,
                    initialLabelIndex: _currentIndex,
                    totalSwitches: 2,
                    labels: _currentIndex == 0
                        ? ['Balance', '']
                        : ['', 'Transaction'],
                    customIcons: [
                      _currentIndex == 0
                          ? null
                          : Icon(
                              FontAwesomeIcons.indianRupeeSign,
                              color: iconColor,
                              size: 20,
                            ),
                      _currentIndex == 1
                          ? null
                          : Icon(
                              FontAwesomeIcons.rightLeft,
                              color: iconColor,
                              size: 20,
                            ),
                    ],
                    radiusStyle: true,
                    onToggle: (index) {
                      setState(() {
                        _currentIndex = index!;
                      });
                    },
                  ),
                ),
              ),
              StreamBuilder<Map<String, dynamic>>(
                stream: bankDataStream,
                builder: (context, bankSnapshot) {
                  if (bankSnapshot.connectionState == ConnectionState.waiting) {
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
                              final latestSalaryDoc = salarySnapshot.data!;
                              final latestSalaryAmount =
                                  latestSalaryDoc['currentAmount'];

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
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              FilterContainer(
                                icon: FeatherIcons.arrowDownLeft,
                                text: "Deposit",
                                color: AppColors.filterButtonBlack,
                                onTap: () {
                                  // Handle the tap event here
                                  print('InkWell tapped!');
                                },
                              ),
                              FilterContainer(
                                icon: FeatherIcons.arrowUpRight,
                                text: "Withdraw",
                                color: Colors.purple,
                                onTap: () {
                                  // Handle the tap event here
                                  print('InkWell tapped!');
                                },
                              ),
                              FilterContainer(
                                icon: FeatherIcons.arrowUp,
                                text: "Transfer",
                                color: AppColors.filterButtonGreen,
                                onTap: () {
                                  // Handle the tap event here
                                  print('InkWell tapped!');
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
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
    return InkWell(
        onTap: onTap,
        child: Container(
          width: 105,
          height: 105,
          padding: const EdgeInsets.fromLTRB(15, 15, 10, 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30.0),
            color: color,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                  height: 0.5 * 100,
                  child: Align(
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
                          size: 20, // Adjust icon size as needed
                        ),
                      ))),
              Text(
                text,
                style: const TextStyle(
                  color: AppColors.backgroundLight,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ));
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
        'currentAmount': amount,
        'timestamp': now,
        'bankId': _selectedBankId
      };

      // Save the data to Firebase
      await FirebaseService().addData(userEmail, documentId, expenseData,
          FirebaseConstants.salaryCollection);

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
            'OK',
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
        'timestamp': now,
        'bankId': _selectedBankId
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
