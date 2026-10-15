import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Contrast's colour: a warm colour (the accent: the buttons, the arcs, the figures) and a cool one (with it on the
/// backdrop). By day both lifted towards white for the backdrop.
enum ContrastPalette {
  claude('Claude', 'Claude', Color(0xFFC96442), Color(0xFF8FA8BD)),
  peach('Персик', 'Peach', Color(0xFFF08A5D), Color(0xFF9EC1CF)),
  terracotta('Терракота', 'Terracotta', Color(0xFFB5553A), Color(0xFF7D9D9C)),
  amber('Янтарь', 'Amber', Color(0xFFE8A33D), Color(0xFF6C8EBF)),
  honey('Мёд', 'Honey', Color(0xFFD9A441), Color(0xFF8C7AA9)),
  citrus('Цитрус', 'Citrus', Color(0xFFD4EE6A), Color(0xFF3A3E44)),
  lemon('Лимон', 'Lemon', Color(0xFFD6C13A), Color(0xFF5E8B7E)),
  olive('Олива', 'Olive', Color(0xFF8A9A3B), Color(0xFFC7956D)),
  mint('Мята', 'Mint', Color(0xFF3FB59A), Color(0xFFF2A07B)),
  emerald('Изумруд', 'Emerald', Color(0xFF1E9C6B), Color(0xFFE9B44C)),
  pine('Хвоя', 'Pine', Color(0xFF2F6F4F), Color(0xFFD99A6C)),
  turquoise('Бирюза', 'Turquoise', Color(0xFF1BA9A9), Color(0xFFF07C6C)),
  lagoon('Лагуна', 'Lagoon', Color(0xFF2A9DB8), Color(0xFFF2B134)),
  sky('Небо', 'Sky', Color(0xFF4A90E2), Color(0xFFF5A65B)),
  ocean('Океан', 'Ocean', Color(0xFF1F5FA8), Color(0xFF5FC9B8)),
  indigo('Индиго', 'Indigo', Color(0xFF4B4FC4), Color(0xFFF2A541)),
  sapphire('Сапфир', 'Sapphire', Color(0xFF2D4BA0), Color(0xFFE07A8B)),
  lavender('Лаванда', 'Lavender', Color(0xFF8E7CC3), Color(0xFFF3B391)),
  lilac('Сирень', 'Lilac', Color(0xFFA26BBF), Color(0xFF79C2A8)),
  amethyst('Аметист', 'Amethyst', Color(0xFF7A3FA8), Color(0xFFE8A87C)),
  cherry('Вишня', 'Cherry', Color(0xFFA4161A), Color(0xFF7FA7B5)),
  chocolate('Шоколад', 'Chocolate', Color(0xFF7B4B2A), Color(0xFFC9A86A)),
  sand('Песок', 'Sand', Color(0xFFC2A878), Color(0xFF7A9E9F)),
  graphite('Графит', 'Graphite', Color(0xFF4A4E57), Color(0xFFC96442)),
  mono('Монохром', 'Mono', Color(0xFF2B2B2B), Color(0xFF9A9A9A)),
  // plain ones
  yellow('Жёлтый', 'Yellow', Color(0xFFE6B800), Color(0xFF8C939C)),
  orange('Оранжевый', 'Orange', Color(0xFFF07B1A), Color(0xFF8C939C)),
  red('Красный', 'Red', Color(0xFFD9342B), Color(0xFF8C939C)),
  green('Зелёный', 'Green', Color(0xFF2E9E4F), Color(0xFF9AA3AD)),
  blue('Синий', 'Blue', Color(0xFF1F6FE0), Color(0xFF9AA3AD)),
  lightBlue('Голубой', 'Light blue', Color(0xFF2AA7E0), Color(0xFF9AA3AD)),
  grey('Серый', 'Grey', Color(0xFF7E858E), Color(0xFFB0B6BD)),
  darkGrey('Тёмно-серый', 'Dark grey', Color(0xFF4C525A), Color(0xFF9AA0A8)),
  // stricter, darker ones
  steel('Сталь', 'Steel', Color(0xFF4A6A8A), Color(0xFF9AA3AD)),
  carbon('Карбон', 'Carbon', Color(0xFFE8681C), Color(0xFF4A4E55)),
  military('Милитари', 'Military', Color(0xFF5B6B3A), Color(0xFFB8A47E)),
  cobalt('Кобальт', 'Cobalt', Color(0xFF1E4FD8), Color(0xFF7C8794)),
  burgundy('Бордо', 'Burgundy', Color(0xFF7A1F2B), Color(0xFF8A8F98)),
  taiga('Тайга', 'Taiga', Color(0xFF2E5E4E), Color(0xFFB87333)),
  petrol('Нефть', 'Petrol', Color(0xFF0E5A6B), Color(0xFFD9922E)),
  bronze('Бронза', 'Bronze', Color(0xFFA0703C), Color(0xFF3A4A66)),
  midnight('Полночь', 'Midnight', Color(0xFF1F3A6B), Color(0xFFC9A54C)),
  racing('Гонка', 'Racing', Color(0xFFC8102E), Color(0xFF5A5F66));

