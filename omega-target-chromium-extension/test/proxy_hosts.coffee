chai = require 'chai'
should = chai.should()

describe 'Proxy host normalization', ->
  SettingsProxyImpl =
    require '../src/module/proxy/proxy_impl_settings'
  ListenerProxyImpl =
    require '../src/module/proxy/proxy_impl_listener'
  FirefoxProxyImpl =
    require '../src/module/proxy/proxy_impl_firefox'
  ProxyAuth = require '../src/module/proxy/proxy_auth'

  idnHost = '\u30b7.\u30b7'
  idnHostAscii = 'xn--xck.xn--xck'
  idnFallbackHost = 'b\u00fccher.example'
  idnFallbackHostAscii = 'xn--bcher-kva.example'

  it 'should normalize fixed server proxy hosts without mutating profiles', ->
    log =
      error: -> null
    impl = new SettingsProxyImpl(log)
    profile =
      profileType: 'FixedProfile'
      bypassList: []
      proxyForHttp:
        scheme: 'http'
        host: idnHost
        port: 8080
      fallbackProxy:
        scheme: 'socks5'
        host: idnFallbackHost
        port: 1080

    config = impl._fixedProfileConfig(profile)

    config.rules.proxyForHttp.host.should.equal(idnHostAscii)
    config.rules.fallbackProxy.host.should.equal(idnFallbackHostAscii)
    profile.proxyForHttp.host.should.equal(idnHost)
    profile.fallbackProxy.host.should.equal(idnFallbackHost)

  it 'should normalize listener proxy info hosts', ->
    proxy =
      scheme: 'https'
      host: idnHost
      port: 8443

    ListenerProxyImpl::proxyInfo(proxy)[0].host.should.equal(idnHostAscii)
    FirefoxProxyImpl::proxyInfo(proxy)[0].host.should.equal(idnHostAscii)

  it 'should normalize proxy auth lookup keys', ->
    log =
      error: -> null
      log: -> null
    auth = new ProxyAuth(log)
    key = auth._keyForProxy(host: idnHost, port: 3128)

    key.should.equal(idnHostAscii + ':3128')
