if not globalThis.window
  globalThis.window = globalThis
  globalThis.global = globalThis
window.UglifyJS_NoUnsafeEval = true
globalThis.zeroDetectModeCB = null
globalThis.startupCheck = undefined

initContextMenu = ->
  return unless chrome.contextMenus
  chrome.contextMenus.removeAll()
  chrome.contextMenus.create({
    id: 'enableQuickSwitch'
    title: chrome.i18n.getMessage('contextMenu_enableQuickSwitch')
    type: 'checkbox'
    checked: false
    contexts: ["action"]
  })

  chrome.contextMenus.create({
    id: 'reportIssue'
    title: chrome.i18n.getMessage('popup_reportIssues')
    contexts: ["action"]
  })
  chrome.contextMenus.create({
    id: 'reload'
    title: 'Reload'
    contexts: ["action"]
  })

initContextMenu()

chrome.contextMenus?.onClicked.addListener((info, tab) ->
  switch info.menuItemId
    when 'reload'
      chrome.runtime.reload()
    when 'reportIssue'
      OmegaDebug.reportIssue()
)