  const ContrastPalette(this.ru, this.en, this.warm, this.cool);

  final String ru;
  final String en;
  final Color warm;
  final Color cool;

  static const fallback = ContrastPalette.citrus;

  /// by day its colour stays as it is on the frames, fills and lit pills, while icons and accent figures go
  /// graphite (light ones washed out on white, darkened ones stopped being themselves): every palette
  bool get inkByDay => true;

  /// the icons' and figures' colour by day for [inkByDay]
  static const ink = Color(0xFF3A3E44);

  /// the accent: the warm colour, by night lifted a little to read on the dark (a near-black one to light grey)
  Color accent(Brightness brightness) {
    if (brightness == Brightness.light) return warm;
    final hsl = HSLColor.fromColor(warm);
    return hsl.lightness < .3 ? hsl.withLightness(.72).toColor() : Color.lerp(warm, Colors.white, .15)!;
  }

  /// the two colours as the backdrop draws them: by day lifted towards white, by night as they are
  (Color, Color) backdrop(Brightness brightness) => brightness == Brightness.light
      ? (Color.lerp(warm, Colors.white, .35)!, Color.lerp(cool, Colors.white, .3)!)
      : (accent(brightness), cool);
}

/// How see-through Contrast's blocks are: the tint over the backdrop (by day, by night) and how much they blur it.
enum ContrastClarity {
  // low: nearly solid; medium a little more see-through; high a little more again
  // the blur light: the thin line backdrops still show through the blocks (a strong one wiped them out and the
  // blocks looked solid next to the other pages' see-through cards)
  weak('Слабо', 'Low', .92, .9, 3),
  medium('Средне', 'Medium', .8, .78, 3),
  strong('Сильно', 'High', .66, .64, 3);

  const ContrastClarity(this.ru, this.en, this.day, this.night, this.blur);

  final String ru;
  final String en;
  final double day;
  final double night;
  final double blur;

  static const fallback = ContrastClarity.strong;
}

/// Contrast's backdrop: ten kinds, laid out at random once when the app starts (the same on every page).
enum ContrastBackdrop {
  circles('Круги', 'Circles'),
  confetti('Конфетти', 'Confetti'),
  relief('Рельеф', 'Relief'),
  stripes('Полосы', 'Stripes'),
  // in the stripes' way
  verticalStripes('Вертикальные', 'Vertical'),
  horizontalStripes('Горизонтальные', 'Horizontal'),
  pinstripes('Тонкие полосы', 'Pinstripes'),
  tartan('Шотландка', 'Tartan'),
  rays('Лучи', 'Rays'),
  chevronStripes('Шевронные полосы', 'Chevron stripes'),
  dots('Сетка точек', 'Dot grid'),
  ribbons('Ленты', 'Ribbons'),
  rings('Кольца', 'Rings'),
  waves('Волны', 'Waves'),
  mosaic('Мозаика', 'Mosaic'),
  grid('Клетка', 'Grid'),
  // quiet ones: thin lines near the page's own colour, the palette in a detail or two
  honeycomb('Соты', 'Honeycomb'),
  horizon('Горизонт', 'Horizon'),
  grain('Зерно', 'Grain'),
  chevron('Шеврон', 'Chevron'),
  // in the chevron's way: thin repeated lines, a few in the palette's colour
  zigzag('Зигзаг', 'Zigzag'),
  waveLines('Волнистые линии', 'Wavy lines'),
  herringbone('Ёлочка', 'Herringbone'),
  steps('Ступени', 'Steps'),
  circuit('Схема', 'Circuit');

