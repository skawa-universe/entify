import "dart:async";

import "package:googleapis/datastore/v1.dart" as ds;

import "errors.dart";
import "api_mapping.dart";
import "util.dart";

R withNamespace<R>(String name, R body()) =>
    runZoned(body, zoneValues: {Namespace.zoneKey: new Namespace(name)});

class Namespace {
  static final Object zoneKey = new Object();

  static Namespace get current => Zone.current[Namespace.zoneKey] as Namespace;

  static String get currentName => current?.name;

  const Namespace(this.name);

  final String name;
}

/// An immutable class that represents a Datastore key.
///
///
class Key implements ApiRepresentation<ds.Key> {
  /// Creates a key of [kind] with a [parent] key as incomplete or either with
  /// an [id] or a [name] (at most one can be specified of these).
  Key(this.kind, {this.name, this.id, this.parent, String namespace})
      : this.namespace = namespace ?? Namespace.currentName {
    if (kind == null)
      throw new DatastoreShellError("The kind must not be null");
    if (parent != null && !parent.isComplete)
      throw new DatastoreShellError("Parent key is not complete");
    if (name != null && id != null)
      throw new DatastoreShellError(
          "Both name and id is specified (name: ${name}, id: ${id})");
  }

  /// Creates a key from the `package:googleapis` representation.
  factory Key.fromApiObject(ds.Key key) {
    Key lastKey;
    String namespace = key.partitionId?.namespaceId;
    for (ds.PathElement element in key.path) {
      lastKey = new Key(
        element.kind,
        name: element.name,
        id: element.id == null ? null : int.parse(element.id, radix: 10),
        parent: lastKey,
        namespace: namespace,
      );
    }
    return lastKey;
  }

  /// Converts the key to the `package:googleapis` representation.
  @override
  ds.Key toApiObject() {
    ds.Key key = new ds.Key()..path = _buildPath();
    if (namespace != null)
      key.partitionId = new ds.PartitionId()..namespaceId = namespace;
    return key;
  }

  /// Returns whether the key is complete: an incomplete key has no
  /// name nor id.
  bool get isComplete => name != null || id != null;

  @override
  String toString() =>
      "${parent?.toString() ?? ''}${parent == null ? '' : '/'}$kind"
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

  @override
  int get hashCode => combineHash(
      kind.hashCode,
      combineHash(
          id.hashCode,
          combineHash(name.hashCode,
              combineHash(parent.hashCode, (namespace ?? "").hashCode))));

  @override
  bool operator ==(dynamic other) =>
      other is Key &&
      kind == other.kind &&
      name == other.name &&
      id == other.id &&
      parent == other.parent &&
      (namespace ?? "") == (other.namespace ?? "");

  final String kind;
  final String name;
  final int id;
  final Key parent;
  final String namespace;
}
