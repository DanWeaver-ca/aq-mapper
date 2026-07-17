import 'dart:ui';

/// Platform seam for CSV delivery — this stub is replaced at compile time by
/// the io or web variant. The shared [SendOutcome] type lives here so every
/// variant (and the service) agrees on one definition.

/// What actually happened when the student tapped "Send to instructor".
/// Drives honest feedback: never claim "sent" after a cancelled share sheet
/// or a silent fallback.
enum SendOutcome {
  /// The share sheet ran to completion (delivery itself can't be confirmed).
  shared,

  /// The student dismissed the share sheet without picking a target.
  cancelled,

  /// This browser can't share files, so the CSV was saved locally instead.
  savedInstead,
}

/// True where saving is a distinct, user-visible action (browsers). On
/// iOS/Android the native share sheet already contains "Save to Files", so
/// the app shows a single button there, not two identical ones.
const bool kHasSeparateSave = false;

/// Keep a local copy of the CSV without sharing it.
Future<void> saveCsv(String csvText, String filename) =>
    throw UnsupportedError('CSV export is not supported on this platform.');

/// Hand the CSV to the platform's share flow.
Future<SendOutcome> sendCsv(String csvText, String filename,
        {Rect? shareOrigin}) =>
    throw UnsupportedError('CSV export is not supported on this platform.');
