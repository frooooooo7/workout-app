import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_colors.dart';
import '../bloc/training_history_cubit.dart';

class TrainingHistoryFiltersBar extends StatefulWidget {
  const TrainingHistoryFiltersBar({
    super.key,
    required this.state,
  });

  final TrainingHistoryState state;

  @override
  State<TrainingHistoryFiltersBar> createState() => _TrainingHistoryFiltersBarState();
}

class _TrainingHistoryFiltersBarState extends State<TrainingHistoryFiltersBar> {
  late final TextEditingController _controller;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.state.query);
  }

  @override
  void didUpdateWidget(covariant TrainingHistoryFiltersBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.query != oldWidget.state.query &&
        widget.state.query != _controller.text) {
      _controller.text = widget.state.query;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        context.read<TrainingHistoryCubit>().setQuery(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = {
      for (final item in widget.state.items) item.plan.id: item.plan.name,
      for (final item in widget.state.calendarSessions) item.plan.id: item.plan.name,
    };
    return Container(
      color: AppColors.background,
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: 'Szukaj planu lub ćwiczenia',
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: AppColors.textMuted,
                ),
              ),
              onChanged: _onChanged,
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_alt_outlined,
              color: widget.state.planFilter != null
                  ? AppColors.primaryVariant
                  : AppColors.textSecondary,
            ),
            color: AppColors.surface,
            enabled: plans.isNotEmpty,
            onSelected: (value) =>
                context.read<TrainingHistoryCubit>().setPlanFilter(value),
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: null,
                child: Text('Wszystkie plany'),
              ),
              ...plans.entries.map(
                (entry) => PopupMenuItem(
                  value: entry.key,
                  child: Text(entry.value),
                ),
              ),
            ],
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: Icon(
              widget.state.viewMode == HistoryViewMode.list
                  ? Icons.calendar_month_rounded
                  : Icons.view_list_rounded,
              color: AppColors.textSecondary,
            ),
            onPressed: () =>
                context.read<TrainingHistoryCubit>().toggleViewMode(),
            tooltip: widget.state.viewMode == HistoryViewMode.list
                ? 'Widok kalendarza'
                : 'Widok listy',
          ),
        ],
      ),
    );
  }
}
