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