import 'package:flutter/material.dart';

class ProfileExpansionPanel extends StatefulWidget {
  const ProfileExpansionPanel({required this.items, super.key});

  final List<String> items;

  @override
  State<ProfileExpansionPanel> createState() => _ProfileExpansionPanelState();
}

class _ProfileExpansionPanelState extends State<ProfileExpansionPanel> {
  late List<bool> _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.items.map((e) => false).toList();
  }

  @override
  Widget build(BuildContext context) {
    return ExpansionPanelList(
      expansionCallback: (panelIndex, isExpanded) {
        setState(() {
          _isExpanded[panelIndex] = isExpanded;
        });
      },
      children: widget.items
          .map(
            (e) => ExpansionPanel(
              headerBuilder: (context, isExpanded) => ListTile(
                title: Text(e),
              ),
              body: const Text('body'),
              isExpanded: _isExpanded[widget.items.indexOf(e)],
            ),
          )
          .toList(),
    );
  }
}
