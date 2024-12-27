OmegaTarget = require('omega-target')
Promise = OmegaTarget.Promise


onChangedListenerInstalled = false
isPulling = false
isPushing = false

state = null
optionsSync = null

mainLetters = ['Z','e', 'r', 'o', 'O', 'm','e', 'g', 'a']
optionFilename = mainLetters.concat(['.json']).join('')
gistId = ''
gistToken = ''
gistHost = 'https://api.github.com'

processCheckCommit = ->
  getLastCommit(gistId).then((remoteCommit) ->
    state.set({
      'lastGistSync': Date.now()
    }).then(->
      state.get({'lastGistCommit': '-2'}).then(({ lastGistCommit }) ->
        return lastGistCommit isnt remoteCommit
      )
    )
  ).catch( ->
    return true
  )

processPull = (syncStore) ->
  return new Promise((resolve, reject) ->
    getGist(gistId).then((gist) ->
      if isPushing
        resolve({changes: {}})
      else
        changes = {}
        getAll(syncStore).then((data) ->
          try
            optionsStr = gist.files[optionFilename]?.content
            options = JSON.parse(optionsStr)
            for own key, val of data
              changes[key] = {
                oldValue: val
              }
            for own key, val of options
              target = changes[key]
              unless target
                changes[key] = {}
                target = changes[key]
              target.newValue = val
            for own key,val of changes
              if JSON.stringify(val.oldValue) is JSON.stringify(val.newValue)
                delete changes[key]
          catch e
            changes = {}
          state?.set({
            'lastGistCommit': gist.history[0]?.version
            'lastGistState': 'success'
            'lastGistSync': Date.now()
          })
          resolve({
            changes: changes,
            remoteOptions: options
          })
        )
    ).catch((e) ->
      state?.set({
        'lastGistSync': Date.now()
        'lastGistState': 'fail: ' + e
      })
      resolve({changes: {}})
    )
  )
getAll = (syncStore) ->
  idbKeyval.entries(syncStore).then((entries) ->
    data = {}
    entries.forEach((entry) ->
      data[entry[0]] = entry[1]
    )
    return data
  )

_processPush = ->
  if processPush.sequence.length > 0
    #    syncStore = processPush.sequence.shift()
    syncStore = processPush.sequence[processPush.sequence.length - 1]
    processPush.sequence.length = 0
    getAll(syncStore).then((data) ->
      updateGist(gistId, data)
    ).then( ->
      _processPush()
    )
  else
    isPushing = false

processPush = (syncStore) ->
  processPush.sequence.push(syncStore)
  return if isPushing
  isPushing = true
  setTimeout(_processPush, 600) # use timeout to merge push

processPush.sequence = []

getLastCommit = (gistId) ->
  fetch(gistHost + '/gists/' + gistId + '/commits?per_page=1', {
    headers: {
      "Accept": "application/vnd.github+json"
      "Authorization": "Bearer " + gistToken
      "X-GitHub-Api-Version": "2022-11-28"
    }
  }).then((res) -> res.json()).then((data) ->
    if data.message
      throw data.message
    return data[0]?.version
  )



getGist = (gistId) ->
#curl -L \
#  -H "Accept: application/vnd.github+json" \
#  -H "Authorization: Bearer <YOUR-TOKEN>" \
#  -H "X-GitHub-Api-Version: 2022-11-28" \
#  https://api.github.com/gists/GIST_ID
  fetch(gistHost + '/gists/' + gistId, {
    headers: {
      "Accept": "application/vnd.github+json"
      "Authorization": "Bearer " + gistToken
      "X-GitHub-Api-Version": "2022-11-28"
    }
  }).then((res) -> res.json()).then((data) ->
    if data.message
      throw data.message
    return data
  )

updateGist = (gistId, options) ->
  postBody = {
    description: mainLetters.concat([' Sync']).join('')
    files: {}
  }
  postBody.files[optionFilename] = {
    content: JSON.stringify(options, null, 4)
  }
  fetch(gistHost + '/gists/' + gistId, {
    headers: {
      "Accept": "application/vnd.github+json"
      "Authorization": "Bearer " + gistToken
      "X-GitHub-Api-Version": "2022-11-28"
    }
    "method": "PATCH"
    body: JSON.stringify(postBody)
  }).then((res) ->
    res.json()
  ).then((data) ->
    if data.status is "404"
      throw new Error("The token with Gist permission is required.")
    if data.message
      throw data.message
    lastGistCommit = data.history[0]?.version
    state?.set({
      'lastGistCommit': lastGistCommit
      'lastGistState': 'success'
      'lastGistSync': Date.now()
    }).then( ->
      optionsSync?.updateBuiltInSyncConfigIf({
        lastGistCommit
      })
    )
    return data
  ).catch((e) ->
    state?.set({
      'lastGistState': 'fail: ' + e
      'lastGistSync': Date.now()
    })
    console.error('update gist fail::', e)
  )
 

