import 'package:flutter_riverpod/legacy.dart';

final deckFormProvider =
    StateNotifierProvider<DeckFormNotifier, DeckFormState>(
  (ref) => DeckFormNotifier(),
);

class DeckFormState {
  final String name;
  final String parentID;

  const DeckFormState({
    this.name = '',
    this.parentID = '',
  });

  DeckFormState copyWith({
    String? name,
    String? parentID,
  }) {
    return DeckFormState(
      name: name ?? this.name,
      parentID: parentID ?? this.parentID,
    );
  }
}

class DeckFormNotifier extends StateNotifier<DeckFormState> {
  DeckFormNotifier() : super(const DeckFormState());

  void setName(String value) {
    state = state.copyWith(name: value);
  }

  void setParent(String parentId) {
    state = state.copyWith(parentID: parentId);
  }

  void reset() {
    state = const DeckFormState();
  }
}
