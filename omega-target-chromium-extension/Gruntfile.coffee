module.exports = (grunt) ->
  require('load-grunt-config')(grunt)
  require('./grunt-po2crx')(grunt)

  grunt.registerTask 'manifest', ->
    manifest = grunt.file.readJSON('overlay/manifest.json')
    manifest.permissions = manifest.permissions.filter (p) -> p != 'downloads'
    grunt.file.write('tmp/chromium/manifest.json', JSON.stringify(manifest))
    manifest = grunt.file.readJSON('overlay/manifest-firefox.json')
    manifest.permissions = manifest.permissions.filter (p) -> p != 'downloads'
    grunt.file.write('tmp/firefox/manifest.json', JSON.stringify(manifest))
