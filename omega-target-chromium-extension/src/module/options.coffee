OmegaTarget = require('omega-target')
OmegaPac = OmegaTarget.OmegaPac
Promise = OmegaTarget.Promise
querystring = require('querystring')
WebRequestMonitor = require('./web_request_monitor')
ChromePort = require('./chrome_port')
fetchUrl = require('./fetch_url')
Url = require('url')

TEMPPROFILEKEY = 'tempProfileState'

class ChromeOptions extends OmegaTarget.Options
  _inspect: null

  fetchUrl: fetchUrl

  constructor: (args...) ->
    super(args...)
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
        tempProfileState = if globalThis.hasStartupCheck
        then tempProfileState[TEMPPROFILEKEY] else null
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

  addTempRule: (domain, profileName) ->
    super(domain, profileName).then =>
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
      #chrome.action.setPopup({popup: 'popup/index.html'})
      chrome.action.setPopup({popup: 'popup-iframe.html'})

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
  setMonitorWebRequests: (enabled) ->
    @_monitorWebRequests = enabled
    if enabled and not @_requestMonitor?
      @_tabRequestInfoPorts = {}
      wildcardForReq = (req) -> OmegaPac.wildcardForUrl(req.url)
      @_requestMonitor = new WebRequestMonitor(wildcardForReq)
      @_requestMonitor.watchTabs (tabId, info) =>
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
      return Promise.reject err

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
