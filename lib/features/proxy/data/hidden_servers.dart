/// Servers the lists leave out: the provider's "Автовыбор игровой" group (its own auto-pick for games, which the
/// app's Auto already does better). Matched by name, whatever the flag or numbering around it.
bool isHiddenServer(String name) {
  final lower = name.toLowerCase();
  return lower.contains('игров') || lower.contains('gaming');
}
