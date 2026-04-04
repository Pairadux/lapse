abstract class Routes {
  static const home = '/';
  static const debug = '/debug';
  static const devStats = '/dev/stats';
  static const devSupabase = '/dev/supabase';
  static const settings = '/settings';
  static const deckNew = '/deck/new';
  static const deck = '/deck/:deckId';
  static const deckEdit = '/deck/:deckId/edit';
  static const cardNew = '/deck/:deckId/card/new';
  static const card = '/deck/:deckId/card/:cardId';
  static const study = '/deck/:deckId/study';
  static const cardBrowser = '/cards';

  static String deckPath(String deckId) => '/deck/$deckId';
  static String deckEditPath(String deckId) => '/deck/$deckId/edit';
  static String cardNewPath(String deckId) => '/deck/$deckId/card/new';
  static String cardPath(String deckId, String cardId) =>
      '/deck/$deckId/card/$cardId';
  static String studyPath(String deckId) => '/deck/$deckId/study';
}
