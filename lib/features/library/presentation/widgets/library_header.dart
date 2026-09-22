import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_tab_header.dart';

class LibraryHeader extends StatelessWidget {
  const LibraryHeader({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    required this.onFilterTap,
    required this.onAddTap,
    required this.onBackTap,
  });

  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onFilterTap;
  final VoidCallback onAddTap;
  final VoidCallback onBackTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTabHeader(
          title: 'Biblioteka',
          gutter: 0,
          leading: AppTabHeaderButton.back(onPressed: onBackTap),
          actions: [
            AppTabHeaderButton(
              tooltip: 'Dodaj ćwiczenie',
              icon: Icons.add_rounded,
              accent: true,
              onPressed: onAddTap,
            ),
          ],
        ),
        const SizedBox(height: 8),
        _SearchBar(
          controller: searchController,
          onChanged: onSearchChanged,
          onFilterTap: onFilterTap,
        ),
      ],
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterTap,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterTap;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late ThemeData _fieldTheme;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _fieldTheme = Theme.of(context).copyWith(
      inputDecorationTheme: const InputDecorationTheme(
        filled: false,
        fillColor: Colors.transparent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Icon(
              Icons.search_rounded,
              color: AppColors.textMuted,
              size: 20,
            ),
          ),
          Expanded(
            child: Theme(
              data: _fieldTheme,
              child: TextField(
                controller: widget.controller,
                onChanged: widget.onChanged,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                cursorColor: AppColors.primary,
                decoration: const InputDecoration(
                  hintText: 'Szukaj ćwiczeń, partii mięśni...',
                  hintStyle: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 14,
                  ),
                  filled: false,
                  fillColor: Colors.transparent,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: AppColors.border)),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
