class EntifyException implements Exception {

}

/// Thrown when there was an error during entity
/// model metadata extraction or during entity
/// property mapping.
class EntityModelException extends EntifyException {
  EntityModelException(this.message);

  @override
  String toString() => "EntityModelError: $message";

  final String message;
}

class PropertyNotFoundException extends EntifyException {
  PropertyNotFoundException(this.propertyName);

  @override
  String toString() => "PropertyNotFoundException: $propertyName";

  final String propertyName;
}
