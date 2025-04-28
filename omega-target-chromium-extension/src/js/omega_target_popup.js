function callBackgroundNoReply(method, args, cb) {
  chrome.runtime.sendMessage({
    method: method,
    args: args,
    noReply: true,
    refreshActivePage: true,
  });
  if (cb) return cb();
}

function callBackground(method, args, cb) {
  chrome.runtime.sendMessage({
    method: method,
    args: args,
  }, function(response) {
    if (chrome.runtime.lastError != null)
      return cb && cb(chrome.runtime.lastError)
    if (response.error) return cb && cb(response.error)
    return cb && cb(null, response.result)
  });
}

var requestInfoCallback = null;

OmegaTargetPopup = {
  getState: function (keys, cb) {
    callBackground('getState', [keys], cb);
    return;
  },
  setState: function (name, value, cb){
    var newItem = {};
    newItem[name] = value
    callBackground('setState', [newItem], cb);
    return;
  },
  applyProfile: function (name, cb) {
    callBackgroundNoReply('applyProfile', [name], cb);
  },
  openOptions: function (hash, cb) {
    var options_url = chrome.runtime.getURL('options.html');
    console.log('open options.....')

    chrome.tabs.query({
      url: options_url
    }, function(tabs) {
      if (!chrome.runtime.lastError && tabs && tabs.length > 0) {
        var props = {
          active: true
        };
        if (hash) {
          var url = options_url + hash;
          props.url = url;
        }
        chrome.tabs.update(tabs[0].id, props);
      } else {
        chrome.tabs.create({
          url: options_url
        });
      }
      if (cb) return cb();
    });
  },
  getActivePageInfo: function(cb) {
    chrome.tabs.query({active: true, lastFocusedWindow: true}, function (tabs) {
      if (tabs.length === 0 || !(tabs[0].pendingUrl || tabs[0].url)) return cb();
      var args = {tabId: tabs[0].id, url: tabs[0].pendingUrl || tabs[0].url};
      callBackground('getPageInfo', [args], cb)
    });
  },
  setDefaultProfile: function(profileName, defaultProfileName, cb) {
    callBackgroundNoReply('setDefaultProfile',
      [profileName, defaultProfileName], cb);
  },
  addCondition: function(condition, profileName, cb){
    callBackground('addCondition', [condition, profileName], cb)
  },
  getTempRules: function(cb){
    callBackground('getTempRules', [], cb);
  },
  addTempRule: function(domain, profileName, toggle, cb) {
    if (typeof toggle == 'function') {
      cb = toggle;
      toggle = null;
    }
    callBackgroundNoReply('addTempRule', [domain, profileName, toggle], cb);
  },
  openManage: function(domain, profileName, cb) {
    chrome.tabs.create({
      url: 'chrome://extensions/?id=' + chrome.runtime.id,
    }, cb);
  },
  getMessage: chrome.i18n.getMessage.bind(chrome.i18n),
};
