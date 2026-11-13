part of 'avpn_home_body.dart';

/// Dots' sites: a line for each, the name on the left and the delay on the right, red when it is slow.
class _SiteDots extends HookConsumerWidget {
  const _SiteDots();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) {
      // no sites marked for the home screen: the block's head stays (its buttons are how the multi-server mode and the fewer hops
      // are reached), with a line on where the sites are chosen
      final t = ref.watch(translationsProvider).requireValue;
      return _dotPaper(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SitesHeader(),
            const Gap(8),
            Text(
              t.avpn.sitesNoneHint,
              textAlign: TextAlign.center,
              style: _Dots.mono(10, _Dots.soft(Theme.of(context).brightness == Brightness.dark), spacing: 0.6),
            ),
          ],
        ),
      );
    }
    final style = ref.watch(Preferences.siteGraph);
    final ink = _Dots.ink(dark);
    final soft = _Dots.soft(dark);
    final faint = _Dots.grid(dark);
    // a tap on the block itself (the pills of its head have their own) chooses how the sites are shown
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => unawaited(_pickSiteGraph(context, ref, style)),
      child: _dotPaper(
        context,
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SitesHeader(),
            switch (style) {
              SiteGraph.list => Column(
                children: [
                  for (final e in entries)
                    _dotRow(
                      context,
                      e.name,
                      !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                      valueColour: e.measured && e.colour != _SiteTiles._good ? _Dots.red : null,
                      country: e.country,
                    ),
                ],
              ),
              SiteGraph.scales => Column(
                children: [
                  for (final e in entries)
                    _sitePlate(
                      dark,
                      e,
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: _flaggedText(e, e.name.toUpperCase(), _Dots.mono(11, soft)),
                                ),
                              ),
                              _siteFigure(e, ink),
                            ],
                          ),
                          const Gap(3),
                          SizedBox(
                            height: 8,
                            child: CustomPaint(
                              painter: _SitePainter(
                                kind: SiteGraph.scales,
                                ms: e.measured ? e.ms : null,
                                ink: ink,
                                accent: _Dots.red,
                                faint: faint,
                                slowAt: _siteSlowAt(ref),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              SiteGraph.digits => Column(
                children: [
                  for (var i = 0; i < entries.length; i += 3)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Row(
                        children: [
                          for (var k = i; k < i + 3; k++)
                            Expanded(
                              child: k < entries.length
                                  ? _flagPlate(dark, entries[k], _siteDigits(entries[k], ink, soft, faint))
                                  : const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
              SiteGraph.columns => Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  children: [
                    for (final e in entries)
                      Expanded(
                        child: _flagPlate(
                          dark,
                          e,
                          Column(
                            children: [
                              SizedBox(
                                height: 7 * 14.0,
                                width: 16,
                                child: CustomPaint(
                                  painter: _SitePainter(
                                    kind: SiteGraph.columns,
                                    ms: e.measured ? e.ms : null,
                                    ink: ink,
                                    accent: _Dots.red,
                                    faint: faint,
                                    slowAt: _siteSlowAt(ref),
                                  ),
                                ),
                              ),
                              const Gap(6),
                              // a site with a server of its own: its flag over the name (the line is kept for all)
                              if (keepSiteLine(entries.any((x) => x.flag.isNotEmpty)))
                                SizedBox(
                                  height: 14,
                                  child: e.flag.isEmpty ? null : Center(child: flagMark(e.flag, width: 18)),
                                ),
                              // the same gap between the flag, the name and the figure
                              const Gap(5),
                              // the whole name, as small as it takes to fit its column
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: SizedBox(
                                  height: 13,
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      e.name.toUpperCase(),
                                      maxLines: 1,
                                      style: _Dots.mono(9, soft, spacing: 0),
                                    ),
                                  ),
                                ),
                              ),
                              const Gap(5),
                              _siteFigure(e, ink, size: 11, align: Alignment.center),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SiteGraph.lanes => Column(
                children: [
                  for (final e in entries)
                    _sitePlate(
                      dark,
                      e,
                      SizedBox(
                        height: 22,
                        child: Row(
                          children: [
                            SizedBox(
                              width: 86,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: _flaggedText(
                                  e,
                                  e.name.toUpperCase(),
                                  _Dots.mono(10, soft, spacing: .2),
                                  fit: true,
                                ),
                              ),
                            ),
                            Expanded(
                              child: CustomPaint(
                                size: const Size.fromHeight(22),
                                painter: _SitePainter(
                                  kind: SiteGraph.lanes,
                                  ms: e.measured ? e.ms : null,
                                  ink: ink,
                                  accent: _Dots.red,
                                  faint: faint,
                                  slowAt: _siteSlowAt(ref),
                                ),
                              ),
                            ),
                            SizedBox(width: 52, child: _siteFigure(e, ink)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            },
          ],
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      ),
    );
  }
}

/// A site's name with its flag before it (when its server is in another country), the name cut by an ellipsis.
Widget _flaggedText(_SiteEntry e, String text, TextStyle style, {String suffix = '', bool fit = false}) {
  // [fit]: the whole name, as small as it takes to fit the room it has (not cut by an ellipsis)
  final label = fit
      ? FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('$text$suffix', maxLines: 1, style: style),
        )
      : Text('$text$suffix', maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
  if (e.flag.isEmpty) return label;
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      flagMark(e.flag, width: 15),
      const Gap(5),
      Flexible(child: label),
    ],
  );
}

/// (the sites with a server of their own are marked by the flag alone, no plate under them)
Widget _flagPlate(bool dark, _SiteEntry e, Widget child) => child;

/// A site's delay in big dots with its name under it (a second and a half is 1.5, in seconds).
Widget _siteDigits(_SiteEntry e, Color ink, Color soft, Color faint) {
  final slow = e.measured && e.colour != _SiteTiles._good;
  final ms = e.ms;
  final text = !e.measured || ms == null ? '—' : (ms >= 1000 ? (ms / 1000).toStringAsFixed(1) : '$ms');
  return Column(
    children: [
      _DotNumber(text, cell: 4.2, colour: slow ? _Dots.red : ink, faint: faint),
      const Gap(5),
      _flaggedText(
        e,
        e.name.toUpperCase(),
        _Dots.mono(9, soft, spacing: .4),
        suffix: ms != null && ms >= 1000 ? ' · С' : '',
        fit: true,
      ),
    ],
  );
}

/// The figure of a site's delay, the accent when it is slow.
Widget _siteFigure(_SiteEntry e, Color ink, {double size = 15, Alignment align = Alignment.centerRight}) => Align(
  alignment: align,
  child: Text(
    !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
    style: _Dots.mono(
      size,
      e.measured && e.colour != _SiteTiles._good ? _Dots.red : ink,
      weight: FontWeight.w800,
      spacing: .5,
    ),
  ),
);

/// A line of the sites' block (the flag before the name says that its server is another one).
Widget _sitePlate(bool dark, _SiteEntry e, Widget row) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: row);

/// The dots of a site: a row filled up to the delay (scales), a column of them (columns), a runner on a track (lanes).
class _SitePainter extends CustomPainter {
  _SitePainter({
    required this.kind,
    required this.ms,
    required this.ink,
    required this.accent,
    required this.faint,
    int? slowAt,
  }) : slowAt = slowAt ?? alertLimits(mobile: _actualNetworkKind.value == NetworkKind.mobile).siteSlow;

  final SiteGraph kind;
  final int? ms;
  final Color ink;
  final Color accent;
  final Color faint;

  /// the delay from which the dots turn to the accent (by the network: mobile data is milder)
  final int slowAt;

  @override
  void paint(Canvas canvas, Size size) {
    void dot(Offset at, double r, Color c) => canvas.drawCircle(at, r, Paint()..color = c);
    final slow = ms != null && ms! >= slowAt;
    switch (kind) {
      case SiteGraph.columns:
        const rows = 7;
        final lit = ms == null ? 0 : (ms! / (400 / rows)).round().clamp(1, rows);
        final rh = size.height / rows;
        for (var r = 0; r < rows; r++) {
          final at = Offset(size.width / 2, size.height - rh / 2 - r * rh);
          if (r < lit) {
            dot(at, 4.2, slow ? accent : ink);
          } else {
            dot(at, 1.4, faint);
          }
        }
      case SiteGraph.lanes:
        const n = 26;
        final gw = size.width / n;
        final y = size.height / 2;
        for (var k = 0; k < n; k++) {
          dot(Offset(gw * k + gw / 2, y), 1.2, faint);
        }
        if (ms != null) {
          // the faster, the nearer the finish on the right
          final run = 1 - (ms!.clamp(0, 400) / 400);
          final head = size.width * run;
          for (var t = 0; t < 5; t++) {
            dot(Offset(math.max(3.0, head - t * 7), y), 3.4 - t * .5, slow ? accent : ink);
          }
        }
        canvas.drawLine(
          Offset(size.width - 1, y - 8),
          Offset(size.width - 1, y + 8),
          Paint()
            ..color = faint
            ..strokeWidth = 1,
        );
      case _:
        const n = 36;
        final gw = size.width / n;
        for (var k = 0; k < n; k++) {
          final v = k / (n - 1) * 400;
          final on = ms != null && v <= ms!;
          final hot = v >= 240;
          dot(Offset(gw * k + gw / 2, size.height / 2), on ? 2.4 : 1.1, on ? (hot ? accent : ink) : faint);
        }
    }
  }

  @override
  bool shouldRepaint(_SitePainter old) =>
      old.kind != kind || old.ms != ms || old.ink != ink || old.accent != accent || old.faint != faint;
}

/// The menu of the ways the sites' block shows the delays.
Future<void> _pickSiteGraph(BuildContext context, WidgetRef ref, SiteGraph now) {
  final ru = ref.read(translationsProvider).requireValue.$meta.locale.languageCode == 'ru';
  return showDialog<void>(
    context: context,
    builder: (dialog) => SimpleDialog(
      title: Text(ru ? 'Вид сайтов' : 'Sites view'),
      children: [
        for (final g in SiteGraph.values)
          ListTile(
            dense: true,
            title: Text(ru ? g.ru : g.en),
            trailing: g == now ? const Icon(Icons.check_rounded) : null,
            onTap: () {
              unawaited(ref.read(Preferences.siteGraph.notifier).update(g));
              Navigator.of(dialog).pop();
            },
          ),
      ],
    ),
  );
}

/// The sites' block in its short form, for a page too low for the whole one (an unfolded phone's half, a car's screen):
/// the names and the delays in a few lines, nothing else. Taken before the block goes off the page altogether.
class _SiteDotsCompact extends HookConsumerWidget {
  const _SiteDotsCompact();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final entries = _siteEntries(ref, scheme);
    if (entries.isEmpty) return const SizedBox.shrink();
    final ink = _Dots.ink(dark);
    final soft = _Dots.soft(dark);
    return _dotPaper(
      context,
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 16,
        runSpacing: 8,
        children: [
          for (final e in entries)
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '${e.name.toUpperCase()}  ', style: _Dots.mono(11, soft)),
                  TextSpan(
                    text: !e.measured ? '…' : (e.ms == null ? '—' : '${e.ms}'),
                    style: _Dots.mono(14, e.measured && e.colour != _SiteTiles._good ? _Dots.red : ink),
                  ),
                ],
              ),
            ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    );
  }
}



/// The delay from which a site's dots turn red: the same marks the other looks use for the chosen method (HTTPS is slower
/// by nature, so its mark is wider than HTTP's) and the network (mobile data is milder).
int _siteSlowAt(WidgetRef ref) =>
    siteGrade(ref.watch(ConfigOptions.pingHttps), mobile: _actualNetworkKind.value == NetworkKind.mobile).slow;
