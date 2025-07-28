import { waitTimeout, escapeHTML, copyToClipoard } from './utils.js'
import { initTabsSelector } from './tab.js'
import { initUrlCellDetail } from './url.js'
import Toastify from "../../../lib/zero-dependencies/toastify/toastify-es.js";
import { filesize} from "../../../lib/zero-dependencies/filesize/filesize.esm.js";
import {
  Tabulator,
  ColumnCalcsModule,
  TooltipModule,
  ValidateModule,
  EditModule,
  InteractionModule,
  FrozenColumnsModule,
  MenuModule,
  ResizeColumnsModule,
  SortModule,
  FilterModule,
  FormatModule,
  SelectRowModule,
  SelectRangeModule,
  KeybindingsModule,
} from "../../../lib/zero-dependencies/tabulator/tabulator_esm.js";
Tabulator.registerModule([
  ColumnCalcsModule,
  TooltipModule,
  ValidateModule,
  EditModule,
  MenuModule,
  InteractionModule,
  FrozenColumnsModule,
  ResizeColumnsModule,
  SortModule,
  FilterModule,
  FormatModule,
  SelectRowModule,
  SelectRangeModule,
  KeybindingsModule,
]);

const sortRequest = (a,b)=>{
  return parseInt(a.requestId) - parseInt(b.requestId)
}

const getHeaderValue = (headers, name)=>{
  const result = headers.find((header)=> header.name == name)
  return result?.value;
}

const MAXRECORDS = 1000

let recentlyRequestId = 0
let autoScrollToBottom = true

const scrollTabulatorToBottom = (tabulatorInstance)=>{
  const el = tabulatorInstance.rowManager.element
  el.scrollTop = el.scrollHeight;
}

const listenerScrollEvent = (tabulatorInstance)=>{
  const targetEl = tabulatorInstance.rowManager.element;
  let isMouseScroll = false
  let timeout = null

  targetEl.addEventListener('wheel', () => {
    if (timeout) {
      clearTimeout(timeout)
      timeout = null;
    }
    isMouseScroll = true;
    timeout = setTimeout(() => {
      isMouseScroll = false;
      timeout = null;
    }, 600);
  });

  tabulatorInstance.on("scrollVertical", function(top, topDir){
    if (!isMouseScroll) return;
    if (topDir) {
      autoScrollToBottom = false
      document.body.classList.add('disable-auto-scroll')
    } else {
      if (!autoScrollToBottom) {
        const maxTop = targetEl.scrollHeight - targetEl.clientHeight;
        if (maxTop - top < 30) {
          autoScrollToBottom = true;
          document.body.classList.remove('disable-auto-scroll')
        }
      }
    }
    //top - the current vertical scroll position
  });

}

