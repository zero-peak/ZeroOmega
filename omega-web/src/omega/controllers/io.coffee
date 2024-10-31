angular.module('omega').controller 'IoCtrl', (
  $scope, $rootScope, $window, $http, omegaTarget, downloadFile
) ->

  $scope.useBuiltInSync = true
  getGistId = (gistUrl = '') ->
    # get gistId from url `https://gist.github.com/{username}/{gistId}`
    # or directly gistId
    gistId = gistUrl.replace(/\/+$/, '')
    gistId = gistId.split('/')
    gistId = gistId[gistId.length - 1]
    return gistId

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
      $scope.gistUrl = "https://gist.github.com/" + getGistId(gistId)
    if gistToken
      $scope.gistToken = gistToken
    $scope.lastGistSync = new Date(lastGistSync or Date.now())
    $scope.lastGistState = lastGistState or ''

  $scope.exportOptions = ->
    $rootScope.applyOptionsConfirm().then ->
      plainOptions = angular.fromJson(angular.toJson($rootScope.options))
      content = JSON.stringify(plainOptions)
      blob = new Blob [content], {type: "text/plain;charset=utf-8"}
      downloadFile(blob, "Zero" + """OmegaOptions.bak""")

  $scope.importSuccess = ->
    $rootScope.showAlert(
      type: 'success'
      i18n: 'options_importSuccess'
      message: 'Options imported.'
    )

  $scope.resetSuccess = ->
    $rootScope.showAlert(
      type: 'success'
      i18n: 'options_importSuccess'
      message: 'Options reset.'
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
    
  ###
  # Function: $scope.restoreOnline
  # Description:
  # This function is responsible for restoring data from a remote URL and
  # updating the application's state using the data retrieved. It sends an HTTP
  # GET request to the provided restoreOnlineUrl, extracts the required content,
  # and calls the resetOptions function to update the app's settings with the
  # new data. If the OnlineUrlLink is present, it communicates with the
  # background script to start an alarm that periodically syncs data from the
  # same URL. The alarm is configured with a duration specified by
  # syncTimerDuration.
  # The function handles errors during the request and data update, ensuring
  # the process completes even if there is a failure.
  #
  ###
  $scope.restoreOnline = ->
    # Save the restoreOnline URL and Online URL Link in the omegaTarget state
    omegaTarget.state('web.restoreOnlineUrl', $scope.restoreOnlineUrl)

    # Send an HTTP GET request to the restoreOnlineUrl to retrieve data
    $scope.restoringOnline = true
    $http(
      method: 'GET'
      url: $scope.restoreOnlineUrl
      cache: false
      timeout: 10000
      responseType: "text"
    ).then (result) ->
      try

        # Extract the data from the response, checking for 'content' in 'files'
        fileContent = result.data.files?[0]?.content
        if fileContent?
          data = fileContent
        else
          data = result.data
          
        # Update the app's options with the received data
        $rootScope.resetOnlyProxies(data).then ->

          # If onlineUrlLink is available, start the alarm
          if $scope.options["-onlineUrlLink"]
            chrome.runtime.sendMessage(
              action: 'startAlarm'
              restoreOnlineUrl: $scope.restoreOnlineUrl
              syncTimerDuration: $scope.options["-restoreInterval"]
            )
          else
            # If no onlineUrlLink, trigger import success function
            $scope.importSuccess()

      catch error
        # Handle errors accessing result.data.files or any other issue
        $scope.restoreLocalError()

    .catch (error) ->
      # Handle errors during the HTTP request itself
      $scope.downloadError()

    $scope.restoringOnline = false

  ###
  # Function: $scope.disableRestoreSync
  # Description:
  # This function stops the periodic sync process that was set up by the alarm.
  # It sends a message to the background script to stop the alarm using the
  # 'stopAlarm' action. After disabling the alarm, it resets the application's
  # options by calling resetOptions and handles any errors that occur.
  # If the reset is successful, it triggers the resetSuccess function;
  # otherwise, it handles errors using restoreLocalError.
  #
  ###
  $scope.disableRestoreSync = ->

    # Send a message to the background script to stop the alarm
    chrome.runtime.sendMessage(action: 'stopAlarm').then ->
      $scope.resetSuccess()

    .catch ->
      # Handle errors during resetOptions with restoreLocalError
      $scope.restoreLocalError()

  ###
  # chrome.runtime.onMessage.addListener
  # Description:
  # This function listens for incoming messages from the background scripts.
  # When a message with the action 'resetOnlyProxies' is received,
  # the function triggers the reset of proxy settings by calling
  # $rootScope.resetOnlyProxies with the data provided in the message.
  #
  # Parameters:
  # - request (Object): The message sent by another part of the extension.
  #   - request.action (String): The action type (here it checks
  #                              for 'resetOnlyProxies').
  #   - request.data (Object): The data needed to reset the proxy settings.
  #
  ###
  chrome.runtime.onMessage.addListener (request) ->

    # Check if the received action is 'resetOnlyProxies'
    if request.action is 'resetOnlyProxies'
      
      # Call $rootScope.resetOnlyProxies with the data received in the message
      $rootScope.resetOnlyProxies(request.data)


  ###
  # Function: $scope.toggleRestoreSync
  # Description:
  # This function handles the behavior of the checkbox that enables or disables
  # the sync process. It is triggered whenever the user
  # checks or unchecks the checkbox.
  #
  # When the checkbox is checked, the function calls $scope.restoreOnline()
  # to start the syncing process using the provided URL.
  # When the checkbox is unchecked, the function calls
  # $scope.disableRestoreSync() to stop the syncing
  # process and disable the periodic sync.
  #
  # Parameters:
  # - isChecked (Boolean): The current state of the checkbox.
  #   - true: Checkbox is checked, start the sync process.
  #   - false: Checkbox is unchecked, stop the sync process.
  #
  ###
  $scope.toggleRestoreSync = (isChecked) ->
    if isChecked
      # If the checkbox is checked, start restoreOnline()
      $scope.restoreOnline()
    else
      # If the checkbox is unchecked, stop syncing by
      # calling disableRestoreSync()
      $scope.disableRestoreSync()

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
      args.useBuiltInSync = $scope.useBuiltInSync
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
