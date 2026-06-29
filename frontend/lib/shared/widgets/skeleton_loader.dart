import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Skeleton loader widget for loading states
class SkeletonLoader extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final ShapeBorder? shape;

  const SkeletonLoader({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape,
  });

  /// Create a circular skeleton loader
  factory SkeletonLoader.circular({
    double size = 40,
  }) {
    return SkeletonLoader(
      width: size,
      height: size,
      shape: const CircleBorder(),
    );
  }

  /// Create a rectangular skeleton loader
  factory SkeletonLoader.rectangular({
    double? width,
    double? height,
    double borderRadius = 8,
  }) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: borderRadius,
    );
  }

  /// Create a text line skeleton
  factory SkeletonLoader.text({
    double width = double.infinity,
    double height = 14,
  }) {
    return SkeletonLoader(
      width: width,
      height: height,
      borderRadius: 4,
    );
  }

  @override
  State<SkeletonLoader> createState() => _SkeletonLoaderState();
}

class _SkeletonLoaderState extends State<SkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: widget.shape != null
              ? null
              : BorderRadius.circular(widget.borderRadius),
          shape: widget.shape is CircleBorder
              ? BoxShape.circle
              : BoxShape.rectangle,
        ),
      ),
    );
  }
}

/// Card skeleton for loading state
class CardSkeleton extends StatelessWidget {
  final int itemCount;
  final Axis direction;

  const CardSkeleton({
    super.key,
    this.itemCount = 4,
    this.direction = Axis.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final list = List.generate(itemCount, (index) => index);

    if (direction == Axis.horizontal) {
      return ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, index) => const SizedBox(
          width: 200,
          child: _CardSkeletonItem(),
        ),
      );
    }

    return Column(
      children: list
          .map((_) => const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: _CardSkeletonItem(),
              ))
          .toList(),
    );
  }
}

class _CardSkeletonItem extends StatelessWidget {
  const _CardSkeletonItem();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader.circular(size: 40),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader.text(width: 100),
                      const SizedBox(height: 6),
                      SkeletonLoader.text(width: 60, height: 12),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SkeletonLoader.text(),
            const SizedBox(height: 8),
            SkeletonLoader.text(width: 150),
          ],
        ),
      ),
    );
  }
}

/// Table row skeleton
class TableSkeleton extends StatelessWidget {
  final int columnCount;
  final int rowCount;

  const TableSkeleton({
    super.key,
    this.columnCount = 5,
    this.rowCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: List.generate(
              columnCount,
              (index) => Expanded(
                child: Padding(
                  padding:
                      EdgeInsets.only(right: index < columnCount - 1 ? 16 : 0),
                  child: SkeletonLoader.text(height: 16),
                ),
              ),
            ),
          ),
        ),
        const Divider(height: 1),
        // Rows
        ...List.generate(
          rowCount,
          (rowIndex) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: List.generate(
                columnCount,
                (index) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                        right: index < columnCount - 1 ? 16 : 0),
                    child: SkeletonLoader.text(height: 14),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Page skeleton for full-page loading
class PageSkeleton extends StatelessWidget {
  final bool showHeader;
  final bool showStats;

  const PageSkeleton({
    super.key,
    this.showHeader = true,
    this.showStats = true,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showHeader) ...[
            SkeletonLoader.text(width: 200, height: 28),
            const SizedBox(height: 8),
            SkeletonLoader.text(width: 300, height: 16),
            const SizedBox(height: 24),
          ],
          if (showStats) ...[
            const CardSkeleton(itemCount: 4),
          ],
          const SizedBox(height: 24),
          SkeletonLoader.text(width: 150, height: 20),
          const SizedBox(height: 16),
          const TableSkeleton(),
        ],
      ),
    );
  }
}
