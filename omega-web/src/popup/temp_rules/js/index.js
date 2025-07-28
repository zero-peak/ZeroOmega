import Toastify from "../../../lib/zero-dependencies/toastify/toastify-es.js";
import { filesize} from "../../../lib/zero-dependencies/filesize/filesize.esm.js";
import {
  Tabulator,
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

const tr = function(){
  const args = arguments
  if (chrome?.i18n?.getMessage){
    return chrome.i18n.getMessage.apply(null, args)
  }
  return args[0] || ''
}

const removeTempRule = (rule)=>{
  return new Promise((resolve)=>{
    window.OmegaTargetPopup.addTempRule(rule.domain, rule.profileName, -1, ()=>{
      resolve();
    })
  })
}

const createTabulator = () => {
  const createFooterElement = () => {
    const footerEl = document.createElement("div");
    footerEl.className = "tabulator-footer";
    const footerContentsEl = document.createElement("div");
    footerContentsEl.className = "tabulator-footer-contents";
    footerEl.append(footerContentsEl);

    const paginatorEl = document.createElement("span");
    paginatorEl.className = "tabulator-paginator";
    footerContentsEl.append(paginatorEl);
    const paginatorBtnsEl = document.createElement("span")
    paginatorBtnsEl.classList.add('btn-group')


    const clearBtnEl = document.createElement('button')
    clearBtnEl.classList.add('btn', 'btn-default', 'btn-sm');
    clearBtnEl.innerHTML = `
      <span class="glyphicon glyphicon-trash" aria-hidden="true"></span>
      Delete all temp rules
    `
    clearBtnEl.onclick = async ()=> {
      tabulatorInstance.alert('Processing...')
      const rules = tabulatorInstance.getData()
      for (let _i=0; _i< rules.length; _i++) {
        await removeTempRule(rules[_i]);
      }
      tabulatorInstance.clearData();
      tabulatorInstance.clearAlert();
    }
    paginatorBtnsEl.append(clearBtnEl);
    paginatorEl.append(paginatorBtnsEl)
    return footerEl;
  };
  const tempProfileRules = window.OmegaPopup.tempProfileRules;
  const rules = Object.keys(tempProfileRules).map((domain)=>{
    return {
      ...tempProfileRules[domain],
      domain
    }
  })

  const tabulatorInstance = new Tabulator(".list-container", {
    height: "100%",
    //addRowPos: "top",
    //placeholder: "loading...",
    data: rules,
    layout: "fitColumns",
    //layout: "fitData",
    index: "domain",
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
    footerElement: createFooterElement(),
    resizableColumnGuide:true,
    placeholder: "No Data",
    columns: [
      //Define Table Columns
      {title:"#", width: 20, maxWidth: 100, field:"domain", hozAlign: 'center', headerHozAlign: 'center', formatter:"rownum",headerSort:false, frozen: true},
      {
        title: "Domain",
        field: "domain"
      },
      {
        title: "Pattern",
        field: "condition.pattern",
        hozAlign: "center",
        headerHozAlign: "center",
        headerSort: true
      },
      {
        title: "Profile",
        field: "profileName",
        width: 300,
      },
      {field: "domain", formatter:"buttonCross",
        topCalc:"count", width:30, hozAlign:"center", headerSort: false,
        cellClick:function(e, cell){
          const rule = cell.getRow().getData()
          removeTempRule(rule);
          cell.getRow().delete();
        }
      }
    ],
  });


  return new Promise((resolve)=>{
    const onTableBuilt = ()=>{
      tabulatorInstance.off('tableBuilt', onTableBuilt)
      resolve(tabulatorInstance);
    }
    tabulatorInstance.on('tableBuilt', onTableBuilt)
  })
};

const init = async () => {
  const tabulatorInstance = await createTabulator();
};
init();
