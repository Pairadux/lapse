import 'package:flutter_riverpod/legacy.dart';

final cardFormProvider =
    StateNotifierProvider<CardFormNotifier, CardFormState>(
  (ref) => CardFormNotifier(),
);

class CardFormState {
  final String deckId;
  final String front;
  final String back;

  const CardFormState({
    this.deckId = '',
    this.front = '',
    this.back = '',
  });

  CardFormState copyWith({
    String? deckId,
    String? front,
    String? back,
  }) {
    return CardFormState(
      deckId: deckId ?? this.deckId,
      front: front ?? this.front,
      back: back ?? this.back,
    );
  }
}

class CardFormNotifier extends StateNotifier<CardFormState> {
  CardFormNotifier() : super(const CardFormState());

  void setDeckId(String value) {
    state = state.copyWith(deckId: value);
  }

  void setFront(String value) {
    state = state.copyWith(front: value);
  }

  void setBack(String value) {
    state = state.copyWith(back: value);
  }

  void reset() {
    state = const CardFormState();
  }
}
