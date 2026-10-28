import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// One block of a [FitBlocks] column: the [group] it belongs to (the blocks in their order on the page) and its [rank]
/// in it: 0 is the full block, 1 a smaller one in its place, and so on.
class FitSlot extends ParentDataWidget<_FitParentData> {
  const FitSlot({super.key, required this.group, this.rank = 0, required super.child});

  final int group;
  final int rank;

  @override
  void applyParentData(RenderObject renderObject) {
    final data = renderObject.parentData! as _FitParentData;
    var changed = false;
    if (data.group != group) {
      data.group = group;
      changed = true;
    }
    if (data.rank != rank) {
      data.rank = rank;
      changed = true;
    }
    if (changed) renderObject.parent?.markNeedsLayout();
  }

  @override
  Type get debugTypicalAncestorWidgetClass => FitBlocks;
}

/// A step of making room: the [group] goes down to [rank], or off the page when [rank] is -1.
typedef FitStep = ({int group, int rank});

/// Blocks one under another that always fit the height: when they don't all fit whole, the [steps] are taken one by
/// one (a block off, a smaller one in its place) until they do, and what room is left is shared in equal gaps between
/// the blocks (and one under the last). The first group is the page's head, with its own space under it.
class FitBlocks extends MultiChildRenderObjectWidget {
  const FitBlocks({super.key, required this.steps, this.minGap = 10, required super.children});

  final List<FitStep> steps;

  /// the least gap between two blocks
  final double minGap;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderFitBlocks(steps: steps, minGap: minGap);

  @override
  void updateRenderObject(BuildContext context, _RenderFitBlocks renderObject) {
    renderObject
      ..steps = steps
      ..minGap = minGap;
  }
}

class _FitParentData extends ContainerBoxParentData<RenderBox> {
  int group = 0;
  int rank = 0;
  bool shown = true;
}

class _RenderFitBlocks extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _FitParentData>, RenderBoxContainerDefaultsMixin<RenderBox, _FitParentData> {
  _RenderFitBlocks({required List<FitStep> steps, required double minGap}) : _steps = steps, _minGap = minGap;

  List<FitStep> _steps;
  set steps(List<FitStep> value) {
    if (identical(value, _steps)) return;
    _steps = value;
    markNeedsLayout();
  }

  double _minGap;
  set minGap(double value) {
    if (value == _minGap) return;
    _minGap = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _FitParentData) child.parentData = _FitParentData();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  double computeMinIntrinsicHeight(double width) => 0;

  @override
  double computeMaxIntrinsicHeight(double width) => 0;

  @override
  void performLayout() {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;
    final children = <RenderBox>[];
    var child = firstChild;
    while (child != null) {
      children.add(child);
      child = childAfter(child);
    }
    // every block as it is on its own
    final natural = <RenderBox, double>{};
    for (final c in children) {
      c.layout(BoxConstraints(minWidth: width, maxWidth: width, maxHeight: height.isFinite ? height : double.infinity), parentUsesSize: true);
      natural[c] = c.size.height;
    }
    final groups = <int>{for (final c in children) (c.parentData! as _FitParentData).group}.toList()..sort();
    // the rank each group is at now (-1: off the page)
    final rank = {for (final g in groups) g: 0};
    RenderBox? pick(int g) {
      for (final c in children) {
        final d = c.parentData! as _FitParentData;
        if (d.group == g && d.rank == rank[g]) return c;
      }
      return null;
    }

    double need() {
      var sum = 0.0;
      var count = 0;
      for (final g in groups) {
        final c = pick(g);
        if (c == null) continue;
        sum += natural[c]!;
        // the head has its own space under it
        if (g != groups.first) count++;
      }
      return sum + _minGap * count;
    }

    var next = 0;
    final taken = <(int, int)>[]; // the group and the rank it had before the step
    while (height.isFinite && need() > height && next < _steps.length) {
      final step = _steps[next++];
      if (!rank.containsKey(step.group)) continue;
      taken.add((step.group, rank[step.group]!));
      rank[step.group] = step.rank;
      // a rank that has no block is off the page
      if (pick(step.group) == null) rank[step.group] = -1;
    }
    // the steps taken are tried back, the last first: what still fits with the room that came free is put back
    for (final (group, before) in taken.reversed) {
      final now = rank[group]!;
      rank[group] = before;
      if (need() > height) rank[group] = now;
    }

    // what is on the page, in equal gaps
    final shown = <RenderBox>[];
    for (final g in groups) {
      final c = pick(g);
      if (c != null) shown.add(c);
    }
    for (final c in children) {
      (c.parentData! as _FitParentData).shown = shown.contains(c);
    }
    final heights = shown.fold<double>(0, (s, c) => s + natural[c]!);
    final head = shown.isNotEmpty && (shown.first.parentData! as _FitParentData).group == groups.first;
    final gaps = shown.length - (head ? 1 : 0);
    final free = height.isFinite ? math.max(0.0, height - heights) : _minGap * gaps;
    final gap = gaps <= 0 ? 0.0 : math.max(_minGap, free / gaps);
    var y = 0.0;
    for (final (i, c) in shown.indexed) {
      (c.parentData! as _FitParentData).offset = Offset(0, y);
      y += natural[c]!;
      if (!(head && i == 0)) {
        y += gap;
      }
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    var child = firstChild;
    while (child != null) {
      final data = child.parentData! as _FitParentData;
      if (data.shown) context.paintChild(child, data.offset + offset);
      child = childAfter(child);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    var child = lastChild;
    while (child != null) {
      final data = child.parentData! as _FitParentData;
      if (data.shown) {
        final hit = result.addWithPaintOffset(
          offset: data.offset,
          position: position,
          hitTest: (result, transformed) => child!.hitTest(result, position: transformed),
        );
        if (hit) return true;
      }
      child = childBefore(child);
    }
    return false;
  }
}
