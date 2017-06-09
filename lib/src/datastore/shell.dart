import "dart:async";
import "package:googleapis/datastore/v1.dart" as ds;

import "query.dart";
import "entity.dart";
import "key.dart";
import "errors.dart";
import "api_mapping.dart";
import "mutations.dart";

/// Provides a useful interface over the `package:googleapis` `DatastoreApi` object.
class DatastoreShell {
  /// Constructs the shell using the given [api] object and [project] identifier.
  DatastoreShell(this.api, this.project);

  /// Prepares a query. Currently it's not much more than a simple wrapper, later
  /// it may emulate running multiple queries at once and merging their responses.
  PreparedQuery prepareQuery(Query query) => new PreparedQuery._(this, query);

  /// Retrieves a single entity by key. Throws (asynchronously)
  /// [EntityNotFoundError] if the entity does not exist.
  Future<Entity> getSingle(Key key) {
    return getRaw([key]).then((ds.LookupResponse resp) {
      if ((resp.deferred?.length ?? 0) > 0)
        throw new DatastoreShellError("Entity lookup deferred");
      if ((resp.missing?.length ?? 0) > 0) throw new EntityNotFoundError(key);
      return new Entity.fromProtocol(resp.found[0].entity);
    });
  }

  /// Retrieves multiple entities by their keys. The resulting map contains
  /// all existing entities, but no entries for the non-existing ones.
  Future<Map<Key, Entity>> getAll(Iterable<Key> keys) {
    return getRaw(keys).then((ds.LookupResponse resp) {
      if ((resp.deferred?.length ?? 0) > 0)
        throw new DatastoreShellError(
            "Entity lookup deferred: ${resp.deferred}");
      return new Map.fromIterable(
          resp.found.map((item) => new Entity.fromProtocol(item.entity)),
          key: (e) => e.key);
    });
  }

  /// Starts a lookup for a list of keys and returns with the raw API response.
  Future<ds.LookupResponse> getRaw(Iterable<Key> keys) {
    ds.LookupRequest lr = new ds.LookupRequest();
    lr.keys = keys.map(ApiRepresentation.mapToApi).toList(growable: false);
    lr.readOptions = new ds.ReadOptions();
    lr.readOptions.readConsistency = "EVENTUAL";
    return api.projects.lookup(lr, project);
  }

  /// Starts a mutation batch.
  MutationBatch beginMutation() => new MutationBatch(this);

  /// The underlying API object.
  final ds.DatastoreApi api;

  /// The project identifier.
  final String project;
}

abstract class QueryResult<T> {
  factory QueryResult(Iterable<T> entities, String endCursor) =>
    new GenericQueryResult(entities, endCursor);

  Iterable<T> get entities;
  String get endCursor;
}

class GenericQueryResult<T> implements QueryResult<T> {
  GenericQueryResult(this.entities, this.endCursor);

  final Iterable<T> entities;
  final String endCursor;
}

/// A bunch of entities returned from a query.
class QueryResultBatch implements QueryResult<Entity> {
  QueryResultBatch(this.shell, ds.RunQueryResponse protocolResponse)
      : endCursor = protocolResponse.batch.endCursor,
        entities = protocolResponse.batch.entityResults
                ?.map((er) => new Entity.fromProtocol(er.entity))
                ?.toList(growable: false) ??
            [],
        isKeysOnly = protocolResponse.batch.entityResultType == "KEY_ONLY",
        isProjection = protocolResponse.batch.entityResultType == "PROJECTION",
        isFull = protocolResponse.batch.entityResultType == "FULL";

  /// The cursor that points after the last entity returned.
  final String endCursor;

  /// The list of entities.
  final List<Entity> entities;

  final bool isKeysOnly;
  final bool isProjection;
  final bool isFull;

  final DatastoreShell shell;
}

/// Contains methods for fetching and returning entities from a [Query].
class PreparedQuery {
  PreparedQuery._fromProtocol(this.shell, this.query);

  PreparedQuery._(this.shell, Query query) : this.query = query.toApiObject();

  /// Runs the query and returns the resulting batch.
  Future<QueryResultBatch> runQuery() => runRawQuery().then(
      (ds.RunQueryResponse response) => new QueryResultBatch(shell, response));

  /// Runs the query and returns the raw API response.
  Future<ds.RunQueryResponse> runRawQuery() {
    ds.RunQueryRequest qr = new ds.RunQueryRequest();
    qr.query = query;
    qr.readOptions = new ds.ReadOptions();
    qr.readOptions..readConsistency = "EVENTUAL";
    return shell.api.projects.runQuery(qr, shell.project);
  }

  final DatastoreShell shell;
  final ds.Query query;
}
