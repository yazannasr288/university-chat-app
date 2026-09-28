import 'dart:ui' as ui;

bool _isRtlCodePoint(int rune) {
  return (rune >= 0x0590 && rune <= 0x08FF) ||
      (rune >= 0xFB1D && rune <= 0xFDFF) ||
      (rune >= 0xFE70 && rune <= 0xFEFF) ||
      (rune >= 0x10800 && rune <= 0x10FFF) ||
      (rune >= 0x1E800 && rune <= 0x1EEFF);
}

bool _isLtrCodePoint(int rune) {
  return (rune >= 0x0041 && rune <= 0x005A) ||
      (rune >= 0x0061 && rune <= 0x007A) ||
      (rune >= 0x00C0 && rune <= 0x024F) ||
      (rune >= 0x0370 && rune <= 0x03FF) ||
      (rune >= 0x0400 && rune <= 0x052F);
}

/// Returns the natural base direction for a chat paragraph.
///
/// The important rule is to follow the first strong directional character,
/// not the existence of any English or Arabic character anywhere in the text.
///
/// Examples:
/// - "مرحبا Ahmed" stays RTL because the first strong character is Arabic.
/// - "Ahmed مرحبا" stays LTR because the first strong character is English.
///
/// Flutter's text engine already applies the Unicode bidirectional algorithm
/// inside the paragraph. This helper only chooses the paragraph base direction;
/// it must not rewrite, reverse, or inject characters into the user's message.
ui.TextDirection chatTextDirectionFor(
  String text, {
  ui.TextDirection fallback = ui.TextDirection.ltr,
}) {
  for (final rune in text.runes) {
    if (_isRtlCodePoint(rune)) return ui.TextDirection.rtl;
    if (_isLtrCodePoint(rune)) return ui.TextDirection.ltr;
  }

  return fallback;
}
