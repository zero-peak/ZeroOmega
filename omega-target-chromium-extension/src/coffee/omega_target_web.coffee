queryTab = (cb) ->
  chrome.tabs.query {active: true, lastFocusedWindow: true}, (tabs) ->
    if tabs.length == 0 or not (tabs[0].pendingUrl || tabs[0].url)
      cb()
    else
      cb(tabs[0])
getActiveTab = (activeTabId, cb) ->
  unless activeTabId
    sp = new URLSearchParams(document.location.search)
    activeTabId = sp.get('activeTabId')
  activeTabId = parseInt(activeTabId)
  if activeTabId
    chrome.tabs.get(activeTabId).then(cb).catch(->
      cb()
    )
  else
    queryTab(cb)

angular.module('omegaTarget', []).factory 'omegaTarget', ($q) ->
  decodeError = (obj) ->
    if obj._error == 'error'
      err = new Error(obj.message)
      err.name = obj.name
      err.stack = obj.stack
      err.original = obj.original
      err
    else
      obj
  callBackgroundNoReply = (method, args...) ->
    chrome.runtime.sendMessage({
      method: method
      args: args
      noReply: true
    })
  callBackground = (method, args...) ->
    d = $q['defer']()
    # On Manifest V3 the background service worker may be asleep or still
    # initializing when the popup is opened right after a browser restart.
    # In that case sendMessage fails with chrome.runtime.lastError (e.g.
    # "Could not establish connection" or "The message port closed before a
    # response was received") and no response is ever delivered. Without a
    # retry the popup would hang forever showing only the toolbar icon, so
    # retry a few times with a small backoff to ride out the wake-up race.
    #
    # If the worker failed to start on a cold start, Chrome marks it invalid
    # and refuses to wake it again for a while; sendMessage then fails with
    # "Receiving end does not exist." A handful of quick retries is not
    # enough to ride that out, so on that specific error keep retrying with
    # a much longer exponential backoff (~15s total) before giving up.
    maxAttempts = 5
    maxWorkerDownAttempts = 9
    send = (attempt) ->
      chrome.runtime.sendMessage({
        method: method
        args: args
      }, (response) ->
        if chrome.runtime.lastError?
          err = chrome.runtime.lastError
          workerDown =
            err.message?.indexOf('Receiving end does not exist') >= 0
          max = if workerDown then maxWorkerDownAttempts else maxAttempts
          if attempt < max
            delay = if workerDown and attempt > maxAttempts
              2000 * Math.pow(2, attempt - maxAttempts - 1)
            else
              100 * attempt
            setTimeout((-> send(attempt + 1)), delay)
          else
            d.reject(err)
          return
        if response?.error
          d.reject(decodeError(response.error))
        else
          d.resolve(response?.result)
      )
      return
    send(1)
    return d.promise
  connectBackground = (name, message, callback) ->
    port = chrome.runtime.connect({name: name})
    onDisconnect = ->
      port.onDisconnect.removeListener(onDisconnect)
      port.onMessage.removeListener(callback)
    port.onDisconnect.addListener(onDisconnect)

    port.postMessage(message)
    port.onMessage.addListener(callback)
    return

  isChromeUrl = (url) -> url.substr(0, 6) == 'chrome' or
    url.substr(0, 4) == 'moz-' or url.substr(0, 6) == 'about:'

  optionsChangeCallback = []
  requestInfoCallback = null
  prefix = 'omega.local.'
  urlParser = document.createElement('a')
  omegaTarget =
    options: null
    state: (name, value) ->
      d = $q.defer()
      if arguments.length == 1
        if Array.isArray(name)
          callBackground('getState', name).then((values) ->
            d.resolve(name.map((key) -> values[key]))
          , d.reject)
        else
          callBackground('getState', [name]).then( (values) ->
            d.resolve(values[name])
          , d.reject)
      else
        newItem = {}
        newItem[name] = value
        callBackground('setState', newItem).then( ->
          d.resolve(value)
        , d.reject)
      return d.promise
    lastUrl: (url) ->
      name = 'web.last_url'
      if url
        localStorage[prefix + name] = url
        url
      else
        try JSON.parse(localStorage[prefix + name])
    addOptionsChangeCallback: (callback) ->
      optionsChangeCallback.push(callback)
    refresh: (args) ->
      return callBackground('getAll').then (opt) ->
        omegaTarget.options = opt
        for callback in optionsChangeCallback
          callback(omegaTarget.options)
        return args
    renameProfile: (fromName, toName) ->
      callBackground('renameProfile', fromName, toName).then omegaTarget.refresh
    replaceRef: (fromName, toName) ->
      callBackground('replaceRef', fromName, toName).then omegaTarget.refresh
    optionsPatch: (patch) ->
      callBackground('patch', patch).then omegaTarget.refresh
    resetOptions: (opt) ->
      callBackground('reset', opt).then omegaTarget.refresh
    updateProfile: (name, opt_bypass_cache) ->
      callBackground('updateProfile', name, opt_bypass_cache).then((results) ->
        for own key, value of results
          results[key] = decodeError(value)
        results
      ).then omegaTarget.refresh
    getMessage: chrome.i18n.getMessage.bind(chrome.i18n)
    openOptions: (hash) ->
      d = $q['defer']()
      options_url = chrome.runtime.getURL('options.html')
      chrome.tabs.query url: options_url, (tabs) ->
        url = if hash
          urlParser.href = tabs[0]?.url || options_url
          urlParser.hash = hash
          urlParser.href
        else
          options_url
        if tabs.length > 0
          props = {active: true}
          if hash
            props.url = url
          chrome.tabs.update(tabs[0].id, props)
        else
          chrome.tabs.create({url: url})
        d.resolve()
      return d.promise
    applyProfile: (name) ->
      callBackground('applyProfile', name)
    applyProfileNoReply: (name) ->
      callBackgroundNoReply('applyProfile', name)
    addTempRule: (domain, profileName, toggle) ->
      callBackground('addTempRule', domain, profileName, toggle)
    addCondition: (condition, profileName) ->
      callBackground('addCondition', condition, profileName)
    addProfile: (profile) ->
      callBackground('addProfile', profile).then omegaTarget.refresh
    setDefaultProfile: (profileName, defaultProfileName) ->
      callBackground('setDefaultProfile', profileName, defaultProfileName)
    getActivePageInfo: (activeTabId) ->
      clearBadge = true
      d = $q['defer']()
      getActiveTab activeTabId, (tab) ->
        unless tab
          d.resolve(null)
          return
        args = {tabId: tab.id, url: tab.pendingUrl || tab.url}
        if tab.id and requestInfoCallback
          connectBackground('tabRequestInfo', args,
            requestInfoCallback)
        d.resolve(callBackground('getPageInfo', args))
      return d.promise.then (info) -> if info?.url then info else null
    refreshActivePage: (activeTabId) ->
      d = $q['defer']()
      getActiveTab activeTabId, (tab) ->
        unless tab
          return d.resolve()
        url = tab.pendingUrl || tab.url
        if url and not isChromeUrl(url)
          if tab.pendingUrl
            chrome.tabs.update(tab.id, {url})
          else
            chrome.tabs.reload(tab.id, {bypassCache: true})
        d.resolve()
      return d.promise
    openManage: ->
      chrome.tabs.create url: 'chrome://extensions/?id=' + chrome.runtime.id
    openShortcutConfig: ->
      chrome.tabs.create url: 'chrome://extensions/configureCommands'
    setOptionsSync: (enabled, args) ->
      callBackground('setOptionsSync', enabled, args)
    resetOptionsSync: (args) -> callBackground('resetOptionsSync', args)
    checkOptionsSyncChange: -> callBackground('checkOptionsSyncChange')
    setRequestInfoCallback: (callback) ->
      requestInfoCallback = callback

  return omegaTarget
