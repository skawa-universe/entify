
/// Thrown when there was an error during entity
/// model metadata extraction or during entity
/// property mapping.
class EntityModelError extends Error {
  EntityModelError(this.message);

  final String message;
}
