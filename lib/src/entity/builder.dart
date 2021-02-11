import "dart:mirrors";

import "accessors.dart";
import "errors.dart";
import "metadata.dart";

/// Defines a mapping between an object property and an entity property.
class EntityPropertyBridge {
  EntityPropertyBridge._(String name, this.metadata, PropertyAccessor accessor)
      : this.accessor = accessor,
        this.name = name ?? accessor.name;

  @override
  String toString() => metadata == null
      ? "${name} <=> ${accessor.name}"
      : metadata.indexed
          ? (metadata.indexedIfNonNull
              ? "${name} <=> unindexedNull(${accessor.name})"
              : "${name} <=> ${accessor.name}")
          : "${name} <=> unindexed(${accessor.name})";

  /// The entity property name.
  final String name;

  /// The persistence metadata attached to this mapping.
  final PropertyMetadata metadata;

  /// The object property accessor object.
  final PropertyAccessor accessor;
}

/// A mutable class from which an immutable EntityBridge object can be built.
class EntityMetadataBuilder {
  factory EntityMetadataBuilder.fromClass(Type type) =>
      new EntityMetadataBuilder.fromMirror(reflectClass(type));

  EntityMetadataBuilder.fromMirror(ClassMirror leaf) {
    EntityModel desc;
    for (InstanceMirror im in leaf.metadata) {
      if (im.reflectee is EntityModel) {
        desc = im.reflectee;
        break;
      }
    }
    if (desc == null) {
      throw new EntityModelError(
          "Type is not entity model: ${leaf.reflectedType}");
    }
    kind = desc.kind ?? MirrorSystem.getName(leaf.simpleName);
    descriptor = desc;
    for (ClassMirror current = leaf;
        current != null;
        current = current.superclass) {
      _process(current);
    }

    if (key == null)
      throw new EntityModelError(
          "Type does not define a key: ${leaf.reflectedType}");
  }

  void _process(ClassMirror s) {
    final Map<Symbol, DeclarationMirror> declarations = s.declarations;
    for (Symbol fieldName in declarations.keys) {
      String fieldNameAsString = MirrorSystem.getName(fieldName);
      final DeclarationMirror declaration = declarations[fieldName];
      List<InstanceMirror> metadata = declaration.metadata;
      PropertyAccessor accessor;
      if (declaration is VariableMirror) {
        VariableMirror vm = declaration;
        if (vm.isStatic) continue;
        accessor = FieldPropertyAccessor.create(vm);
      }
      if (declaration is MethodMirror) {
        MethodMirror mm = declaration;
        if (mm.isStatic || !mm.isGetter) continue;
        String setterName = "${MirrorSystem.getName(mm.simpleName)}=";
        MethodMirror setter = declarations[new Symbol(setterName)];
        // setter may be null, but that's OK
        accessor = MethodPropertyAccessor.create(mm, setter);
        if (setter != null) {
          // create a shallow copy of the list first
          metadata = metadata.toList();
          metadata.addAll(setter.metadata);
        }
      }

      if (accessor == null) continue;

      String propertyName;
      Persistent p;
      for (InstanceMirror im in metadata) {
        if (im.reflectee is Persistent) {
          p = im.reflectee;
          if (p.primaryKey)
            key = new EntityPropertyBridge._("__key__", p, accessor);
          else
            propertyName = im.reflectee.name ?? fieldNameAsString;
          break;
        } else if (im.reflectee is EntityVersion && accessor.acceptsType(int)) {
          versionFields.add(new EntityPropertyBridge._(null, null, accessor));
        }
      }
      if (p != null && propertyName != null) {
        propertyMetadata[fieldNameAsString] =
            new EntityPropertyBridge._(propertyName, p, accessor);
      }
    }
  }

  @override
  String toString() => propertyMetadata.toString();

  String kind;
  final Map<String, EntityPropertyBridge> propertyMetadata = {};

  EntityModel descriptor;

  EntityPropertyBridge key;

  final List<EntityPropertyBridge> versionFields = [];
}
