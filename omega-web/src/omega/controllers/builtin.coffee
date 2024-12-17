angular.module('omega').controller 'BuiltinCtrl', ($scope, $stateParams,
  $location, $rootScope,
  $timeout, $state, $modal,
  builtinProfiles, profileColorPalette,
  getAttachedName, getParentName, getVirtualTarget,
  omegaTarget
) ->

  customBuiltinProfiles = {}

  decorateBuiltinProfile = (newOptions) ->
    Object.assign(
      customBuiltinProfiles,
      builtinProfiles,
      newOptions?['-builtinProfiles']
    )
    $scope.systemProfile = customBuiltinProfiles['+system']
    $scope.directProfile = customBuiltinProfiles['+direct']

  omegaTarget.addOptionsChangeCallback decorateBuiltinProfile

  decorateBuiltinProfile($rootScope.options)
  $scope.moveColor = (color, key) ->
    customBuiltinProfiles[key].color = color
    # make sure options watcher watch value changed
    $rootScope.options['-builtinProfiles'] =
      JSON.parse(JSON.stringify(customBuiltinProfiles))
  $scope.changeColor = (color) ->
    console.log('change color::::', color)
  $scope.spectrumOptions =
    localStorageKey: 'spectrum.profileColor'
    palette: profileColorPalette
    preferredFormat: 'hex'
    showButtons: false
    showInitial: true
    showInput: true
    showPalette: true
    showSelectionPalette: true
    maxSelectionSize: 5
