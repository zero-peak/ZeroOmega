OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise
querystring = require('querystring')
WebRequestMonitor = require('./web_request_monitor')
ProxyActivityTracker = require('./proxy_activity')
ChromePort = require('./chrome_port')
fetchUrl = require('./fetch_url')
Url = require('url')

TEMPPROFILEKEY = 'tempProfileState'

class ChromeOptions extends OmegaTarget.Options
  _inspect: null
  _actionForUrl: null
  _tabs: null
  _drawActivityIcon: null
  _proxyActivity: null
  _activityWatching: false
  _activityRecordedIds: null

  fetchUrl: fetchUrl
  _networkInspectPorts: []

  constructor: (args...) ->
    super(args...)
    @_activityRecordedIds = {}
    @_proxyActivity = new ProxyActivityTracker(
      setTabIcon: (tabId, icon) =>
        @_tabs?.setIcon(icon, tabId)
      setTabTitle: (tabId, title) =>
        @_tabs?.setTitle(title, tabId)
      drawActivityIcon: (activityColor, profileColor, showDot) =>
        @_drawActivityIcon?(activityColor, profileColor, showDot)
      getDefaultAction: =>
        @_tabs?._defaultAction
      getMessage: (key, subs) ->
        chrome.i18n?.getMessage?(key, subs) or ''
    )

    chrome.runtime.onConnect.addListener((port) =>
      if port.name is 'proxy-activity'
        @_proxyActivity.attachPort(port)
        return
      return if port.name isnt 'network-inspect'
      unless @_requestMonitor
        originalEnabled = @_monitorWebRequests
        @setMonitorWebRequests(true)
        @_monitorWebRequests = originalEnabled
      port.postMessage({
        type: 'connected'
      })
      onMessage = (msg) =>
        switch msg.type
          when 'init'
            requestTabId = msg.tabId
            _tabInfo = @_requestMonitor.tabInfo
            if requestTabId
              _tabInfo = {}
              _tabInfo[requestTabId] = @_requestMonitor.tabInfo[requestTabId]
            port.postMessage({
              type: 'init'
              data: _tabInfo
            })
      port.onMessage.addListener(onMessage)
      @_networkInspectPorts.push(port)
      disConnect = =>
        port.onMessage.removeListener(onMessage)
        port.onDisconnect.removeListener(disConnect)
        pos = 0
        while pos >= 0
          pos = @_networkInspectPorts.indexOf(port)
          if pos >= 0
            @_networkInspectPorts.splice(pos, 1)
      port.onDisconnect.addListener(disConnect)
    )

    chrome.alarms.onAlarm.addListener (alarm) =>
      switch alarm.name
        when 'omega.updateProfile'
          @ready.then( =>
            @updateProfile()
          )
    chrome.contextMenus?.onClicked.addListener((info, tab) =>
      @ready.then( =>
        switch info.menuItemId
          when 'enableQuickSwitch'
            changes = {}
            changes['-enableQuickSwitch'] = info.checked
            setOptions = @_setOptions(changes)
            if info.checked and not @_quickSwitchCanEnable
              setOptions.then ->
                chrome.tabs.create(
                  url: chrome.runtime.getURL('options.html#/ui')
                )
      )
    )

    chrome.action.onClicked.addListener (tab) =>
      if browser?.proxy?.onRequest?
        browser.permissions.request({origins: ["<all_urls>"]})
      @ready.then( =>
        @clearBadge()
        if not @_options['-enableQuickSwitch']
          # If we reach here, then the browser does not support popup.
          # Let's open the popup page in a tab.
          chrome.tabs.create(url: 'popup/index.html')
          return
        profiles = @_options['-quickSwitchProfiles']
        index = profiles.indexOf(@_currentProfileName)
        index = (index + 1) % profiles.length
        @applyProfile(profiles[index]).then =>
          if @_options['-refreshOnProfileChange']
            url = tab.pendingUrl or tab.url
            return if not url
            return if url.substr(0, 6) == 'chrome'
            return if url.substr(0, 6) == 'about:'
            return if url.substr(0, 4) == 'moz-'
            if tab.pendingUrl
              chrome.tabs.update(tab.id, {url: url})
            else
              chrome.tabs.reload(tab.id)
      )

  init: (startupCheck) ->
    super(startupCheck)
    @ready.then =>
      chrome.storage.session
      .get(TEMPPROFILEKEY).then((tempProfileState = {}) =>
        tempProfileState = tempProfileState[TEMPPROFILEKEY]
        # tempProfileState =
        # { _tempProfile,
        # _tempProfileActive}
        if tempProfileState
          @_tempProfile = tempProfileState._tempProfile
          @_tempProfile.rules.forEach((_rule) =>
            key = OmegaPac.Profiles.nameAsKey(_rule.profileName)
            @_tempProfileRulesByProfile[key] =
              @_tempProfileRulesByProfile[key] or []
            @_tempProfileRulesByProfile[key].push(_rule)
            condition = _rule.condition
            domain = condition.pattern.substring(2)
            @_tempProfileRules[domain] = _rule
          )
          #@_tempProfileRules = tempProfileState._tempProfileRules
          #@_tempProfileRulesByProfile =
          #  tempProfileState._tempProfileRulesByProfile
          @_tempProfileActive = tempProfileState._tempProfileActive
          OmegaPac.Profiles.updateRevision(@_tempProfile)
          console.log('apply temp state profile', @_currentProfileName)
          @applyProfile(@_currentProfileName)
        )
    @ready

  addTempRule: (domain, profileName, toggle) ->
    super(domain, profileName, toggle).then =>
      _zeroState = {}
      _zeroState[TEMPPROFILEKEY] = {
        _tempProfile: @_tempProfile
        _tempProfileActive: @_tempProfileActive
      }
      chrome.storage.session.set(_zeroState)
  updateProfile: (args...) ->
    super(args...).then (results) ->
      error = false
      for own profileName, result of results
        if result instanceof Error
          error = true
          break
      if error
        # TODO(catus): Find a better way to notify the user.
        ###
        @setBadge(
          text: '!'
          color: '#faa732'
          title: chrome.i18n.getMessage('browserAction_titleDownloadFail')
        )
        ###
      return results

  _proxyNotControllable: null
  proxyNotControllable: -> @_proxyNotControllable
  setProxyNotControllable: (reason, badge) ->
    @_proxyNotControllable = reason
    if reason
      @_state.set({'proxyNotControllable': reason})
      @setBadge(badge)
    else
      @_state.remove(['proxyNotControllable'])
      @clearBadge()

  _badgeTitle: null
  setBadge: (options) ->
    if not options
      options =
        if @_proxyNotControllable
          text: '='
          color: '#da4f49'
        else
          text: '?'
          color: '#49afcd'
    chrome.action.setBadgeText(text: options.text)
    chrome.action.setBadgeBackgroundColor(color: options.color)
    if options.title
      @_badgeTitle = options.title
      chrome.action.setTitle(title: options.title)
    else
      @_badgeTitle = null
  clearBadge: ->
    return if @externalApi.disabled
    if @_badgeTitle
      @currentProfileChanged('clearBadge')
    if @_proxyNotControllable
      @setBadge()
    else
      chrome.action.setBadgeText?(text: '')
    return

  _quickSwitchCanEnable: false
  setQuickSwitch: (quickSwitch, canEnable) ->
    @_quickSwitchCanEnable = canEnable
    if quickSwitch
      chrome.action.setPopup({popup: ''})
    else
      chrome.action.setPopup({popup: globalThis.POPUPHTMLURL})

    chrome.contextMenus?.update('enableQuickSwitch', {checked: !!quickSwitch})
    Promise.resolve()

  setInspect: (settings) ->
    if @_inspect
      if settings.showMenu
        @_inspect.enable()
      else
        @_inspect.disable()
    return Promise.resolve()

  _requestMonitor: null
  _monitorWebRequests: false
  _tabRequestInfoPorts: null

  setProxyActivityDeps: (tabs, drawActivityIcon) ->
    @_tabs = tabs
    @_drawActivityIcon = drawActivityIcon
    tabs?.setProxyActivity?(@_proxyActivity)
    return

  setProxyActivityConfig: (config) ->
    @_proxyActivity?.setConfig(config)
    if config?.enabled
      unless @_requestMonitor?
        originalEnabled = @_monitorWebRequests
        @setMonitorWebRequests(true)
        @_monitorWebRequests = originalEnabled
      @_ensureProxyActivityMonitor()
    Promise.resolve()

  getProxyActivity: (tabId) ->
    Promise.resolve(@_proxyActivity?.getSnapshot(tabId) or null)

  _ensureProxyActivityMonitor: ->
    return if @_activityWatching
    return unless @_requestMonitor?
    @_activityWatching = true
    ignoredUrlRe = /^(chrome|moz)-extension:|^(chrome|about|data|blob|file):/i
    @_requestMonitor.watchActivity (status, req) =>
      return unless req?.url
      return if ignoredUrlRe.test(req.url)
      if status == 'start' and req.type == 'main_frame' and req.tabId >= 0
        if req.url.indexOf('chrome://errorpage/') != 0
          @_proxyActivity.onTabNavigationStart(req.tabId, req.url)
      return unless @_proxyActivity?.config?.enabled
      return unless @_actionForUrl?
      if not @_proxyActivity.config.ignoreCache
        return unless status == 'start'
      else
        if status == 'headers'
          if Object.keys(@_activityRecordedIds).length > 1000
            @_activityRecordedIds = {}
          @_activityRecordedIds[req.requestId] = true
        else if status == 'done'
          if @_activityRecordedIds[req.requestId]
            delete @_activityRecordedIds[req.requestId]
            return
          return if req.fromCache
        else
          return
      @_actionForUrl(req.url, {skipIcon: true}).then((action) =>
        @_proxyActivity.recordRequest(req, action)
      ).catch(-> null)
    return

  setMonitorWebRequests: (enabled) ->
    @_monitorWebRequests = enabled
    if enabled and not @_requestMonitor?
      @_tabRequestInfoPorts = {}
      wildcardForReq = (req) -> OmegaPac.wildcardForUrl(req.url)
      @_requestMonitor = new WebRequestMonitor(wildcardForReq)
      if @_proxyActivity?.config?.enabled
        @_ensureProxyActivityMonitor()
      @_requestMonitor.watchTabs (tabId, info, req, status) =>
        unless /^(chrome|moz)-extension:\/\//i.test(req?.url)
          updateMessage = =>
            @_networkInspectPorts.forEach((port) ->
              port.postMessage({
                type: 'update'
                data: {
                  tabId,
                  info,
                  req,
                  status
                }
              })
            )
          if status is 'start'
            @_actionForUrl(req.url, {skipIcon: true})
              .then((action) ->
                request = info.requests[req.requestId]
                if request
                  request.actionProfile = action
                  updateMessage()
              )
          updateMessage()
        return unless @_monitorWebRequests
        if info.errorCount > 0
          info.badgeSet = true
          badge = {text: info.errorCount.toString(), color: '#f0ad4e'}
          chrome.action.setBadgeText(text: badge.text, tabId: tabId)
          .catch((e) ->
            console.log('error:',e)
          )
          chrome.action.setBadgeBackgroundColor(
            color: badge.color
            tabId: tabId
          ).catch((e) ->
            console.log('error:',e)
          )
        else if info.badgeSet
          info.badgeSet = false
          chrome.action.setBadgeText(text: '', tabId: tabId)
          .catch((e) ->
            console.log('error:',e)
          )
        @_tabRequestInfoPorts[tabId]?.postMessage({
          errorCount: info.errorCount
          summary: info.summary
        })

      chrome.runtime.onConnect.addListener (rawPort) =>
        return unless rawPort.name == 'tabRequestInfo'
        return unless @_monitorWebRequests
        tabId = null
        port = new ChromePort(rawPort)
        port.onMessage.addListener (msg) =>
          tabId = msg.tabId
          @_tabRequestInfoPorts[tabId] = port
          info = @_requestMonitor.tabInfo[tabId]
          if info
            port.postMessage({
              errorCount: info.errorCount
              summary: info.summary
            })
        port.onDisconnect.addListener =>
          delete @_tabRequestInfoPorts[tabId] if tabId?

  schedule: (name, periodInMinutes) ->
    name = 'omega.' + name
    if periodInMinutes < 0
      chrome.alarms.clear(name)
    else
      chrome.alarms.create(name, {
        periodInMinutes: periodInMinutes
      })
    Promise.resolve()

  printFixedProfile: (profile) ->
    return unless profile.profileType == 'FixedProfile'
    result = ''
    for scheme in OmegaPac.Profiles.schemes when profile[scheme.prop]
      pacResult = OmegaPac.Profiles.pacResult(profile[scheme.prop])
      if scheme.scheme
        result += "#{scheme.scheme}: #{pacResult}\n"
      else
        result += "#{pacResult}\n"
    result ||= chrome.i18n.getMessage(
      'browserAction_profileDetails_DirectProfile')
    return result

  printProfile: (profile) ->
    type = profile.profileType
    if type.indexOf('RuleListProfile') >= 0
      type = 'RuleListProfile'

    if type == 'FixedProfile'
      @printFixedProfile(profile)
    else if type == 'PacProfile' and profile.pacUrl
      profile.pacUrl
    else
      chrome.i18n.getMessage('browserAction_profileDetails_' + type) || null

  upgrade: (options, changes) ->
    super(options).catch (err) ->
      return Promise.reject err if options?['schemaVersion']
      return Promise.reject new OmegaTarget.Options.NoOptionsError()

  onFirstRun: (reason) ->
    console.log('first run ....')
    chrome.tabs.create url: chrome.runtime.getURL('options.html')

  getPageInfo: ({tabId, url}) ->
    errorCount = @_requestMonitor?.tabInfo[tabId]?.errorCount
    result = if errorCount then {errorCount: errorCount} else null
    getBadge = new Promise (resolve, reject) ->
      if not chrome.action.getBadgeText?
        resolve('')
        return
      chrome.action.getBadgeText {tabId: tabId}, (result) ->
        resolve(result)

    getInspectUrl = @_state.get({inspectUrl: ''})
    Promise.join getBadge, getInspectUrl, (badge, {inspectUrl}) =>
      if badge == '#' and inspectUrl
        url = inspectUrl
      else
        @clearBadge()
      return result if not url
      if url.substr(0, 6) == 'chrome'
        errorPagePrefix = 'chrome://errorpage/'
        if url.substr(0, errorPagePrefix.length) == errorPagePrefix
          url = querystring.parse(url.substr(url.indexOf('?') + 1)).lasturl
          return result if not url
        else
          return result
      return result if url.substr(0, 6) == 'about:'
      return result if url.substr(0, 4) == 'moz-'
      domain = OmegaPac.getBaseDomain(Url.parse(url).hostname)
      subdomain = OmegaPac.getSubdomain(url)

      return {
        url: url
        domain: domain
        subdomain: subdomain
        tempRuleProfileName: @queryTempRule(domain)
        errorCount: errorCount
      }

module.exports = ChromeOptions
