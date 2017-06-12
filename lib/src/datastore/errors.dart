import "key.dart";

/// Thrown when there's an underlying issue with the Datastore.
class DatastoreShellError extends Error {
  DatastoreShellError(this.message);

  @override
  String toString() => "DatastoreShellError($message)";

  final String message;
}

/// Thrown when a single entity query failed.
class EntityNotFoundError extends DatastoreShellError {
  EntityNotFoundError(Key key): super("Entity not found: $key");

  @override
  String toString() => "DatastoreShellError($message)";
}