  const ContrastBackdrop(this.ru, this.en);

  final String ru;
  final String en;

  static const fallback = ContrastBackdrop.circles;
}

/// The seed of this run's layout: picked when the app starts, the same until it's closed.
final contrastBackdropSeed = math.Random().nextInt(1 << 30);

/// Draws a [ContrastBackdrop] in a palette's two colours on the page's base colour.
class ContrastBackdropPainter extends CustomPainter {
  ContrastBackdropPainter({
    required this.kind,
    required this.warm,
    required this.cool,
    required this.dark,
    required this.seed,
    this.area,
  });

  /// the size it's laid out on (the screen), so a page's own backdrop lines up with the one round it; its own size
  /// when not given
  final Size? area;

  final ContrastBackdrop kind;
  final Color warm;
  final Color cool;
  final bool dark;
  final int seed;

  /// the page's own colour, under the backdrop
  static Color base(bool dark) => dark ? const Color(0xFF1D1D20) : const Color(0xFFEFEDE8);

  @override
  void paint(Canvas canvas, Size box) {
    final size = area ?? box;
    final w = size.width;
    final h = size.height;
    final r = math.Random(seed);
    final fill = Paint()..isAntiAlias = true;
    Paint stroke(Color c, double width) => Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = c;
    canvas.drawRect(Offset.zero & box, Paint()..color = base(dark));
    // the quiet backdrops' lines: near the page's own colour, thin
    final faint = dark ? const Color(0xFF3A3A42) : const Color(0xFFD9D4CC);
    final thin = math.max(1.0, w / 411 * 1.4);
    // the line families' lit rows: the ones nearest a quarter, a half and three quarters down (in the gaps between
    // the blocks there), the same every time
    bool lit(double y, double pitch) => const [.24, .52, .8].any((f) => (y - f * h).abs() < pitch / 2);
    Paint line(bool on) => stroke(on ? warm : faint, on ? thin * 1.6 : thin);
    canvas.save();
    canvas.clipRect(Offset.zero & box);
    switch (kind) {
      case ContrastBackdrop.circles:
        // four or five small discs, warm and cool in turn, each in its own band down the screen and on the other
        // half from the one before (the unfolded phone's whole width, not one side of it); sized by the shorter
        // side, so they're no bigger unfolded
        final count = 4 + r.nextInt(2);
        final unit = math.min(w, h * .5);
        final left = r.nextBool();
        for (var i = 0; i < count; i++) {
          final d = (.4 + r.nextDouble() * .2) / (r.nextBool() ? 2 : 3) * unit;
          final cx = ((i.isEven == left) ? r.nextDouble() * .5 : .5 + r.nextDouble() * .5) * w;
          final cy = (i + .2 + r.nextDouble() * .6) / count * h;
          canvas.drawCircle(Offset(cx, cy), d / 2, fill..color = i.isEven ? warm : cool);
        }
      case ContrastBackdrop.confetti:
        for (var i = 0; i < 40; i++) {
          final d = (4 + r.nextDouble() * 20) * w / 411;
          canvas.drawCircle(
            Offset(r.nextDouble() * w, r.nextDouble() * h),
            d / 2,
            fill..color = r.nextDouble() < .6 ? warm : cool,
          );
        }
      case ContrastBackdrop.relief:
        final phase = r.nextDouble() * 100;
        for (var j = 0; j < 16; j++) {
          final y0 = h * (j + .5) / 15;
          final path = Path()..moveTo(-20, y0);
          for (var x = 0.0; x <= w + 40; x += 40 * w / 411) {
            final step = 40 * w / 411;
            path.quadraticBezierTo(
              x + step / 2,
              y0 + math.sin((x + j * 37 + phase) / 60) * 24 * w / 411,
              x + step,
              y0 + math.cos((x + j * 53 + phase) / 70) * 18 * w / 411,
            );
          }
          canvas.drawPath(path, stroke(j % 3 == 0 ? cool : warm, 2.2 * w / 411));
        }
      case ContrastBackdrop.stripes:
        canvas.save();
        canvas.translate(w / 2, h / 2);
        canvas.rotate((20 + r.nextDouble() * 20) * math.pi / 180);
        final shift = r.nextDouble() * w * .36;
        for (var j = 0; j < 9; j++) {
          final x = -w * 1.4 + j * w * .36 + shift;
          final width = j.isOdd ? w * .09 : w * .17;
          canvas.drawRect(Rect.fromLTWH(x, -h, width, h * 2), fill..color = j.isOdd ? cool : warm);
        }
        canvas.restore();
      case ContrastBackdrop.verticalStripes:
        for (var j = 0; j < 8; j++) {
          final width = j.isOdd ? w * .05 : w * .11;
          canvas.drawRect(Rect.fromLTWH(j * w / 6 - w * .04, 0, width, h), fill..color = j.isOdd ? cool : warm);
        }
      case ContrastBackdrop.horizontalStripes:
        for (var j = 0; j < 10; j++) {
          final height = j.isOdd ? h * .018 : h * .045;
          canvas.drawRect(Rect.fromLTWH(0, j * h / 8 - h * .02, w, height), fill..color = j.isOdd ? cool : warm);
        }
      case ContrastBackdrop.pinstripes:
        canvas.save();
        canvas.translate(w / 2, h / 2);
        canvas.rotate(-35 * math.pi / 180);
        for (var j = 0; j < 48; j++) {
          final on = j % 5 == 2;
          canvas.drawRect(
            Rect.fromLTWH(-w * 2 + j * w / 12, -h, on ? 3 * w / 411 : 1.4 * w / 411, h * 2),
            fill..color = on ? warm : faint,
          );
        }
        canvas.restore();
      case ContrastBackdrop.tartan:
        for (var j = 0; j < 5; j++) {
          canvas.drawRect(Rect.fromLTWH(j * w / 4, 0, w * .08, h), fill..color = warm.withValues(alpha: .55));
          canvas.drawRect(Rect.fromLTWH(0, j * h / 5, w, h * .04), fill..color = cool.withValues(alpha: .55));
        }
      case ContrastBackdrop.rays:
        final origin = Offset(w + 10, -10);
        final reach = h * 2;
        for (var j = 0; j < 11; j++) {
          final a = (95 + j * 8) * math.pi / 180;
          final b = a + (j.isOdd ? .03 : .07);
          final ray = Path()
            ..moveTo(origin.dx, origin.dy)
            ..lineTo(origin.dx + math.cos(a) * reach, origin.dy + math.sin(a) * reach)
            ..lineTo(origin.dx + math.cos(b) * reach, origin.dy + math.sin(b) * reach)
            ..close();
          canvas.drawPath(ray, fill..color = j.isOdd ? cool : warm);
        }
      case ContrastBackdrop.chevronStripes:
        for (var j = 0; j < 7; j++) {
          final y = j * h / 5;
          final band = j.isOdd ? h * .025 : h * .05;
          final path = Path()
            ..moveTo(0, y)
            ..lineTo(w / 2, y + w * .35)
            ..lineTo(w, y)
            ..lineTo(w, y + band)
            ..lineTo(w / 2, y + w * .35 + band)
            ..lineTo(0, y + band)
            ..close();
          canvas.drawPath(path, fill..color = j.isOdd ? cool : warm);
        }
      case ContrastBackdrop.dots:
        final centre = Offset(w * (.2 + r.nextDouble() * .6), h * (.15 + r.nextDouble() * .5));
        final step = 26 * w / 411;
        final grey = dark ? const Color(0xFF4A4A52) : const Color(0xFFCFCAC2);
        for (var y = step * .6; y < h; y += step) {
          for (var x = step * .5; x < w; x += step) {
            final near = (Offset(x, y) - centre).distance < w * .5;
            canvas.drawCircle(Offset(x, y), (near ? 4 : 2.2) * w / 411, fill..color = near ? warm : grey);
          }
        }
      case ContrastBackdrop.ribbons:
        final shader = LinearGradient(colors: [warm, cool]).createShader(Offset.zero & size);
        final start = .1 + r.nextDouble() * .15;
        for (var j = 0; j < 3; j++) {
          final y = h * (start + j * .28);
          final path = Path()
            ..moveTo(-40, y)
            ..cubicTo(w * .25, y - h * .12, w * .65, y + h * .14, w + 40, y - h * .04)
            ..lineTo(w + 40, y + h * .06)
            ..cubicTo(w * .65, y + h * .22, w * .25, y - h * .04, -40, y + h * .09)
            ..close();
          canvas.drawPath(
            path,
            Paint()
              ..shader = shader
              ..color = Colors.black.withValues(alpha: .9 - j * .15),
          );
        }
      case ContrastBackdrop.rings:
        final flip = r.nextBool();
        final a = Offset(flip ? -30 : w + 20, h * (.08 + r.nextDouble() * .1));
        final b = Offset(flip ? w + 20 : -30, h * (.72 + r.nextDouble() * .12));
        for (var j = 0; j < 8; j++) {
          canvas.drawCircle(a, w * .15 + j * w * .09, stroke(j.isOdd ? cool : warm, w * .024));
          canvas.drawCircle(b, w * .12 + j * w * .09, stroke(j.isOdd ? warm : cool, w * .024));
        }
      case ContrastBackdrop.waves:
        final phase = r.nextDouble() * .1;
        for (var j = 0; j < 4; j++) {
          final y = h * (.22 + phase + j * .2);
          final path = Path()
            ..moveTo(0, y)
            ..cubicTo(w * .3, y - h * .08, w * .6, y + h * .08, w, y - h * .02)
            ..lineTo(w, h)
            ..lineTo(0, h)
            ..close();
          canvas.drawPath(path, fill..color = (j.isOdd ? cool : warm).withValues(alpha: dark ? .55 : .6));
        }
      case ContrastBackdrop.mosaic:
        const columns = 6;
        final cell = w / columns;
        for (var y = 0; y < h / cell + 1; y++) {
          for (var x = 0; x < columns; x++) {
            final v = r.nextDouble();
            if (v >= .42) continue;
            final path = Path();
            final l = x * cell;
            final t = y * cell;
            if (v < .1 || v > .3) {
              path
                ..moveTo(l, t)
                ..lineTo(l + cell, t)
                ..lineTo(l + cell, t + cell);
            } else {
              path
                ..moveTo(l, t)
                ..lineTo(l, t + cell)
                ..lineTo(l + cell, t + cell);
            }
            canvas.drawPath(path..close(), fill..color = v < .2 ? warm : cool);
          }
        }
      case ContrastBackdrop.grid:
        final cell = w / 8;
        final line = stroke(dark ? const Color(0xFF3A3A40) : const Color(0xFFD6D1C9), 1.2);
        for (var x = 0.0; x < w; x += cell) {
          canvas.drawLine(Offset(x, 0), Offset(x, h), line);
        }
        for (var y = 0.0; y < h; y += cell) {
          canvas.drawLine(Offset(0, y), Offset(w, y), line);
        }
        final rows = (h / cell).floor();
        for (var i = 0; i < 5; i++) {
          final cx = r.nextInt(7);
          final cy = (i * rows / 5 + r.nextDouble() * rows / 5).floor();
          canvas.drawRect(
            Rect.fromLTWH(cx * cell, cy * cell, cell * 2, cell * 2),
            fill..color = i.isEven ? warm : cool,
          );
        }
      case ContrastBackdrop.honeycomb:
        final a = w / 9;
        final rowH = a * math.sqrt(3) / 2;
        var row = 0;
        for (var y = 0.0; y < h + a; y += rowH, row++) {
          for (var x = row.isOdd ? a * .75 : 0.0; x < w + a; x += a * 1.5) {
            final path = Path();
            for (var k = 0; k < 6; k++) {
              final t = math.pi / 3 * k;
              final p = Offset(x + math.cos(t) * a / 2, y + math.sin(t) * a / 2);
              k == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
            }
            path.close();
            if (r.nextDouble() < .07) {
              canvas.drawPath(path, fill..color = (r.nextBool() ? warm : cool).withValues(alpha: .55));
            }
            canvas.drawPath(path, stroke(faint, thin));
          }
        }
      case ContrastBackdrop.horizon:
        final accentEvery = 6 + r.nextInt(4);
        for (var j = 0; j < 42; j++) {
          final y = h * .12 + j * h * .02;
          canvas.drawLine(
            Offset(0, y),
            Offset(w, y),
            stroke((j % accentEvery == 2 ? warm : faint).withValues(alpha: (1 - j / 50).clamp(.1, 1)), thin),
          );
        }
      case ContrastBackdrop.grain:
        final speck = dark ? const Color(0xFF45454D) : const Color(0xFFCFC9C0);
        final count = (w * h / 400).round().clamp(400, 3000);
        for (var k = 0; k < count; k++) {
          canvas.drawCircle(
            Offset(r.nextDouble() * w, r.nextDouble() * h),
            w / 411 * (.6 + r.nextDouble() * .9),
            fill..color = r.nextDouble() < .12 ? warm : speck,
          );
        }
      case ContrastBackdrop.chevron:
        final c = w / 7;
        var row = 0;
        for (var y = 0.0; y < h + c; y += c * .6, row++) {
          for (var x = 0.0; x < w + c; x += c) {
            final path = Path()
              ..moveTo(x, y + c * .3)
              ..lineTo(x + c / 2, y)
              ..lineTo(x + c, y + c * .3);
            canvas.drawPath(path, line(lit(y, c * .6)));
          }
        }
      case ContrastBackdrop.zigzag:
        final c = w / 12;
        var row = 0;
        for (var y = 0.0; y < h + c; y += c * .9, row++) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < w + c; x += c) {
            path
              ..lineTo(x + c / 2, y + c * .45)
              ..lineTo(x + c, y);
          }
          canvas.drawPath(path, line(lit(y, c * .9)));
        }
      case ContrastBackdrop.waveLines:
        final c = w / 6;
        var row = 0;
        for (var y = 0.0; y < h + c; y += c * .42, row++) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < w + c; x += c) {
            path
              ..quadraticBezierTo(x + c / 4, y - c * .18, x + c / 2, y)
              ..quadraticBezierTo(x + c * .75, y + c * .18, x + c, y);
          }
          canvas.drawPath(path, line(lit(y, c * .42)));
        }
      case ContrastBackdrop.herringbone:
        final c = w / 9;
        final rowH = c * .55;
        var row = 0;
        for (var y = 0.0; y < h + c; y += rowH, row++) {
          final on = lit(y, rowH);
          for (var x = row.isOdd ? c / 2 : 0.0; x < w + c; x += c) {
            canvas.drawLine(Offset(x, y), Offset(x + c * .4, y + rowH * .8), line(on));
            canvas.drawLine(Offset(x + c * .9, y), Offset(x + c * .5, y + rowH * .8), line(on));
          }
        }
      case ContrastBackdrop.steps:
        final c = w / 8;
        var row = 0;
        for (var y = 0.0; y < h + c; y += c * .7, row++) {
          final path = Path()..moveTo(0, y);
          for (var x = 0.0; x < w + c; x += c) {
            path
              ..lineTo(x + c / 2, y)
              ..lineTo(x + c / 2, y - c * .3)
              ..lineTo(x + c, y - c * .3)
              ..lineTo(x + c, y);
          }
          canvas.drawPath(path, line(lit(y, c * .7)));
        }
      case ContrastBackdrop.circuit:
        final g = w / 10;
        for (var k = 0; k < 22; k++) {
          var x = (r.nextDouble() * 10).roundToDouble() * g;
          var y = (r.nextDouble() * h / g).roundToDouble() * g;
          final path = Path()..moveTo(x, y);
          for (var st = 0; st < 4; st++) {
            if (r.nextBool()) {
              x += g * (1 + r.nextInt(3)) * (r.nextBool() ? -1 : 1);
            } else {
              y += g * (1 + r.nextInt(3));
            }
            path.lineTo(x, y);
          }
          final lit = k % 6 == 0;
          canvas.drawPath(path, stroke(lit ? warm : faint, thin));
          canvas.drawCircle(Offset(x, y), w / 411 * 3, fill..color = lit ? warm : cool);
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(ContrastBackdropPainter old) =>
      old.kind != kind ||
      old.warm != warm ||
      old.cool != cool ||
      old.dark != dark ||
      old.seed != seed ||
      old.area != area;
}

