import "dart:mirrors";
import "dart:typed_data";

import "accessors.dart";
import "errors.dart";
import "builder.dart";
import "../datastore/entity.dart";
import "../datastore/key.dart";
import "../datastore/query.dart";

/// Maps entity model objects of a certain type to [Entity] objects and back.
///
/// The type parameter [T] must be the same class that is passed to the constructor
/// (or pass the type to the default constructor as a generic type parameter).
class EntityBridge<T> {
  /// Constructs an entity mapper object based on [type].
  ///
  /// Uses an internal cache of [EntityBridge] objects.
  factory EntityBridge.fromClass(Type type) {
    EntityBridge<T> result = _cachedBridges[type];
    if (result != null) return result;
    result = new EntityBridge.uniqueFromClass(type);
    _cachedBridges[type] = result;
    return result;
  }

  /// Constructs a brand new and unique mapper based on [type].
  ///
  /// Normally there's no need to use this constructor, the cached object
  /// should do every time.
  factory EntityBridge.uniqueFromClass(Type type) {
    EntityMetadataBuilder b = new EntityMetadataBuilder.fromClass(type);
    return new EntityBridge._(b.kind, b.key, b.propertyMetadata);
  }

  /// Constructs or returns a cached [EntityBridge] object based on
  /// the type parameter [T].
  factory EntityBridge() {
    return new EntityBridge<T>.fromClass(T);
  }

  EntityBridge._(this.kind, this._key, this._propertyMetadata);

  Key createKey({String name, int id, Key parent}) =>
      new Key(kind, name: name, id: id, parent: parent);

  /// Converts an entity model object to an [Entity] object.
  Entity toEntity(T model) {
    InstanceMirror im = reflect(model);
    Entity result = new Entity();
    dynamic key = _key.accessor.getValue(im);
    if (key is Key) {
      if (key.kind != kind) {
        throw new EntityModelError("Key has a kind \"${key.kind}\", but "
            "the model entity is \"${kind}\"");
      }
      result.key = key;
    } else if (key is int) {
      result.key = new Key(kind, id: key);
    } else if (key is String || key == null) {
      result.key = new Key(kind, name: key);
    } else {
      throw new EntityModelError("Unrecognized key type: ${key.runtimeType}");
    }

    for (EntityPropertyBridge prop in _propertyMetadata.values) {
      var value = prop.accessor.getValue(im);
      // flatten/duplicate iterables so there's no strange changes in lists
      if (value is! TypedData && value is Iterable) value = value.toList();
      final bool indexed = prop.metadata.indexed &&
          (!prop.metadata.indexedIfNonNull || value != null);
      result.setValue(prop.name, value, indexed: indexed);
    }

    return result;
  }

  /// Sets the properties of an entity model object based on an [Entity] object and
  /// returns the entity model object.
  T fromEntity(Entity source, T target) {
    InstanceMirror im = reflect(target);
    Key key = source.key;
    PropertyAccessor keyAccessor = _key.accessor;
    if (keyAccessor.acceptsType(Key)) {
      keyAccessor.setValue(im, key);
    } else if (key.isComplete) {
      if (key.id != null && keyAccessor.acceptsType(int)) {
        keyAccessor.setValue(im, key.id);
      } else if (key.name != null && keyAccessor.acceptsType(String)) {
        keyAccessor.setValue(im, key.name);
      }
    }
    for (EntityPropertyBridge prop in _propertyMetadata.values)
      prop.accessor.setValue(im, source[prop.name]);
    return target;
  }

  /// Creates a new [Query] object on the kind represented by this [EntityBridge] object.
  Query query() => new Query(kind);

  String toString() =>
      "EntityBridge($kind, $_key, ${_propertyMetadata.values.join(", ")})";

  /// The kind this [EntityBridge] instance represents.
  final String kind;
  final EntityPropertyBridge _key;
  final Map<String, EntityPropertyBridge> _propertyMetadata;

  static final Map<Type, dynamic> _cachedBridges = {};
}
