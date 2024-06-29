
logStore = idbKeyval.createStore('log-store', 'log-store')

isProcessing = false

window.OmegaDebug =
  getProjectVersion: ->
    chrome.runtime.getManifest().version
  getExtensionVersion: ->
    chrome.runtime.getManifest().version
  downloadLog: ->
    return if isProcessing
    isProcessing = true
    idbKeyval.entries(logStore).then((entries) ->
      zip = new JSZip()
      zipFolder = zip.folder('ZeroOmega')
      entries.forEach((entry) ->
        if entry[0] != 'lastError'
          zipFolder.file(entry[1].date + '.log', entry[1].val)
      )
      return zip.generateAsync({
        compression: "DEFLATE",
        compressionOptions: {
          level: 9
        },
        type: 'blob'
      })
    ).then((blob) ->
      filename = "ZeroOmegaLog_#{Date.now()}.zip"
      saveAs(blob, filename)
      isProcessing = false
    )
  resetOptions: ->
    return if isProcessing
    isProcessing = true
    Promise.all([
      idbKeyval.clear(logStore),
      chrome.storage.local.clear()
    ]).then( ->
      localStorage.clear()
      # Prevent options loading from sync storage after reload.
      localStorage['omega.local.syncOptions'] = '"conflict"'
      isProcessing = false
      chrome.runtime.reload()
    )
  reportIssue: ->
    return if isProcessing
    isProcessing = true
    idbKeyval.get('lastError', logStore).then((lastError) ->
      isProcessing = false
      url = 'https://github.com/suziwen/ZeroOmega/issues/new?title=&body='
      finalUrl = url
      try
        projectVersion = OmegaDebug.getProjectVersion()
        extensionVersion = OmegaDebug.getExtensionVersion()
        env =
          extensionVersion: extensionVersion
          projectVersion: extensionVersion
          userAgent: navigator.userAgent
        body = chrome.i18n.getMessage('popup_issueTemplate', [
          env.projectVersion, env.userAgent
        ])
        body ||= """
          \n\n
          <!-- Please write your comment ABOVE this line. -->
          SwitchyOmega #{env.projectVersion}
          #{env.userAgent}
        """
        finalUrl = url + encodeURIComponent(body)
        err = lastError or ''
        if err
          body += "\n```\n#{err}\n```"
          finalUrl = (url + encodeURIComponent(body)).substr(0, 2000)

      chrome.tabs.create(url: finalUrl)
    )
