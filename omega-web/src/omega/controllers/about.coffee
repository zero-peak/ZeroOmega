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

  $scope.htmlLicense = """
ZeroOm&#8203ega is
  <a href='https://www.gnu.org/philosophy/free-sw.en.html'>free software</a>
licensed under
<a href='https://www.gnu.org/licenses/gpl.html'>GNU General Public License</a>
Version 3 or later.
  """
  $scope.htmlCredits = """
Z&#8203eroOmega is made possible by the
<a href='https://github.com/suziwen/ZeroOmega'>Ze&#8203roOmega</a>
open source project and other
<a href='https://github.com/FelisCatus/SwitchyOmega/blob/master/AUTHORS'>
open source software
</a>.
  """
  try
    $scope.version = omegaDebug.getProjectVersion()
  catch _
    $scope.version = '?.?.?'