class ChromeSyncStorage extends OmegaTarget.Storage
  @parseStorageErrors: (err) ->
    return Promise.reject(err)

  constructor: (@areaName, _state) ->
    state = _state
    syncStore = idbKeyval.createStore('sync-store',  'sync')
    @syncStore = syncStore
    get = (key) ->
      return new Promise((resolve, reject) ->
        getAll(syncStore).then((data) ->
          result = {}
          if Array.isArray(key)
            key.forEach( _key ->
              result[_key] = data[_key]
            )
          else if key is null
            result = data
          else
            result[key] = data[key]
          resolve(result)
        )
      )
    set = (record) ->
      return new Promise((resolve, reject) ->
        try
          if !record or typeof record isnt 'object' or Array.isArray(record)
            throw new SyntaxError(
              'Only Object with key value pairs are acceptable')
          entries = []
          for own key, value of record
            entries.push([key, value])
          idbKeyval.setMany(entries, syncStore).then( ->
            processPush(syncStore)
            resolve(record)
          )
        catch e
          reject(e)
      )
    _remove = (key) ->
      if Array.isArray(key)
        Promise.resolve(idbKeyval.delMany(key, syncStore))
      else
        Promise.resolve(idbKeyval.del(key, syncStore))
    remove = (key) ->
      Promise.resolve(_remove(key).then( ->
        processPush(syncStore)
        return
      ))
    clear = ->
      Promise.resolve(idbKeyval.clear(syncStore).then(->
        processPush(syncStore)
        return
      ))
    @storage =
      get: get
      set: set
      remove: remove
      clear: clear
  get: (keys) ->
    keys ?= null
    Promise.resolve(@storage.get(keys))
      .catch(ChromeSyncStorage.parseStorageErrors)

  set: (items) ->
    if Object.keys(items).length == 0
      return Promise.resolve({})
    Promise.resolve(@storage.set(items))
      .catch(ChromeSyncStorage.parseStorageErrors)

  remove: (keys) ->
    if not keys?
      return Promise.resolve(@storage.clear())
    if Array.isArray(keys) and keys.length == 0
      return Promise.resolve({})
    Promise.resolve(@storage.remove(keys))
      .catch(ChromeSyncStorage.parseStorageErrors)
  destroy: ->
    idbKeyval.clear(@syncStore)
  flush: ({data}) ->
    entries = []
    result = null
    if data and data.schemaVersion
      for own key, value of data
        entries.push([key, value])
      result = idbKeyval.setMany(entries, @syncStore)
    Promise.resolve(result)

  ##
  # param(withRemoteData) retrive gist file content
  ##
  init: (args) ->
    optionsSync = args.optionsSync
    state = args.state
    gistId = args.gistId || ''
    if gistId.indexOf('/') >= 0
      # get gistId from url `https://gist.github.com/{username}/{gistId}`
      gistId = gistId.replace(/\/+$/, '')
      gistId = gistId.split('/')
      gistId = gistId[gistId.length - 1]
    gistToken = args.gistToken
    return new Promise((resolve, reject) ->
      getLastCommit(gistId).then( (lastGistCommit) ->
        if args.withRemoteData
          getGist(gistId).then((gist) ->
            try
              optionsStr = gist.files[optionFilename].content
              options = JSON.parse(optionsStr)
              resolve({options, lastGistCommit})
            catch e
              resolve({})
          )
        else
          resolve({})
      ).catch((e) ->
        reject(e)
      )
    )

  ##
  # param (opts) opts.immediately , immediately update changed
  # param (opts) opts.force, force get remote content
  ##
  checkChange: (opts = {}) ->
    isPulling = true
    processCheckCommit().then((isChanged) =>
      if isChanged or opts.force
        processPull(@syncStore).then(({changes, remoteOptions}) =>
          @flush({data: remoteOptions}).then( =>
            isPulling = false
            ChromeSyncStorage.onChangedListener(changes, @areaName, opts)
          )
        )
      else
        console.log('no changed')
        isPulling = false
    )

  watch: (keys, callback) ->
    chrome.alarms.create('omega.syncCheck', {
      periodInMinutes: 5
    })
    ChromeSyncStorage.watchers[@areaName] ?= {}
    area = ChromeSyncStorage.watchers[@areaName]
    watcher = {keys: keys, callback: callback}
    enableSync = true
    id = Date.now().toString()
    while area[id]
      id = Date.now().toString()

    if Array.isArray(keys)
      keyMap = {}
      for key in keys
        keyMap[key] = true
      keys = keyMap
    area[id] = {keys: keys, callback: callback}
    if not onChangedListenerInstalled
      # chrome alerm
      @checkChange()
      chrome.alarms.onAlarm.addListener (alarm) =>
        return unless enableSync
        return if isPulling
        switch alarm.name
          when 'omega.syncCheck'
            @checkChange()
      #chrome.storage.onChanged.addListener(ChromeSyncStorage.onChangedListener)
      onChangedListenerInstalled = true
    return ->
      enableSync = false
      delete area[id]

  ##
  # param (opts) opts.immediately , immediately update changed
  ##
  @onChangedListener: (changes, areaName, opts = {}) ->
    map = null
    for _, watcher of ChromeSyncStorage.watchers[areaName]
      match = watcher.keys == null
      if not match
        for own key of changes
          if watcher.keys[key]
            match = true
            break
      if match
        if not map?
          map = {}
          for own key, change of changes
            map[key] = change.newValue
        watcher.callback(map, opts)

  @watchers: {}

module.exports = ChromeSyncStorage
