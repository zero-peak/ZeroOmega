import { escapeHTML, tr, compareProfile, getProfileIcon } from "./utils.js";
import Toastify from "../../../lib/toastify/toastify-es.js";

const updateMainBtn = (mainBtnEl, profile, profiles)=>{
  let text = tr('profile_' + profile.name) ||
    profile.name;
  if (profile.defaultProfileName) {
    text += ' [' + profile.defaultProfileName + ']';
  }

  var targetProfile = profile;
  if (profile.profileType === 'VirtualProfile') {
    targetProfile = profiles['+' + profile.defaultProfileName];
  }

  let iconClass = getProfileIcon(targetProfile)
  if (targetProfile !== profile) {
    iconClass += ' om-virtual-profile-icon'
  }
  mainBtnEl.dataset.profile = profile.name;
  mainBtnEl.innerHTML = `
    <span>
      <span class="glyphicon ${iconClass}" style="color: ${targetProfile.color};">
      </span>
    </span>
    <span>${escapeHTML(text)}</span>
    <span class="caret"></span>
  `
}




function createMenuItemForProfile(profile, profiles) {
  const profileDisp = document.createElement('li');
  profileDisp.classList.add('om-nav-item')
  let text = tr('profile_' + profile.name) ||
    profile.name;
  if (profile.defaultProfileName) {
    text += ' [' + profile.defaultProfileName + ']';
  }
  var targetProfile = profile;
  if (profile.profileType === 'VirtualProfile') {
    targetProfile = profiles['+' + profile.defaultProfileName];
  }

  profileDisp.setAttribute('title',
    targetProfile.desc || targetProfile.name || '');

  let iconClass = getProfileIcon(targetProfile)
  if (targetProfile !== profile) {
    iconClass += ' om-virtual-profile-icon'
  }

  profileDisp.innerHTML = `
      <a href="#" role="button">
        <span class="glyphicon ${iconClass}" style="color: ${targetProfile.color};"></span>
        <span class="om-profile-name">${escapeHTML(text)}</span>
      </a>
  `
  return profileDisp;
}


function createProfileDropdown(state, containerEl) {

  const profileSelectorEl = containerEl.querySelector('.omega-profile-select');
  const mainBtnEl = profileSelectorEl.querySelector('.dropdown-toggle')

  var ul = document.createElement('ul');
  ul.classList.add('dropdown-menu')
  const {
    availableProfiles,
    lastProfileNameForCondition,
    currentProfileName,
    validResultProfiles,
    currentProfileCanAddRule
  } = state;
  const profiles = validResultProfiles.map(function(name) {
    return availableProfiles['+' + name];
  }).sort(compareProfile);
  const preSelectedProfileName = lastProfileNameForCondition || 'direct'
  updateMainBtn(mainBtnEl, availableProfiles['+' + preSelectedProfileName], availableProfiles)
  profiles.forEach(function(profile) {
    if (profile.name.indexOf('__') === 0) return;
    if ((profile.name === currentProfileName) &&
      (validResultProfiles.length > 1)
    ) return;
    var li = createMenuItemForProfile(profile, availableProfiles);
    if (preSelectedProfileName == profile.name) {
      li.classList.add('active');
    }
    var link = li.querySelector('a');
    link.onclick = (e)=>{
      ul.querySelectorAll('.om-nav-item.active').forEach((el)=> el.classList.remove('active'))
      li.classList.add('active')
      e.preventDefault();
      e.stopPropagation();
      updateMainBtn(mainBtnEl, profile, availableProfiles)
      $(mainBtnEl).dropdown('toggle')
    }
    ul.appendChild(li);
  });
  profileSelectorEl.appendChild(ul)
}

