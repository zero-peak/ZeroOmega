window.onerror = (message, url, line, col, err) ->
  console.log('globalThis onerror', arguments)
  log = localStorage['log'] || ''
  if err?.stack
    log += err.stack + '\n\n'
  else
    log += "#{url}:#{line}:#{col}:\t#{message}\n\n"
  localStorage['log'] = log
  return
