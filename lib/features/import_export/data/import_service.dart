import 'dart:io';
import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart';
import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';

class DeckImportService {
  final DeckRepository _deckRepository;
  final CardRepository _cardRepository;

  DeckImportService(this._deckRepository, this._cardRepository);

  /// Imports cards from a CSV file, optionally under [parentDeckId].
  ///
  /// When [parentDeckId] is null, decks are created from the root.
  /// When [skipDuplicates] is true, cards whose front text already
  /// exists in the target deck are skipped.
  Future<void> importDeckFromCSV(
    File csvFile, {
    String? parentDeckId,
    bool skipDuplicates = false,
  }) async {
    final content = csvFile.readAsStringSync();
    final cards = parseCsv(content);
    await _createCardsInDecks(
      cards,
      parentDeckId: parentDeckId,
      skipDuplicates: skipDuplicates,
    );
  }

  Future<void> _createCardsInDecks(
    List<CardData> cards, {
    String? parentDeckId,
    bool skipDuplicates = false,
  }) async {
    final Map<String, List<CardData>> cardsByDeck = {};
    for (final card in cards) {
      cardsByDeck.putIfAbsent(card.path, () => []).add(card);
    }

    for (final entry in cardsByDeck.entries) {
      final deck = await _deckRepository.getOrCreateByPath(
        entry.key,
        parentId: parentDeckId,
      );

      Set<String>? existingFronts;
      if (skipDuplicates) {
        final existing = await _cardRepository.getByDeckId(deck.deckId);
        existingFronts = existing.map((c) => c.front).toSet();
      }

      for (final cardData in entry.value) {
        if (existingFronts != null && existingFronts.contains(cardData.front)) {
          continue;
        }
        final card = Flashcard.newCard(
          deckId: deck.deckId,
          front: cardData.front,
          back: cardData.back,
        );
        await _cardRepository.create(card);
      }
    }
  }

  List<CardData> parseCsv(String content) {
  final normalized = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  final rows = const CsvToListConverter(eol: '\n').convert(normalized);

  return rows.skip(1).where((row) {
    if (row.length < 3) {
      debugPrint('Skipping malformed CSV row (expected 3 columns, got ${row.length}): $row');
      return false;
    }
    return true;
  }).map((row) {
    return CardData(
      path:  row[0].toString(),
      front: row[1].toString(),
      back:  row[2].toString(),
    );
  }).toList();
}
}

class CardData {
  final String path;
  final String front;
  final String back;
  CardData({required this.path, required this.front, required this.back});
}
