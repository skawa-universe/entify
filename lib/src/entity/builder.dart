import "dart:mirrors";

import "accessors.dart";
import "errors.dart";
import "metadata.dart";

/// Defines a mapping between an object property and an entity property.
class EntityPropertyBridge {
  EntityPropertyBridge._(String name, this.metadata, PropertyAccessor accessor)
      : this.accessor = accessor,
        this.name = name ?? accessor.name;

  String toString() => metadata.indexed
    ? "${name} <=> ${accessor.name}"
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
    EntityModel desc = null;
    for (InstanceMirror im in leaf.metadata) {
      if (im.reflectee is EntityModel) {
        desc = im.reflectee;
        break;
      }
    }
    if (desc == null)
      throw new EntityModelError(
          "Type is not entity model: ${leaf.reflectedType}");
    kind = desc.kind ?? MirrorSystem.getName(leaf.simpleName);
    for (ClassMirror current = leaf;
        current != null;
        current = current.superclass) {
      _process(current);
    }
  }

  void _process(ClassMirror s) {
    final Map<Symbol, DeclarationMirror> decls = s.declarations;
    for (Symbol fieldName in decls.keys) {
      String fieldNameAsString = MirrorSystem.getName(fieldName);
      DeclarationMirror decl = decls[fieldName];
      PropertyAccessor accessor = null;
      if (decl is VariableMirror) {
        VariableMirror vm = decl;
        if (vm.isStatic) continue;
        accessor = new FieldPropertyAccessor(vm);
      }
      if (decl is MethodMirror) {
        MethodMirror mm = decl;
        if (mm.isStatic || !mm.isGetter) continue;
        String setterName = "${MirrorSystem.getName(mm.simpleName)}=";
        MethodMirror setter = decls[new Symbol(setterName)];
        if (setter == null) continue;
        accessor = new MethodPropertyAccessor(mm, setter);
      }

      if (accessor == null) continue;

      String propertyName = null;
      Persistent p = null;
      for (InstanceMirror im in decl.metadata) {
        if (im.reflectee is Persistent) {
          p = im.reflectee;
          if (p.primaryKey)
            key = new EntityPropertyBridge._("__key__", p, accessor);
          else
            propertyName = im.reflectee.name ?? fieldNameAsString;
          break;
        }
      }
      if (p != null && propertyName != null) {
        propertyMetadata[fieldNameAsString] =
            new EntityPropertyBridge._(propertyName, p, accessor);
      }
    }
  }

  String toString() => propertyMetadata.toString();

  String kind = null;
  final Map<String, EntityPropertyBridge> propertyMetadata = {};
  EntityPropertyBridge key = null;
}
