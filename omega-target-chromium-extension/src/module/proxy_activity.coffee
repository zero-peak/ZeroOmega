Url = require('url')

MAX_TIMESTAMPS = 200
MAX_HOSTS = 12
BLINK_INTERVAL_MS = 450
PORT_PUSH_THROTTLE_MS = 150

extractHost = (rawUrl) ->
  return '' unless rawUrl
  try
    parsed = Url.parse(rawUrl)
    return parsed.hostname or ''
  catch _
    return ''

extractOrigin = (rawUrl) ->
  return '' unless rawUrl
  try
    parsed = Url.parse(rawUrl)
    if parsed.protocol and parsed.host
      return "#{parsed.protocol}//#{parsed.host}".toLowerCase()
  catch _
    return ''
  return ''

class ProxyActivityTracker
  constructor: (@deps = {}) ->
    @_now = @deps.now or -> Date.now()
    @_setInterval = @deps.setInterval or (fn, ms) -> setInterval(fn, ms)
    @_clearInterval = @deps.clearInterval or (id) -> clearInterval(id)
    @_setTimeout = @deps.setTimeout or (fn, ms) -> setTimeout(fn, ms)
    @_clearTimeout = @deps.clearTimeout or (id) -> clearTimeout(id)

    @config =
      enabled: true
      iconMode: 'blink'
      windowSec: 10
      subrequestsOnly: false
      popupHighlight: true
      scope: 'tab'
      ignoreCache: false

    @_byTab = {}
    @_global = {}
    @_tabBaseAction = {}
    @_tabOrigins = {}
    @_tabVisualState = {}
    @_ports = []
    @_timer = null
    @_blinkPhase = 1
    @_pushTimer = null

  windowMs: ->
    sec = parseInt(@config.windowSec, 10)
    sec = 10 if isNaN(sec) or sec < 1
    sec = 300 if sec > 300
    sec * 1000

  setConfig: (nextConfig) ->
    return unless nextConfig?
    @config =
      enabled: !!nextConfig.enabled
      iconMode: nextConfig.iconMode or 'blink'
      windowSec: nextConfig.windowSec or 10
      subrequestsOnly: !!nextConfig.subrequestsOnly
      popupHighlight: nextConfig.popupHighlight != false
      scope: nextConfig.scope or 'tab'
      ignoreCache: !!nextConfig.ignoreCache

    if not @config.enabled or @config.iconMode == 'off'
      @_restoreAllTabVisuals()
      @_stopTimer()
    else
      @_refreshAllTabVisuals()

    @_broadcastNow()

  setTabOrigin: (tabId, url) ->
    return unless tabId? and tabId >= 0
    origin = extractOrigin(url)
    if origin
      @_tabOrigins[tabId] = origin
    else
      delete @_tabOrigins[tabId]

  setTabBaseAction: (tabId, url, action) ->
    return unless tabId? and tabId >= 0
    @setTabOrigin(tabId, url)
    if action?
      @_tabBaseAction[tabId] = action
    else
      delete @_tabBaseAction[tabId]

    if @_tabVisualState[tabId]?
      if @_isTabEligibleForIcon(tabId)
        @_applyTabVisual(tabId, @_blinkPhase, true)
      else
        @_restoreTabVisual(tabId)
        @_stopTimerIfIdle()

  hasActiveIconOverride: (tabId) ->
    return false unless tabId? and tabId >= 0
    @_isTabEligibleForIcon(tabId)

  onTabNavigationStart: (tabId, url) ->
    return unless tabId? and tabId >= 0
    delete @_byTab[tabId]
    @setTabOrigin(tabId, url)
    if @_tabVisualState[tabId]?
      @_restoreTabVisual(tabId)
      @_stopTimerIfIdle()
    @_scheduleBroadcast()

  onTabRemoved: (tabId) ->
    return unless tabId?
    delete @_byTab[tabId]
    delete @_tabBaseAction[tabId]
    delete @_tabOrigins[tabId]
    delete @_tabVisualState[tabId]
    @_stopTimerIfIdle()

  onProfileChanged: ->
    @_byTab = {}
    @_global = {}
    @_tabBaseAction = {}
    @_tabVisualState = {}
    @_stopTimer()
    @_broadcastNow()

  _resolveTargetTabs: (req) ->
    if req.tabId? and req.tabId >= 0
      return [req.tabId]
    initiator = req.initiator or req.originUrl or req.documentUrl
    origin = extractOrigin(initiator)
    return [] unless origin
    matched = []
    for own idStr, tabOrigin of @_tabOrigins
      if tabOrigin == origin
        matched.push(parseInt(idStr, 10))
    matched

  _recordIntoBucket: (bucket, profileName, color, host, now, isSub) ->
    entry = bucket[profileName]
    if not entry?
      entry = bucket[profileName] =
        name: profileName
        color: color
        lastUsed: now
        timestamps: []
        hosts: {}
        hasSubrequest: false
    entry.color = color if color
    entry.lastUsed = now
    entry.hasSubrequest = true if isSub
    entry.timestamps.push(now)
    if entry.timestamps.length > MAX_TIMESTAMPS
      entry.timestamps.splice(0, entry.timestamps.length - MAX_TIMESTAMPS)
    if host
      entry.hosts[host] = now
    entry

  recordRequest: (req, action) ->
    return unless @config.enabled
    return unless req? and action?
    return if action.isDirect
    return unless action.isProxy
    profile = action.profile
    return unless profile?.name
    return if profile.profileType in ['DirectProfile', 'SystemProfile']

    now = @_now()
    profileName = profile.name
    color = profile.color or '#99ccee'
    host = extractHost(req.url)
    isSub = req.type != 'main_frame'

    @_recordIntoBucket(@_global, profileName, color, host, now, isSub)

    targetTabs = @_resolveTargetTabs(req)
    for tabId in targetTabs
      bucket = (@_byTab[tabId] ?= {})
      @_recordIntoBucket(bucket, profileName, color, host, now, isSub)
      if @_isTabEligibleForIcon(tabId)
        @_blinkPhase = 1 unless @_timer?
        @_applyTabVisual(tabId, 1, false)
        @_ensureTimer()

    @_scheduleBroadcast()

  _pruneBucket: (bucket, now) ->
    return [] unless bucket?
    cutoff = now - @windowMs()
    active = []
    for own name, entry of bucket
      if entry.lastUsed < cutoff
        delete bucket[name]
        continue
      while entry.timestamps.length > 0 and entry.timestamps[0] < cutoff
        entry.timestamps.shift()
      for own h, ts of entry.hosts
        if ts < cutoff
          delete entry.hosts[h]
      if entry.timestamps.length == 0
        delete bucket[name]
        continue
      active.push(entry)
    active.sort((a, b) -> b.lastUsed - a.lastUsed)
    active

  _isTabEligibleForIcon: (tabId) ->
    return false unless @config.enabled
    return false if @config.iconMode == 'off'
    bucket = @_byTab[tabId]
    return false unless bucket?
    now = @_now()
    active = @_pruneBucket(bucket, now)
    if active.length == 0
      delete @_byTab[tabId]
      return false
    if @config.subrequestsOnly
      base = @_tabBaseAction[tabId]
      return false if base?.isProxy
    return true

  _topHosts: (hostsMap, limit = MAX_HOSTS) ->
    pairs = []
    for own host, ts of hostsMap
      pairs.push([host, ts])
    pairs.sort((a, b) -> b[1] - a[1])
    pairs.slice(0, limit).map((p) -> p[0])

  _buildActivityTitle: (baseTitle, activeEntries) ->
    stableEntries = activeEntries.slice().sort((a, b) ->
      if a.name < b.name then -1 else if a.name > b.name then 1 else 0
    )
    parts = stableEntries.slice(0, 4).map((entry) =>
      hosts = @_topHosts(entry.hosts, 2).sort()
      if hosts.length > 0
        "#{entry.name} (#{hosts.join(', ')})"
      else
        entry.name
    )
    prefix = @deps.getMessage?(
      'browserAction_proxyActivityTitle',
      [String(@config.windowSec), parts.join(', ')]
    )
    unless prefix
      prefix = "Active proxy (#{@config.windowSec}s): #{parts.join(', ')}"
    if baseTitle
      "#{baseTitle}\n#{prefix}"
    else
      prefix

  _applyTabVisual: (tabId, phase, forceIcon) ->
    bucket = @_byTab[tabId]
    now = @_now()
    active = @_pruneBucket(bucket, now)
    if active.length == 0
      @_restoreTabVisual(tabId)
      return

    latest = active[0]
    base = @_tabBaseAction[tabId] or @deps.getDefaultAction?()
    visual = (@_tabVisualState[tabId] ?= {
      lastFrameKey: null
      lastTitleKey: null
      lastTitle: null
    })

    profileColor = base?.profileColor ? base?.profile?.color ? null
    showLit = (@config.iconMode == 'glow') or (phase == 1)

    if showLit
      frameKey = "on:#{latest.color}:#{profileColor ? ''}"
      if forceIcon or visual.lastFrameKey != frameKey
        icon = @deps.drawActivityIcon?(latest.color, profileColor, true)
        if icon?
          @deps.setTabIcon?(tabId, icon)
        visual.lastFrameKey = frameKey
    else
      frameKey = "off:#{base?.resultColor ? ''}:#{profileColor ? ''}"
      if forceIcon or visual.lastFrameKey != frameKey
        icon = base?.icon
        if not icon?
          fallbackOuter = base?.resultColor or '#aaaaaa'
          icon = @deps.drawActivityIcon?(fallbackOuter, profileColor, false)
        if icon?
          @deps.setTabIcon?(tabId, icon)
        visual.lastFrameKey = frameKey

    titleKey = active.map((e) -> e.name).sort().join('|') +
      ":#{base?.title or ''}:#{@config.windowSec}"
    if visual.lastTitleKey != titleKey
      title = @_buildActivityTitle(base?.title, active)
      visual.lastTitleKey = titleKey
      if visual.lastTitle != title
        @deps.setTabTitle?(tabId, title)
        visual.lastTitle = title

  _restoreTabVisual: (tabId) ->
    return unless @_tabVisualState[tabId]?
    delete @_tabVisualState[tabId]
    base = @_tabBaseAction[tabId] or @deps.getDefaultAction?()
    if base?
      @deps.setTabIcon?(tabId, base.icon) if base.icon?
      @deps.setTabTitle?(tabId, base.title) if base.title?

  _restoreAllTabVisuals: ->
    tabIds = Object.keys(@_tabVisualState)
    for idStr in tabIds
      @_restoreTabVisual(parseInt(idStr, 10))

  _refreshAllTabVisuals: ->
    allTabIds = {}
    for own k of @_tabVisualState
      allTabIds[k] = true
    for own k of @_byTab
      allTabIds[k] = true
    hasActive = false
    for own idStr of allTabIds
      tabId = parseInt(idStr, 10)
      if @_isTabEligibleForIcon(tabId)
        @_applyTabVisual(tabId, @_blinkPhase, true)
        hasActive = true
      else
        @_restoreTabVisual(tabId)
    if hasActive
      @_ensureTimer()
    else
      @_stopTimer()

  _ensureTimer: ->
    return if @_timer?
    @_timer = @_setInterval(@_tick.bind(this), BLINK_INTERVAL_MS)

  _stopTimer: ->
    if @_timer?
      @_clearInterval(@_timer)
      @_timer = null
    @_blinkPhase = 1

  _stopTimerIfIdle: ->
    if Object.keys(@_tabVisualState).length == 0
      @_stopTimer()

  _tick: ->
    @_blinkPhase = if @_blinkPhase == 1 then 0 else 1
    tabIds = Object.keys(@_tabVisualState)
    for idStr in tabIds
      tabId = parseInt(idStr, 10)
      if @_isTabEligibleForIcon(tabId)
        @_applyTabVisual(tabId, @_blinkPhase, false)
      else
        @_restoreTabVisual(tabId)
    @_stopTimerIfIdle()

  getSnapshot: (tabId) ->
    now = @_now()
    globalActive = @_pruneBucket(@_global, now)
    tabBucket = if tabId? and tabId >= 0 then @_byTab[tabId] else null
    tabActive = if tabBucket? then @_pruneBucket(tabBucket, now) else []

    tabSet = {}
    for entry in tabActive
      tabSet[entry.name] = true

    sourceList =
      if not @config.enabled or not @config.popupHighlight
        []
      else if @config.scope == 'all'
        globalActive
      else
        tabActive

    entries = {}
    for entry in sourceList
      entries[entry.name] =
        name: entry.name
        color: entry.color
        lastUsed: entry.lastUsed
        count: entry.timestamps.length
        hosts: @_topHosts(entry.hosts, MAX_HOSTS)
        inCurrentTab: !!tabSet[entry.name]

    {
      type: 'activity'
      now: now
      tabId: tabId
      config:
        enabled: @config.enabled
        iconMode: @config.iconMode
        windowSec: @config.windowSec
        popupHighlight: @config.popupHighlight
        scope: @config.scope
      entries: entries
    }

  attachPort: (port) ->
    rec =
      port: port
      tabId: null
    @_ports.push(rec)

    onMessage = (msg) =>
      return unless msg?
      if msg.type == 'init'
        rec.tabId = msg.tabId if msg.tabId?
        try
          port.postMessage(@getSnapshot(rec.tabId))
        catch _
          return

    onDisconnect = =>
      port.onMessage.removeListener(onMessage)
      port.onDisconnect.removeListener(onDisconnect)
      idx = @_ports.indexOf(rec)
      @_ports.splice(idx, 1) if idx >= 0

    port.onMessage.addListener(onMessage)
    port.onDisconnect.addListener(onDisconnect)

  _scheduleBroadcast: ->
    return if @_ports.length == 0
    return if @_pushTimer?
    @_pushTimer = @_setTimeout(=>
      @_pushTimer = null
      @_broadcastNow()
    , PORT_PUSH_THROTTLE_MS)

  _broadcastNow: ->
    if @_pushTimer?
      @_clearTimeout(@_pushTimer)
      @_pushTimer = null
    return if @_ports.length == 0
    for rec in @_ports.slice()
      try
        rec.port.postMessage(@getSnapshot(rec.tabId))
      catch _
        continue

module.exports = ProxyActivityTracker
