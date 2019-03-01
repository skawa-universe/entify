// Simple example using the DatastoreShell API only (no EntityBridge)
// This needs a Datastore emulator to be running (assuming the Google Cloud SDK is installed):
// gcloud beta emulators datastore start --project=example --no-store-on-disk
import "dart:async";
import "package:http/http.dart" as http;
import "package:googleapis/datastore/v1.dart" as ds;
import "package:entify/entify.dart";

const String appId = "example";

Future<ds.DatastoreApi> getDatastoreApi() async {
  // This example connects to the Datastore Emulator and can use a simple http client
  http.Client client = new http.Client();
  return new ds.DatastoreApi(client, rootUrl: "http://localhost:8081/");
}

Future<DatastoreShell> getDatastoreShell() =>
    getDatastoreApi().then((api) => new DatastoreShell(api, appId));

Future<void> insertOrUpdateEntity(DatastoreShell ds) async {
  Key entityKey = new Key("Event", name: "last");
  int now = new DateTime.now().millisecondsSinceEpoch;
  Entity e = new Entity();
  e.key = entityKey;
  e.indexed["timestamp"] = now;
  try {
    // Fetch the entity: getSingle throws EntityNotFoundError when the entity does not exist
    Entity old = await ds.getSingle(entityKey);
    Duration diff = new Duration(milliseconds: now - old["timestamp"]);
    print("Time difference between this run and last run: $diff");
    // It exists so we update the entity
    await ds.beginMutation().update(e).commit();
    print("Entity successfully updated");
  } on EntityNotFoundError {
    // If it does not exist we insert
    await ds.beginMutation().insert(e).commit();
    print("Entity successfully inserted");
  }
}

Future<void> main() async {
  DatastoreShell ds = await getDatastoreShell();
  await insertOrUpdateEntity(ds);
}
