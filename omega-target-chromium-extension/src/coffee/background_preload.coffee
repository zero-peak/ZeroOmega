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
    id: 'network'
    title: 'Network monitor'
    contexts: ["action"]
  })
  chrome.contextMenus.create({
    id: 'tempRulesManager'
    title: 'Temp Rules Manager'
    contexts: ["action"]
  })
  chrome.contextMenus.create({
    id: 'reportIssue'
    title: chrome.i18n.getMessage('popup_reportIssues')
    contexts: ["action"]
  })
  chrome.contextMenus.create({
    id: 'reload'
    title: chrome.i18n.getMessage('popup_Reload')
    contexts: ["action"]
  })
  if !!globalThis.localStorage
    chrome.contextMenus.create({
      id: 'options'
      title: chrome.i18n.getMessage('popup_showOptions')
      contexts: ["action"]
    })

initContextMenu()

chrome.contextMenus?.onClicked.addListener((info, tab) ->
  switch info.menuItemId
    when 'network'
      url = chrome.runtime.getURL('popup/network/index.html?tabId=') + tab.id
      chrome.tabs.create({url: url})
    when 'tempRulesManager'
      url = chrome.runtime.getURL('popup/temp_rules/index.html')
      tab = chrome.tabs.query url: url, (tabs) ->
        if tabs.length > 0
          props = {active: true}
          chrome.tabs.update(tabs[0].id, props)
        else
          chrome.tabs.create({url: url})
    when 'options'
      browser.runtime.openOptionsPage()
    when 'reload'
      chrome.runtime.reload()
    when 'reportIssue'
      OmegaDebug.reportIssue()
)
