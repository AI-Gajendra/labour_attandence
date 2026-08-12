import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../design_tokens.dart';

/// Shows a generated PDF before it goes anywhere.
///
/// Exports used to fire the Android share sheet immediately, so the first time
/// anyone saw the document was after they had already sent it to a worker.
/// A wage slip is handed to a person and argued over — it should be read once
/// before it leaves the phone.
///
/// Printing (and "save as PDF") comes from the same viewer, so the document can
/// also go to paper without a round trip through WhatsApp.
class PdfPreviewScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Uint8List bytes;
  final String fileName;

  /// Invoked by the SHARE button. Kept as a callback so sharing stays in
  /// [ExportService] and uses the same share sheet as the CSV export.
  final Future<void> Function() onShare;

  const PdfPreviewScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.bytes,
    required this.fileName,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DS.surfaceContainerHigh,
      body: Column(
        children: [
          // ── Dark header ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 20),
            decoration: const BoxDecoration(color: DS.primaryContainer),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontFamily: DS.fontHeadline,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontFamily: DS.fontBody,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          color: Colors.white.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── The document ──
          Expanded(
            child: PdfPreview(
              build: (format) => bytes,
              pdfFileName: fileName,
              // Sharing is the app's own button below, so it reads the same as
              // every other share in the app.
              allowSharing: false,
              allowPrinting: true,
              canChangePageFormat: false,
              canChangeOrientation: false,
              canDebug: false,
              useActions: true,
              scrollViewDecoration: const BoxDecoration(
                color: DS.surfaceContainerHigh,
              ),
              loadingWidget: const Center(
                child: CircularProgressIndicator(color: DS.green),
              ),
            ),
          ),

          // ── Share ──
          _ShareBar(onShare: onShare),
        ],
      ),
    );
  }
}

// ── Share Bar ──
class _ShareBar extends StatefulWidget {
  final Future<void> Function() onShare;
  const _ShareBar({required this.onShare});

  @override
  State<_ShareBar> createState() => _ShareBarState();
}

class _ShareBarState extends State<_ShareBar> {
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await widget.onShare();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not share: $e'),
          backgroundColor: DS.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DS.surfaceContainerLowest,
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      child: GestureDetector(
        onTap: _share,
        child: Container(
          height: DS.buttonHeight,
          decoration: BoxDecoration(
            gradient: DS.ctaGradient,
            borderRadius: BorderRadius.circular(DS.radiusXl),
            boxShadow: DS.buttonShadow,
          ),
          alignment: Alignment.center,
          child: _sharing
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text(
                      'SHARE',
                      style: TextStyle(
                        fontFamily: DS.fontHeadline,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
