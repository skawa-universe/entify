import "dart:async";
import "package:googleapis/datastore/v1.dart" as ds;

import "query.dart";
import "entity.dart";
import "key.dart";
import "errors.dart";
import "api_mapping.dart";
import "mutations.dart";
import "options.dart";

/// Provides a useful interface over the `package:googleapis` `DatastoreApi` object.
class DatastoreShell {
  /// Constructs the shell using the given [api] object and [project] identifier.
  factory DatastoreShell(ds.DatastoreApi api, String project) =>
      new DatastoreShell._(api, project, transactionId: null, rootShell: null);

  DatastoreShell._(this.api, this.project, {String transactionId, DatastoreShell rootShell})
      : this._rootShell = rootShell,
        this.transactionId = transactionId,
        _activeTransaction = transactionId != null;

  /// Returns a [DatastoreShell] instance that runs every operation in the
  /// newly created transaction.
  ///
  /// The transaction can be committed by running a (possibly empty) mutation
  Future<DatastoreShell> beginTransaction() {
    ds.BeginTransactionRequest request = new ds.BeginTransactionRequest();
    return api.projects.beginTransaction(request, project).then((ds.BeginTransactionResponse response) {
      if (response.transaction == null) throw new DatastoreShellError("Expected a transaction");
      return new DatastoreShell._(api, project, transactionId: response.transaction, rootShell: nonTransactionalShell);
    });
  }

  Future<Null> rollback() {
    if (!isTransactional) throw new DatastoreShellError("No active transaction");
    ds.RollbackRequest request = new ds.RollbackRequest();
    request.transaction = transactionId;
    _activeTransaction = false;
    return api.projects.rollback(request, project).then((ds.RollbackResponse response) => null);
  }

  /// Prepares a query. Currently it's not much more than a simple wrapper, later
  /// it may emulate running multiple queries at once and merging their responses.
  ///
  /// Only ancestor queries can be run in a transaction.
  PreparedQuery prepareQuery(Query query) => new PreparedQuery._(this, query);

  /// Retrieves a single entity by key. Throws (asynchronously)
  /// [EntityNotFoundError] if the entity does not exist.
  Future<Entity> getSingle(Key key, {ReadConsistency readConsistency}) {
    return getRaw([key], readConsistency: readConsistency).then((ds.LookupResponse resp) {
      if ((resp.deferred?.length ?? 0) > 0) throw new DatastoreShellError("Entity lookup deferred");
      if ((resp.missing?.length ?? 0) > 0) throw new EntityNotFoundError(key);
      return new Entity.fromEntityResult(resp.found[0]);
    });
  }

  /// Retrieves multiple entities by their keys. The resulting map contains
  /// all existing entities, but no entries for the non-existing ones.
  Future<Map<Key, Entity>> getAll(Iterable<Key> keys, {ReadConsistency readConsistency}) {
    return getRaw(keys, readConsistency: readConsistency).then((ds.LookupResponse resp) {
      if ((resp.deferred?.length ?? 0) > 0) throw new DatastoreShellError("Entity lookup deferred: ${resp.deferred}");
      return new Map.fromIterable((resp.found ?? const []).map((item) => new Entity.fromEntityResult(item)),
          key: (e) => e.key);
    });
  }

  /// Starts a lookup for a list of keys and returns with the raw API response.
  Future<ds.LookupResponse> getRaw(Iterable<Key> keys, {ReadConsistency readConsistency}) {
    ds.LookupRequest lr = new ds.LookupRequest();
    lr.keys = keys.map(ApiRepresentation.mapToApi).toList(growable: false);
    lr.readOptions = new ds.ReadOptions();
    lr.readOptions.readConsistency = readConsistency?.name;
    if (transactionId != null) lr.readOptions.transaction = transactionId;
    return api.projects.lookup(lr, project);
  }

  Future<T> runTransaction<T>(Future<T> transactionBody(DatastoreShell transactionShell),
      {int retryCount: 16,
      Duration firstRetryDuration: const Duration(milliseconds: 10),
      bool delayOnConflict: false,
      bool backDownOnConflict: false,
      Duration stepDownRetryDuration(Duration previousDuration): defaultExponentialStepDown,
      void errorCallback(WrappedServerError error)}) async {
    WrappedServerError lastError;
    Duration nextRetryDuration = firstRetryDuration;
    while (retryCount > 0) {
      --retryCount;
      DatastoreShell transactional = await beginTransaction();
      try {
        return await transactionBody(transactional);
      } on DatastoreConflictError catch (e) {
        lastError = e;
        if (errorCallback != null) errorCallback(e);
        if (delayOnConflict) {
          await new Future.delayed(nextRetryDuration, () => null);
          if (backDownOnConflict) nextRetryDuration = stepDownRetryDuration(nextRetryDuration);
        }
      } on DatastoreTransientError catch (e) {
        lastError = e;
        if (errorCallback != null) errorCallback(e);
        await new Future.delayed(nextRetryDuration, () => null);
        nextRetryDuration = stepDownRetryDuration(nextRetryDuration);
      } finally {
        if (transactional._activeTransaction) await transactional.rollback();
      }
    }
    throw lastError;
  }

  static Duration defaultExponentialStepDown(Duration previousDuration) {
    if (previousDuration.compareTo(const Duration(seconds: 10)) >= 0) return previousDuration;
    return previousDuration * 2;
  }

  /// Starts a mutation batch.
  MutationBatch beginMutation() => new MutationBatch(this, onCommit: (_) => _activeTransaction = false);

  /// The underlying API object.
  final ds.DatastoreApi api;

  /// The project identifier.
  final String project;

  /// The transaction id this instance uses for all operations.
  final String transactionId;

  bool get isTransactional => transactionId != null;

  final DatastoreShell _rootShell;

  bool _activeTransaction;

  /// The non-transactional shell instance.
  DatastoreShell get nonTransactionalShell => _rootShell ?? (transactionId == null ? this : null);
}

abstract class QueryResult<T> {
  factory QueryResult(Iterable<T> entities, String endCursor) => new GenericQueryResult(entities, endCursor);

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
                ?.map((er) => new Entity.fromEntityResult(er))
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
  Future<QueryResultBatch> runQuery() =>
      runRawQuery().then((ds.RunQueryResponse response) => new QueryResultBatch(shell, response));

  /// Runs the query and returns the raw API response.
  Future<ds.RunQueryResponse> runRawQuery() {
    ds.RunQueryRequest qr = new ds.RunQueryRequest();
    qr.query = query;
    qr.readOptions = new ds.ReadOptions();
    qr.readOptions.readConsistency = null;
    if (shell.isTransactional) {
      qr.readOptions
        ..transaction = shell.transactionId;
    }
    return shell.api.projects.runQuery(qr, shell.project);
  }

  final DatastoreShell shell;
  final ds.Query query;
}
