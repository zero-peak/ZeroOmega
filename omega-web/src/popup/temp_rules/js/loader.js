window.UglifyJS_NoUnsafeEval = true
window.OmegaPopup = {};
$script('../../js/omega_pac.min.js', 'omega-pac')
$script('../../js/omega_target_popup.js', 'om-target', function() {
  $script('../js/style.js', 'om-style')
  function init(){
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
      OmegaTargetPopup.getTempRules(function(err, tempProfileRules){
        window.OmegaPopup.state = state;
        window.OmegaPopup.tempProfileRules = tempProfileRules;
        import('./index.js')
      })
    });
  }
  init();
});
