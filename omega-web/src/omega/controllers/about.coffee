angular.module('omega').controller 'AboutCtrl', (
  $scope, $rootScope,$modal, omegaDebug
) ->
  $scope.downloadLog = ->
    $scope.logDownloading = true
    Promise.resolve(omegaDebug.downloadLog()).then( ->
      $scope.logDownloading = false
    )
  $scope.reportIssue = ->
    $scope.issueReporting = true
    omegaDebug.reportIssue().then( ->
      $scope.issueReporting = false
    )

  $scope.showResetOptionsModal = ->
    $modal
      .open(templateUrl: 'partials/reset_options_confirm.html').result
      .then ->
        $scope.optionsReseting = true
        omegaDebug.resetOptions().then( ->
          $scope.optionsReseting = false
        )

  try
    $scope.version = omegaDebug.getProjectVersion()
  catch _
    $scope.version = '?.?.?'