/// The backdrop as frosted glass shows it: drawn once, blurred, into a small picture (half the screen's size: it's
/// blurred anyway) and kept until the look or the screen changes. The blocks show their part of it instead of
/// blurring what's behind them on every frame, which made the whole interface lag.
class ContrastFrostImage {
  ContrastFrostImage._();

  static final _kept = <String, ui.Image>{};

  static ui.Image of({
    required ContrastBackdrop kind,
    required Color warm,
    required Color cool,
    required bool dark,
    required Size area,
    required double blur,
    // the picture's pixels per point: the screen's own (up to 2), so it's drawn pixel for pixel and doesn't shimmer
    // as a card moves over it
    required double scale,
  }) {
    final key =
        '${kind.name}|${warm.toARGB32()}|${cool.toARGB32()}|$dark|${area.width.round()}x${area.height.round()}|$blur|$scale';
    final kept = _kept[key];
    if (kept != null) return kept;
    // a handful at most (day and night, a few clarities); the old ones go to the collector
    if (_kept.length > 8) _kept.clear();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    canvas.saveLayer(
      Offset.zero & area,
      Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur, tileMode: TileMode.clamp),
    );
    ContrastBackdropPainter(
      kind: kind,
      warm: warm,
      cool: cool,
      dark: dark,
      seed: contrastBackdropSeed,
      area: area,
    ).paint(canvas, area);
    canvas.restore();
    final image = recorder.endRecording().toImageSync(
      math.max(1, (area.width * scale).ceil()),
      math.max(1, (area.height * scale).ceil()),
    );
    return _kept[key] = image;
  }
}

