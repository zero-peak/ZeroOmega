module.exports =
  options:
    mode: 'zip'
  chromium:
    options:
      archive: '../dist/chromium-release.zip'
    files: [
      {
        cwd: 'build'
        src: ['**', '!manifest.json', '!manifest-firefox.json']
        expand: true
        filter: 'isFile'
      }
      {
        cwd: 'tmp/chromium/'
        src: 'manifest.json'
        expand: true
      }
    ]
  firefox:
    options:
      archive: '../dist/firefox-release.zip'
    files: [
      {
        cwd: 'build'
        src: ['**', '!manifest.json', '!manifest-firefox.json']
        expand: true
        filter: 'isFile'
      }
      {
        cwd: 'tmp/firefox/'
        src: 'manifest.json'
        expand: true
      }
    ]
