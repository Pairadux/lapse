import 'package:lapse/features/cards/domain/flashcard.dart';

/// Factory for generating card preview text for list views.
class CardPreviewFactory {
  static String buildPreview(Flashcard card) {
    switch (card) {
       case TwoSidedCard():
        return _buildTwoSidedPreview(card);
      case ReverseCard():
        return _buildReversePreview(card);
      case ClozeCard():
        return _buildClozePreview(card);
    }
  }

  static String _buildTwoSidedPreview(TwoSidedCard card) {
    return '${card.front} → ${card.back}';
  }

  static String _buildReversePreview(ReverseCard card) {
    return '${card.front} → ${card.back}';
  }

  static String _buildClozePreview(ClozeCard card) {
    final clozeText = card.front.replaceAllMapped(
      RegExp(r'\{\{c\d+::.*?\}\}'),
      (match) => '[...]',
    );
    return clozeText;
  }
}
