
document.location.href = './popup/index.html'
// arc browser can't use location.href to change.
// https://github.com/suziwen/ZeroOmega/issues/4
$script('js/omega_target_popup.js', 'om-target', function() {
  $script('popup/js/style.js', 'om-style')
  iFrameResize({
    sizeWidth: true,
    autoResize: true,
    resizeFrom: 'child',
    heightCalculationMethod: 'bodyScroll',
    widthCalculationMethod: 'bodyOffset'
  }, '#myIframe')
})
