part of 'side_bar_stats_overview.dart';

/// The legend in the graph's colours and the minute's peak and average download speed, under the graph.
class _GraphSummary extends ConsumerWidget {
  const _GraphSummary({
    required this.history,
    required this.color,
    required this.downColor,
    required this.upColor,
    required this.speed,
    this.oneLine = false,
  });

  final List<({int down, int up})> history;

  /// the text colour on the block
  final Color color;
  final Color downColor;
  final Color upColor;
  final String Function(int) speed;

  /// the legend and the figures side by side
  final bool oneLine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final solid = Theme.of(context).araLook.neonFill != null;
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: solid ? color : color.withValues(alpha: .85),
      fontWeight: solid ? FontWeight.w600 : null,
    );
    final strong = style?.copyWith(color: color, fontWeight: FontWeight.w700);
    final downs = history.map((s) => s.down).toList();
    final peak = downs.isEmpty ? 0 : downs.reduce((a, b) => a > b ? a : b);
    final average = downs.isEmpty ? 0 : downs.reduce((a, b) => a + b) ~/ downs.length;
    Widget swatch(Color c) => Container(
      width: 12,
      height: 8,
      decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2)),
    );
    Widget legend(Color c, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        swatch(c),
        const Gap(4),
        Text(text, style: style),
      ],
    );
    final figures = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '${t.avpn.graphPeak} ', style: style),
          TextSpan(text: speed(peak), style: strong),
          TextSpan(text: '  ${t.avpn.graphAverage} ', style: style),
          TextSpan(text: speed(average), style: strong),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: oneLine ? TextAlign.end : TextAlign.start,
    );
    if (oneLine) {
      return Row(
        children: [
          legend(downColor, '↓'),
          const Gap(10),
          legend(upColor, '↑'),
          const Gap(12),
          Expanded(child: figures),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 14,
          runSpacing: 4,
          children: [legend(downColor, t.avpn.statsDownload), legend(upColor, t.avpn.statsUpload)],
        ),
        const Gap(4),
        figures,
      ],
    );
  }
}

/// The last minute of download and upload speed as smooth filled curves in their own colours, on a scale
/// rounded to a readable number with its values on the side, and a time axis marked every 15 seconds.
class _SpeedGraph extends CustomPainter {
  _SpeedGraph(
    this.samples, {
    required this.color,
    required this.downColor,
    required this.upColor,
    required this.label,
    required this.detailed,
    required this.textStyle,
    required this.ticks,
    this.slots = SpeedHistory.length,
    this.slide,
  }) : super(repaint: slide);

  /// 0 → 1 over the second after a new sample: the lines slide one step to the left instead of jumping
  final Animation<double>? slide;

  /// how many samples the graph's width holds (fewer samples sit at the right)
  final int slots;

  final List<({int down, int up})> samples;

  /// the grid and the labels
  final Color color;
  final Color downColor;
  final Color upColor;

  /// a mark of the scale, given the top mark (the marks share its unit)
  final String Function(int bytesPerSecond, int top) label;
  final bool detailed;
  final TextStyle textStyle;

  /// the time axis labels, from 60 seconds ago to now (5 of them)
  final List<String> ticks;

  /// The top of the scale: 1, 2 or 5 times a power of ten in the unit the value reads in (KB/s, MB/s…), at or
  /// above [value], so the scale says "10 MB/s" rather than "9.5 MB/s". At least 1 KB/s.
  static int niceCeiling(int value) {
    if (value <= 1024) return 1024;
    var unit = 1;
    while (value / unit >= 1024) {
      unit *= 1024;
    }
    final inUnit = value / unit;
    var decade = 1;
    while (decade * 10 <= inUnit) {
      decade *= 10;
    }
    for (final m in [1, 2, 5, 10]) {
      if (decade * m >= inUnit) return decade * m * unit;
    }
    return decade * 10 * unit;
  }

  TextPainter _text(String text) => TextPainter(
    text: TextSpan(text: text, style: textStyle),
    textDirection: TextDirection.ltr,
  )..layout();

