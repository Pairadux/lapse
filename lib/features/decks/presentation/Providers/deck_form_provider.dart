import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:lapse/features/decks/presentation/Providers/deck_list_provider.dart';
import '../../domain/deck.dart';
import '../../data/deck_repository.dart';
import 'package:uuid/uuid.dart';

final deckFormProvider = StateNotifierProvider<DeckFormNotifier, DeckFormState>(
  (ref) => DeckFormNotifier(ref.read as Reader),
);

class DeckFormState {
  final String deckName;
  final String? parentID;
  final bool isSubmitting;
  final String? error;

  DeckFormState({this.deckName = '', this.parentID, this.isSubmitting = false, this.error});

  DeckFormState copyWith({String? deckName, String? parentID, bool? isSubmitting, String? error}) {
    return DeckFormState(
      deckName: deckName ?? this.deckName,
      parentID: parentID ?? this.parentID,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }
}

class DeckFormNotifier extends StateNotifier<DeckFormState> {
  final Reader read;

  DeckFormNotifier(this.read) : super(DeckFormState());

  void setDeckName(String name) {
    state = state.copyWith(deckName: name, error: null);
  }

  void setParentID(String? parentID) {
    state = state.copyWith(parentID: parentID);
  }

  // Create a new deck
  Future<bool> submitNewDeck() async {
    if (state.deckName.trim().isEmpty) {
      state = state.copyWith(error: 'Deck name cannot be empty');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    final deck = Deck(
      deckID: const Uuid().v4(),
      parentID: state.parentID ?? '',
      deckName: state.deckName.trim(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      isDeleted: false,
      cards: [],
      cardCount: 0,
      dueCount: 0,
    );

    try {
      await read.createDeck(deck);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }

  // Edit existing deck
  Future<bool> submitEditDeck(Deck existingDeck) async {
    if (state.deckName.trim().isEmpty) {
      state = state.copyWith(error: 'Deck name cannot be empty');
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    final updatedDeck = existingDeck.copyWith(
      deckName: state.deckName.trim(),
      updatedAt: DateTime.now(),
      parentID: state.parentID,
    );

    try {
      await read.updateDeck(updatedDeck);
      state = state.copyWith(isSubmitting: false);
      return true;
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
      return false;
    }
  }
}
