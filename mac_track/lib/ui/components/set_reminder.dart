import 'package:day_night_time_picker/lib/constants.dart';
import 'package:day_night_time_picker/lib/daynight_timepicker.dart';
import 'package:day_night_time_picker/lib/state/time.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mac_track/ui/components/theme_manager.dart';
import 'package:mac_track/ui/components/toast.dart';
import 'package:mac_track/config/constants.dart';
import 'package:mac_track/services/flutter_local_notification_plugin.dart';
import 'package:mac_track/ui/theme.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:mac_track/utils/reminders.dart';
import 'package:provider/provider.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetReminderDialog extends StatefulWidget {
  final String documentId;
  final String reminderName;
  const SetReminderDialog(
      {super.key, required this.documentId, required this.reminderName});

  @override
  SetReminderDialogState createState() => SetReminderDialogState();
}

class SetReminderDialogState extends State<SetReminderDialog> {
  Time _time = Time(hour: 11, minute: 30, second: 20);
  String _selectedReminderType = AppConstants.reminderOnce;
  bool isReminder = false;
  bool isReminderCompleted = false;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    final now = DateTime.now();
    _time = Time(hour: now.hour, minute: now.minute, second: now.second);
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void onTimeChanged(Time newTime) {
    setState(() {
      _time = newTime;
    });
  }

  Future<void> _setReminder() async {
    checkAndRequestExactAlarm();
    try {
      final reminder = await Reminders.setReminder(
        documentId: widget.documentId,
        time: _time,
        type: _selectedReminderType,
        reminderName: widget.reminderName,
      );
      if (reminder) {
        showToast('Reminder set successfully', isSuccess: true);

        if (!mounted) return;

        Navigator.pop(context);
      } else {
        showToast('Failed to set reminder', isSuccess: false);
      }
    } catch (e) {
      showToast('Error: $e', isSuccess: false);
    }
  }

  Future<void> ensureExactAlarmPermission() async {
    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31) {
      // Ask the user to manually allow it
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
    }
  }

  Future<void> checkAndRequestExactAlarm() async {
    final prefs = await SharedPreferences.getInstance();
    final hasAsked = prefs.getBool('exact_alarm_requested') ?? false;

    final androidInfo = await DeviceInfoPlugin().androidInfo;
    if (androidInfo.version.sdkInt >= 31 && !hasAsked) {
      const intent = AndroidIntent(
        action: 'android.settings.REQUEST_SCHEDULE_EXACT_ALARM',
      );
      await intent.launch();
      await prefs.setBool('exact_alarm_requested', true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;
    final theme = Theme.of(context);

    return CommonDialog(
      title: 'Manage Reminder',
      showCloseButton: true,
      body: SingleChildScrollView(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                dropdownColor: theme.scaffoldBackgroundColor,
                icon: Icon(
                  FontAwesomeIcons.repeat,
                  color: theme.iconTheme.color,
                ),
                initialValue: _selectedReminderType,
                items: reminderRepetitions.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value, style: theme.textTheme.bodyLarge),
                  );
                }).toList(),
                onChanged: (selectedName) {
                  setState(() {
                    _selectedReminderType = selectedName!;
                  });
                },
                decoration: InputDecoration(
                  labelText: 'Reminder Frequency',
                  labelStyle: theme.textTheme.labelSmall,
                  border: const OutlineInputBorder(),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: AppColors.secondary),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                style: ButtonStyle(
                  backgroundColor:
                      WidgetStateProperty.all(AppColors.transparent),
                  side: WidgetStateProperty.all(
                    BorderSide(
                      color: themeMode == ThemeMode.dark
                          ? AppColors.white
                          : Colors.black54,
                      width: 1,
                    ),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    showPicker(
                      context: context,
                      value: _time,
                      onChange: onTimeChanged,
                      backgroundColor: theme.scaffoldBackgroundColor,
                      showSecondSelector: true,
                      minuteInterval: TimePickerInterval.FIVE,
                      themeData: Theme.of(context).copyWith(
                        timePickerTheme: TimePickerThemeData(
                          backgroundColor:
                              Theme.of(context).colorScheme.surface,
                          dialHandColor: AppColors.secondaryGreen,
                          hourMinuteTextColor:
                              theme.textTheme.labelSmall!.color,
                          dialBackgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          entryModeIconColor: AppColors.secondaryGreen,
                        ),
                        colorScheme: Theme.of(context).colorScheme.copyWith(
                              primary: AppColors.secondaryGreen,
                              onPrimary: Colors.white,
                              surface: theme.scaffoldBackgroundColor,
                              onSurface: theme.scaffoldBackgroundColor,
                            ),
                        dialogTheme: DialogThemeData(
                          backgroundColor: theme.scaffoldBackgroundColor,
                        ),
                      ),
                    ),
                  );
                },
                child: Text(
                  "$_time",
                  style: theme.textTheme.bodySmall,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 200,
                child: ElevatedButton(
                  onPressed: _setReminder,
                  style: ButtonStyle(
                    backgroundColor:
                        WidgetStateProperty.all(AppColors.secondaryGreen),
                  ),
                  child: Text(
                    'Add Reminder',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: theme.textTheme.bodyLarge!.fontSize,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () async {
                  await Reminders.cancelReminder(widget.documentId);
                  showToast("Reminder cancelled");
                  if (!mounted) return;
                  Navigator.pop(context);
                },
                child: const Text(
                  "Cancel Reminder",
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
