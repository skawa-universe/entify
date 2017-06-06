import "dart:mirrors";

import "errors.dart";

/// Provides access to a model property.
/// 
/// This object is bound to the model class, the instance is passed at every
/// [setValue] call.
abstract class PropertyAccessor {
  /// The name of this field/getter-setter pair.
  /// 
  /// This name will be used as a default value, of the [Persistent]
  /// metadata object does not override the name.
  String get name;

  /// Whether the property type is compatible with the given [type].
  bool acceptsType(Type type);

  /// Sets the property [value] on the mirrorred [object].
  void setValue(InstanceMirror object, dynamic value);

  /// Returns the property value of the mirrored [object].
  dynamic getValue(InstanceMirror object);
}

/// Provides unified access to object fields.
class FieldPropertyAccessor implements PropertyAccessor {
  /// Constructs the accessor based on a [VariableMirror] instance.
  FieldPropertyAccessor(this._variable);

  @override
  String get name => MirrorSystem.getName(_variable.simpleName);

  @override
  bool acceptsType(Type type) =>
      reflectType(type).isAssignableTo(_variable.type);

  @override
  void setValue(InstanceMirror object, dynamic value) {
    object.setField(_variable.simpleName, value);
  }

  @override
  dynamic getValue(InstanceMirror object) =>
      object.getField(_variable.simpleName).reflectee;

  final VariableMirror _variable;
}

/// Provides unified access to getter-setter pairs on objects.
class MethodPropertyAccessor implements PropertyAccessor {
  /// Constructs the accessor based on a getter and a setter pair.
  /// 
  /// The parameters can be provided in any order the constructor detects
  /// which one is which.
  MethodPropertyAccessor(
      MethodMirror getterOrSetter, MethodMirror setterOrGetter)
      : _getter = getterOrSetter.isGetter ? getterOrSetter : setterOrGetter,
        _setter = getterOrSetter.isSetter ? getterOrSetter : setterOrGetter {
    if (!_setter.isSetter) throw new EntityModelError("No setter was given");
    if (!_getter.isGetter) throw new EntityModelError("No getter was given");
  }

  @override
  String get name => MirrorSystem.getName(_getter.simpleName);

  @override
  bool acceptsType(Type type) =>
      reflectType(type).isAssignableTo(_setter.parameters[0].type);

  @override
  void setValue(InstanceMirror object, dynamic value) {
    object.setField(_getter.simpleName, value);
  }

  @override
  dynamic getValue(InstanceMirror object) =>
      object.getField(_getter.simpleName).reflectee;

  final MethodMirror _setter;
  final MethodMirror _getter;
}
