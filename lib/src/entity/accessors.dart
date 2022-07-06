import "dart:mirrors";
import "dart:typed_data";

import "errors.dart";
import "model.dart";

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

  /// The property supports reading
  bool get hasGetter;

  /// The property supports writing
  bool get hasSetter;

  TypeMirror get _typeMirror;
}

final TypeMirror valueHolderMirror = reflectType(ValueHolder);

TypeMirror _valueHolderType(TypeMirror type) {
  if (type is ClassMirror) {
    if (type.qualifiedName == valueHolderMirror.qualifiedName) {
      return type.typeArguments.first;
    } else {
      TypeMirror fromSupertype = _valueHolderType(type.superclass);
      if (fromSupertype != null) return fromSupertype;
      for (ClassMirror superinterface in type.superinterfaces) {
        TypeMirror fromSuperinterface = _valueHolderType(superinterface);
        if (fromSuperinterface != null) return fromSuperinterface;
      }
      return null;
    }
  } else {
    return null;
  }
}

class _ValueHolderAdapter implements PropertyAccessor {
  static PropertyAccessor adapt(PropertyAccessor nested) {
    TypeMirror nestedType = nested._typeMirror;
    if (nestedType is ClassMirror && nestedType.isSubtypeOf(valueHolderMirror)) {
      return _ValueHolderAdapter(nested);
    } else {
      return nested;
    }
  }

  _ValueHolderAdapter(this.nested) : _typeMirror = _valueHolderType(nested._typeMirror);

  @override
  String get name => nested.name;

  @override
  final TypeMirror _typeMirror;

  @override
  bool acceptsType(Type type) => reflectType(type).isAssignableTo(_typeMirror);

  @override
  dynamic getValue(InstanceMirror object) => (nested.getValue(object) as ValueHolder)?.value;

  @override
  void setValue(InstanceMirror object, Object value) {
    ValueHolder nestedHolder = nested.getValue(object);
    if (nestedHolder != null) nestedHolder.value = value;
  }

  @override
  final bool hasGetter = true;

  @override
  final bool hasSetter = true;

  final PropertyAccessor nested;
}

/// Provides unified access to object fields.
class FieldPropertyAccessor implements PropertyAccessor {
  static PropertyAccessor create(VariableMirror variable) =>
      _ValueHolderAdapter.adapt(FieldPropertyAccessor(variable));

  /// Constructs the accessor based on a [VariableMirror] instance.
  FieldPropertyAccessor(this._variable)
      : _setValueAdapter = _createValueAdapter(_variable.type);

  @override
  String get name => MirrorSystem.getName(_variable.simpleName);

  @override
  bool acceptsType(Type type) =>
      reflectType(type).isAssignableTo(_typeMirror);

  @override
  void setValue(InstanceMirror object, dynamic value) {
    if (_setValueAdapter != null) value = _setValueAdapter(value);
    object.setField(_variable.simpleName, value);
  }

  @override
  dynamic getValue(InstanceMirror object) =>
      object.getField(_variable.simpleName).reflectee;

  @override
  final bool hasGetter = true;

  @override
  final bool hasSetter = true;

  @override
  TypeMirror get _typeMirror => _variable.type;

  final VariableMirror _variable;
  final _ValueAdapter _setValueAdapter;
}

/// Provides unified access to getter-setter pairs on objects.
class MethodPropertyAccessor implements PropertyAccessor {
  static PropertyAccessor create(MethodMirror getterOrSetter,
      [MethodMirror setterOrGetter]) =>
      _ValueHolderAdapter.adapt(MethodPropertyAccessor(getterOrSetter, setterOrGetter));

  /// Constructs the accessor based on a getter and a setter pair.
  ///
  /// The parameters can be provided in any order the constructor detects
  /// which one is which.
  MethodPropertyAccessor(MethodMirror getterOrSetter,
      [MethodMirror setterOrGetter])
      : _getter = _getterOf(getterOrSetter, setterOrGetter),
        _setter = _setterOf(getterOrSetter, setterOrGetter),
        _setValueAdapter = _createValueAdapter(
            (_setterOf(getterOrSetter, setterOrGetter))
                ?.parameters
                ?.first
                ?.type) {
    if (!_getter.isGetter) throw new EntityModelException("No getter was given");
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
  dynamic getValue(InstanceMirror object) =>
      object.getField(_getter.simpleName).reflectee;

  @override
  bool get hasGetter => _getter != null;

  @override
  bool get hasSetter => _setter != null;

  @override
  TypeMirror get _typeMirror =>
      _setter != null ? _setter.parameters[0].type : _getter.returnType;

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
  if (expectedType is ClassMirror &&
      (expectedType.isSubclassOf(_iterableTypeMirror) ||
          expectedType.isSubclassOf(_listTypeMirror)) &&
      !expectedType.isSubclassOf(_typedDataTypeMirror)) {
    Type elementType = _iterableType(expectedType);
    if (elementType != null) {
      ClassMirror listType = reflectType(List, [elementType]);
      return (dynamic value) {
        if (value is Iterable && value is! TypedData) {
          return listType.newInstance(_from, [value]).reflectee;
        } else {
          return value;
        }
      };
    }
  }
  return null;
}

Type _iterableType(TypeMirror type) {
  if (type is ClassMirror) {
    if (type.isSubclassOf(_iterableTypeMirror) &&
        type.typeArguments.length == 1) {
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

MethodMirror _setterOf(
        MethodMirror getterOrSetter, MethodMirror setterOrGetter) =>
    getterOrSetter.isSetter ? getterOrSetter : setterOrGetter;

MethodMirror _getterOf(
        MethodMirror getterOrSetter, MethodMirror setterOrGetter) =>
    getterOrSetter.isGetter ? getterOrSetter : setterOrGetter;
