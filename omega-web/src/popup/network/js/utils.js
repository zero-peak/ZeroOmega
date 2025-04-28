export const debounce = (callback, wait) => {
  let timeoutId = null;

  return (...args) => {
    window.clearTimeout(timeoutId);

    timeoutId = window.setTimeout(() => {
      callback.apply(null, args);
    }, wait);
  };
}

export const waitTimeout = function(maxTimeout=3000){
  return new Promise((resolve)=>{
    setTimeout(()=>{
      resolve()
    }, maxTimeout) // 最多 3秒
  })
}

export const escapeHTML = (str)=> {
  return str
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

export const copyToClipoard = (data, opts)=>{
  return new Promise((resolve)=>{
    document.addEventListener('copy', (e)=>{
      e.preventDefault()
      e.stopPropagation()
      e.clipboardData.setData(opts?.type || 'text/plain', data)
      resolve()
    }, {once: true})
    document.execCommand('copy')
  })
}

export const tr = function(){
  const args = arguments
  if (chrome?.i18n?.getMessage){
    return chrome.i18n.getMessage.apply(null, args)
  }
  return args[0] || ''
}

const orderForType = {
  'FixedProfile': -2000,
  'PacProfile': -1000,
  'VirtualProfile': 1000,
  'SwitchProfile': 2000,
  'RuleListProfile': 3000,
};

export const compareProfile = (a, b) => {
    var diff;
    diff = (orderForType[a.profileType] | 0) - (orderForType[b.profileType] | 0);
    if (diff !== 0) {
      return diff;
    }
    if (a.name === b.name) {
      return 0;
    } else if (a.name < b.name) {
      return -1;
    } else {
      return 1;
    }
  }


const iconForProfileType = {
  'DirectProfile': 'glyphicon-transfer',
  'SystemProfile': 'glyphicon-off',
  'AutoDetectProfile': 'glyphicon-file',
  'FixedProfile': 'glyphicon-globe',
  'PacProfile': 'glyphicon-file',
  'VirtualProfile': 'glyphicon-question-sign',
  'RuleListProfile': 'glyphicon-list',
  'SwitchProfile': 'glyphicon-retweet',
};

export const getProfileIcon = (profile)=>{
  return iconForProfileType[profile?.profileType || 'DirectProfile']
}
