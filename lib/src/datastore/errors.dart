import "package:googleapis/datastore/v1.dart" as ds;

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
  EntityNotFoundError(Key key) : super("Entity not found: $key");

  @override
  String toString() => "DatastoreShellError($message)";
}

class WrappedServerError extends DatastoreShellError {
  WrappedServerError(String message, this.originalError) : super(message);

  @override
  String toString() => "${super.toString()}/${originalError.toString()}";

  final ds.DetailedApiRequestError originalError;
}

class DatastoreConflictError extends WrappedServerError {
  DatastoreConflictError(
      String message, ds.DetailedApiRequestError originalError)
      : super(message, originalError);
}

class DatastoreTransientError extends WrappedServerError {
  DatastoreTransientError(
      String message, ds.DetailedApiRequestError originalError)
      : super(message, originalError);
}

class UnknownDatastoreError extends WrappedServerError {
  UnknownDatastoreError(
      String message, ds.DetailedApiRequestError originalError)
      : super(message, originalError);
}
