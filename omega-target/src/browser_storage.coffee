Storage = require('./storage')
Promise = require('bluebird')

_globalLocalStorageCache = null

class BrowserStorage extends Storage
  constructor: (@storage, @prefix = '') ->
    @proto = Object.getPrototypeOf(@storage)

  get: (keys) ->
    promiseResult = idbKeyval.get('localStorage').then((initValuesMap) =>
      if !_globalLocalStorageCache
        @proto.initValuesMap?(initValuesMap)
        _globalLocalStorageCache = true
      map = {}
      if typeof keys == 'string'
        map[keys] = undefined
      else if Array.isArray(keys)
        for key in keys
          map[key] = undefined
      else if typeof keys == 'object'
        map = keys
      for own key of map
        try
          value = JSON.parse(@proto.getItem.call(@storage, @prefix + key))
        map[key] = value if value?
        if typeof map[key] == 'undefined'
          delete map[key]
      return map
    )
    Promise.resolve promiseResult

  set: (items) ->
    promiseResult = idbKeyval.get('localStorage').then((initValuesMap) =>
      if !_globalLocalStorageCache
        @proto.initValuesMap?(initValuesMap)
        _globalLocalStorageCache = true
      for own key, value of items
        value = JSON.stringify(value)
        @proto.setItem.call(@storage, @prefix + key, value)
      return new Promise( (resolve) ->
        # firefox localStorage need real async
        setTimeout( ->
          resolve(items)
        , 1)
      )
    ).then((items) =>
      return items unless @proto.getValuesMap
      initValuesMap = @proto.getValuesMap()
      idbKeyval.set('localStorage', initValuesMap).then( ->
        return items
      )
    )
    Promise.resolve promiseResult

  remove: (keys) ->
    promiseResult = idbKeyval.get('localStorage').then((initValuesMap) =>
      if !_globalLocalStorageCache
        @proto.initValuesMap?(initValuesMap)
        _globalLocalStorageCache = true
      if not keys?
        if not @prefix
          @proto.clear.call(@storage)
        else
          index = 0
          while true
            key = @proto.key.call(@storage, index)
            break if key == null
            if key.substr(0, @prefix.length) == @prefix
              @proto.removeItem.call(@storage, @prefix + keys)
            else
              index++
      if typeof keys == 'string'
        @proto.removeItem.call(@storage, @prefix + keys)
      for key in keys
        @proto.removeItem.call(@storage, @prefix + key)

    ).then( ->
      return new Promise((resolve) ->
        # firefox localStorage need real async
        setTimeout( ->
          resolve()
        , 1)
      )
    ).then( =>
      return unless @proto.getValuesMap
      initValuesMap = @proto.getValuesMap()
      idbKeyval.set('localStorage', initValuesMap).then( ->
        return
      )
    )
    Promise.resolve promiseResult

module.exports = BrowserStorage
