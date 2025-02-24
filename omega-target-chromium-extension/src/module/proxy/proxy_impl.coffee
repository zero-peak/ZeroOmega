OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise
ProxyAuth = require('./proxy_auth')


# TODO temp profile will always create new cache.
profilePacCache = new Map()

class ProxyImpl
  constructor: (log) ->
    @log = log
  @isSupported: -> false
  applyProfile: (profile, meta) -> Promise.reject()
  watchProxyChange: (callback) -> null
  parseExternalProfile: (details, options) -> null
  _profileNotFound: (name) ->
    @log.error("Profile #{name} not found! Things may go very, very wrong.")
    return OmegaPac.Profiles.create({
      name: name
      profileType: 'VirtualProfile'
      defaultProfileName: 'direct'
    })
  setProxyAuth: (profile, options) ->
    return Promise.try(=>
      @_proxyAuth ?= new ProxyAuth(@log)
      @_proxyAuth.listen()
      referenced_profiles = []
      ref_set = OmegaPac.Profiles.allReferenceSet(profile,
        options, profileNotFound: @_profileNotFound.bind(this))
      for own _, name of ref_set
        profile = OmegaPac.Profiles.byName(name, options)
        if profile
          referenced_profiles.push(profile)
      @_proxyAuth.setProxies(referenced_profiles)
    )
  getProfilePacScript: (profile, meta, options) ->
    meta ?= profile
    referenced_profiles = []
    ref_set = OmegaPac.Profiles.allReferenceSet(profile,
      options, profileNotFound: @_profileNotFound.bind(this))
    for own _, name of ref_set
      _profile = OmegaPac.Profiles.byName(name, options)
      if _profile
        referenced_profiles.push(_profile)
    cachedProfiles = Array.from(profilePacCache.keys())
    allProfiles = Object.values(options)
    cachedProfiles.forEach((cachedProfile) ->
      if allProfiles.indexOf(cachedProfile) < 0
        profilePacCache.delete(cachedProfile)
    )
    profilePac = profilePacCache.get(profile)
    profilePacKey = referenced_profiles.map(
      (_profile) ->
        revision = _profile.revision or 1
        # remote pacScript and rule list use sha256 to  ensue uniqueId
        if OmegaPac.Profiles.updateUrl(_profile) and _profile.sha256
          revision = _profile.sha256
        _profile.name + '_' + revision
    ).join(',')
    if profilePac?[profilePacKey]
      return profilePac[profilePacKey]
    ast = OmegaPac.PacGenerator.script(options, profile,
      profileNotFound: @_profileNotFound.bind(this))
    ast = OmegaPac.PacGenerator.compress(ast)
    script = OmegaPac.PacGenerator.ascii(ast.print_to_string())
    profileName = OmegaPac.PacGenerator.ascii(JSON.stringify(meta.name))
    profileName = profileName.replace(/\*/g, '\\u002a')
    profileName = profileName.replace(/\\/g, '\\u002f')
    prefix = "/*OmegaProfile*#{profileName}*#{meta.revision}*/"
    pacScript = prefix + script
    profilePac = {}
    profilePac[profilePacKey] = pacScript
    profilePacCache.set(profile, profilePac)
    return pacScript

module.exports = ProxyImpl
