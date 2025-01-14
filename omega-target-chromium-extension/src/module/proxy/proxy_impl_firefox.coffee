OmegaTarget = require('omega-target')
# The browser only accepts native promises as onRequest return values.
# DO NOT USE Bluebird Promises here!
NativePromise = Promise ? null
ProxyImpl = require('./proxy_impl')

blobUrl = null

class FirefoxProxyImpl extends ProxyImpl
  @isSupported: ->
    # chrome.contextMenus check is Android or PC,
    # browser.proxy.settings doesn't support on Firefox Android
    return  !!chrome.contextMenus and
    Promise? and
    browser?.proxy?.onRequest? and
    browser?.proxy?.settings
  features: ['fullUrl', 'socks5Auth']
  constructor: ->
    super(arguments...)
    @_optionsReady = new NativePromise (resolve) =>
      @_optionsReadyCallback = resolve
    # We want to register listeners early so that it can start blocking requests
    # when starting the browser & extension, returning correct results later.
    @_initRequestListeners()
  _initRequestListeners: ->
    browser.proxy.onRequest.addListener(@onRequest.bind(this),
      {urls: ["<all_urls>"]})
    browser.proxy.onError.addListener(@onError.bind(this))
  watchProxyChange: (callback) -> null
  applyProfile: (profile, state, options) ->
    if blobUrl
      URL.revokeObjectURL(blobUrl)
    if browser.extension.isAllowedIncognitoAccess()
      if profile.profileType is 'DirectProfile'
        browser.proxy.settings.set({
          value: {
            proxyType: 'none'
          }
        })
      else if profile.profileType is 'SystemProfile'
        # Clear proxy settings, returning proxy control to Firefox.
        browser.proxy.settings.clear({})
      else
        pacScript = @getProfilePacScript(profile, state, options)
        blob = new Blob(
          [pacScript],
          { type: 'application/x-ns-proxy-autoconfig' })
        blobUrl = URL.createObjectURL(blob)
        browser.proxy.settings.set({
          value: {
            proxyDNS: true,
            proxyType: 'autoConfig',
            autoConfigUrl: blobUrl
          }
        })
    @_options = options
    @_profile = profile
    @_optionsReadyCallback?()
    @_optionsReadyCallback = null
    return @setProxyAuth(profile, options)
  onRequest: (requestDetails) ->
    #return undefined if browser.extension.isAllowedIncognitoAccess()
    # TODO 将来可以在这里实现按标签进行代理控制功能
    #return undefined
    # The browser only recognizes native promises return values, not Bluebird.
    return NativePromise.resolve(@_optionsReady.then(=>
      request = OmegaPac.Conditions.requestFromUrl(requestDetails.url)
      profile = @_profile
      while profile
        result = OmegaPac.Profiles.match(profile, request)
        if not result
          switch profile.profileType
            when 'DirectProfile'
              return {type: 'direct'}
            when 'SystemProfile', 'PacProfile'
              # Returning undefined means using the default proxy from previous.
              # https://hg.mozilla.org/mozilla-central/rev/9f0ee2f582a2#l1.337
              return undefined
            else
              throw new Error('Unsupported profile: ' + profile.profileType)
        if Array.isArray(result)
          proxy = result[2]
          auth = result[3]
          return @proxyInfo(proxy, auth) if proxy
          next = result[0]
        else if result.profileName
          next = OmegaPac.Profiles.nameAsKey(result.profileName)
        else
          break
        profile = OmegaPac.Profiles.byKey(next, @_options)

      throw new Error('Profile not found: ' + next)
    ))
  onError: (error) ->
    @log.error(error)
  proxyInfo: (proxy, auth) ->
    proxyInfo =
      type: proxy.scheme
      host: proxy.host
      port: proxy.port
    if proxyInfo.type == 'socks5'
      # MOZ: SOCKS5 proxies should be specified as "type": "socks".
      # https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/proxy/ProxyInfo
      proxyInfo.type = 'socks'
      if auth
        # Username & password here are only available for SOCKS5.
        # https://developer.mozilla.org/en-US/Add-ons/WebExtensions/API/proxy/ProxyInfo
        # HTTP proxy auth must be handled via webRequest.onAuthRequired.
        proxyInfo.username = auth.username
        proxyInfo.password = auth.password
    if proxyInfo.type == 'socks'
      # Enable SOCKS remote DNS.
      # TODO(catus): Maybe allow the users to configure this?
      proxyInfo.proxyDNS = true

    # TODO(catus): Maybe allow proxyDNS for socks4? Server may support SOCKS4a.
    # It cannot default to true though, since SOCKS4 servers that does not have
    # the SOCKS4a extension may simply refuse to work.

    return [proxyInfo]

module.exports = FirefoxProxyImpl
