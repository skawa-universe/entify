import "dart:mirrors";
import "dart:typed_data";

import "accessors.dart";
import "metadata.dart";
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
    return new EntityBridge._(b.descriptor, b.kind, b.key, new Map.unmodifiable(b.propertyMetadata),
        new List.unmodifiable(b.versionFields));
  }

  /// Constructs or returns a cached [EntityBridge] object based on
  /// the type parameter [T].
  factory EntityBridge() {
    return new EntityBridge<T>.fromClass(T);
  }

  EntityBridge._(this.descriptor, this.kind, this._key, this._propertyMetadata, this._versionFields);

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
      if (value is Key && !value.isComplete)
        throw new EntityModelError("Value of ${prop.name} is an incomplete key: $value!");
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
    bool defaultSkip = descriptor.skipMissingProperties ?? false;
    if ((descriptor.checkKeyKind ?? true) && key != null && key.kind != kind)
      throw new ArgumentError.value(key.kind, "source.key.kind", "is not $kind");
    if (keyAccessor.acceptsType(Key)) {
      keyAccessor.setValue(im, key);
    } else if (key?.isComplete ?? false) {
      if (key.id != null && keyAccessor.acceptsType(int)) {
        keyAccessor.setValue(im, key.id);
      } else if (key.name != null && keyAccessor.acceptsType(String)) {
        keyAccessor.setValue(im, key.name);
      }
    }
    for (EntityPropertyBridge prop in _versionFields) {
      if (!(prop.metadata?.skipIfMissing ?? defaultSkip) || source.version != null) {
        prop.accessor.setValue(im, source.version);
      }
    }
    for (EntityPropertyBridge prop in _propertyMetadata.values) {
      if (!(prop.metadata?.skipIfMissing ?? defaultSkip) || source.containsProperty(prop.name)) {
        dynamic value = source[prop.name];
        // copy lists so there's no strange changes in lists
        if (value is! TypedData && value is Iterable) value = value.toList();
        prop.accessor.setValue(im, source[prop.name]);
      }
    }
    return target;
  }

  /// Creates a new [Query] object on the kind represented by this [EntityBridge] object.
  Query query() => new Query(kind);

  bool entityKindMatches(Entity entity) => entity?.kind == kind;

  bool keyKindMatches(Key key) => key?.kind == kind;

  String toString() =>
      "EntityBridge($kind, $_key, ${_propertyMetadata.values.join(", ")})";

  final EntityModel descriptor;
  /// The kind this [EntityBridge] instance represents.
  final String kind;
  final EntityPropertyBridge _key;
  final Map<String, EntityPropertyBridge> _propertyMetadata;
  final List<EntityPropertyBridge> _versionFields;

  static final Map<Type, dynamic> _cachedBridges = {};
}
