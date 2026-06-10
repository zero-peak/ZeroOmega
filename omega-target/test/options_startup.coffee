chai = require 'chai'
should = chai.should()
sinon = require 'sinon'
chai.use require('sinon-chai')
Promise = require 'bluebird'

# Regression tests for issue #276:
# "On a Chrome cold start the extension very often shows only the icon, the
#  popup won't load and clicking does nothing, so the proxy is unusable."
#
# Root cause: on a service-worker cold start a storage read (the IndexedDB
# backed `state`) can stall indefinitely. Options#init awaits that read
# BEFORE it applies a profile, so when the read never resolves:
#   * options.ready never resolves -> the popup's getState never gets a
#     reply -> the popup stays blank ("only an icon"), and
#   * applyProfile is never called -> chrome.proxy.settings is never set ->
#     the whole proxy is dead,
# until the extension is manually reloaded.
#
# These tests simulate the stalling state read deterministically (no browser,
# no network, no credentials needed) and assert that startup still recovers.
describe 'Options startup resilience (issue #276)', ->
  Options = require '../src/options'
  Storage = require '../src/storage'
  Log = require '../src/log'
  defaultOptions = require '../src/default_options'

  before ->
    sinon.stub(Log, 'log')
    sinon.stub(Log, 'error')
  after ->
    Log.log.restore()
    Log.error.restore()

  makeProxyImpl = ->
    applyProfile: sinon.spy(-> Promise.resolve())
    watchProxyChange: ->
    setProxyAuth: -> Promise.resolve()
    features: []

  # A `state` whose reads never resolve, simulating IndexedDB stalling during
  # a service-worker cold start. Writes resolve so they don't mask the read.
  makeHangingState = ->
    get: -> new Promise(-> )    # never resolves
    set: -> Promise.resolve({})
    remove: -> Promise.resolve()
    watch: -> (-> )
    apply: -> Promise.resolve()

  # A `state` that behaves normally (reads resolve with defaults).
  makeWorkingState = ->
    state = makeHangingState()
    state.get = (keys) ->
      if keys? and typeof keys == 'object' and not Array.isArray(keys)
        Promise.resolve(keys)
      else
        Promise.resolve({})
    state

  buildOptions = (state) ->
    storage = new Storage()
    # The local profile storage (chrome.storage.local) loads fine; only the
    # IndexedDB-backed `state` stalls.
    storage.set(defaultOptions())
    options = new Options(storage, state, Log, null, makeProxyImpl())
    # Keep the test fast: a real cold start would use a multi-second timeout.
    options.startupTimeout = 200
    # _watch pulls in csso / quick-switch / inspect machinery that needs the
    # extension environment; it is irrelevant to startup control flow here.
    sinon.stub(options, '_watch').returns(-> )
    # Short-circuit applyProfile so we test init's control flow, not the proxy
    # plumbing. We only care THAT a profile gets applied.
    sinon.stub(options, 'applyProfile').returns(Promise.resolve())
    options

  it 'applies a profile and settles ready even when a state read stalls', ->
    options = buildOptions(makeHangingState())
    options.initWithOptions(null, -> false)
    return options.ready.timeout(2000).then ->
      options.applyProfile.should.have.been.called

  it 'still applies a profile normally when state reads succeed', ->
    options = buildOptions(makeWorkingState())
    options.initWithOptions(null, -> false)
    return options.ready.timeout(2000).then ->
      options.applyProfile.should.have.been.called