const generateConditionSuggestion = function (
  currentDomain,
  subdomain = "",
  subdomainLevel = 0
) {
  let conditionSuggestion = null;
  let currentDomainEscaped = currentDomain.replace(/\./g, "\\.");
  let domainLooksLikeIp = false;
  if (currentDomain.indexOf(":") >= 0) {
    domainLooksLikeIp = true;
    if (currentDomain[0] !== "[") {
      currentDomain = "[" + currentDomain + "]";
      currentDomainEscaped = currentDomain
        .replace(/\./g, "\\.")
        .replace(/\[/g, "\\[")
        .replace(/\]/g, "\\]");
    }
  } else if (currentDomain[currentDomain.length - 1] >= 0) {
    domainLooksLikeIp = true;
  }
  if (domainLooksLikeIp) {
    conditionSuggestion = {
      HostWildcardCondition: currentDomain,
      HostRegexCondition: "^" + currentDomainEscaped + "$",
      UrlWildcardCondition: "*://" + currentDomain + "/*",
      UrlRegexCondition: "://" + currentDomainEscaped + "(:\\d+)?/",
      KeywordCondition: currentDomain,
    };
  } else {
    if (subdomain) {
      let subdomains = subdomain.split(".");
      subdomainLevel = subdomainLevel % (subdomains.length + 1);
      if (subdomainLevel > 0) {
        subdomains = subdomains.splice(subdomainLevel - 1);
        subdomains.push(currentDomain);
        currentDomain = subdomains.join(".");
        currentDomainEscaped = currentDomain.replace(/\./g, "\\.");
      }
    }
    conditionSuggestion = {
      HostWildcardCondition: "*." + currentDomain,
      HostRegexCondition: "(^|\\.)" + currentDomainEscaped + "$",
      UrlWildcardCondition: "*://*." + currentDomain + "/*",
      UrlRegexCondition: "://([^/.]+\\.)*" + currentDomainEscaped + "(:\\d+)?/",
      KeywordCondition: currentDomain,
    };
  }
  return conditionSuggestion;
};

const getState = ()=>{
  return new Promise((resolve)=>{
     OmegaTargetPopup.getState([
      'availableProfiles',
      'currentProfileName',
      'validResultProfiles',
      'isSystemProfile',
      'currentProfileCanAddRule',
      'proxyNotControllable',
      'externalProfile',
      'showExternalProfile',
      'lastProfileNameForCondition',
      'customCss',
    ], function(err, state) {
      resolve(state);
    })
  })
}

