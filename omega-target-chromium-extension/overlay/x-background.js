import zeroLocalStorage from "./localstorage-polyfill.js"
import ZeroLogFactory from './log.js'
import ZeroIndexedDBFactory from './indexedDB.js'

import "./lib/zero-dependencies/compare-versions/compare-versions.js"
import "./js/background_preload.js"
import "./lib/zero-dependencies/idb-keyval/idb-keyval.js"
import "./lib/zero-dependencies/moment/moment-with-locales.js"
import "./lib/zero-dependencies/csso/csso.js"
import "./js/log_error.js"
//import "./log.js"
//import "./lib/FileSaver/FileSaver.min.js"
import "./js/omega_debug.js"
import "./js/omega_pac.min.js"
import "./js/omega_target.min.js"
import "./js/omega_target_chromium_extension.min.js"
import "./img/icons/draw_omega.js"
import "./js/background.js" // zeroBackground

/**
 * author: suziwen1@gmail.com
 **/

const isFirefox = !!globalThis.localStorage

globalThis.POPUPHTMLURL = './popup-iframe.html'
//if android, (eg. edge canary for android), use default popup/index.html
//https://github.com/zero-peak/ZeroOmega/issues/93
if (globalThis.navigator && /Android/i.test(globalThis.navigator.userAgent)){
  globalThis.POPUPHTMLURL = './popup/index.html'
}

// keepAlive
setInterval(chrome.runtime.getPlatformInfo, 25 * 1000) //https://developer.chrome.com/docs/extensions/develop/migrate/to-service-workers

function detectPrivateMode(cb) {
  var db, tempMode,on, off;
  on = cb.bind(null, true);
  off = cb.bind(null, false);
  if (isFirefox) {
    // in private mode, localStorage will be erased when browser restart
    tempMode = localStorage.getItem('zeroOmega.isPrivateMode')
    if (tempMode) {
      tempMode == 'true' ? on() : off()
    } else {
      db = indexedDB.open("zeroOmega-test"), db.onerror = on, db.onsuccess = off
    }
  } else {
    off()
  }
}

detectPrivateMode(function (isPrivateMode) {
  if (isFirefox) {
    localStorage.setItem('zeroOmega.isPrivateMode', isPrivateMode ? 'true' : 'false')
  }

  if (isPrivateMode && isFirefox) {
    // fake indexedDB
    ZeroIndexedDBFactory()
  }
  ZeroLogFactory()
  const zeroStorage = isFirefox ? localStorage : zeroLocalStorage
  globalThis.zeroBackground(zeroStorage)
  console.log('is private mode: ' + isPrivateMode)
})
