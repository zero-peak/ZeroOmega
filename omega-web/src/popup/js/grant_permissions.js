
window.addEventListener('load', async function(){
  const dialogEl = document.querySelector('.loading-dialog')
  dialogEl.showModal()
  dialogEl.addEventListener('cancel', (e)=>e.preventDefault())
  const permissionValue = {origins: ["<all_urls>"]}
  const hasPermission = await browser.permissions.contains(permissionValue);
  const isAllowedIncognitoAccess = !chrome.contextMenus || await browser.extension.isAllowedIncognitoAccess()
  if (hasPermission) {
    document.querySelector('.site-permissions-required').remove()
  }
  if (isAllowedIncognitoAccess) {
    document.querySelector('.incognito-access-required').remove()
  }
  dialogEl.remove()
  document.body.style.opacity = '';
}, {once: true})
const btn = document.querySelector('#grant-permissions-btn')
btn.onclick = async ()=>{
  const permissionValue = {origins: ["<all_urls>"]}
  const hasPermission = await browser.permissions.request(permissionValue);
  const isAllowedIncognitoAccess = !chrome.contextMenus || await browser.extension.isAllowedIncognitoAccess()
  if (hasPermission) {
    document.querySelector('.site-permissions-required')?.remove()
  }
  if (isAllowedIncognitoAccess) {
    document.querySelector('.incognito-access-required')?.remove()
  }
  if (hasPermission && isAllowedIncognitoAccess) {
    location.href = 'index.html'
  }
}
