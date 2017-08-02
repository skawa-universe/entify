## 0.2.0

* Added support for transactions.
* Renamed `MutationBatch.execute` and `executeRaw` to `commit`.
  The `execute` methods are deprecated now and will be removed in a future release.

## 0.1.2+2

* Setters are optional for properties in entity model classes

## 0.1.2+1

* Handles `null` values in `fromValue` better
* Throws error if the entity model class does not have a key

## 0.1.2

* Renamed `fromProtocol` to `fromApiObject` in `Key` and `Entity` to follow
  common naming convention
* `fromValue` now handles empty values (treats them as `null`)
* `Entity` throws more meaningful errors in `fromApiObject`

## 0.1.1+3

* Added `createKey` method to `EntityBridge`
* Created `QueryResult` interface

## 0.1.1

* The `bool` parameter of `toValue` became a named parameter as it is recommended.
