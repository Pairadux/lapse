import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

/// Factory for creating card content widgets based on card type.
class CardContentFactory {
  static Widget buildFront(Flashcard card, {bool showTapHint = true}) {
  final content = switch (card) {
    TwoSidedCard c => _buildContent(c.cardType, c.front, isFront: true),
    ReverseCard c => _buildContent(c.cardType, c.front, isFront: true),
    ClozeCard c => _buildContent(c.cardType, c.front, isFront: true),
  };
  return _CardContentContainer(
    showTapHint: showTapHint,
    child: content,
  );
  }

  static Widget buildBack(Flashcard card) {
    final content = switch (card) {
      TwoSidedCard c => _buildContent(c.cardType, c.back, isFront: false),
      ReverseCard c => _buildContent(c.cardType, c.back, isFront: false),
      ClozeCard c => _buildContent(c.cardType, c.front, isFront: false), // Show the same text but with answers revealed
    };
    return _CardContentContainer(
      showTapHint: false,
      child: content,
    );
  }

  static Widget _buildContent(CardType type, String content, {required bool isFront}) {
    switch (type) {
      case CardType.twoSided:
        return _BasicCardContent(content: content);
      case CardType.reverse:
        return _BasicCardContent(content: content);
      case CardType.cloze:
        return _ClozeCardContent(content: content, isFront: isFront);
    }
  }
}

/// Container that provides consistent padding and optional tap hint.
class _CardContentContainer extends StatelessWidget {
  final Widget child;
  final bool showTapHint;

  const _CardContentContainer({required this.child, required this.showTapHint});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox.expand(
          child: Stack(
            children: [
              Positioned.fill(
                child: Padding(padding: const EdgeInsets.all(Spacing.xl), child: child),
              ),
              if (showTapHint)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: Spacing.lg,
                  child: Text(
                    'Tap to reveal',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Basic text card content with Markdown support.
class _BasicCardContent extends StatelessWidget {
  final String content;

  const _BasicCardContent({required this.content});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 2 * Spacing.xl),
        child: Center(
          child: MarkdownBody(
            data: content,
            onTapLink: (text, href, title) {
              if (href != null) launchUrl(Uri.parse(href));
            },
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
              p: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.normal),
              strong: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: WrapAlignment.center,
              listBullet: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.normal),
              blockquote: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.normal, color: AppColors.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Cloze deletion card content.
/// Front: Shows text with {{c1::answer}} replaced by [...]
/// Back: Shows text with answers revealed
class _ClozeCardContent extends StatelessWidget {
  final String content;
  final bool isFront;

  const _ClozeCardContent({required this.content, required this.isFront});

  @override
  Widget build(BuildContext context) {
    final processedContent = isFront ? _processClozeForFront(content) : _processClozeForBack(content);

    return _BasicCardContent(content: processedContent);
  }

  String _processClozeForFront(String text) {
    // Replace {{c1::answer}} with [...]
    return text.replaceAllMapped(RegExp(r'\{\{c\d+::([^}]+)\}\}'), (match) => '[...]');
  }

  String _processClozeForBack(String text) {
    // Replace {{c1::answer}} with **answer**
    return text.replaceAllMapped(RegExp(r'\{\{c\d+::([^}]+)\}\}'), (match) => '**${match.group(1)}**');
  }
}
