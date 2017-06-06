import "package:googleapis/datastore/v1.dart" as ds;

import "errors.dart";
import "api_mapping.dart";
import "util.dart";

/// An immutable class that represents a Datastore key.
///
///
class Key implements ApiRepresentation<ds.Key> {
  /// Creates a key of [kind] with a [parent] key as incomplete or either with
  /// an [id] or a [name] (at most one can be specified of these).
  Key(this.kind, {this.name, this.id, this.parent}) {
    if (parent != null && !parent.isComplete)
      throw new DatastoreShellError("Parent key is not complete");
    if (name != null && id != null)
      throw new DatastoreShellError("Both name and id is specified (name: ${name}, id: ${id})");
  }

  /// Creates a key from the `package:googleapis` representation.
  factory Key.fromProtocol(ds.Key key) {
    Key lastKey = null;
    for (ds.PathElement element in key.path) {
      lastKey = new Key(element.kind,
          name: element.name,
          id: element.id == null ? null : int.parse(element.id, radix: 10),
          parent: lastKey);
    }
    return lastKey;
  }

  /// Converts the key to the `package:googleapis` representation.
  ds.Key toApiObject() => new ds.Key()..path = _buildPath();

  /// Returns whether the key is complete: an incomplete key has no
  /// name nor id.
  bool get isComplete => name != null || id != null;

  String toString() => "${parent?.toString() ?? ''}${parent == null ? '' : '/'}$kind"
      "(${id == null ? '' : id}"
      "${name == null ? '' : '\"$name\"'})";

  List<ds.PathElement> _buildPath() {
    ds.PathElement e = new ds.PathElement()
      ..kind = kind
      ..name = name
      ..id = id?.toString();
    if (parent == null)
      return [e];
    else
      return parent._buildPath()..add(e);
  }

  int get hashCode => combineHash(kind.hashCode,
      combineHash(id.hashCode, combineHash(name.hashCode, parent.hashCode)));

  bool operator ==(dynamic other) =>
      other is Key &&
      kind == other.kind &&
      name == other.name &&
      id == other.id &&
      parent == other.parent;

  final String kind;
  final String name;
  final int id;
  final Key parent;
}
