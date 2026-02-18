import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'theme_manager.dart';

class CommonAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  // Optional dynamic state
  final bool isSelectionMode;
  final int selectedCount;
  final int totalCount;

  final VoidCallback? onExitSelection;
  final VoidCallback? onToggleSelectAll;
  final VoidCallback? onDeleteSelected;

  const CommonAppBar({
    super.key,
    required this.title,
    this.isSelectionMode = false,
    this.selectedCount = 0,
    this.totalCount = 0,
    this.onExitSelection,
    this.onToggleSelectAll,
    this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final theme = Theme.of(context);

    return AppBar(
      iconTheme: theme.iconTheme,

      // Dynamic title
      title: Center(
        child: Text(
          isSelectionMode ? "$selectedCount selected" : title,
          style: theme.textTheme.displayMedium,
        ),
      ),

      leading: isSelectionMode
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: onExitSelection,
            )
          : null,

      actions: [
        // Selection actions
        if (isSelectionMode) ...[
          TextButton(
            onPressed: onToggleSelectAll,
            child: Text(
              selectedCount == totalCount
                  ? "Unselect All"
                  : "Select All",
              style: theme.textTheme.bodyMedium,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDeleteSelected,
          ),
        ],

        // Theme toggle always present
        IconButton(
          icon: Icon(
            themeManager.themeMode == ThemeMode.dark
                ? Icons.dark_mode
                : Icons.light_mode,
            color: theme.iconTheme.color,
          ),
          onPressed: themeManager.toggleTheme,
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
