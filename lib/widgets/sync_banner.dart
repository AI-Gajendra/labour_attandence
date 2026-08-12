import 'package:flutter/material.dart';
import '../design_tokens.dart';
import '../services/sync_status.dart';

/// Thin strip that tells the operator whether their work has actually reached
/// the server.
///
/// Collapses to nothing when online with no pending writes, so it costs no
/// screen space in the normal case. Shown on the app shell and on the
/// attendance screen — the two places where losing a write would hurt most.
class SyncBanner extends StatelessWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SyncStatus.instance,
      builder: (context, _) {
        final status = SyncStatus.instance;
        final pending = status.pending;
        final offline = status.isOffline;
        final error = status.lastError;

        if (!offline && pending == 0 && error == null) {
          return const SizedBox.shrink();
        }

        late final Color background;
        late final Color foreground;
        late final IconData icon;
        late final String message;

        if (error != null) {
          background = DS.error.withAlpha(30);
          foreground = DS.error;
          icon = Icons.error_outline;
          message = 'A change could not be saved. Tap to dismiss.';
        } else if (offline) {
          background = DS.warning.withAlpha(30);
          foreground = const Color(0xFF8A5A00);
          icon = Icons.cloud_off;
          message = pending > 0
              ? 'Offline — $pending change${pending == 1 ? '' : 's'} saved on this phone'
              : 'Offline — changes are saved on this phone';
        } else {
          background = DS.tertiary.withAlpha(25);
          foreground = DS.tertiary;
          icon = Icons.sync;
          message = 'Syncing $pending change${pending == 1 ? '' : 's'}…';
        }

        return GestureDetector(
          onTap: error == null ? null : status.clearError,
          child: Container(
            width: double.infinity,
            color: background,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: foreground),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontFamily: DS.fontBody,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
