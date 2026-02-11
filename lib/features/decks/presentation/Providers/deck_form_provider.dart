import 'package:flutter_riverpod/legacy.dart';

final deckFormProvider =
    StateNotifierProvider<DeckFormNotifier, DeckFormState>(
  (ref) => DeckFormNotifier(),
);

class DeckFormState {
  final String name;
  final String parentId;

  const DeckFormState({
    this.name = '',
    this.parentId = '',
  });

  DeckFormState copyWith({
    String? name,
    String? parentId,
  }) {
    return DeckFormState(
      name: name ?? this.name,
      parentId: parentId ?? this.parentId,
    );
  }
}

class DeckFormNotifier extends StateNotifier<DeckFormState> {
  DeckFormNotifier() : super(const DeckFormState());

  void setName(String value) {
    state = state.copyWith(name: value);
  }

  void setParent(String parentId) {
    state = state.copyWith(parentId: parentId);
  }

  void reset() {
    state = const DeckFormState();
  }
}
