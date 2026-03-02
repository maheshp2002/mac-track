import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mac_track/ui/components/theme_manager.dart';
import 'package:mac_track/ui/sign.dart';
import 'package:mac_track/ui/widgets/common_dialog.dart';
import 'package:provider/provider.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;

  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDeleteSelected;
  final VoidCallback? onSearch;
  final VoidCallback? onAdvancedFilterDialog;

  const CommonAppBar({
    super.key,
    required this.title,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onExitSelection,
    this.onToggleSelectAll,
    this.onDeleteSelected,
    this.onSearch,
    this.onAdvancedFilterDialog,
  });

  void _signOutAlert(BuildContext context, ThemeData theme) {
    showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return CommonDialog(
            title: "Confirm Sign Out",
            body: Text("Are you sure you want to sign out?", style: theme.textTheme.bodyLarge,),
            primaryActionText: "Sign Out",
            onPrimaryAction: () => _signOut(context),
            showCloseButton: true,
            cancelText: "Cancel",
          );
        });
  }

  Future<void> _signOut(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => SignInPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeManager = Provider.of<ThemeManager>(context);

    return AppBar(
      backgroundColor: theme.scaffoldBackgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      toolbarHeight: 70,
      iconTheme: theme.iconTheme,
      title: isSelectionMode
          ? Text(
              "$selectedCount selected",
              style: theme.textTheme.titleLarge,
            )
          : Text(
              title,
              style: theme.textTheme.titleLarge,
            ),
      leading: isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: onExitSelection,
            )
          : IconButton(
              icon: Icon(
                FontAwesomeIcons.magnifyingGlass,
                color: theme.iconTheme.color,
              ),
              onPressed: onSearch,
            ),
      actions: isSelectionMode
          ? [
              TextButton(
                onPressed: onToggleSelectAll,
                child: Text(
                  selectedCount == totalCount ? "Unselect All" : "Select All",
                  style: theme.textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: selectedCount != 0 ? onDeleteSelected : null,
              ),
            ]
          : [
              PopupMenuButton<String>(
                color: theme.scaffoldBackgroundColor,
                icon: const Icon(Icons.more_vert),
                onSelected: (value) {
                  switch (value) {
                    case "filter":
                      if (onAdvancedFilterDialog != null) {
                        onAdvancedFilterDialog!();
                      }
                      break;
                    case "theme":
                      themeManager.toggleTheme();
                      break;
                    case "logout":
                      _signOutAlert(context, theme);
                      break;
                  }
                },
                itemBuilder: (_) {
                  final items = [
                    {
                      "value": "filter",
                      "label": "Advanced Filters",
                      "icon": FontAwesomeIcons.filter,
                    },
                    {
                      "value": "theme",
                      "label": "Toggle Theme",
                      "icon": themeManager.themeMode == ThemeMode.dark
                          ? Icons.light_mode
                          : Icons.dark_mode,
                    },
                    {
                      "value": "logout",
                      "label": "Sign Out",
                      "icon": FontAwesomeIcons.arrowRightFromBracket,
                    },
                  ];

                  return items.map((item) {
                    return PopupMenuItem<String>(
                      value: item["value"] as String,
                      child: Row(
                        children: [
                          Icon(
                            item["icon"] as IconData,
                            size: 20,
                            color: theme.iconTheme.color,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            item["label"] as String,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    );
                  }).toList();
                },
              )
            ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(70);
}
