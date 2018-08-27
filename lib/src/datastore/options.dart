/// Specifies read consistency.
class ReadConsistency {
  /// Strong consistency.
  static const ReadConsistency strong = const ReadConsistency._("STRONG");

  /// Eventual consistency.
  static const ReadConsistency eventual = const ReadConsistency._("EVENTUAL");

  static const List<ReadConsistency> values = const [strong, eventual];

  /// Look up read consistency by name.
  static ReadConsistency lookup(String name) {
    if (_nameToValue == null) {
      _nameToValue =
          new Map<String, ReadConsistency>.fromIterable(values, key: (value) => (value as ReadConsistency).name);
    }
    return _nameToValue[name] ?? new ReadConsistency._(name);
  }

  const ReadConsistency._(this.name);

  /// Creates a [ReadConsistency] using a currently unsupported API value,
  /// or returns a currently existing instance if it is already supported.
  factory ReadConsistency.custom(String name) => lookup(name);

  final String name;

  static Map<String, ReadConsistency> _nameToValue;
}
