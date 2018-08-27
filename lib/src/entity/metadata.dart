
/// Common interface for all property metadata objects.
abstract class PropertyMetadata {
  bool get indexed;
  bool get indexedIfNonNull;
  bool get skipIfMissing;
}

/// Marks the field as persistent, mappable to entity properties.
class Persistent implements PropertyMetadata {
  /// Marks the field or property as persistent. If the field is a property it
  /// should be declared on the getter. In this case the setter will be looked
  /// for and used, but its `Persistent` annotation is optional and will be
  /// ignored.
  const Persistent({
    this.name,
    this.indexed: true,
    this.primaryKey: false,
    this.indexedIfNonNull: false,
    this.skipIfMissing,
  });

  /// Overrides the property name if not `null`. Otherwise the name will be
  /// the name of the field. Not applicable to primary keys.
  final String name;
  /// Specifies whether the property should be indexed. The default is `true`.
  /// Not applicable to primary keys.
  @override
  final bool indexed;
  /// Only indexed if the value is not `null`: `null` values are unindexed.
  @override
  final bool indexedIfNonNull;
  /// Specifies whether the property defines the primary key for this entity.
  /// Every entity has to have a primary key field.
  final bool primaryKey;
  /// When bridging from an entity leave this property alone if it is missing in the entity,
  /// or `null` to use the default specified in [EntityModel].
  @override
  final bool skipIfMissing;
}

/// Persistent with default settings.
///
/// The default settings are:
/// - the field's name is used as property name
/// - the value will be indexed
/// - it is a regular property not the primary key
const Persistent persistent = const Persistent();
/// The field is the primary key.
const Persistent primaryKey = const Persistent(primaryKey: true);
/// Same as [persistent] except that this property value will be unindexed.
const Persistent unindexed = const Persistent(indexed: false);

/// Fields with type of `int` and marked with this annotation will be set to the
/// entity version, or `null` if the entity version info is missing (for
/// example all reads without strong consistency).
class EntityVersion {
  const EntityVersion();
}

/// Fields with type of `int` and marked with this annotation will be set to the
/// entity version, or `null` if the entity version info is missing (for
/// example all reads without strong consistency).
const EntityVersion entityVersion = const EntityVersion();

/// Marks the class as a persistent object, mappable to entities.
class EntityModel {
  /// Marks the class as an entity model class.
  ///
  /// Use the [kind] parameter to optionally override the entity kind. If
  /// [kind] is set to `null` (or is omitted) the kind will be the entity model
  /// class name.
  const EntityModel({this.kind, this.skipMissingProperties: false, this.checkKeyKind: true});

  final String kind;
  final bool skipMissingProperties;
  final bool checkKeyKind;
}

/// Attribute for entity model classes with the default kind name (the class
/// name).
const EntityModel entityModel = const EntityModel();
