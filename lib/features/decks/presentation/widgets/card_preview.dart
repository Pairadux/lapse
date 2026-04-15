import 'package:lapse/features/cards/domain/flashcard.dart';

/// Factory for generating card preview text for list views.
class CardPreviewFactory {
  static String buildPreview(Flashcard card) {
    switch (card.cardType) {
      case CardType.basic:
        return _buildBasicPreview(card);
      case CardType.cloze:
        return _buildClozePreview(card);
      case CardType.image:
        return _buildImagePreview(card);
      case CardType.audio:
        return _buildAudioPreview(card);
      case CardType.imageOcclusion:
        return _buildImageOcclusionPreview(card);
    }
  }

  static String _buildBasicPreview(Flashcard card) {
    return '${card.front} → ${card.back}';
  }

  static String _buildClozePreview(Flashcard card) {
    // Show the cloze text with answers hidden
    final clozeText = card.front.replaceAllMapped(RegExp(r'\{\{c\d+::([^}]+)\}\}'), (match) => '[...]');
    return '$clozeText → ${card.back}';
  }

  static String _buildImagePreview(Flashcard card) {
    final parts = card.front.split('|');
    final imageName = _extractFileName(parts[0]);
    final caption = parts.length > 1 ? parts[1].trim() : '';
    return '🖼️ ${caption.isNotEmpty ? caption : imageName} → ${card.back}';
  }

  static String _buildAudioPreview(Flashcard card) {
    final parts = card.front.split('|');
    final audioName = _extractFileName(parts[0]);
    final transcript = parts.length > 1 ? parts[1].trim() : '';
    return '🔊 ${transcript.isNotEmpty ? transcript : audioName} → ${card.back}';
  }

  static String _buildImageOcclusionPreview(Flashcard card) {
    final parts = card.front.split('|');
    final imageName = _extractFileName(parts[0]);
    return '🖼️⬜ $imageName → ${card.back}';
  }

  static String _extractFileName(String url) {
    try {
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      return pathSegments.isNotEmpty ? pathSegments.last : url;
    } catch (_) {
      return url;
    }
  }
}
