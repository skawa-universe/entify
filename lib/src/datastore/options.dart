
/// Specifies read consistency.
class ReadConsistency {
  /// Strong consistency.
  static const strong = const ReadConsistency._("STRONG");

  /// Eventual consistency.
  static const eventual = const ReadConsistency._("EVENTUAL");

  static const List<ReadConsistency> values = const [strong, eventual];

  /// Look up read consistency by name.
  static ReadConsistency lookup(String opName) {
    if (_nameToValue == null) {
      _nameToValue = {};
      for (ReadConsistency op in values) {
        _nameToValue[op.name] = op;
      }
    }
    return _nameToValue[opName] ?? new ReadConsistency._(opName);
  }

  const ReadConsistency._(this.name);

  /// Creates a [ReadConsistency] using a currently unsupported API value,
  /// or returns a currently existing instance if it is already supported.
  factory ReadConsistency.custom(String name) => lookup(name);

  final String name;

  static Map<String, ReadConsistency> _nameToValue;
}