export const initUrlCellDetail = async (cell) => {

  const urlStr = cell.getValue();
  const request = cell.getRow().getData();
  const tabulatorInstance = cell.getTable();
  tabulatorInstance.alert('loading...')

  const state = await getState()
  const {
    availableProfiles,
    lastProfileNameForCondition,
    currentProfileName,
    validResultProfiles,
    currentProfileCanAddRule
  } = state;

  const urlContainerEl = document.createElement("div");
  urlContainerEl.classList.add("url-detail-container");
  const url = new URL(urlStr);
  const domain = OmegaPac.getBaseDomain(url.hostname);
  const subdomain = OmegaPac.getSubdomain(urlStr);

  let headerTitle = tr('popup_addCondition')
  if (currentProfileCanAddRule){
    const profileUrl = chrome.runtime.getURL('options.html') + '#!/profile/' + encodeURIComponent(currentProfileName)
    const profileLink = `<a href="${profileUrl}" target="_blank">${escapeHTML(currentProfileName)}</a>`
    headerTitle = `${tr('popup_addConditionTo')} (${profileLink})`
  }
  const shortTitle = request.actionProfile?.shortTitle || currentProfileName || '';
  urlContainerEl.innerHTML = `
  <div class="url-details-container">
    <div class="header">
      <h3>
        ${escapeHTML(shortTitle)}
      </h3>
    </div>
    <div class="content">
      <form class="condition-form">
        <fieldset>
          <legend>${headerTitle}</legend>
          <div class="form-group" style="display:none;"><label>${tr("options_conditionType")}</label>
            <select class="form-control condition-type" name="conditionType">
              <option value="HostWildcardCondition" selected>${tr(
                "condition_HostWildcardCondition"
              )}</option>
              <option value="HostRegexCondition">${tr(
                "condition_HostRegexCondition"
              )}</option>
              <option value="UrlWildcardCondition">${tr(
                "condition_UrlWildcardCondition"
              )}</option>
              <option value="UrlRegexCondition">${tr(
                "condition_UrlRegexCondition"
              )}</option>
              <option value="KeywordCondition">${tr(
                "condition_KeywordCondition"
              )}</option>
            </select>
          </div>
          <div class="form-group">
            <label>${tr("options_conditionDetails")}</label>
            <span class="input-group">
              <input class="form-control condition-details" type="text" required readonly>
              <span class="input-group-btn">
                <button class="btn btn-default toggle-subdomain-level-btn" type="button">
                  <i class="glyphicon glyphicon-transfer"></i>
                </button>
              </span>
            </span>
          </div>
          <div class="form-group">
            <label>${tr('options_resultProfileForSelectedDomains')}</label>
            <div class="btn-group omega-profile-select" dropdown="dropdown">
              <button type="button" data-toggle="dropdown" aria-haspopup="true" aria-expanded="false" class="btn btn-default dropdown-toggle">
                Dropdown trigger
                <span class="caret"></span>
              </button>
            </div>
          </div>
        </fieldset>
      </form>
    </div>
    <div class="footer">
      <button class="btn btn-default close-btn" type="button">${tr(
        "dialog_close"
      )}</button>
      <button class="btn btn-default add-temp-condition-btn" type="button">Add temp condition</button>
      <button class="btn btn-primary add-condition-btn" type="button">Add condition</button>
    </div>
  </div>
  `;
  createProfileDropdown(state, urlContainerEl)
  const typeEl = urlContainerEl.querySelector(".condition-type");
  const detailEl = urlContainerEl.querySelector(".condition-details");
  const toggleBtnEl = urlContainerEl.querySelector(
    ".toggle-subdomain-level-btn"
  );
  let level = 0;
  typeEl.onchange = () => {
    detailEl.value = generateConditionSuggestion(domain, subdomain, level)[
      typeEl.value
    ];
  };
  toggleBtnEl.onclick = () => {
    const conditionSuggestion = generateConditionSuggestion(
      domain,
      subdomain,
      ++level
    );
    detailEl.value =
      conditionSuggestion[typeEl.value || "HostWildcardCondition"];
  };
  detailEl.value = generateConditionSuggestion(domain, subdomain, level)[
    typeEl.value
  ];

  urlContainerEl.querySelector(".close-btn").onclick = () => {
    tabulatorInstance.clearAlert();
  };
  urlContainerEl.querySelector(".add-temp-condition-btn").onclick = () => {
    const mainBtnEl = urlContainerEl.querySelector('.omega-profile-select .dropdown-toggle');
    const profileName = mainBtnEl.dataset.profile;
    const pattern = detailEl.value;
    tabulatorInstance.clearAlert();
    OmegaTargetPopup.addTempRule(pattern.substring(2), profileName, 1, ()=>{
      OmegaTargetPopup.setState('lastProfileNameForCondition', profileName, ()=>{
        Toastify({
          text: "Add temp condition success",
          position: "center",
        }).showToast();
      })
    })
  };

  const addConditionBtnEl = urlContainerEl.querySelector(".add-condition-btn");
  addConditionBtnEl.onclick = ()=>{
    const mainBtnEl = urlContainerEl.querySelector('.omega-profile-select .dropdown-toggle');
    const profileName = mainBtnEl.dataset.profile;
    const pattern = detailEl.value;
    tabulatorInstance.clearAlert();
    OmegaTargetPopup.addCondition([{
      conditionType: 'HostWildcardCondition',
      pattern
    }], profileName, ()=>{
      OmegaTargetPopup.setState('lastProfileNameForCondition', profileName, ()=>{
        Toastify({
          text: "Add condition success",
          position: "center",
        }).showToast();
      })
    });
  }
  if (!currentProfileCanAddRule) {
    addConditionBtnEl.style.display = 'none';
  }


  tabulatorInstance.alert(urlContainerEl);
};
