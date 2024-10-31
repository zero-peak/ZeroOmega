import zeroLocalStorage from "./localstorage-polyfill.js"
import ZeroLogFactory from './log.js'
import ZeroIndexedDBFactory from './indexedDB.js'

import "./lib/compare-versions.js"
import "./js/background_preload.js"
import "./lib/idb-keyval.js"
import "./lib/moment-with-locales.js"
import "./lib/csso.js"
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
const zcb = globalThis.zeroDetectModeCB

function detectPrivateMode(cb) {
  var db, tempMode,on, off;
  if (zcb) {
    on = zcb(cb, true);
    off = zcb(cb, false);
  } else {
    on = ()=> {setTimeout(cb.bind(null, true), 1)};
    off = ()=> {setTimeout(cb.bind(null, false), 1)};
  }
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

/**
 * Listener for managing alarms and responding to messages from content scripts or popup scripts.
 * 
 * This function listens for two types of actions:
 * 1. **startAlarm**: Starts a periodic alarm based on a provided sync timer duration. The alarm will trigger a 
 *    background process, such as fetching data from a specified URL.
 * 2. **stopAlarm**: Stops the existing alarm and clears associated data like the stored URL and last sync timestamp.
 * 
 * Key details:
 * - The alarm triggers based on a given `syncTimerDuration` and runs every set interval.
 * - The `restoreOnlineUrl` is stored in `localStorage` to persist it and use it when the alarm triggers.
 * - When stopping the alarm, all associated data in `localStorage` (e.g., `restoreOnlineUrl`, `lastSyncUpdate`) is cleared.
 * 
 * @param {Object} message - The message object containing the action type and any relevant data (e.g., URL and sync duration).
 * @param {Object} sender - The sender of the message (e.g., content script, popup).
 * @param {Function} sendResponse - Function to send a response back to the sender, indicating success or failure.
 * 
 * Example message to start the alarm:
 * {
 *   action: 'startAlarm',
 *   restoreOnlineUrl: 'https://example.com/sync',
 *   syncTimerDuration: 1
 * }
 * 
 * Example message to stop the alarm:
 * {
 *   action: 'stopAlarm'
 * }
 */
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.action === 'startAlarm') {
    const restoreOnlineUrl = message.restoreOnlineUrl;
    const syncTimerDuration = message.syncTimerDuration;
    
    chrome.alarms.clear('restoreOnlineAlarm', () => {
      chrome.alarms.create('restoreOnlineAlarm', {
        periodInMinutes: syncTimerDuration
      });
      localStorage.setItem('restoreOnlineUrl', restoreOnlineUrl);
      sendResponse({ success: true });
    });
    
    return true;
  }

  if (message.action === 'stopAlarm') {
    chrome.alarms.clear('restoreOnlineAlarm', (wasCleared) => {
      if (wasCleared) {
        localStorage.removeItem('restoreOnlineUrl');
        localStorage.removeItem('lastSyncUpdate');
        sendResponse({ success: true, message: 'Alarm stopped successfully' });
      } else {
        sendResponse({ success: false, message: 'No alarm to stop or failed to stop' });
      }
    });
    return true;
  }
});

// Listener for the alarm trigger
chrome.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === 'restoreOnlineAlarm') {
    const restoreOnlineUrl = localStorage.getItem('restoreOnlineUrl');
    if (restoreOnlineUrl) {
      fetch(restoreOnlineUrl, { method: 'GET', cache: 'no-cache' })
        .then(response => response.text())
        .then(data => {
          let resultData = data;
          try {
            resultData = JSON.parse(data);
          } catch (e) {
            // Handle non-JSON response
          }
          const fileContent = resultData?.files?.[0]?.content || resultData;

        resetOnlyProxies(fileContent)
        })
        .catch(err => {
          console.error('Download error', err);
        });
    }
  }
});

/**
 * Sends a message to reset only the proxy settings based on the provided data.
 * The message is sent to the background script or another part of the Chrome
 * extension using `chrome.runtime.sendMessage`.
 * 
 * @param {Object} data - The data to be used for resetting proxy settings.
 * @returns {Promise} - A promise that resolves when the message is sent successfully, 
 *                      or rejects if an error occurs.
 */
function resetOnlyProxies(data) {
  return new Promise((resolve, reject) => {
    try {
      chrome.runtime.sendMessage({
        action: 'resetOnlyProxies',
        data: data
      }, function(response) {
        console.log('Resetting options with data:', data);
      });

      resolve();
    } catch (error) {
      reject(error);
    }
  });
}
