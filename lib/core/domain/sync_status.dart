enum SyncStatus {
  synced('synced'),
  pending('pending'),
  conflict('conflict');

  final String value;
  const SyncStatus(this.value);
}
