import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A country's flag as a small grid of square pixels (Dots): the stripes, crosses and discs of the commonest countries;
/// any other country keeps its emoji.
Widget flagMark(String? flag, {double width = 26}) {
  if (flag == null || flag.isEmpty) {
    return Text(
      '🌐',
      style: TextStyle(fontSize: width * .66, height: 1, fontFamilyFallback: const ['Emoji']),
    );
  }
  return FlagMark(flag, width);
}

/// A flag in pixels: the pattern drawn by hand when there is one, else the country's emoji of the bundled font turned
/// into the same grid (drawn to a picture once, each cell the average of its block), so every country has a pixel flag.
class FlagMark extends StatefulWidget {
  const FlagMark(this.flag, this.width);

  final String flag;
  final double width;

  @override
  State<FlagMark> createState() => _FlagMarkState();
}

class _FlagMarkState extends State<FlagMark> {
  List<List<Color>>? _grid;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(FlagMark old) {
    super.didUpdateWidget(old);
    if (old.flag != widget.flag) _resolve();
  }

  void _resolve() {
    final flag = widget.flag;
    _grid = PixelFlag.of(flag) ?? PixelFlag.pixelated[flag];
    _failed = false;
    if (_grid != null) return;
    unawaited(
      PixelFlag.pixelate(flag).then((grid) {
        if (!mounted || widget.flag != flag) return;
        setState(() {
          _grid = grid;
          _failed = grid == null;
        });
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final grid = _grid;
    if (grid != null) {
      return CustomPaint(size: Size(widget.width, widget.width * 2 / 3), painter: PixelFlag(grid));
    }
    if (_failed) {
      return Text(
        widget.flag,
        style: TextStyle(fontSize: widget.width * .66, height: 1, fontFamilyFallback: const ['Emoji']),
      );
    }
    // while the picture is made: the room of the flag
    return SizedBox(width: widget.width, height: widget.width * 2 / 3);
  }
}

class PixelFlag extends CustomPainter {
  PixelFlag(this.grid, {this.dots = true});

  final List<List<Color>> grid;

  /// a round dot for each cell (the topology's flags) instead of a square
  final bool dots;

  static const cols = 12;
  static const rows = 8;

  static const _k = Color(0xFF151515);
  static const _w = Color(0xFFF2F2EE);
  static const _r = Color(0xFFD52B1E);
  static const _bl = Color(0xFF0057B8);
  static const _y = Color(0xFFFFD500);
  static const _g = Color(0xFF1FA34A);
  static const _o = Color(0xFFFF883E);
  static const _mar = Color(0xFF9E3039);
  static const _sky = Color(0xFF00AFCA);

  static Color Function(int, int) _hs(List<(Color, int)> parts) {
    final rowsOf = [
      for (final (c, n) in parts)
        for (var i = 0; i < n; i++) c,
    ];
    return (x, y) => rowsOf[y];
  }

  static Color Function(int, int) _vs(Color a, Color b, Color c) =>
      (x, y) => x < 4 ? a : (x < 8 ? b : c);

  static Color Function(int, int) _cross(Color bg, Color cross) =>
      (x, y) => (x == 3 || x == 4 || y == 3 || y == 4) ? cross : bg;

  static double _dist(int x, int y) => math.sqrt(math.pow(x - 5.5, 2) + math.pow(y - 3.5, 2));

  static final Map<String, Color Function(int, int)> _flags = {
    'DE': _hs([(_k, 3), (_r, 2), (_y, 3)]),
    'NL': _hs([(_r, 3), (_w, 2), (_bl, 3)]),
    'PL': _hs([(_w, 4), (_r, 4)]),
    'LV': _hs([(_mar, 3), (_w, 2), (_mar, 3)]),
    'LT': _hs([(_y, 3), (_g, 2), (_r, 3)]),
    'EE': _hs([(_bl, 3), (_k, 2), (_w, 3)]),
    'RU': _hs([(_w, 3), (_bl, 2), (_r, 3)]),
    'UA': _hs([(_bl, 4), (_y, 4)]),
    'AT': _hs([(_r, 3), (_w, 2), (_r, 3)]),
    'HU': _hs([(_r, 3), (_w, 2), (_g, 3)]),
    'BG': _hs([(_w, 3), (_g, 2), (_r, 3)]),
    'ES': _hs([(_r, 2), (_y, 4), (_r, 2)]),
    'SG': _hs([(_r, 4), (_w, 4)]),
    'FR': _vs(_bl, _w, _r),
    'IT': _vs(_g, _w, _r),
    'BE': _vs(_k, _y, _r),
    'RO': _vs(_bl, _y, _r),
    'IE': _vs(_g, _w, _o),
    'FI': _cross(_w, _bl),
    'SE': _cross(_bl, _y),
    'DK': _cross(_r, _w),
    'NO': _cross(_r, _w),
    'CH': (x, y) => ((x >= 5 && x <= 6 && y >= 1 && y <= 6) || (y >= 3 && y <= 4 && x >= 3 && x <= 8)) ? _w : _r,
    // the Union Jack: a red cross on a white one, white diagonals over the blue
    'GB': (x, y) {
      if ((x >= 5 && x <= 6) || (y >= 3 && y <= 4)) return _r;
      if ((x >= 4 && x <= 7) || (y >= 2 && y <= 5)) return _w;
      // the diagonals of the 12 by 8 field (slope 8/12), a cell and a bit thick
      final dx = x + .5 - 6;
      final dy = y + .5 - 4;
      final near = math.min((dy - dx * 2 / 3).abs(), (dy + dx * 2 / 3).abs());
      return near < .85 ? _w : _bl;
    },
    'US': (x, y) => (x < 5 && y < 4) ? _bl : (y.isEven ? _r : _w),
    'TR': (x, y) => _dist(x, y) < 1.9 ? _w : _r,
    'JP': (x, y) => _dist(x, y) < 2.3 ? _r : _w,
    'KZ': (x, y) => _dist(x, y) < 2.0 ? _y : _sky,
    'CZ': (x, y) => (x <= 4 && (y - 3.5).abs() <= (4.6 - x) * .85) ? _bl : (y < 4 ? _w : _r),
    'PT': (x, y) => x < 5 ? _g : _r,
    'CA': (x, y) => (x >= 5 && x <= 6 && y >= 2 && y <= 5) ? _r : ((x < 3 || x >= 9) ? _r : _w),
  };

  static final _cache = <String, List<List<Color>>?>{};

  /// the flags made from the emoji, by the emoji (kept: a flag is drawn once)
  static final pixelated = <String, List<List<Color>>?>{};
  static final _making = <String, Future<List<List<Color>>?>>{};

  /// The country's emoji drawn to a picture and cut to the grid; null when the font has no picture for it.
  static Future<List<List<Color>>?> pixelate(String flag) => _making.putIfAbsent(flag, () async {
    try {
      final painter = TextPainter(
        text: TextSpan(
          text: flag,
          style: const TextStyle(fontSize: 120, height: 1, fontFamily: 'Emoji', color: Color(0xFF000000)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = painter.width.ceil();
      final h = painter.height.ceil();
      if (w < 8 || h < 8) return null;
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), Offset.zero);
      final image = await recorder.endRecording().toImage(w, h);
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      if (data == null) return null;
      final px = data.buffer.asUint8List();
      // the box the flag takes in the picture
      var x0 = w, y0 = h, x1 = -1, y1 = -1;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          if (px[(y * w + x) * 4 + 3] > 40) {
            if (x < x0) x0 = x;
            if (x > x1) x1 = x;
            if (y < y0) y0 = y;
            if (y > y1) y1 = y;
          }
        }
      }
      if (x1 - x0 < 8 || y1 - y0 < 8) return null;
      final bw = (x1 - x0 + 1) / cols;
      final bh = (y1 - y0 + 1) / rows;
      final grid = <List<Color>>[];
      for (var cy = 0; cy < rows; cy++) {
        final row = <Color>[];
        for (var cx = 0; cx < cols; cx++) {
          var r = 0.0, g = 0.0, b = 0.0, a = 0.0;
          final xa = (x0 + cx * bw).floor(), xb = (x0 + (cx + 1) * bw).ceil();
          final ya = (y0 + cy * bh).floor(), yb = (y0 + (cy + 1) * bh).ceil();
          for (var y = ya; y < yb && y < h; y++) {
            for (var x = xa; x < xb && x < w; x++) {
              final i = (y * w + x) * 4;
              final alpha = px[i + 3] / 255;
              r += px[i] * alpha;
              g += px[i + 1] * alpha;
              b += px[i + 2] * alpha;
              a += alpha;
            }
          }
          row.add(
            a < 1 ? const Color(0xFF808080) : Color.fromARGB(255, (r / a).round(), (g / a).round(), (b / a).round()),
          );
        }
        grid.add(row);
      }
      return pixelated[flag] = grid;
    } catch (_) {
      return null;
    }
  });

  /// the pixels of a flag emoji's country, null when there is no pattern for it
  static List<List<Color>>? of(String flag) => _cache.putIfAbsent(flag, () {
    final letters = flag.runes.where((r) => r >= 0x1F1E6 && r <= 0x1F1FF).toList();
    if (letters.length < 2) return null;
    final code = String.fromCharCodes([letters[0] - 0x1F1E6 + 65, letters[1] - 0x1F1E6 + 65]);
    final cell = _flags[code];
    if (cell == null) return null;
    return [
      for (var y = 0; y < rows; y++) [for (var x = 0; x < cols; x++) cell(x, y)],
    ];
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cell = size.width / cols;
    final side = cell * .88;
    // a thin frame, so a white stripe does not melt into the paper (the dots need none)
    if (!dots) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = const Color(0x66808080)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    if (dots) {
      for (var y = 0; y < rows; y++) {
        for (var x = 0; x < cols; x++) {
          canvas.drawCircle(
            Offset((x + .5) * cell, (y + .5) * cell),
            cell * (size.width < 24 ? .56 : .47),
            Paint()..color = grid[y][x],
          );
        }
      }
      return;
    }
    for (var y = 0; y < rows; y++) {
      for (var x = 0; x < cols; x++) {
        canvas.drawRect(
          Rect.fromLTWH(x * cell + (cell - side) / 2, y * cell + (cell - side) / 2, side, side),
          Paint()..color = grid[y][x],
        );
      }
    }
  }

  @override
  bool shouldRepaint(PixelFlag old) => !identical(old.grid, grid) || old.dots != dots;
}

/// A country's flag drawn on a canvas as pixels, centred on [centre], [width] wide; false while there is no pixel flag
/// for it yet (it is being made: the caller draws the emoji, the next repaint finds the pixels).
bool paintPixelFlag(Canvas canvas, String flag, Offset centre, double width, {double alpha = 1, bool dots = true}) {
  final grid = PixelFlag.of(flag) ?? PixelFlag.pixelated[flag];
  if (grid == null) {
    unawaited(PixelFlag.pixelate(flag));
    return false;
  }
  final box = Rect.fromCenter(center: centre, width: width, height: width * 2 / 3);
  canvas.save();
  canvas.translate(box.left, box.top);
  if (alpha < 1) canvas.saveLayer(Offset.zero & box.size, Paint()..color = Color.fromRGBO(0, 0, 0, alpha));
  PixelFlag(grid, dots: dots).paint(canvas, box.size);
  if (alpha < 1) canvas.restore();
  canvas.restore();
  return true;
}

/// A text whose flag emojis are pixel flags ([width] wide, in the line): "через VPN · 🇸🇪 🇱🇻" in the Dots look.
Widget flagsText(String text, {TextStyle? style, int maxLines = 1, double width = 15}) {
  final flag = RegExp(r'[\u{1F1E6}-\u{1F1FF}]{2}', unicode: true);
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in flag.allMatches(text)) {
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    spans.add(
      WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: flagMark(m.group(0), width: width),
      ),
    );
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return Text.rich(
    TextSpan(children: spans, style: style),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
  );
}

/// An app's own icon, decoded, to be drawn with a thin grid of pixels over it (Dots).
class PixelIcon {
  const PixelIcon(this.image, this.source);

  final ui.Image image;

  /// the part of the picture that is the icon: a square round what is drawn in it, so icons with wide empty margins
  /// (a round one on nothing) come out as big as those that fill their tile
  final Rect source;
}

/// The icons of the apps as [PixelIcon]s: decoded once for an app, as it is met; [revision] ticks when a new one is ready,
/// so the picture that waits for it draws again.
class PixelIcons {
  static const _side = 192;

  static final _icons = <String, PixelIcon>{};
  static final _making = <String, Future<void>>{};
  static final _failed = <String>{};

  /// ticks when an icon is ready
  static final revision = ValueNotifier<int>(0);

  /// the icon of the app [key] from its [png], or null while it is made (it is started now)
  static PixelIcon? of(String key, Uint8List png) {
    final kept = _icons[key];
    if (kept != null) return kept;
    unawaited(_making.putIfAbsent(key, () => _make(key, png)));
    return null;
  }

  static Future<void> _make(String key, Uint8List png) async {
    try {
      final codec = await ui.instantiateImageCodec(png, targetWidth: _side, targetHeight: _side);
      final frame = await codec.getNextFrame();
      codec.dispose();
      final data = await frame.image.toByteData();
      var left = _side, top = _side, right = -1, bottom = -1;
      if (data != null) {
        for (var y = 0; y < _side; y++) {
          for (var x = 0; x < _side; x++) {
            if (data.getUint8((y * _side + x) * 4 + 3) < 48) continue;
            if (x < left) left = x;
            if (x > right) right = x;
            if (y < top) top = y;
            if (y > bottom) bottom = y;
          }
        }
      }
      const whole = _side * 1.0;
      var source = const Rect.fromLTWH(0, 0, whole, whole);
      if (right > left && bottom > top) {
        final side = math.min(whole, (math.max(right - left, bottom - top) + 1) * 1.02);
        final cx = (left + right + 1) / 2, cy = (top + bottom + 1) / 2;
        final x = (cx - side / 2).clamp(0.0, whole - side).toDouble();
        final y = (cy - side / 2).clamp(0.0, whole - side).toDouble();
        source = Rect.fromLTWH(x, y, side, side);
      }
      _icons[key] = PixelIcon(frame.image, source);
      revision.value++;
    } catch (_) {
      // an icon that cannot be read stays as the picture it is
      _failed.add(key);
      revision.value++;
    }
  }

  /// whether the icon of [key] could not be made
  static bool failed(String key) => _failed.contains(key);

  /// the icon in [box] as it is, with a thin grid of fine lines over it (only over the icon itself, not its corners)
  static void paint(Canvas canvas, Rect box, PixelIcon icon, {double alpha = 1}) {
    canvas.saveLayer(box, Paint()..color = Color.fromRGBO(255, 255, 255, alpha));
    canvas.drawImageRect(icon.image, icon.source, box, Paint()..filterQuality = FilterQuality.high);
    final n = box.width < 30 ? 12 : 18;
    final cell = box.width / n;
    final line = Paint()
      ..blendMode = BlendMode.srcATop
      ..color = const Color(0x46000000)
      ..strokeWidth = (box.width / 132).clamp(.4, 1.0);
    for (var i = 1; i < n; i++) {
      canvas.drawLine(Offset(box.left + i * cell, box.top), Offset(box.left + i * cell, box.bottom), line);
      canvas.drawLine(Offset(box.left, box.top + i * cell), Offset(box.right, box.top + i * cell), line);
    }
    canvas.restore();
  }
}

/// Whether a pixel flag for [flag] is ready now (if it is not, it is made: the next drawing finds it).
bool hasPixelFlag(String flag) {
  if (PixelFlag.of(flag) != null || PixelFlag.pixelated[flag] != null) return true;
  unawaited(PixelFlag.pixelate(flag));
  return false;
}

class _PixelIconPainter extends CustomPainter {
  _PixelIconPainter(this.icon);

  final PixelIcon icon;

  @override
  void paint(Canvas canvas, Size size) => PixelIcons.paint(canvas, Offset.zero & size, icon);

  @override
  bool shouldRepaint(_PixelIconPainter old) => !identical(old.icon, icon);
}

/// An app's icon in the Dots look, [size] square: cells for the ground and the sign smooth over them. While it is made
/// there is room for it; an icon that cannot be made is the picture itself.
class DotsAppIcon extends StatelessWidget {
  const DotsAppIcon({super.key, required this.icon, this.size = 32});

  final Uint8List icon;
  final double size;

  /// what the icon is kept under: its size and the start of its bytes
  static String keyOf(Uint8List bytes) => '${bytes.length}:${Object.hashAll(bytes.take(256))}';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: PixelIcons.revision,
    builder: (context, _, _) {
      final key = keyOf(icon);
      final made = PixelIcons.of(key, icon);
      if (made != null) return CustomPaint(size: Size.square(size), painter: _PixelIconPainter(made));
      if (PixelIcons.failed(key)) return Image.memory(icon, width: size, height: size, gaplessPlayback: true);
      return SizedBox(width: size, height: size);
    },
  );
}
