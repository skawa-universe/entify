import "dart:mirrors";
import "dart:typed_data";

import "errors.dart";

/// Provides access to a model property.
///
/// This object is bound to the model class, the instance is passed at every
/// [setValue] call.
abstract class PropertyAccessor {
  /// The name of this field/getter-setter pair.
  ///
  /// This name will be used as a default value, of the `Persistent`
  /// metadata object does not override the name.
  String get name;

  /// Whether the property type is compatible with the given [type].
  bool acceptsType(Type type);

  /// Sets the property [value] on the mirrored [object].
  void setValue(InstanceMirror object, dynamic value);

  /// Returns the property value of the mirrored [object].
  dynamic getValue(InstanceMirror object);
}

/// Provides unified access to object fields.
class FieldPropertyAccessor implements PropertyAccessor {
  /// Constructs the accessor based on a [VariableMirror] instance.
  FieldPropertyAccessor(this._variable) : _setValueAdapter = _createValueAdapter(_variable.type);

  @override
  String get name => MirrorSystem.getName(_variable.simpleName);

  @override
  bool acceptsType(Type type) => reflectType(type).isAssignableTo(_variable.type);

  @override
  void setValue(InstanceMirror object, dynamic value) {
    if (_setValueAdapter != null) value = _setValueAdapter(value);
    object.setField(_variable.simpleName, value);
  }

  @override
  dynamic getValue(InstanceMirror object) => object.getField(_variable.simpleName).reflectee;

  final VariableMirror _variable;
  final _ValueAdapter _setValueAdapter;
}

/// Provides unified access to getter-setter pairs on objects.
class MethodPropertyAccessor implements PropertyAccessor {
  /// Constructs the accessor based on a getter and a setter pair.
  ///
  /// The parameters can be provided in any order the constructor detects
  /// which one is which.
  MethodPropertyAccessor(MethodMirror getterOrSetter, [MethodMirror setterOrGetter])
      : _getter = _getterOf(getterOrSetter, setterOrGetter),
        _setter = _setterOf(getterOrSetter, setterOrGetter),
        _setValueAdapter = _createValueAdapter((_setterOf(getterOrSetter, setterOrGetter))?.parameters?.first?.type) {
    if (!_getter.isGetter) throw new EntityModelError("No getter was given");
  }

  @override
  String get name => MirrorSystem.getName(_getter.simpleName);

  @override
  bool acceptsType(Type type) => reflectType(type).isAssignableTo(_typeMirror);

  @override
  void setValue(InstanceMirror object, dynamic value) {
    if (_setter != null) {
      if (_setValueAdapter != null) value = _setValueAdapter(value);
      object.setField(_getter.simpleName, value);
    }
  }

  @override
  dynamic getValue(InstanceMirror object) => object.getField(_getter.simpleName).reflectee;

  TypeMirror get _typeMirror => _setter != null ? _setter.parameters[0].type : _getter.returnType;

  final MethodMirror _setter;
  final MethodMirror _getter;
  final _ValueAdapter _setValueAdapter;
}

typedef dynamic _ValueAdapter(dynamic val);

final TypeMirror _iterableTypeMirror = reflectClass(Iterable);
final TypeMirror _listTypeMirror = reflectClass(List);
final TypeMirror _typedDataTypeMirror = reflectClass(TypedData);
final Symbol _from = new Symbol("from");

_ValueAdapter _createValueAdapter(TypeMirror expectedType) {
  if (expectedType == null) return null;
  bool verbose = expectedType.reflectedType.runtimeType.toString() == "List<int>";
  if (verbose) print("1..");
  if (expectedType is ClassMirror &&
      expectedType.isSubclassOf(_listTypeMirror) &&
      !expectedType.isSubclassOf(_typedDataTypeMirror)) {
    if (verbose) print("2..");
    Type elementType = _iterableType(expectedType);
    if (verbose) print("3.. $elementType");
    if (elementType != null) {
      ClassMirror listType = reflectType(List, [elementType]);
      if (verbose) print("4.. $listType");
      return (dynamic value) {
        if (value is Iterable && value is! TypedData) {
          if (verbose) print("5.. $listType");
          return listType.newInstance(_from, [value]).reflectee;
        } else {
          if (verbose) print("6.. ${value.runtimeType}");
          return value;
        }
      };
    }
  }
  if (verbose) print("7..");
  return null;
}

Type _iterableType(TypeMirror type) {
  if (type is ClassMirror) {
    if (type.isSubclassOf(_iterableTypeMirror) && type.typeArguments.length == 1) {
      return type.typeArguments.first.reflectedType;
    }
    Type result = _iterableType(type.superclass);
    if (result != null) return result;
    for (TypeMirror interfaceMirror in type.superinterfaces) {
      result = _iterableType(interfaceMirror);
      if (result != null) return result;
    }
  }
  return null;
}

MethodMirror _setterOf(MethodMirror getterOrSetter, MethodMirror setterOrGetter) =>
    getterOrSetter.isSetter ? getterOrSetter : setterOrGetter;

MethodMirror _getterOf(MethodMirror getterOrSetter, MethodMirror setterOrGetter) =>
    getterOrSetter.isGetter ? getterOrSetter : setterOrGetter;
