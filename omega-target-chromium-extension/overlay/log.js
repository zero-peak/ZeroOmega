const ZeroLogFactory = ()=>{
  const logStore = idbKeyval.createStore('log-store', 'log-store');

  const logSequence = []
  let isRunning = false
  let splitStr = '\n----Z-e-r-o-O-m-e-g-a--------------\n'

  const originConsoleLog = console.log
  const originConsoleError = console.error

  const _logFn = async function(){
    if (isRunning) return
    isRunning = true
    const _moment = moment()

    const dayOfWeek = _moment.format('E') // Day of Week (ISO),  keep logs max 7 day
    const monthNum = _moment.format('DD')
    const logKey = 'zerolog-' + dayOfWeek
    while (logSequence.length > 0) {
      const str = logSequence.join('\n');
      logSequence.length = 0;
      let logInfo = await idbKeyval.get(logKey, logStore)
      let date = _moment.format('YYYY-MM-DD')
      if (!logInfo || !logInfo.date) {
        logInfo = { date: date, val: ''}
      }
      let { val } = logInfo
      if ( logInfo.date != date) {
        val = ''
      }
      val += splitStr
      splitStr = `\n`
      val += str
      await idbKeyval.set(logKey, { date, val }, logStore)
    }
    isRunning = false
  }


  const logFn = (str)=>{
    logSequence.push(moment().format('YYYY-MM-DD HH:mm:ss   ') + ` ` + str)
    _logFn()
  }

  const replacerFn = (key, value)=>{
    switch (key) {
      case 'username':
      case 'password':
      case 'host':
      case 'port':
      case 'token':
      case 'gistToken':
      case 'gistId':
        return '<secret>'
      default:
        return value
    }
  }

  const getStr = function (){
    const strArgs = [...arguments].map((obj)=>{
      let str = '';
      try {
        if (typeof obj == 'string') {
          str = obj
        } else {
          str = JSON.stringify(obj, replacerFn, 4)
        }
      } catch(e){
        try {
          str = obj.toString()
        } catch(e){
        }
      }
      return str
    })
    return strArgs.join(' ')
  }

  const ZeroLog = function(){
    logFn(getStr.apply(null, arguments))
  }

  const _lastErrorLogFn = async ()=>{
    if (_lastErrorLogFn.isRunning) return
    _lastErrorLogFn.isRunning = true
    while (_lastErrorLogFn.val) {
      const val = _lastErrorLogFn.val
      _lastErrorLogFn.val = ''
      await idbKeyval.set('lastError', val, logStore)
    }
    _lastErrorLogFn.isRunning = false
  }

  const lastErrorLogFn = async function (){
    const val = getStr.apply(null, arguments)
    _lastErrorLogFn.val = val
    _lastErrorLogFn()
  }

  const ZeroLogInfo = function() {
    originConsoleLog.apply(null, arguments)
    ZeroLog.apply(null, ['[INFO]', ...arguments])
  }
  const ZeroLogError = function(){
    originConsoleError.apply(null, arguments)
    ZeroLog.apply(null, ['[ERROR]', ...arguments])
    lastErrorLogFn.apply(null, arguments)
  }

  const ZeroLogClear = async function(){
    await idbKeyval.clear(logStore)
  }

  console.log = ZeroLogInfo
  console.error = ZeroLogError
}

export default ZeroLogFactory
