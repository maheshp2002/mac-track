import 'package:flutter/material.dart';
import 'package:mac_track/components/curvedToggleButton.dart';
import 'package:provider/provider.dart';
import 'components/commonAppBar.dart';
import 'components/graph.dart';
import 'components/navbar.dart';
import 'components/themeManager.dart';
import 'theme.dart';

class Insight extends StatefulWidget {
  @override
  _InsightState createState() => _InsightState();
}

class _InsightState extends State<Insight> {
  @override
  Widget build(BuildContext context) {
    final themeManager = Provider.of<ThemeManager>(context);
    final themeMode = themeManager.themeMode;
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: CommonAppBar(
        title: 'Insight',
      ),
      drawer: NavBar(),
      body: Container(
          decoration: AppTheme.getBackgroundDecoration(themeMode),
          padding: const EdgeInsets.only(top: kToolbarHeight + 50),
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                SizedBox(
                    width: double.infinity,
                    height: 80,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Total Expense", style: theme.textTheme.bodyLarge),
                        Text("Rs. 999.0", style: theme.textTheme.displayLarge)
                      ],
                    )),
                CurvedToggleButton(),
                const ExpenseGraph(),
              ]))),
    );
  }
}
