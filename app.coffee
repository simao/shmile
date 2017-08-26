express = require "express"
jade = require "jade"
http = require "http"
fs = require "fs"
yaml = require "yaml"
dotenv = require "dotenv"
exec = require("child_process").exec
# Promise = require('promise')
Q = require 'q'
# Deferred = require( 'promise.coffee' ).Deferred;
bodyParser = require('body-parser')

dotenv.load()

ShmileConfig = require("./lib/shmile_config")

PhotoFileUtils = require("./lib/photo_file_utils")
StubCameraControl = require("./lib/stub_camera_control")
CameraControl = require("./lib/camera_control")

TemplateControl = require("./lib/template_control")

exp = express()
web = http.createServer(exp)
urlEncodedParser = bodyParser.urlencoded({ extended: false })

config = new ShmileConfig()

# TODO: Global :/
templateControl = new TemplateControl(config.currentTemplate)

templateControl.setTemplate(config.currentTemplate)

console.log("printer is: #{templateControl.printerEnabled}")

exp.configure ->
  exp.set "views", __dirname + "/views"
  exp.set "view engine", "jade"
  exp.use express.json()
  exp.use express.methodOverride()
  exp.use exp.router
  exp.use express.static(__dirname + "/public")

exp.get "/", (req, res) ->
  res.render "index",
    title: "shmile"
    extra_css: []

exp.get "/gallery", (req, res) ->
  res.render "gallery",
    title: "gallery!"
    extra_css: [ "photoswipe/photoswipe" ]
    image_paths: PhotoFileUtils.composited_images(true)

exp.post "/config", urlEncodedParser, (req, res) ->
  console.log(req.body)
  new_template = config.setTemplate(req.body.currentTemplate)
  templateControl.setTemplate(new_template)
  res.redirect("/")

exp.get "/config", (req, res) ->
  res.render "config",
    title: "Config"
    currentTemplate: config.currentTemplate
    templates: templateControl.availableTemplates
   
ccKlass = if process.env['STUB_CAMERA'] is "true" then StubCameraControl else CameraControl
camera = new ccKlass().init()

camera.on "photo_saved", (filename, path, web_url) ->
  # FIXME:
  # template.compositor.image_src_list.push path
  templateControl.template.compositor.push path

io = require("socket.io").listen(web)
web.listen 3000
io.sockets.on "connection", (websocket) ->
  console.log "Web browser connected"

  compositor = templateControl.compositor.init()

  websocket.emit "template", templateControl.template

  camera.on "camera_begin_snap", ->
    websocket.emit "camera_begin_snap"

  camera.on "camera_snapped", ->
    websocket.emit "camera_snapped"

  camera.on "photo_saved", (filename, path, web_url) ->
    websocket.emit "photo_saved",
      filename: filename
      path: path
      web_url: web_url

  websocket.on "snap", () ->
    camera.emit "snap"

  # websocket.on "all_images", ->

  shouldPrintDefer = Q.defer();
  imageCompositedDefer = Q.defer()

  websocket.on "print", ->
    console.log 'should print'
    shouldPrintDefer.resolve true
    # shouldPrint = true

  websocket.on "do_not_print", ->
    console.log 'Should NOT print'
    # shouldPrint = false
    shouldPrintDefer.reject 'not printing'

  compositor.on "composited", (output_file_path) ->
    console.log "Finished compositing image. Output image is at ", output_file_path
    # State.image_src_list = []
    template.compositor.clearImages()
    imageCompositedDefer.resolve output_file_path

    # Control this with PRINTER=true or PRINTER=false
    # if process.env.PRINTER_ENABLED is "true"
    # if template.printerEnabled && shouldPrint
    #   console.log "Printing image at ", output_file_path
    #   # exec "lpr -o #{process.env.PRINTER_IMAGE_ORIENTATION} -o media=\"#{process.env.PRINTER_MEDIA}\" #{output_file_path}"
    #   exec "lpr -o #{template.printer} #{output_file_path}"
    websocket.broadcast.emit "composited_image", PhotoFileUtils.photo_path_to_url(output_file_path)

  websocket.on "composite", ->
    # shouldPrintPromise = new Promise (resolve, reject) ->
    shouldPrintDefer = Q.defer()
    imageCompositedDefer = Q.defer()
      # # do a thing
      # success = true
      # if success
      #   resolve 'stuff worked'
      # else
      #   reject Error 'it broke'
    # shouldPrint = false
    if templateControl.printerEnabled
      console.log "The printer is enabled, showing message"
      websocket.emit "printer_enabled"
    else
      console.log "The printer is NOT enabled, proceeding to 'review_composited'"
      websocket.emit "review_composited"

    compositor.emit "composite", templateControl.overlayImage

    # compositor.on "composited", (output_file_path) ->
    #   console.log "Finished compositing image. Output image is at ", output_file_path
    #   # State.image_src_list = []
    #   template.compositor.clearImages()
    #   imageCompositedDefer.resolve output_file_path
    #
    #   # Control this with PRINTER=true or PRINTER=false
    #   # if process.env.PRINTER_ENABLED is "true"
    #   # if template.printerEnabled && shouldPrint
    #   #   console.log "Printing image at ", output_file_path
    #   #   # exec "lpr -o #{process.env.PRINTER_IMAGE_ORIENTATION} -o media=\"#{process.env.PRINTER_MEDIA}\" #{output_file_path}"
    #   #   exec "lpr -o #{template.printer} #{output_file_path}"
    #   websocket.broadcast.emit "composited_image", PhotoFileUtils.photo_path_to_url(output_file_path)

    # Promise.when(
      # shouldPrintPromise,
      # imageCompositedPromise
    # ).then (shouldPrint, compositeImage) ->
      # renderPage(apiCallOneData, apiCallTwoData)
    # )
    # Promise.all([shouldPrintPromise, imageCompositedPromise]).then (shouldPrint, compositeImage) ->

    Q.all([shouldPrintDefer.promise, imageCompositedDefer.promise]).then (value) ->
      # this part will run after all promises have finished
      console.log 'yay my promises finished'
      # console.log arrayOfResults
      # if shouldPrint
      console.log "Printing image from ", value[1]
      # exec "lpr -o #{process.env.PRINTER_IMAGE_ORIENTATION} -o media=\"#{process.env.PRINTER_MEDIA}\" #{output_file_path}"
      console.log  "lpr -o #{template.printer} #{output_file_path}"

  compositor.on "generated_thumb", (thumb_path) ->
    websocket.broadcast.emit "generated_thumb", PhotoFileUtils.photo_path_to_url(thumb_path)
