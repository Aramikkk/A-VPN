import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Contrast's colour: a warm colour (the accent: the buttons, the arcs, the figures) and a cool one (with it on the
/// backdrop). By day both lifted towards white for the backdrop.
enum ContrastPalette {
  claude('Claude', 'Claude', Color(0xFFC96442), Color(0xFF8FA8BD)),
  peach('Персик', 'Peach', Color(0xFFF08A5D), Color(0xFF9EC1CF)),
  coral('Коралл', 'Coral', Color(0xFFFF6F61), Color(0xFF6EC6CA)),
  terracotta('Терракота', 'Terracotta', Color(0xFFB5553A), Color(0xFF7D9D9C)),
  amber('Янтарь', 'Amber', Color(0xFFE8A33D), Color(0xFF6C8EBF)),
  honey('Мёд', 'Honey', Color(0xFFD9A441), Color(0xFF8C7AA9)),
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
  plum('Слива', 'Plum', Color(0xFF7B2D5B), Color(0xFF9CB8A0)),
  fuchsia('Фуксия', 'Fuchsia', Color(0xFFD13C8F), Color(0xFF4FB3BF)),
  rose('Роза', 'Rose', Color(0xFFE07A9A), Color(0xFF8AA6C1)),
  raspberry('Малина', 'Raspberry', Color(0xFFC2185B), Color(0xFFF2C14E)),
  cherry('Вишня', 'Cherry', Color(0xFFA4161A), Color(0xFF7FA7B5)),
  chocolate('Шоколад', 'Chocolate', Color(0xFF7B4B2A), Color(0xFFC9A86A)),
  sand('Песок', 'Sand', Color(0xFFC2A878), Color(0xFF7A9E9F)),
  graphite('Графит', 'Graphite', Color(0xFF4A4E57), Color(0xFFC96442)),
  mono('Монохром', 'Mono', Color(0xFF2B2B2B), Color(0xFF9A9A9A)),
  neon('Неон', 'Neon', Color(0xFFFF2E88), Color(0xFF2EF2C8));

  const ContrastPalette(this.ru, this.en, this.warm, this.cool);

  final String ru;
  final String en;
  final Color warm;
  final Color cool;

  static const fallback = ContrastPalette.claude;

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
  weak('Слабо', 'Low', .62, .62, 10),
  medium('Средне', 'Medium', .3, .35, 18),
  strong('Сильно', 'High', .12, .18, 26);

  const ContrastClarity(this.ru, this.en, this.day, this.night, this.blur);

  final String ru;
  final String en;
  final double day;
  final double night;
  final double blur;

  static const fallback = ContrastClarity.medium;
}

/// Contrast's backdrop: ten kinds, laid out at random once when the app starts (the same on every page).
enum ContrastBackdrop {
  circles('Круги', 'Circles'),
  confetti('Конфетти', 'Confetti'),
  relief('Рельеф', 'Relief'),
  stripes('Полосы', 'Stripes'),
  dots('Сетка точек', 'Dot grid'),
  ribbons('Ленты', 'Ribbons'),
  rings('Кольца', 'Rings'),
  waves('Волны', 'Waves'),
  mosaic('Мозаика', 'Mosaic'),
  grid('Клетка', 'Grid');

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
