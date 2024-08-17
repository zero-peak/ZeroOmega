if not globalThis.window
  globalThis.window = globalThis
  globalThis.global = globalThis
window.UglifyJS_NoUnsafeEval = true
globalThis.zeroDetectModeCB = null
globalThis.startupCheck = undefined

createContextMenu = ->
  chrome.contextMenus?.create({
    id: 'enableQuickSwitch'
    title: chrome.i18n.getMessage('contextMenu_enableQuickSwitch')
    type: 'checkbox'
    checked: false
    contexts: ["action"]
  })

chrome.runtime.onInstalled.addListener( ->
  # We don't need this API. However its presence indicates that Chrome >= 35
  # which provides info.checked we need in contextMenu callback.
  # https://developer.chrome.com/extensions/contextMenus
  if chrome.i18n.getUILanguage?
    createContextMenu()
)

if browser?.proxy?.onRequest?
  #firefox bug fix?
  createContextMenu()
