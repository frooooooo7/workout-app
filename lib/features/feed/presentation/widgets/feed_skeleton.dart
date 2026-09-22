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
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            const _SkeletonStrip(),
            const SizedBox(height: 14),
            for (var i = 0; i < widget.count; i++)
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 0, 12, 16),
                child: _SkeletonCard(),
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonStrip extends StatelessWidget {
  const _SkeletonStrip();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(width: 20),
        itemBuilder: (_, _) => const Column(
          children: [
            SizedBox(height: 2),
            _Block(width: 54, height: 54, radius: 18),
            SizedBox(height: 8),
            _Block(width: 40, height: 9),
          ],
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.55)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Block(width: 54, height: 54, radius: 18),
              SizedBox(width: 12),
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
          _Block(height: 64, radius: 16),
          SizedBox(height: 16),
          _Block(height: 11),
          SizedBox(height: 7),
          _Block(width: 220, height: 11),
          SizedBox(height: 18),
          Row(
            children: [
              Expanded(child: _Block(height: 42, radius: 21)),
              SizedBox(width: 8),
              Expanded(child: _Block(height: 42, radius: 21)),
            ],
          ),
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