const createTabulator = () => {
  const createFooterElement = () => {
    const footerEl = document.createElement("div");
    footerEl.className = "tabulator-footer";
    const footerContentsEl = document.createElement("div");
    footerContentsEl.className = "tabulator-footer-contents";
    footerEl.append(footerContentsEl);

    const tabsSelectorContainerEl = document.createElement('span')
    tabsSelectorContainerEl.classList.add('tabs-selector-container')
    footerContentsEl.append(tabsSelectorContainerEl)




    const paginatorEl = document.createElement("span");
    paginatorEl.className = "tabulator-paginator";
    footerContentsEl.append(paginatorEl);
    const paginatorBtnsEl = document.createElement("span")
    paginatorBtnsEl.classList.add('btn-group')

    const scrollToBottomBtnEl = document.createElement('button')
    scrollToBottomBtnEl.classList.add('btn', 'btn-default', 'btn-sm', 'scroll-to-bottom-btn')
    scrollToBottomBtnEl.innerHTML = `
      <span class="glyphicon glyphicon-fast-forward" aria-hidden="true"></span>
    `
    scrollToBottomBtnEl.onclick = ()=>{
      autoScrollToBottom = true;
      document.body.classList.remove('disable-auto-scroll')
      scrollTabulatorToBottom(tabulatorInstance)
    }
    paginatorBtnsEl.append(scrollToBottomBtnEl)


    const clearBtnEl = document.createElement('button')
    clearBtnEl.classList.add('btn', 'btn-default', 'btn-sm');
    clearBtnEl.innerHTML = `
      <span class="glyphicon glyphicon-ban-circle" aria-hidden="true"></span>
    `
    clearBtnEl.onclick = async ()=> {
      tabulatorInstance.clearData();
      waitTimeout(600);
      autoScrollToBottom = true;
      document.body.classList.remove('disable-auto-scroll')
    }
    paginatorBtnsEl.append(clearBtnEl);
    paginatorEl.append(paginatorBtnsEl)
    return footerEl;
  };

  const tabulatorInstance = new Tabulator(".network-list-container", {
    height: "100%",
    //addRowPos: "top",
    //placeholder: "loading...",
    data: [],
    layout: "fitColumns",
    //layout: "fitData",
    index: "requestId",
    //renderVertical: 'basic',
    columnDefaults: {
      headerClick: (e, column)=>{
        const def = column.getDefinition()
        if (!def.headerSort) return;
        const sorters = tabulatorInstance.getSorters()
        const result = sorters.find((sorter)=> {
          if (sorter.column === column && sorter.dir === 'asc') {
            const currSort = sorter.field + '_' + sorter.dir
            if (tabulatorInstance.__prevSort === currSort) {
              tabulatorInstance.clearSort()
              tabulatorInstance.__prevSort = null
            } else {
              tabulatorInstance.__prevSort = currSort;
            }
            return true
          }
          return false
        })
      }
    },
    //layout:"fitDataFill",
    //layout:"fitDataStretch",
    selectableRows: true,
    selectableRowsRangeMode: "click",
    selectableRowsPersistence: true,
    //    selectableRange:true, //allow only one range at a time
    //    selectableRangeColumns:false,
    //    selectableRangeRows:true,
    //    selectableRangeClearCells:false,
    footerElement: createFooterElement(),
    resizableColumnGuide:true,
    columns: [
      //Define Table Columns
      {
        title: "ID",
        width: 100,
        field: "requestId"
      },
      {
        title: "🕛️",
        field: "statusInfo.start",
        width: 105,
        hozAlign: "center",
        headerHozAlign: "center",
        headerSort: true,
        formatter: (cell) => {
          const cellVal = cell.getValue();
          return `<time title="${moment(cellVal)
            .toDate()
            .toLocaleString()}">${moment(cellVal).format("HH:mm:ss")}</time>`;
        },
      },
      {
        title: '',
        field: "recentlyStatus",
        width: 50,
        hozAlign: "center",
        headerSort: false,
        headerFilter:"list",
        headerFilterParams: {
          values: {
            "all": "",
            "ongoing": "Ongoing",
            "done": "Done",
            "fail": "Fail"
          },
          elementAttributes:{
            class: "form-control"
          },
          clearable:true,
          itemFormatter:function(label, value, item, element){
            switch (value) {
              case "ongoing": {
                return "<i class='glyphicon glyphicon-circle-arrow-down'/> Ongoing";
              }
              case "done": {
                return "<i class='glyphicon glyphicon-ok-sign'/> Done";
              }
              case "fail": {
                return `<i class='glyphicon glyphicon-exclamation-sign'/> Fail`;
              }
              default:{
                return `<i class='glyphicon glyphicon-info-sign'/> All`;
              }
            }
          }
        },
        headerFilterFunc: function(headerValue, rowValue, rowData, filterParams){
          switch (headerValue){
            case "ongoing":{
              return ['start', 'ongoing'].indexOf(rowValue) >= 0
            }
            case "done":{
              return headerValue == rowValue
            }
            case "fail":{
              return ['error', 'timeout', 'timeoutAbort'].indexOf(rowValue) >= 0
            }
            default: {
              return true
            }
          }
        },
        formatter: (cell) => {
          const recentlyStatus = cell.getValue();
          const request = cell.getRow().getData();
          switch (recentlyStatus) {
            case "start": {
              return "<i class='glyphicon glyphicon-circle-arrow-down status-start' title='Request start'/>";
            }
            case "done": {
              return "<i class='glyphicon glyphicon-ok-sign status-done' title='Request done'/>";
            }
            case "timeout": {
              return "<i class='glyphicon glyphicon-question-sign status-timeout' title='Request timeout'/>";
            }
            case "timeoutAbort": {
              return "<i class='glyphicon glyphicon-exclamation-sign status-timeout-abort' title='Request timeout abort'/>";
            }
            case "error": {
              return `<i class='glyphicon glyphicon-exclamation-sign status-error' title='Request error: ${request.error || ''}'/>`;
            }
            case "ongoing": {
              return "<i class='glyphicon glyphicon-circle-arrow-down status-ongoing' title='Request ongoing'/>";
            }
          }
        },
      },
      {
        title: "Profile",
        field: "profileName",
        width: 300,
        headerFilter:"input",
        headerFilterParams: {
          elementAttributes:{
            class: "form-control"
          }
        },
        tooltip: (e, cell, onRendered)=>{
          const el = document.createElement('div')
          const request = cell.getRow().getData();
          const actionProfile = request.actionProfile || {}
          const detailTitle = actionProfile.title || actionProfile.shortTitle || ''
          el.innerText = detailTitle;
          return el;
        },
      },
      { title: "URL", field: "url", minWidth: 300, tooltip: true,
        cssClass: 'url-field',
        headerFilter:"input",
        headerFilterParams: {
          elementAttributes:{
            class: "form-control"
          }
        },
        formatter: (cell)=>{
          return `<span class="glyphicon glyphicon-duplicate copy-btn" aria-hidden="true"></span><span>${escapeHTML(decodeURI(cell.getValue()))}</span>`
        },
        cellClick: (e, cell)=>{
          if (e && e.target) {
            e.preventDefault();
            e.stopPropagation()
            if (e.target.classList.contains('copy-btn')) {
              copyToClipoard(cell.getValue()).then(()=>{
                Toastify({
                  text: "Copy success",
                  position: "center",
                }).showToast();
              })
              return
            }
          }
          initUrlCellDetail(cell);
        }
      },
      {
        title: "Time",
        field: "recentlyTimestamp",
        headerSort: false,
        width: 100,
        formatter: (cell) => {
          const recentlyStatus = cell.getValue();
          const request = cell.getRow().getData();
          const startTimestamp = request.statusInfo["start"];
          const recentlyTimestamp = request.statusInfo[recentlyStatus];
          if (recentlyTimestamp && startTimestamp) {
            let  icon = `<span class="glyphicon glyphicon-question-sign request-from-icon"></span>`
            if (recentlyStatus == 'done') {
              icon = `<span class="glyphicon glyphicon-cloud request-from-icon" title="From remote server"></span>`
              if (request.fromCache) {
                icon = `<span class="glyphicon glyphicon-hdd request-from-icon" title="From local cache"></span>`
              }
            }
            const duration = Number.parseFloat(recentlyTimestamp - startTimestamp).toFixed(2)
            return `${icon} ${duration}ms`;
          }
          return "-";
        },
      },
      { title: "Remote IP", field: "ip", width: 200,
        headerFilter:"input",
        headerFilterParams: {
          elementAttributes:{
            class: "form-control"
          }
        },
      },
      { title: "MethodType", field: "type", width: 100, visible: false },
      { title: "Status", field: "statusCode", width: 100 },
      { title: "Type", field: "contentType", width: 100, tooltip: true,
        headerFilter:"input",
        headerFilterParams: {
          elementAttributes:{
            class: "form-control"
          }
        },
      },
      { title: "Size", field: "contentLength", width: 100, tooltip: true,
        formatter: (cell)=>{
          const cellVal = cell.getValue() || 0
          if (cellVal > 0) {
            return filesize(cellVal);
          } else {
            return '-'
          }
        }
      },
      { title: "Cache", field: "fromCache", width: 50, visible: false },
      { title: "Method", field: "method", width: 100, visible: false },
      { title: "Tab", field: "tabId", width: 50, visible: false },
    ],
  });
  window.tt = tabulatorInstance;
  tabulatorInstance.on("rowAdded", function(row){
    const rowCount = tabulatorInstance.getDataCount();
    const rows = tabulatorInstance.getRows()
    if (rowCount > MAXRECORDS) {
      rows[0].delete()
    }
//    const rows = tabulatorInstance.getRows()
//    const lastRow = rows[rows.length - 1];
//    const rowIndex = lastRow.getIndex()
//    tabulatorInstance.scrollToRow(rowIndex)
      //row - row component
  });



  return new Promise((resolve)=>{
    const onTableBuilt = ()=>{
      tabulatorInstance.alert('loading...')
      tabulatorInstance.off('tableBuilt', onTableBuilt)
      listenerScrollEvent(tabulatorInstance);
      resolve(tabulatorInstance);
    }
    tabulatorInstance.on('tableBuilt', onTableBuilt)
  })
};


