import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:lapse/core/theme/app_colors.dart';
import 'package:lapse/core/theme/spacing.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';

/// Factory for creating card content widgets based on card type.
class CardContentFactory {
  static Widget buildFront(Flashcard card, {bool showTapHint = true}) {
    return _CardContentContainer(
      showTapHint: showTapHint,
      child: _buildContent(card.cardType, card.front, isFront: true),
    );
  }

  static Widget buildBack(Flashcard card) {
    return _CardContentContainer(showTapHint: false, child: _buildContent(card.cardType, card.back, isFront: false));
  }

  static Widget _buildContent(CardType type, String content, {required bool isFront}) {
    switch (type) {
      case CardType.basic:
        return _BasicCardContent(content: content);
      case CardType.cloze:
        return _ClozeCardContent(content: content, isFront: isFront);
      case CardType.image:
        return _ImageCardContent(content: content, isFront: isFront);
      case CardType.audio:
        return _AudioCardContent(content: content, isFront: isFront);
      case CardType.imageOcclusion:
        return _ImageOcclusionCardContent(content: content, isFront: isFront);
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

/// Image card content.
/// Content format: "image_url|caption" or just "image_url"
class _ImageCardContent extends StatelessWidget {
  final String content;
  final bool isFront;

  const _ImageCardContent({required this.content, required this.isFront});

  @override
  Widget build(BuildContext context) {
    final parts = content.split('|');
    final imageUrl = parts[0].trim();
    final caption = parts.length > 1 ? parts[1].trim() : null;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 2 * Spacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 64);
                },
              ),
              if (caption != null && caption.isNotEmpty) ...[
                const SizedBox(height: Spacing.md),
                Text(caption, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Audio card content.
/// Content format: "audio_url|transcript" or just "audio_url"
class _AudioCardContent extends StatelessWidget {
  final String content;
  final bool isFront;

  const _AudioCardContent({required this.content, required this.isFront});

  @override
  Widget build(BuildContext context) {
    final parts = content.split('|');
    final audioUrl = parts[0].trim();
    final transcript = parts.length > 1 ? parts[1].trim() : null;

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 2 * Spacing.xl),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.play_arrow, size: 64),
                onPressed: () {
                  // TODO: Implement audio playback
                  launchUrl(Uri.parse(audioUrl));
                },
              ),
              const SizedBox(height: Spacing.md),
              Text('Tap to play audio', style: Theme.of(context).textTheme.bodyMedium),
              if (transcript != null && transcript.isNotEmpty && !isFront) ...[
                const SizedBox(height: Spacing.lg),
                Text(
                  transcript,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Image occlusion card content.
/// Content format: "image_url|occlusion_data" where occlusion_data is JSON
class _ImageOcclusionCardContent extends StatelessWidget {
  final String content;
  final bool isFront;

  const _ImageOcclusionCardContent({required this.content, required this.isFront});

  @override
  Widget build(BuildContext context) {
    final parts = content.split('|');
    final imageUrl = parts[0].trim();

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.sizeOf(context).height - 2 * Spacing.xl),
        child: Center(
          child: Stack(
            children: [
              Image.network(
                imageUrl,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image, size: 64);
                },
              ),
              if (isFront) ...[
                // TODO: Add occlusion overlays based on occlusion_data
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Text('Reveal the occluded areas', style: TextStyle(color: Colors.white, fontSize: 18)),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
