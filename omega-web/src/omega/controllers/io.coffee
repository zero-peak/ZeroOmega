angular.module('omega').controller 'IoCtrl', (
  $scope, $rootScope, $window, $http, omegaTarget, downloadFile
) ->

  omegaTarget.state([
    'web.restoreOnlineUrl',
    'gistId',
    'gistToken',
    'lastGistSync',
    'lastGistState'
  ]).then ([url, gistId, gistToken, lastGistSync, lastGistState]) ->
    if url
      $scope.restoreOnlineUrl = url
    if gistId
      $scope.gistId = gistId
    if gistToken
      $scope.gistToken = gistToken
    $scope.lastGistSync = new Date(lastGistSync or Date.now())
    $scope.lastGistState = lastGistState or ''

  $scope.exportOptions = ->
    $rootScope.applyOptionsConfirm().then ->
      plainOptions = angular.fromJson(angular.toJson($rootScope.options))
      content = JSON.stringify(plainOptions)
      blob = new Blob [content], {type: "text/plain;charset=utf-8"}
      downloadFile(blob, "OmegaOptions.bak")

  $scope.importSuccess = ->
    $rootScope.showAlert(
      type: 'success'
      i18n: 'options_importSuccess'
      message: 'Options imported.'
    )

  $scope.restoreLocal = (content) ->
    $scope.restoringLocal = true
    $rootScope.resetOptions(content).then(( ->
      $scope.importSuccess()
    ), -> $scope.restoreLocalError()).finally ->
      $scope.restoringLocal = false

  $scope.restoreLocalError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importFormatError'
      message: 'Invalid backup file!'
    )
  $scope.downloadError = ->
    $rootScope.showAlert(
      type: 'error'
      i18n: 'options_importDownloadError'
      message: 'Error downloading backup file!'
    )
  $scope.triggerFileInput = ->
    angular.element('#restore-local-file').click()
    return
  $scope.restoreOnline = ->
    omegaTarget.state('web.restoreOnlineUrl', $scope.restoreOnlineUrl)
    $scope.restoringOnline = true
    $http(
      method: 'GET'
      url: $scope.restoreOnlineUrl
      cache: false
      timeout: 10000
      responseType: "text"
    ).then(((result) ->
      $rootScope.resetOptions(result.data).then (->
        $scope.importSuccess()
      ), -> $scope.restoreLocalError()
    ), $scope.downloadError).finally ->
      $scope.restoringOnline = false

  $scope.enableOptionsSync = (args = {}) ->
    enable = ->
      if !$scope.gistId or !$scope.gistToken
        $rootScope.showAlert(
          type: 'error'
          message: 'Gist Id or Gist Token is required'
        )
        return
      args.gistId = $scope.gistId
      args.gistToken = $scope.gistToken
      $scope.enableOptionsSyncing = true
      omegaTarget.setOptionsSync(true, args).then( ->
        $window.location.reload()
      ).catch((e) ->
        $scope.enableOptionsSyncing = false
        $rootScope.showAlert(
          type: 'error'
          message: e + ''
        )
        console.log('error:::', e)
      )
    if args?.force
      enable()
    else
      $rootScope.applyOptionsConfirm().then enable

  $scope.checkOptionsSyncChange = ->
    $scope.enableOptionsSyncing = true
    omegaTarget.checkOptionsSyncChange().then( ->
      $window.location.reload()
    )
  $scope.disableOptionsSync = ->
    omegaTarget.setOptionsSync(false).then ->
      $rootScope.applyOptionsConfirm().then ->
        $window.location.reload()

  $scope.resetOptionsSync = ->
    if !$scope.gistId or !$scope.gistToken
      $rootScope.showAlert(
        type: 'error'
        message: 'Gist Id or Gist Token is required'
      )
      return
    omegaTarget.resetOptionsSync({
      gistId: $scope.gistId
      gistToken: $scope.gistToken
    }).then( ->
      $rootScope.applyOptionsConfirm().then ->
        $window.location.reload()
    ).catch((e) ->
      $rootScope.showAlert(
        type: 'error'
        message: e + ''
      )
      console.log('error:::', e)
    )
