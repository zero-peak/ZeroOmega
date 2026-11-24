chai = require('chai')
expect = chai.expect
ProxyActivityTracker = require('../src/module/proxy_activity')

createHarness = ->
  nowMs = 10000
  nextTimerId = 1
  intervals = {}
  timeouts = {}
  iconCalls = []
  titleCalls = []
  drawCalls = []

  deps =
    now: -> nowMs
    setInterval: (fn, ms) ->
      id = nextTimerId++
      intervals[id] = {fn: fn, ms: ms}
      id
    clearInterval: (id) ->
      delete intervals[id]
    setTimeout: (fn, ms) ->
      id = nextTimerId++
      timeouts[id] = {fn: fn, ms: ms}
      id
    clearTimeout: (id) ->
      delete timeouts[id]
    setTabIcon: (tabId, icon) ->
      iconCalls.push({tabId: tabId, icon: icon})
    setTabTitle: (tabId, title) ->
      titleCalls.push({tabId: tabId, title: title})
    drawActivityIcon: (activityColor, profileColor, showDot) ->
      rec = {
        activityColor: activityColor
        profileColor: profileColor
        showDot: !!showDot
      }
      drawCalls.push(rec)
      rec
    getDefaultAction: ->
      icon: {defaultIcon: true}
      title: 'ZeroOmega:: auto switch'
      resultColor: '#aaaaaa'
      profileColor: '#99dd99'
    getMessage: (key, subs) ->
      if key == 'browserAction_proxyActivityTitle'
        return "Active proxy (#{subs[0]}s): #{subs[1]}"
      ''

  tracker = new ProxyActivityTracker(deps)

  {
    tracker: tracker
    iconCalls: iconCalls
    titleCalls: titleCalls
    drawCalls: drawCalls
    intervals: intervals
    timeouts: timeouts
    advance: (ms) -> nowMs += ms
    tickIntervals: ->
      for own id, rec of intervals
        rec.fn()
    flushTimeouts: ->
      keys = Object.keys(timeouts)
      for id in keys
        rec = timeouts[id]
        delete timeouts[id]
        rec?.fn()
  }

makeAction = (name, opts = {}) ->
  profileType = opts.profileType or 'FixedProfile'
  isDirect = !!opts.isDirect
  isProxy = (not isDirect) and
    (profileType not in ['DirectProfile', 'SystemProfile'])
  {
    profile:
      name: name
      profileType: profileType
      color: opts.color or '#ffaa00'
    icon: opts.icon or {baseFor: name}
    title: opts.title or "ZeroOmega:: auto switch -> #{name}"
    resultColor: opts.color or '#ffaa00'
    profileColor: '#99dd99'
    isDirect: isDirect
    isProxy: isProxy
  }

