import 'package:flutter/material.dart';
import 'package:hiddify/features/chain/overview/chain_look.dart';

class ChainTimelineArrow extends StatelessWidget {
  final bool showArrow;

  const ChainTimelineArrow({super.key, this.showArrow = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      margin: const EdgeInsetsDirectional.only(start: 8.5),
      child: CustomPaint(
        painter: _ChainTimeLineArrowPainter(showArrow: showArrow, color: ChainLook.soft(context)),
      ),
    );
  }
}

class _ChainTimeLineArrowPainter extends CustomPainter {
  final bool showArrow;
  final Color color;

  _ChainTimeLineArrowPainter({required this.showArrow, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final centerX = size.width / 2;
    final bottomY = size.height - (showArrow ? 10.0 : 0.0);
    // the line is a column of dots, the way the program draws its lines
    const gap = 8.0;
    for (var y = 0.0; y <= bottomY; y += gap) {
      canvas.drawCircle(Offset(centerX, y), 1.6, paint);
    }
    if (showArrow) {
      // the arrowhead is two short rows of dots
      for (var k = 1; k <= 3; k++) {
        canvas.drawCircle(Offset(centerX - k * 3.0, bottomY - 9 + k * 3.0), 1.6, paint);
        canvas.drawCircle(Offset(centerX + k * 3.0, bottomY - 9 + k * 3.0), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ChainTimeLineArrowPainter oldDelegate) {
    return oldDelegate.showArrow != showArrow || oldDelegate.color != color;
  }
}
