import "package:googleapis/datastore/v1.dart" as ds;

import "api_mapping.dart";
import "values.dart";
import "key.dart";
import "errors.dart";

/// A helper class to add indexed/unindexed properties to [Entity] objects using
/// the `[]` operator.
///
/// It acts as a view, if the [Entity] object changes, it is reflected here and
/// vice versa.
class PropertyOutlet {
  PropertyOutlet._(this.parent, this.indexed);

  /// Returns the given property depending on whether it's (un)indexed or not.
  Object operator [](String name) =>
      parent.isIndexed(name) == indexed ? parent._properties[name] : null;

  /// Sets a property with the specified indexed value.
  void operator []=(String name, Object value) =>
      parent.setValue(name, value, indexed: indexed);

  /// Merges the whole map of properties in [values] and sets the `indexed`
  /// property uniformly for these properties.
  void addAll(Map<String, Object> values) {
    parent._properties.addAll(values);
    for (String key in values.keys) parent.setIndexed(key, indexed: indexed);
  }

  /// Removes a property
  void remove(String name) {
    if (parent.isIndexed(name) == indexed) parent.remove(name);
  }

  /// Set to the [Entity] object this outlet writes to.
  final Entity parent;

  /// Set to whether this [PropertyOutlet] sets the values as indexed
  /// (`true`) or as unindexed (`false`).
  final bool indexed;
}

/// Represents a Datastore entity. Allows a simpler, easier to manage interface
/// than the API class (in `package:googleapis`).
///
/// Allows conversion to and from API level entity objects.
class Entity implements ApiRepresentation<ds.Entity> {
  /// Creates an entity with a `null` key.
  ///
  /// An entity may not be inserted in this state, it must have at least an
  /// incomplete key (a key with kind, but no id or name).
  Entity() : version = null;

  /// Creates an entity with an incomplete key.
  ///
  /// An incomplete key is a key that has a kind, but no id or name. When an
  /// entity like this is inserted into the Datastore, an id is automatically
  /// generated for it.
  Entity.ofKind(String kind) : key = new Key(kind), version = null;

  /// Creates an entity from a `package:googleapis` object.
  factory Entity.fromApiObject(ds.Entity entity) => new Entity._fromApiObject(entity);

  /// Creates an entity from a `package:googleapis` `EntityResult` object, so the
  /// version field is filled.
  factory Entity.fromEntityResult(ds.EntityResult result) => new Entity._fromApiObject(result.entity,
      version: result.version != null ? int.parse(result.version, radix: 10) : result.version);

  Entity._fromApiObject(ds.Entity entity, {int version})
      : key = new Key.fromApiObject(entity.key),
        version = version {
    Map<String, ds.Value> values = entity.properties;
    if (values != null) {
      _properties.addAll(new Map.fromIterable(values.keys, value: (name) {
        try {
          return fromValue(values[name]);
        } on DatastoreShellError catch (e) {
          throw new DatastoreShellError("Field $name: ${e.message}");
        }
      }));
      _unindexedProperties.addAll(
          values.keys.where((name) => values[name].excludeFromIndexes ?? false));
    }
  }

  @override
  String toString() => {"key": key, "properties": _properties, "unindexed": _unindexedProperties}.toString();

  /// Creates a `package:googleapis` object representation of this entity.
  ds.Entity toApiObject() => new ds.Entity()
    ..key = key.toApiObject()
    ..properties = new Map.fromIterable(
      _properties.keys,
      value: (name) => toValue(_properties[name],
          excludeFromIndexes: _unindexedProperties.contains(name)),
    );

  /// Returns the kind of this entity, or `null` if this entity has a `null` key
  /// (which is an invalid state, it should have at least an incomplete key).
  String get kind => key?.kind;

  /// Sets the property named [name] to the value [value] and makes it (un)[indexed]
  /// (default is indexed).
  void setValue(String name, Object value, {bool indexed: true}) {
    if (value is IndexedOverride) {
      IndexedOverride override = value;
      indexed = override.indexed;
      value = override.value;
    }
    _properties[name] = value;
    setIndexed(name, indexed: indexed);
  }

  /// Overrides whether the property named [name] should be indexed.
  void setIndexed(String name, {bool indexed: true}) {
    if (_properties.containsKey(name)) {
      if (indexed)
        _unindexedProperties.remove(name);
      else
        _unindexedProperties.add(name);
    }
  }

  /// Returns whether the given property is indexed (`true`) or not (`false`).
  bool isIndexed(String name) => !_unindexedProperties.contains(name);

  /// Returns whether the given property is set.
  bool containsProperty(String name) => _properties.containsKey(name);

  /// Removes the property by [name].
  Object remove(String name) {
    _unindexedProperties.remove(name);
    return _properties.remove(name);
  }

  /// Removes all properties from this entity.
  void clearProperties() {
    _properties.clear();
    _unindexedProperties.clear();
  }

  void setPropertiesFrom(Entity other) {
    _unindexedProperties.removeAll(other._properties.keys);
    _unindexedProperties.addAll(other._unindexedProperties);
    _properties.addAll(other._properties);
  }


  Iterable<String> get propertyNames => _properties.keys;

  /// Returns a property value.
  Object operator [](String name) => _properties[name];

  /// Returns a view on the indexed properties.
  ///
  /// All changes on this outlet are reflected on the entity and vice versa.
  PropertyOutlet get indexed {
    if (_indexed == null) _indexed = new PropertyOutlet._(this, true);
    return _indexed;
  }

  /// Returns a view on the unindexed properties.
  ///
  /// All changes on this outlet are reflected on the entity and vice versa.
  PropertyOutlet get unindexed {
    if (_unindexed == null) _unindexed = new PropertyOutlet._(this, false);
    return _unindexed;
  }

  PropertyOutlet _indexed;
  PropertyOutlet _unindexed;

  /// The key of this entity.
  Key key;
  final Map<String, Object> _properties = {};
  final Set<String> _unindexedProperties = new Set();

  /// The datastore provided version
  final int version;
}
