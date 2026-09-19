import 'package:flutter/material.dart';

class SearchBarWidget extends StatelessWidget {
  const SearchBarWidget({
    super.key,
    this.onTap,
    this.controller,
    this.hint = 'Search spare parts, OEM numbers',
  });

  final VoidCallback? onTap;
  final TextEditingController? controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return SearchBar(
      controller: controller,
      onTap: onTap,
      hintText: hint,
      leading: const Icon(Icons.search),
      elevation: const WidgetStatePropertyAll(0),
      side: WidgetStatePropertyAll(
          BorderSide(color: Theme.of(context).dividerColor)),
      backgroundColor: const WidgetStatePropertyAll(Colors.white),
      padding:
          const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
  }
}