/// The backdrop drawn once into a picture at the screen's size (no more than two pixels per point) and kept until
/// the look or the screen changes: each frame then shows one image instead of drawing hundreds or thousands of
/// shapes again (the grain alone is thousands), which the phone did on every frame anything moved.
class ContrastBackdropImage {
  ContrastBackdropImage._();

  static final _kept = <String, ui.Image>{};

  static ui.Image of({
    required ContrastBackdrop kind,
    required Color warm,
    required Color cool,
    required bool dark,
    required Size area,
    required double scale,
  }) {
    final key =
        '${kind.name}|${warm.toARGB32()}|${cool.toARGB32()}|$dark|${area.width.round()}x${area.height.round()}|$scale';
    final kept = _kept[key];
    if (kept != null) return kept;
    // a few at most (day and night, folded and unfolded); the old ones go to the collector
    if (_kept.length > 4) _kept.clear();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(scale);
    ContrastBackdropPainter(
      kind: kind,
      warm: warm,
      cool: cool,
      dark: dark,
      seed: contrastBackdropSeed,
      area: area,
    ).paint(canvas, area);
    final image = recorder.endRecording().toImageSync(
      math.max(1, (area.width * scale).ceil()),
      math.max(1, (area.height * scale).ceil()),
    );
    return _kept[key] = image;
  }
}

/// Paints a [ContrastBackdropImage] from its box's corner, at its points' size.
class ContrastImagePainter extends CustomPainter {
  ContrastImagePainter(this.image, this.scale);

  final ui.Image image;
  final double scale;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(1 / scale);
    canvas.drawImage(image, Offset.zero, Paint()..filterQuality = FilterQuality.low);
    canvas.restore();
  }

  @override
  bool shouldRepaint(ContrastImagePainter old) => !identical(old.image, image) || old.scale != scale;
}
