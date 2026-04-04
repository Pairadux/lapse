// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'card_browser_filters.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$CardBrowserFiltersCWProxy {
  CardBrowserFilters searchQuery(String searchQuery);

  CardBrowserFilters deckId(String? deckId);

  CardBrowserFilters cardState(CardStateFilter cardState);

  CardBrowserFilters sortBy(CardSortBy sortBy);

  CardBrowserFilters sortAscending(bool sortAscending);

  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `CardBrowserFilters(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CardBrowserFilters(...).copyWith(id: 12, name: "My name")
  /// ```
  CardBrowserFilters call({
    String searchQuery,
    String? deckId,
    CardStateFilter cardState,
    CardSortBy sortBy,
    bool sortAscending,
  });
}

/// Callable proxy for `copyWith` functionality.
/// Use as `instanceOfCardBrowserFilters.copyWith(...)` or call `instanceOfCardBrowserFilters.copyWith.fieldName(value)` for a single field.
class _$CardBrowserFiltersCWProxyImpl implements _$CardBrowserFiltersCWProxy {
  const _$CardBrowserFiltersCWProxyImpl(this._value);

  final CardBrowserFilters _value;

  @override
  CardBrowserFilters searchQuery(String searchQuery) =>
      call(searchQuery: searchQuery);

  @override
  CardBrowserFilters deckId(String? deckId) => call(deckId: deckId);

  @override
  CardBrowserFilters cardState(CardStateFilter cardState) =>
      call(cardState: cardState);

  @override
  CardBrowserFilters sortBy(CardSortBy sortBy) => call(sortBy: sortBy);

  @override
  CardBrowserFilters sortAscending(bool sortAscending) =>
      call(sortAscending: sortAscending);

  @override
  /// Creates a new instance with the provided field values.
  /// Passing `null` to a nullable field nullifies it, while `null` for a non-nullable field is ignored. To update a single field use `CardBrowserFilters(...).copyWith.fieldName(value)`.
  ///
  /// Example:
  /// ```dart
  /// CardBrowserFilters(...).copyWith(id: 12, name: "My name")
  /// ```
  CardBrowserFilters call({
    Object? searchQuery = const $CopyWithPlaceholder(),
    Object? deckId = const $CopyWithPlaceholder(),
    Object? cardState = const $CopyWithPlaceholder(),
    Object? sortBy = const $CopyWithPlaceholder(),
    Object? sortAscending = const $CopyWithPlaceholder(),
  }) {
    return CardBrowserFilters(
      searchQuery:
          searchQuery == const $CopyWithPlaceholder() || searchQuery == null
          ? _value.searchQuery
          // ignore: cast_nullable_to_non_nullable
          : searchQuery as String,
      deckId: deckId == const $CopyWithPlaceholder()
          ? _value.deckId
          // ignore: cast_nullable_to_non_nullable
          : deckId as String?,
      cardState: cardState == const $CopyWithPlaceholder() || cardState == null
          ? _value.cardState
          // ignore: cast_nullable_to_non_nullable
          : cardState as CardStateFilter,
      sortBy: sortBy == const $CopyWithPlaceholder() || sortBy == null
          ? _value.sortBy
          // ignore: cast_nullable_to_non_nullable
          : sortBy as CardSortBy,
      sortAscending:
          sortAscending == const $CopyWithPlaceholder() || sortAscending == null
          ? _value.sortAscending
          // ignore: cast_nullable_to_non_nullable
          : sortAscending as bool,
    );
  }
}

extension $CardBrowserFiltersCopyWith on CardBrowserFilters {
  /// Returns a callable class used to build a new instance with modified fields.
  /// Example: `instanceOfCardBrowserFilters.copyWith(...)` or `instanceOfCardBrowserFilters.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$CardBrowserFiltersCWProxy get copyWith =>
      _$CardBrowserFiltersCWProxyImpl(this);
}
