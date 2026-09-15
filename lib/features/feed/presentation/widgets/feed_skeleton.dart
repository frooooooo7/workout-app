import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Szkielet listy postów na czas pierwszego wczytania.
class FeedSkeleton extends StatefulWidget {
  const FeedSkeleton({super.key, this.count = 3});

  final int count;

  @override
  State<FeedSkeleton> createState() => _FeedSkeletonState();
}

class _FeedSkeletonState extends State<FeedSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
    lowerBound: 0.55,
    upperBound: 1,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Wczytywanie feedu',
      child: FadeTransition(
        opacity: _controller,
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: widget.count,
          separatorBuilder: (_, _) => const SizedBox(height: 14),
          itemBuilder: (_, _) => const _SkeletonCard(),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Block(width: 36, height: 36, radius: 11),
              SizedBox(width: 11),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Block(width: 120, height: 12),
                  SizedBox(height: 6),
                  _Block(width: 80, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 16),
          _Block(width: 170, height: 16),
          SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _Block(height: 30)),
              SizedBox(width: 12),
              Expanded(child: _Block(height: 30)),
              SizedBox(width: 12),
              Expanded(child: _Block(height: 30)),
            ],
          ),
          SizedBox(height: 16),
          _Block(height: 11),
          SizedBox(height: 7),
          _Block(width: 220, height: 11),
          SizedBox(height: 18),
          _Block(height: 32),
        ],
      ),
    );
  }
}

class _Block extends StatelessWidget {
  const _Block({this.width, required this.height, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
