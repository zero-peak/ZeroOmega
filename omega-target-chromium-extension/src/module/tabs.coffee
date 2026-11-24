class ChromeTabs
  _defaultAction: null
  _badgeTab: null
  _proxyActivity: null

  constructor: (@actionForUrl) ->
    @_dirtyTabs = {}
    return

  setProxyActivity: (tracker) ->
    @_proxyActivity = tracker
    return

  ignoreError: ->
    chrome.runtime.lastError
    return

  watch: ->
    chrome.tabs.onUpdated.addListener @onUpdated.bind(this)
    chrome.tabs.onRemoved.addListener (tabId) =>
      @_proxyActivity?.onTabRemoved(tabId)
    chrome.tabs.onActivated.addListener (info) =>
      chrome.tabs.get info.tabId, (tab) =>
        return if chrome.runtime.lastError
        if @_dirtyTabs.hasOwnProperty(info.tabId)
          @onUpdated tab.id, {}, tab
    chrome.tabs.query {}, (tabs) =>
      return if chrome.runtime.lastError
      for tab in tabs
        @_proxyActivity?.setTabOrigin(tab.id, tab.url) if tab?.url

  resetAll: (action) ->
    @_defaultAction = action
    chrome.tabs.query {}, (tabs) =>
      @_dirtyTabs = {}
      tabs.forEach (tab) =>
        @_dirtyTabs[tab.id] = tab.id
        @onUpdated tab.id, {}, tab if tab.active
    title = if @_canSetPopup() then action.title else action.shortTitle
    chrome.action.setTitle({title: title})
    @setIcon(action.icon)

  onUpdated: (tabId, changeInfo, tab) ->
    if @_dirtyTabs.hasOwnProperty(tab.id)
      delete @_dirtyTabs[tab.id]
    else if not changeInfo.url? and changeInfo.status == "complete"
      return
    @processTab(tab, changeInfo)

  processTab: (tab, changeInfo) ->
    if @_badgeTab
      for own id of @_badgeTab
        try chrome.action.setBadgeText?(text: '', tabId: id)
        @_badgeTab = null

    if not tab.url? or tab.url.indexOf("chrome") == 0
      @_proxyActivity?.setTabBaseAction(tab.id, tab.url, null)
      if @_defaultAction
        chrome.action.setTitle({
          title: @_defaultAction.title
          tabId: tab.id
        })
        @clearIcon tab.id
      return
    @actionForUrl(tab.url).then((action) =>
      if not action
        @_proxyActivity?.setTabBaseAction(tab.id, tab.url, null)
        @clearIcon tab.id
        chrome.action.setBadgeText?(text: '', tabId: tab.id)
        return
      title = if @_canSetPopup() then action.title else action.shortTitle
      baseAction = Object.assign({}, action, {title: title})
      @_proxyActivity?.setTabBaseAction(tab.id, tab.url, baseAction)
      if action.badgeText
        chrome.action.setBadgeText?(
          text: action.badgeText,
          tabId: tab.id
        )
      unless @_proxyActivity?.hasActiveIconOverride(tab.id)
        @setIcon(action.icon, tab.id)
        return @setTitle(title, tab.id)
    ).catch((e) ->
      console.log('error:', e)
    )

  setTitle: (title, tabId) ->
    return unless title?
    params = {title: title}
    params.tabId = tabId if tabId?
    try
      chrome.action.setTitle?(params, @ignoreError)
    catch _
      return

  setTabBadge: (tab, badge) ->
    @_badgeTab ?= {}
    @_badgeTab[tab.id] = true
    chrome.action.setBadgeText?(text: badge.text, tabId: tab.id)
    chrome.action.setBadgeBackgroundColor?(
      color: badge.color
      tabId: tab.id
    )

  setIcon: (icon, tabId) ->
    return unless icon?
    params = {
      imageData: icon
    }
    params.tabId = tabId if tabId?
    @_chromeSetIcon(params)

  _canSetPopup: ->
    chrome.action.setPopup?

  _chromeSetIcon: (params) ->
    try
      chrome.action.setIcon?(params, @ignoreError)
    catch _
      # Some legacy Chrome versions will panic if there are other icon sizes.
      params.imageData = {19: params.imageData[19], 38: params.imageData[38]}
      chrome.action.setIcon?(params, @ignoreError)

  clearIcon: (tabId) ->
    return unless @_defaultAction?.icon?
    @_chromeSetIcon({
      imageData: @_defaultAction.icon
      tabId: tabId
    }, @ignoreError)

module.exports = ChromeTabs
