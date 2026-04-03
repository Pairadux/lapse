import 'package:lapse/features/cards/data/card_repository.dart';
import 'package:lapse/features/cards/domain/flashcard.dart';
import 'package:lapse/features/decks/data/deck_repository.dart';
import 'package:lapse/features/decks/domain/deck.dart';

class DeckExport {
  /// Export a specific deck and all descendant decks' cards as CSV.
  ///
  /// Automatically fetches cards from the deck and all its children.
  /// [cardRepo] and [deckRepo] handle all database queries.
  Future<String> exportDeckWithRepositories(Deck deck, CardRepository cardRepo, DeckRepository deckRepo) async {
    final allDecks = await deckRepo.getAll();
    final allCards = await cardRepo.getAllCards(); // single query, already ordered by deck_id
    return exportDeck(deck, allCards, allDecks);
  }

  // Deck is the root
  // alldecks is the full list of decks to build the path map for labeling
  String exportDeck(Deck deck, List<Flashcard> cards, List<Deck> allDecks) {
    final pathMap = buildPathMap(allDecks);
    final deckIds = _collectDeckAndDescendants(deck.deckId, allDecks);

    // Filter cards to only those in the target deck tree and convert to row maps.
    final deckCards = cards.where((card) => deckIds.contains(card.deckId)).toList();

    final cardRows = deckCards.map((card) => {'deck_id': card.deckId, 'front': card.front, 'back': card.back}).toList();

    return writeCsv(cardRows, pathMap);
  }

  Set<String> _collectDeckAndDescendants(String rootDeckId, List<Deck> decks) {
    final byParent = <String, List<Deck>>{};

    for (final deck in decks) {
      if (deck.parentId != null) {
        byParent.putIfAbsent(deck.parentId!, () => []).add(deck);
      }
    }

    final descendants = <String>{rootDeckId};
    final queue = <String>[rootDeckId];

    while (queue.isNotEmpty) {
      final current = queue.removeLast();
      final children = byParent[current];
      if (children == null) continue;
      for (final child in children) {
        if (descendants.add(child.deckId)) {
          queue.add(child.deckId);
        }
      }
    }

    return descendants;
  }

  Map<String, String> buildPathMap(List<Deck> decks) {
    final byId = {for (final d in decks) d.deckId: d};
    final paths = <String, String>{};

    for (final deck in decks) {
      final segments = <String>[];
      var current = deck;
      while (true) {
        segments.add(current.deckName);
        final parent = byId[current.parentId];
        if (parent == null) break;
        current = parent;
      }
      paths[deck.deckId] = segments.reversed.join('::');
    }
    return paths;
  }

  String writeCsv(List<Map<String, dynamic>> cardRows, Map<String, String> pathMap) {
    final buffer = StringBuffer();
    buffer.writeln('deck,front,back');

    for (final row in cardRows) {
      final path = pathMap[row['deck_id']];
      final front = escapeCsvField(row['front'] as String);
      final back = escapeCsvField(row['back'] as String);
      // If the card deck path is missing for some reason, use root deck id context.
      final deckLabel = path ?? row['deck_id']?.toString() ?? '';
      final escapedDeck = escapeCsvField(deckLabel);
      buffer.writeln('$escapedDeck,$front,$back');
    }

    return buffer.toString();
  }

  String escapeCsvField(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n') || value.contains('\r')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
