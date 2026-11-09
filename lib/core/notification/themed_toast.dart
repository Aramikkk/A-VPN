import 'package:flutter/material.dart';
import 'package:hiddify/core/theme/strip_look.dart';

/// What a notification is about: its marker's colour.
enum ToastKind { info, success, error }

/// A notification in the look of the theme in use (see [StripLook]): a marker in the colour of its kind, the text and, when
/// it has one, a button (Undo and the like). A tap anywhere else closes it.
class ThemedToast extends StatelessWidget {
  const ThemedToast({
    super.key,
    required this.message,
    required this.kind,
    required this.onClose,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final ToastKind kind;
  final VoidCallback onClose;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final look = StripLook.of(context);
    final scheme = Theme.of(context).colorScheme;
    // opaque: the screen under a notification must not show through its text
    final solid = Color.alphaBlend(look.fill, scheme.surface);
    final marker = switch (kind) {
      ToastKind.success => const Color(0xFF4CC38A),
      ToastKind.error => const Color(0xFFE5484D),
      ToastKind.info => look.accent,
    };
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: EdgeInsetsDirectional.fromSTEB(14, 11, onAction == null ? 14 : 8, 11),
        decoration: BoxDecoration(
          color: solid,
          borderRadius: BorderRadius.circular(look.radius),
          border: look.edge == Colors.transparent ? null : Border.all(color: look.edge, width: look.edgeWidth),
          boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(color: marker, shape: BoxShape.circle),
            ),
            const SizedBox(width: 11),
            Flexible(
              child: Text(
                look.dots ? message.toUpperCase() : message,
                maxLines: 6,
                overflow: TextOverflow.ellipsis,
                style: look.text(look.dots ? 12.5 : 14, look.ink),
              ),
            ),
            if (onAction != null && actionLabel != null) ...[
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () {
                  onClose();
                  onAction!();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: look.btnFill,
                    borderRadius: BorderRadius.circular(look.dots ? 6 : 14),
                  ),
                  child: Text(
                    look.dots ? actionLabel!.toUpperCase() : actionLabel!,
                    style: look.text(12.5, look.btnInk, weight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
