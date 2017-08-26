fs = require('fs')

class ShmileConfig
  defaults:
    configFile: "shmile_config.json"

  constructor: (@opts=null) ->
    @opts = @defaults if @opts is null
    this.read()

  read: ->
    @config = JSON.parse(fs.readFileSync(@opts.configFile, 'utf8'))
    @currentTemplate = @config.current_template
    @config

  write: ->
    fs.writeFileSync(@opts.configFile, JSON.stringify(@config, null, 2))
    this.read()
    
  setTemplate: (template) ->
    @config.current_template = template
    this.write()
    template

module.exports = ShmileConfig