function createConnectPort(tabulatorInstance, tabsSelectorInstance) {
  let sequenceDataCache = {}
  async function sequenceUpdateDatas(datas=[]){
    datas.forEach((data)=>{
      sequenceDataCache[data.requestId] = data;
    })
    if (sequenceUpdateDatas.isRunning) return
    sequenceUpdateDatas.isRunning = true
    while(Object.keys(sequenceDataCache).length > 0){
      if (document.visibilityState !== 'visible') {
        break
      }
      if (!autoScrollToBottom) {
        break
      }
      let useReplace = false
      console.log('update datassssss:::', Object.keys(sequenceDataCache).length, sequenceDataCache)
      if (Object.keys(sequenceDataCache).length > 20) {
        useReplace = true
        const tableDatas = tabulatorInstance.getData()
        tableDatas.forEach((data)=> {
          if (!sequenceDataCache[data.requestId]) {
            sequenceDataCache[data.requestId] = data
          }
        })
      }
      let sequenceDatas = Object.values(sequenceDataCache)
      const filterTabId = tabsSelectorInstance.getSelectedTabId()
      if (filterTabId) {
        sequenceDatas = sequenceDatas.filter((data)=> filterTabId == data.tabId)
      }
      sequenceDatas.sort(sortRequest)
      if (sequenceDatas.length > MAXRECORDS) {
        sequenceDatas = sequenceDatas.slice(-MAXRECORDS);
      }
      sequenceDataCache = {}
      if (sequenceDatas.length == 0) {
        continue
      }
      const lastRequestId = parseInt(sequenceDatas[sequenceDatas.length - 1].requestId)
      if (useReplace) {
        const selectedDatas = tabulatorInstance.getSelectedData()
        await tabulatorInstance.replaceData(sequenceDatas)
        tabulatorInstance.selectRow(selectedDatas.map((data)=> data.requestId));
      } else {
        await tabulatorInstance.updateOrAddData(sequenceDatas)
      }
      //await waitTimeout(100);
      if (lastRequestId > recentlyRequestId) {
        recentlyRequestId = lastRequestId;
      }
    }
    if (autoScrollToBottom) {
      scrollTabulatorToBottom(tabulatorInstance);
    }
    sequenceUpdateDatas.isRunning = false
  }

  document.addEventListener('visibilitychange', function() {
    if (document.visibilityState === 'visible') {
      console.log('visible::::', Object.keys(sequenceDataCache).lenth, sequenceDataCache)
      sequenceUpdateDatas()
    }
  });


  const config = { attributes: true, attributeFilter: ['class'] };

  const callback = function(mutationsList, observer) {
    for (const mutation of mutationsList) {
      if (mutation.type === 'attributes' && mutation.attributeName === 'class') {
        if (!document.body.classList.contains('disable-auto-scroll')) {
          sequenceUpdateDatas();
        }
      }
    }
  };
  const observer = new MutationObserver(callback);
  observer.observe(document.body, config);

  const port = chrome.runtime.connect({ name: "network-inspect" });
  const decorateRequest = (request)=>{
    if (request.actionProfile) {
      const prefix = request.actionProfile.prefix || ''
      request.profileName = prefix + request.actionProfile.shortTitle.substring(6)
    }
    if (request.responseHeaders && request.recentlyStatus == 'done') {
      request.contentType = getHeaderValue(request.responseHeaders, 'content-type') || '-';
      request.contentLength = parseInt(getHeaderValue(request.responseHeaders, 'content-length')) || 0;
    }
  }
  const onMessage = (msg) => {
    switch (msg.type) {
      case "connected": {
        port.postMessage({
          type: 'init',
          tabId: tabsSelectorInstance.getSelectedTabId()
        })
        break
      }
      case "init": {
        const requests = [];
        Object.values(msg.data).forEach((tabRequestInfo) => {
          if (tabRequestInfo) {
            const requestStatus = tabRequestInfo.requestStatus;
            Object.values(tabRequestInfo.requests).forEach((request) => {
              request.recentlyStatus = requestStatus[request.requestId];
              request.recentlyTimestamp = request.recentlyStatus
              request.profileName = ''
              decorateRequest(request)
              // only display have start request
              if (request.statusInfo.start && !/^(chrome|moz)-extension:\/\//i.test(request.url)) {
                requests.push(request);
              }
            });
          }
        });
        tabulatorInstance.clearAlert();
        tabulatorInstance.clearData();
        sequenceUpdateDatas(requests.slice(-MAXRECORDS))
        break;
      }
      case "update": {
        const { info, req, status } = msg.data
        //return
        if (req){
          const request = info.requests[req.requestId]
          const requestStatus = info.requestStatus;
          request.recentlyStatus = requestStatus[request.requestId];
          request.recentlyTimestamp = request.recentlyStatus
          decorateRequest(request)
          sequenceUpdateDatas([request])
        }
        break;
      }
    }
  };

  const onDisconnect = () => {
    port.onMessage.removeListener(onMessage);
    port.onDisconnect.removeListener(onDisconnect);
    tabulatorInstance.alert('The connection has been closed. Please try refreshing this page to continue network monitoring.')
  };
  port.onDisconnect.addListener(onDisconnect);
  port.onMessage.addListener(onMessage);
  return port;
}

const init = async () => {
  const currentTab = await chrome.tabs.getCurrent();
  await chrome.tabs.update(currentTab.id, {autoDiscardable: false});
  const tabulatorInstance = await createTabulator();
  const tabsSelectorContainerEl = document.querySelector('.tabs-selector-container')
  const tabsSelectorInstance = await initTabsSelector(tabsSelectorContainerEl, {
    setTab: (tab)=>{
      if (tab && tab.id) {
        const filterTabId = tab.id;
        //tabulatorInstance.setFilter([{field: 'tabId', type: '=', value: filterTabId}])
        port.postMessage({
          type: 'init',
          tabId: filterTabId
        })
      } else {
        //tabulatorInstance.clearFilter()
        port.postMessage({
          type: 'init',
        })
      }
      console.log('tab changed:::', tab)
    }
  })
  const port = createConnectPort(tabulatorInstance, tabsSelectorInstance);
};

init();
