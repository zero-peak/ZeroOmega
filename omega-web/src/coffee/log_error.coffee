# Keep room for the popup state, which shares localStorage with error logs.
MAX_ERROR_LOG_LENGTH = 64 * 1024

appendErrorLog = (entry = '') ->
  try
    storage = globalThis.localStorage
    return unless storage
    oldLog = storage['log'] || ''
    log = (oldLog + entry).slice(-MAX_ERROR_LOG_LENGTH)
    storage['log'] = log if log != oldLog
  catch _
    # A full or unavailable store must not make the error handler throw.
    try
      storage['log'] = entry.slice(-MAX_ERROR_LOG_LENGTH) if storage
    catch _
      return
  return

# Recover space even when an earlier version left a large log behind.
appendErrorLog()

window.onerror = (message, url, line, col, err) ->
  entry = "#{url}:#{line}:#{col}:\t#{message}\n"
  if err?.stack
    entry += err.stack + '\n'
  appendErrorLog(entry + '\n')
  return
