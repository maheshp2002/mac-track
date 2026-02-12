import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/components/toast.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/firebase_service.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';

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
  bool _bankIdValid = true;
  late FocusNode _bankIdFocusNode;
  final TextEditingController _bankIdController = TextEditingController();
  final firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _bankDataStream = firebaseService.streamBankData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final hasOnlyDefault =
          widget.userBanks.length == 1 && widget.userBanks.first['id'] == 'add';
      setState(() {
        _isPrimary = hasOnlyDefault;
      });
    });
    _bankIdFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _bankIdFocusNode.dispose();
    _bankIdController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBankId != null) {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null ||
          user.email == null &&
              (_selectedBankId != AppConstants.otherCategory ||
                  _bankIdController.text.isNotEmpty)) {
        showToast('User not signed in.');
        return;
      }
      String userEmail = user.email ?? "";

      String? bankName = _selectedBankId == AppConstants.otherCategory
          ? _bankIdController.text
          : _selectedBankId;

      // Generate a unique document ID using date, time, and amount
      DateTime now = DateTime.now();
      String documentId = "${now.toIso8601String()}_$bankName";

      // Step 1: Unmark other banks as primary
      if (_isPrimary) {
        for (var bank in widget.userBanks) {
          if (bank['id'] != 'add' && bank['isPrimary'] == true) {
            await firebaseService.updateDocumentFieldString(
              userEmail,
              FirebaseConstants.userBankCollection,
              bank['documentId'],
              FirebaseConstants.isPrimaryField,
              false,
            );
          }
        }
      }

      // Step 2: Prepare the data to be stored
      Map<String, dynamic> bankData = {
        'isPrimary': _isPrimary,
        FirebaseConstants.timestampField: now,
        FirebaseConstants.bankIdField: _selectedBankId,
        FirebaseConstants.bankNameField: bankName
      };

      // Step 3: Save the data to Firebase
      await firebaseService.addData(userEmail, documentId, bankData,
          FirebaseConstants.userBankCollection);

      if (!mounted) return;

      // Optionally close the modal after submitting
      Navigator.of(context).pop("Add");
    } else if (_selectedBankId == AppConstants.otherCategory &&
        _bankIdController.text.trim().isEmpty) {
      showToast('Please enter bank id for "Other"');
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

    return CommonDialog(
      title: 'Add Bank',
      primaryActionText: 'Add',
      onPrimaryAction: _submit,
      cancelText: 'Cancel',
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: StreamBuilder<Map<String, dynamic>>(
          stream: _bankDataStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppColors.secondaryGreen,
                ),
              );
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  "An Error Occurred",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(
                child: Text(
                  "No bank data available.",
                  style: theme.textTheme.bodyLarge,
                ),
              );
            }

            final bankData = snapshot.data!;

            return Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.userBanks.length > 1)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: SwitchListTile(
                        inactiveTrackColor: customTheme!.chipBackgroundColor,
                        activeThumbColor: AppColors.primaryGreen,
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
                      ),
                    ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Choose Bank',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      ...bankData.entries
                          .where(
                            (entry) => entry.key != AppConstants.otherCategory,
                          )
                          .map(
                            (entry) => ChoiceChip(
                              showCheckmark: false,
                              avatar: Image.network(entry.value['image']),
                              label: Text(entry.value['name']),
                              labelStyle: TextStyle(
                                color: _selectedBankId == entry.key
                                    ? Colors.white
                                    : theme.textTheme.bodyLarge!.color,
                              ),
                              selectedColor: AppColors.secondary,
                              backgroundColor: customTheme!.chipBackgroundColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(50),
                              ),
                              selected: _selectedBankId == entry.key,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedBankId = selected ? entry.key : null;
                                });
                              },
                            ),
                          ),
                      ChoiceChip(
                        showCheckmark: false,
                        avatar: const Icon(
                          FontAwesomeIcons.buildingColumns,
                          size: 18,
                          color: Colors.white,
                        ),
                        label: const Text('Other'),
                        labelStyle: TextStyle(
                          color: _selectedBankId == AppConstants.otherCategory
                              ? Colors.white
                              : theme.textTheme.bodyLarge!.color,
                        ),
                        selectedColor: AppColors.secondary,
                        backgroundColor: customTheme!.chipBackgroundColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(50),
                        ),
                        selected: _selectedBankId == AppConstants.otherCategory,
                        onSelected: (selected) {
                          setState(() {
                            _selectedBankId =
                                selected ? AppConstants.otherCategory : null;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  if (_selectedBankId == AppConstants.otherCategory)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: TextFormField(
                        controller: _bankIdController,
                        focusNode: _bankIdFocusNode,
                        maxLength: 7,
                        decoration: InputDecoration(
                          labelText: 'Bank Id',
                          labelStyle: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          suffixIcon: Icon(
                            FontAwesomeIcons.buildingColumns,
                            color: _bankIdValid
                                ? _bankIdFocusNode.hasFocus
                                    ? AppColors.secondary
                                    : theme.iconTheme.color
                                : Colors.red,
                          ),
                          border: const OutlineInputBorder(),
                          focusedBorder: const OutlineInputBorder(
                            borderSide: BorderSide(color: AppColors.secondary),
                          ),
                        ),
                        cursorColor: AppColors.secondary,
                        onChanged: (_) {
                          _formKey.currentState?.validate();
                        },
                        validator: (value) {
                          if (_selectedBankId == AppConstants.otherCategory) {
                            if (value == null || value.isEmpty) {
                              setState(() {
                                _bankIdValid = false;
                              });
                              return 'Please enter a value';
                            }

                            final isAlphabetOnly =
                                RegExp(r'^[a-zA-Z]+$').hasMatch(value);
                            if (!isAlphabetOnly) {
                              setState(() {
                                _bankIdValid = false;
                              });
                              return 'Only alphabets are allowed (no space)';
                            }
                          }
                          setState(() {
                            _bankIdValid = true;
                          });
                          return null;
                        },
                      ),
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