  /// A curve through [points] that never overshoots them: each segment bends towards the midpoint.
  static Path _smooth(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      path.quadraticBezierTo(a.dx, a.dy, mid.dx, mid.dy);
      if (i == points.length - 1) path.lineTo(b.dx, b.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final timeAxis = detailed ? 14.0 : 0.0;
    // the scale covers both lines: an upload burst above the download used to run off the top
    final peak = samples.fold<int>(0, (m, s) => [m, s.down, s.up].reduce((a, b) => a > b ? a : b));
    final top = niceCeiling(peak);
    final rows = detailed ? 4 : 2;
    // the scale's values sit in their own strip on the right, clear of the lines
    final labels = [for (var i = 0; i < rows; i++) _text(label((top * (rows - i) / rows).round(), top))];
    final gutter = labels.fold<double>(0, (w, l) => l.width > w ? l.width : w) + 6;
    final chart = Size(size.width - gutter, size.height - timeAxis);

    final grid = Paint()
      ..color = color.withValues(alpha: .14)
      ..strokeWidth = 1;
    for (var i = 0; i <= rows; i++) {
      final y = chart.height * i / rows;
      canvas.drawLine(Offset(0, y), Offset(chart.width, y), grid);
      // each mark centred on its line (the top one just under the edge)
      if (i < rows) {
        final h = labels[i].height;
        // a graph squeezed lower than a label (folding, unfolding) would make the range upside down and throw
        labels[i].paint(
          canvas,
          Offset(size.width - labels[i].width, (y - h / 2).clamp(0, math.max(0.0, chart.height - h))),
        );
      }
    }
    // every 15 seconds: a faint line, and on the detailed graph its label
    final step = chart.width / (slots - 1).clamp(1, 1 << 20);
    var firstEnd = 0.0;
    final lastStart = detailed && ticks.length > 4 ? chart.width - _text(ticks[4]).width : chart.width;
    for (var k = 0; k <= 4; k++) {
      final x = chart.width * k / 4;
      if (k > 0 && k < 4) {
        canvas.drawLine(Offset(x, 0), Offset(x, chart.height), grid);
      }
      if (detailed && k < ticks.length) {
        final tick = _text(ticks[k]);
        final dx = k == 0 ? 0.0 : (k == 4 ? x - tick.width : x - tick.width / 2);
        // a mark that would run into the first or the last label is left out
        final clear = k == 0 || k == 4 || (dx > firstEnd + 6 && dx + tick.width < lastStart - 6);
        if (clear) tick.paint(canvas, Offset(dx, chart.height + 2));
        if (k == 0) firstEnd = dx + tick.width;
      }
    }
    if (samples.length < 2) return;
    // nothing draws outside the chart (the end dots may reach a little over its edges)
    canvas.clipRect(Rect.fromLTRB(-6, -6, chart.width + 6, chart.height + 6));

    final start = chart.width - step * (samples.length - 1) + step * (1 - (slide?.value ?? 1));
    Offset point(int i, int value) => Offset(start + step * i, chart.height - chart.height * value / top);

    void series(List<int> values, Color c, double width, double fill) {
      final points = [for (var i = 0; i < values.length; i++) point(i, values[i])];
      final line = _smooth(points);
      // Dots with the Mono or Grotesk figures: the line solid, no fill under it
      if (solidDotsLines) {
        canvas.drawPath(
          line,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = solidLineWidth(mono: width + .8, wide: width * 2.2 + 1),
        );
        return;
      }
      // Dots: the line as a row of dots, no fill under it
      if (homeLookNow == HomeLayout.dots) {
        for (final metric in line.computeMetrics()) {
          canvas.drawPoints(
            ui.PointMode.points,
            [for (var d = 0.0; d < metric.length; d += 5) metric.getTangentForOffset(d)!.position],
            Paint()
              ..color = c
              ..strokeCap = StrokeCap.round
              ..strokeWidth = width + 1.2,
          );
        }
        return;
      }
      // Bento: a solid area under a thick line
      if (homeLookNow == HomeLayout.bento) {
        canvas.drawPath(
          Path.from(line)
            ..lineTo(points.last.dx, chart.height)
            ..lineTo(points.first.dx, chart.height)
            ..close(),
          Paint()..color = c.withValues(alpha: fill * .55),
        );
        canvas.drawPath(
          line,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = width * 1.8
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
        return;
      }
      final area = Path.from(line)
        ..lineTo(points.last.dx, chart.height)
        ..lineTo(points.first.dx, chart.height)
        ..close();
      canvas.drawPath(
        area,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              c.withValues(alpha: fill),
              c.withValues(alpha: .02),
            ],
          ).createShader(Offset.zero & chart),
      );
      canvas.drawPath(
        line,
        Paint()
          ..color = c
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // upload under download, so the download (usually the bigger one) stays on top
    series([for (final s in samples) s.up], upColor, 1.6, .35);
    series([for (final s in samples) s.down], downColor, 2.2, .6);

    // now: both values marked
    final upNow = point(samples.length - 1, samples.last.up);
    final downNow = point(samples.length - 1, samples.last.down);
    switch (homeLookNow) {
      // Dots with the Mono or Grotesk figures: round marks
      case HomeLayout.dots when solidDotsLines:
        canvas.drawCircle(upNow, 4, Paint()..color = upColor);
        canvas.drawCircle(downNow, 5.5, Paint()..color = downColor);
      // Dots: square marks
      case HomeLayout.dots:
        canvas.drawRect(Rect.fromCenter(center: upNow, width: 6, height: 6), Paint()..color = upColor);
        canvas.drawRect(Rect.fromCenter(center: downNow, width: 8, height: 8), Paint()..color = downColor);
      // Bento: big round marks with a white middle
      case HomeLayout.bento:
        canvas.drawCircle(upNow, 4.5, Paint()..color = upColor);
        canvas.drawCircle(downNow, 6, Paint()..color = downColor);
        canvas.drawCircle(downNow, 2.2, Paint()..color = Colors.white);
      default:
        canvas.drawCircle(upNow, 3, Paint()..color = upColor);
        canvas.drawCircle(downNow, 3.8, Paint()..color = downColor);
    }
  }

  @override
  bool shouldRepaint(_SpeedGraph old) =>
      old.samples != samples || old.color != color || old.downColor != downColor || old.upColor != upColor;
}
