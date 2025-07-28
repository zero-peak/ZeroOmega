import fakeIndexedDB from "./lib/zero-dependencies/fake-indexeddb/fakeIndexedDB.js";
import FDBCursor from "./lib/zero-dependencies/fake-indexeddb/FDBCursor.js";
import FDBCursorWithValue from "./lib/zero-dependencies/fake-indexeddb/FDBCursorWithValue.js";
import FDBDatabase from "./lib/zero-dependencies/fake-indexeddb/FDBDatabase.js";
import FDBFactory from "./lib/zero-dependencies/fake-indexeddb/FDBFactory.js";
import FDBIndex from "./lib/zero-dependencies/fake-indexeddb/FDBIndex.js";
import FDBKeyRange from "./lib/zero-dependencies/fake-indexeddb/FDBKeyRange.js";
import FDBObjectStore from "./lib/zero-dependencies/fake-indexeddb/FDBObjectStore.js";
import FDBOpenDBRequest from "./lib/zero-dependencies/fake-indexeddb/FDBOpenDBRequest.js";
import FDBRequest from "./lib/zero-dependencies/fake-indexeddb/FDBRequest.js";
import FDBTransaction from "./lib/zero-dependencies/fake-indexeddb/FDBTransaction.js";
import FDBVersionChangeEvent from "./lib/zero-dependencies/fake-indexeddb/FDBVersionChangeEvent.js";


/**
 * author: suziwen1@gmail.com
 **/
const ZeroIndexedDBFactory = ()=> {
  var globalVar =
      typeof window !== "undefined"
          ? window
          : typeof WorkerGlobalScope !== "undefined"
          ? self
          : typeof global !== "undefined"
          ? global
          : Function("return this;")();

  Object.defineProperty(globalVar, 'indexedDB', {
      value: fakeIndexedDB
  });
  Object.defineProperty(globalVar, 'IDBCursor', {
      value: FDBCursor
  });
  Object.defineProperty(globalVar, 'IDBCursorWithValue', {
      value: FDBCursorWithValue
  });
  Object.defineProperty(globalVar, 'IDBDatabase', {
      value: FDBDatabase
  });
  Object.defineProperty(globalVar, 'IDBFactory', {
      value: FDBFactory
  });
  Object.defineProperty(globalVar, 'IDBIndex', {
      value: FDBIndex
  });
  Object.defineProperty(globalVar, 'IDBKeyRange', {
      value: FDBKeyRange
  });
  Object.defineProperty(globalVar, 'IDBObjectStore', {
      value: FDBObjectStore
  });
  Object.defineProperty(globalVar, 'IDBOpenDBRequest', {
      value: FDBOpenDBRequest
  });
  Object.defineProperty(globalVar, 'IDBRequest', {
      value: FDBRequest
  });
  Object.defineProperty(globalVar, 'IDBTransaction', {
      value: FDBTransaction
  });
  Object.defineProperty(globalVar, 'IDBVersionChangeEvent', {
      value: FDBVersionChangeEvent
  });
       
}

export default ZeroIndexedDBFactory
