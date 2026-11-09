import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hiddify/core/notification/themed_toast.dart';
import 'package:hiddify/core/notification/toast_hover_pause.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:toastification/toastification.dart';

part 'in_app_notification_controller.g.dart';

@Riverpod(keepAlive: true)
InAppNotificationController inAppNotificationController(Ref ref) {
  return InAppNotificationController();
}

enum NotificationType { info, error, success }

/// A button at the end of a toast, such as Undo. Pressing it also closes the toast.
typedef ToastAction = ({String label, VoidCallback onPressed});

class InAppNotificationController with AppLogger {
  ToastificationItem? _show(String message, {NotificationType type = NotificationType.info, ToastAction? action}) {
    // Notifications raised during bootstrap (before runApp) have no overlay to
    // attach to, and toastification throws when it cannot find one. Swallow
    // that so a notification can never abort startup or crash the app.
    try {
      toastification.dismissAll();
      late final ToastificationItem item;
      final closeAfter = action == null ? const Duration(seconds: 4) : const Duration(seconds: 8);
      // the notification is drawn by the app, in the look of the theme in use (Dots, Bento, Glass, Contrast)
      item = toastification.showCustom(
        alignment: AlignmentDirectional.bottomCenter,
        // 4 s, a Material 3 snackbar's time; 8 s with a button, to read it and reach the button
        autoCloseDuration: closeAfter,
        builder: (context, holder) => Padding(
          padding: const EdgeInsets.only(bottom: 64 + 16, right: 16, left: 16),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: 1,
            child: ToastHoverPause(
              item: () => holder,
              child: ThemedToast(
                message: message,
                kind: switch (type) {
                  NotificationType.success => ToastKind.success,
                  NotificationType.error => ToastKind.error,
                  NotificationType.info => ToastKind.info,
                },
                onClose: () => toastification.dismiss(holder),
                actionLabel: action?.label,
                onAction: action?.onPressed,
              ),
            ),
          ),
        ),
      );
      // a phone: the toast always goes by itself. Its own timer could be held (a hover that never ended, the app in
      // the background) and the notice stayed on the screen; this one doesn't wait for anything. A computer keeps
      // the pause while the mouse is over the toast.
      if (!PlatformUtils.isDesktop) {
        Timer(closeAfter + const Duration(seconds: 1), () {
          if (toastification.findToastificationItem(item.id) != null) toastification.dismiss(item);
        });
      }
      return item;
    } catch (e, stackTrace) {
      loggy.warning("failed to show notification, overlay may not be ready", e, stackTrace);
      return null;
    }
  }

  ToastificationItem? showErrorToast(String message) => _show(message, type: NotificationType.error);

  ToastificationItem? showSuccessToast(String message, {ToastAction? action}) =>
      _show(message, type: NotificationType.success, action: action);

  ToastificationItem? showInfoToast(String message, {ToastAction? action}) => _show(message, action: action);
}