describe 'ProxyActivityTracker', ->
  it 'blinks icon on proxied sub-request and restores after windowSec', ->
    h = createHarness()
    t = h.tracker
    baseDirect = makeAction('direct',
      profileType: 'DirectProfile'
      color: '#aaaaaa'
      icon: {baseDirect: true}
      title: 'ZeroOmega:: auto switch (direct)'
    )
    t.setTabBaseAction(1, 'https://site.example.com/watch?v=1', baseDirect)

    proxyAction = makeAction('ProxyA', color: '#ffcc00')
    t.recordRequest(
      {tabId: 1, type: 'xmlhttprequest', url: 'https://media1.example.net/v'}
      proxyAction
    )

    expect(h.iconCalls.length).to.equal(1)
    expect(h.iconCalls[0].icon.activityColor).to.equal('#ffcc00')
    expect(h.iconCalls[0].icon.showDot).to.equal(true)
    expect(h.titleCalls[0].title).to.contain(
      'Active proxy (10s): ProxyA (media1.example.net)'
    )
    expect(Object.keys(h.intervals).length).to.equal(1)

    # Tick 1 -> phase 0 (base direct icon)
    h.advance(450)
    h.tickIntervals()
    expect(h.iconCalls.length).to.equal(2)
    expect(h.iconCalls[1].icon).to.deep.equal({baseDirect: true})

    # Tick 2 -> phase 1 (lit proxy icon again)
    h.advance(450)
    h.tickIntervals()
    expect(h.iconCalls.length).to.equal(3)
    expect(h.iconCalls[2].icon.showDot).to.equal(true)

    # Expire past 10s -> restores base icon & title and stops timer
    h.advance(10000)
    h.tickIntervals()
    lastIcon = h.iconCalls[h.iconCalls.length - 1]
    lastTitle = h.titleCalls[h.titleCalls.length - 1]
    expect(lastIcon.icon).to.deep.equal({baseDirect: true})
    expect(lastTitle.title).to.equal('ZeroOmega:: auto switch (direct)')
    expect(Object.keys(h.intervals).length).to.equal(0)

  it 'keeps steady icon in glow mode without redundant setIcon calls', ->
    h = createHarness()
    t = h.tracker
    t.setConfig(
      enabled: true
      iconMode: 'glow'
      windowSec: 5
      subrequestsOnly: false
      popupHighlight: true
      scope: 'tab'
    )
    baseDirect = makeAction('direct',
      profileType: 'DirectProfile'
      color: '#aaaaaa'
      icon: {baseDirect: true}
    )
    t.setTabBaseAction(2, 'https://example.com/', baseDirect)
    t.recordRequest(
      {tabId: 2, type: 'image', url: 'https://cdn.example.org/a.png'}
      makeAction('ProxyB', color: '#00cc66')
    )

    expect(h.iconCalls.length).to.equal(1)
    expect(h.iconCalls[0].icon.showDot).to.equal(true)

    # Ticks inside 5s window should NOT redraw icon in glow mode
    h.advance(2000)
    h.tickIntervals()
    h.advance(2000)
    h.tickIntervals()
    expect(h.iconCalls.length).to.equal(1)

    # After 5s window expires -> restores base icon
    h.advance(2000)
    h.tickIntervals()
    expect(h.iconCalls.length).to.equal(2)
    expect(h.iconCalls[1].icon).to.deep.equal({baseDirect: true})

  it 'does not modify icon when iconMode is off but highlights popup', ->
    h = createHarness()
    t = h.tracker
    t.setConfig(
      enabled: true
      iconMode: 'off'
      windowSec: 10
      popupHighlight: true
      scope: 'tab'
    )
    t.recordRequest(
      {tabId: 3, type: 'script', url: 'https://sub.example.com/app.js'}
      makeAction('ProxyC', color: '#ee8866')
    )
    expect(h.iconCalls.length).to.equal(0)
    expect(h.titleCalls.length).to.equal(0)
    snap = t.getSnapshot(3)
    expect(snap.entries['ProxyC']).to.exist
    expect(snap.entries['ProxyC'].count).to.equal(1)

  it 'respects subrequestsOnly when main tab page is proxied vs direct', ->
    h = createHarness()
    t = h.tracker
    t.setConfig(
      enabled: true
      iconMode: 'blink'
      windowSec: 10
      subrequestsOnly: true
      popupHighlight: true
      scope: 'tab'
    )
    proxiedBase = makeAction('ProxyA', color: '#ffcc00')
    t.setTabBaseAction(4, 'https://app.example.com/', proxiedBase)
    t.recordRequest(
      {tabId: 4, type: 'xmlhttprequest', url: 'https://api.example.com/u'}
      proxiedBase
    )
    # Main page is proxied -> no icon override, but popup still sees it
    expect(h.iconCalls.length).to.equal(0)
    expect(t.getSnapshot(4).entries['ProxyA']).to.exist

    # Direct main page -> subrequest DOES trigger icon
    directBase = makeAction('direct', profileType: 'DirectProfile')
    t.setTabBaseAction(5, 'https://site.example.com/', directBase)
    t.recordRequest(
      {tabId: 5, type: 'media', url: 'https://media2.example.net/seg'}
      proxiedBase
    )
    expect(h.iconCalls.length).to.equal(1)
    expect(h.iconCalls[0].tabId).to.equal(5)

  it 'separates tab scope vs all scope and attributes SW requests', ->
    h = createHarness()
    t = h.tracker
    directBase = makeAction('direct', profileType: 'DirectProfile')
    t.setTabBaseAction(10, 'https://site.example.com/watch', directBase)
    t.setTabBaseAction(20, 'https://other.example.org/', directBase)

    # Service Worker request (tabId = -1) initiated by site.example.com
    t.recordRequest(
      {
        tabId: -1
        initiator: 'https://site.example.com'
        type: 'xmlhttprequest'
        url: 'https://media3.example.net/chunk'
      }
      makeAction('ProxyA', color: '#ffcc00')
    )
    # Request on tab 20
    t.recordRequest(
      {tabId: 20, type: 'image', url: 'https://img.example.org/x.jpg'}
      makeAction('ProxyB', color: '#00cc66')
    )

    # Default scope = 'tab'
    snap10 = t.getSnapshot(10)
    expect(Object.keys(snap10.entries)).to.deep.equal(['ProxyA'])
    expect(snap10.entries['ProxyA'].inCurrentTab).to.equal(true)

    # Switch to scope = 'all'
    t.setConfig(
      enabled: true
      iconMode: 'blink'
      windowSec: 10
      popupHighlight: true
      scope: 'all'
    )
    snapAll = t.getSnapshot(10)
    expect(snapAll.entries['ProxyA'].inCurrentTab).to.equal(true)
    expect(snapAll.entries['ProxyB'].inCurrentTab).to.equal(false)

  it 'ignores direct, system, and bypassList direct requests', ->
    h = createHarness()
    t = h.tracker
    t.recordRequest(
      {tabId: 1, type: 'main_frame', url: 'https://site.example.com/'}
      makeAction('direct', profileType: 'DirectProfile')
    )
    t.recordRequest(
      {tabId: 1, type: 'script', url: 'https://site.example.com/s.js'}
      makeAction('system', profileType: 'SystemProfile')
    )
    t.recordRequest(
      {tabId: 1, type: 'xmlhttprequest', url: 'http://localhost:8080/'}
      makeAction('ProxyA', isDirect: true)
    )
    expect(h.iconCalls.length).to.equal(0)
    expect(Object.keys(t.getSnapshot(1).entries).length).to.equal(0)

  it 'clears tab activity on navigation, removal, disable, and port push', ->
    h = createHarness()
    t = h.tracker
    messages = []
    listeners = {}
    fakePort =
      onMessage:
        addListener: (fn) -> listeners.msg = fn
        removeListener: -> delete listeners.msg
      onDisconnect:
        addListener: (fn) -> listeners.disc = fn
        removeListener: -> delete listeners.disc
      postMessage: (m) -> messages.push(m)

    t.attachPort(fakePort)
    listeners.msg({type: 'init', tabId: 7})
    expect(messages.length).to.equal(1)
    expect(Object.keys(messages[0].entries).length).to.equal(0)

    t.recordRequest(
      {tabId: 7, type: 'xmlhttprequest', url: 'https://res.example.test/api'}
      makeAction('ProxyD', color: '#ff8844')
    )
    h.flushTimeouts()
    expect(messages.length).to.equal(2)
    expect(messages[1].entries['ProxyD'].count).to.equal(1)

    # Navigating to a new page resets tab 7 activity
    t.onTabNavigationStart(7, 'https://clean.example.com/')
    expect(Object.keys(t.getSnapshot(7).entries).length).to.equal(0)

    # Disabling indicator restores visuals & returns empty entries
    t.recordRequest(
      {tabId: 7, type: 'image', url: 'https://res.example.test/i.png'}
      makeAction('ProxyD', color: '#ff8844')
    )
    t.setConfig(enabled: false, iconMode: 'blink', windowSec: 10)
    expect(Object.keys(h.intervals).length).to.equal(0)
    expect(Object.keys(t.getSnapshot(7).entries).length).to.equal(0)

  it 'keeps toolbar title stable without flickering across rapid requests', ->
    h = createHarness()
    t = h.tracker
    directBase = makeAction('direct',
      profileType: 'DirectProfile'
      title: 'ZeroOmega:: auto switch'
    )
    t.setTabBaseAction(9, 'https://site.example.com/', directBase)

    t.recordRequest(
      {tabId: 9, type: 'xmlhttprequest', url: 'https://b.example.net/1'}
      makeAction('ProxyZ', color: '#ffcc00')
    )
    expect(h.titleCalls.length).to.equal(1)

    # More rapid requests through same proxy should NOT call setTabTitle again
    h.advance(100)
    t.recordRequest(
      {tabId: 9, type: 'xmlhttprequest', url: 'https://a.example.net/2'}
      makeAction('ProxyZ', color: '#ffcc00')
    )
    h.advance(450)
    h.tickIntervals()
    expect(h.titleCalls.length).to.equal(1)

    # Second proxy appears -> updates title once in alphabetical order
    t.recordRequest(
      {tabId: 9, type: 'image', url: 'https://img.example.org/1.jpg'}
      makeAction('ProxyA', color: '#00cc66')
    )
    expect(h.titleCalls.length).to.equal(2)
    expect(h.titleCalls[1].title).to.contain(
      'ProxyA (img.example.org), ProxyZ'
    )

    # Alternating requests between both proxies must NOT rewrite title again
    h.advance(200)
    t.recordRequest(
      {tabId: 9, type: 'xmlhttprequest', url: 'https://c.example.net/3'}
      makeAction('ProxyZ', color: '#ffcc00')
    )
    h.advance(200)
    t.recordRequest(
      {tabId: 9, type: 'image', url: 'https://z.example.org/2.jpg'}
      makeAction('ProxyA', color: '#00cc66')
    )
    h.advance(450)
    h.tickIntervals()
    expect(h.titleCalls.length).to.equal(2)
