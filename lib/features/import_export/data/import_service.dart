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

  Future<void> importDeckFromCSV(File csvFile) async {
    final content = csvFile.readAsStringSync();
    final cards = parseCsv(content);
    await _createCardsInDecks(cards);
  }

  Future<void> _createCardsInDecks(List<CardData> cards) async {
    final Map<String, List<CardData>> cardsByDeck = {};
    for (final card in cards) {
      cardsByDeck.putIfAbsent(card.path, () => []).add(card);
    }

    for (final entry in cardsByDeck.entries) {
      final deck = await _deckRepository.getOrCreateByPath(entry.key);
      for (final cardData in entry.value) {
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
