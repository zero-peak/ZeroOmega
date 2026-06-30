chai = require 'chai'
should = chai.should()

OmegaTarget = require 'omega-target'
Promise = OmegaTarget.Promise
SettingsProxyImpl =
  require '../src/module/proxy/proxy_impl_settings'

describe 'SettingsProxyImpl', ->
  beforeEach ->
    @originalChrome = global.chrome
    @originalFetch = global.fetch
    global.chrome =
      runtime: {}
      proxy:
        settings:
          set: (details, callback) -> callback()
          get: -> null
    global.fetch = -> Promise.reject(new Error('skip network'))

  afterEach ->
    global.chrome = @originalChrome
    global.fetch = @originalFetch

  it 'should not leak auth preflight rules into the applied profile', (done) ->
    impl = new SettingsProxyImpl(error: -> null)
    profile =
      name: 'auto'
      profileType: 'SwitchProfile'
      revision: '1'
      defaultProfileName: 'direct'
      rules: [
        {
          condition:
            conditionType: 'HostWildcardCondition'
            pattern: '*.example.com'
          profileName: 'proxy'
        }
      ]
    authProfile =
      name: 'proxy'
      profileType: 'FixedProfile'
      revision: '1'
      fallbackProxy:
        scheme: 'http'
        host: '127.0.0.1'
        port: 8080
      auth:
        all:
          username: 'u'
          password: 'p'
    options =
      '+auto': profile
      '+proxy': authProfile

    pacProfile = null
    impl.setProxyAuth = -> Promise.resolve()
    impl.getProfilePacScript = (profileForPac, meta) ->
      pacProfile = profileForPac
      meta.should.equal(profile)
      return 'function FindProxyForURL(){return "DIRECT";}'

    impl.applyProfile(profile, profile, options).then( ->
      profile.rules.length.should.equal(1)
      should.not.exist profile.rules[0].isPreflightRule
      pacProfile.should.not.equal(profile)
      pacProfile.rules.length.should.equal(2)
      pacProfile.rules[0].isPreflightRule.should.equal(true)
      pacProfile.rules[1].should.eql(profile.rules[0])
      done()
    ).catch(done)
