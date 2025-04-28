import { escapeHTML } from './utils.js'

let tabInfo = {}
let selfTabId = null;




chrome.tabs.onCreated.addListener((tab) =>{
  if (!tab.id) return;
  tabInfo[tab.id] = tab
  updateTabSelectorOptions()
})
chrome.tabs.onRemoved.addListener((tabId) =>{
  delete tabInfo[tabId]
  updateTabSelectorOptions()
})
chrome.tabs.onReplaced?.addListener((added, removed) =>{
  tabInfo[added] = {}
  delete tabInfo[removed]
  updateTabSelectorOptions()
})

chrome.tabs.onUpdated.addListener((tabId, changeInfo, tab)=>{
  if (!tabInfo[tab.id]) {
    tabInfo[tab.id] = {}
  }
  const info = tabInfo[tab.id]
  info.windowId = tab.windowId;
  if (info.title !== tab.title) {
    info.title = tab.title;
    info.url = tab.url;
    updateTabSelectorOptions()
  }
})

const initTabInfo = async ()=> {
  const tabs = await chrome.tabs.query({})
  tabs.forEach((tab)=>{
    if (!tab.id) return;
    tabInfo[tab.id] = tab;
  })
}

const updateTabSelectorOptions = (selectedKey)=>{
  document.querySelectorAll('.tab-selector').forEach((selectorEl)=>{
    selectedKey ||= selectorEl.value;
    const optionHtmls = [`<option value=''>(All)All tabs</option>`]
    if (selectedKey) {
      if (!tabInfo[selectedKey]) {
        const selectedEl = selectorEl.querySelector(`option[value="${selectedKey}"]`)
        if (selectedEl) {
          selectedEl.setAttribute('selected', 'selected');
          selectedEl.style.color = `var(--negativeColor, red)`;
          selectedEl.style.fontWeight = `bolder`;
          optionHtmls.push(selectedEl.outerHTML)
        }
      }
    }
    Object.values(tabInfo).forEach((_tab)=>{
      const selected = _tab.id == selectedKey ? 'selected' : ''
      optionHtmls.push(`<option value="${_tab.id}" ${selected}>(${_tab.id})${escapeHTML(_tab.title)}</option>`)
    })
    selectorEl.innerHTML = optionHtmls.join('');
    upateSelectedTabInfo(selectorEl);
  })
}

const upateSelectedTabInfo = (selectorEl)=>{
  const containerEl = selectorEl.parentElement;
  const tabId = selectorEl.value;
  if (tabId) {
    containerEl.classList.add('tab-selected')
    const tab = tabInfo[tabId]
    if (tab) {
      const tabTipEl = containerEl.querySelector('.tab-tip')
      if (tab.url) {
        try {
          const u = new URL(tab.url)
          tabTipEl.innerText = u.hostname;
        } catch(e){
          tabTipEl.innerText = ''
        }
      } else {
        tabTipEl.innerText = ``
      }
      containerEl.classList.remove('tab-closed')
    } else {
      containerEl.classList.add('tab-closed')
    }
  } else {
    containerEl.classList.remove('tab-selected', 'tab-closed')
  }
}

export const initTabsSelector = async (containerEl, opts={})=>{
  await initTabInfo();
  const selfTab = await chrome.tabs.getCurrent();
  selfTabId = selfTab.id;

  const sp = new URLSearchParams(document.location.search)
  const tabId = sp.get('tabId');

  const selectorEl = document.createElement('select')
  selectorEl.classList.add('tab-selector', 'form-control')
  selectorEl.onchange = (e)=>{
    upateSelectedTabInfo(selectorEl);
    opts.setTab?.(tabInfo[selectorEl.value]);
  }
  containerEl.append(selectorEl);

  const tabInfoContainerEl = document.createElement('span');
  tabInfoContainerEl.classList.add('tab-info-container')
  tabInfoContainerEl.innerHTML = `
  <span class="tab-closed-tip">(Closed)</span>
  <span class="btn-group tab-btns">
    <span class="btn btn-default btn-sm refresh-tab-btn">
      <span class="glyphicon glyphicon-refresh" aria-hidden="true"></span>
    </span>
    <span class="btn btn-default btn-sm view-tab-btn">
      <span class="glyphicon glyphicon-eye-open" aria-hidden="true"></span>
    </span>
  </span>
  <span class="tab-tip"></span>
  `
  containerEl.append(tabInfoContainerEl)
  tabInfoContainerEl.querySelector('.refresh-tab-btn').onclick = (e)=>{
    const selectedKey = selectorEl.value;
    if (selectedKey == selfTabId) return;
    const tab = tabInfo[selectedKey]
    if (tab) {
      chrome.tabs.reload(parseInt(selectedKey), {bypassCache: true})
    }
  }
  tabInfoContainerEl.querySelector('.view-tab-btn').onclick = (e)=>{
    const selectedKey = selectorEl.value;
    if (selectedKey == selfTabId) return;
    const tab = tabInfo[selectedKey]
    if (tab) {
      chrome.tabs.update(parseInt(selectedKey), {active: true})
      const selfTab = tabInfo[selfTabId];
      if (selfTab.windowId != tab.windowId) {
        chrome.windows.update(tab.windowId, {drawAttention: true, focused: true})
      }
    }
  }
  updateTabSelectorOptions(tabId);
  return {
    selfTabId,
    getSelectedTabId: ()=>{
      return selectorEl.value;
    }
  }
}
