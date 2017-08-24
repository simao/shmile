im = require("imagemagick")
fs = require("fs")
EventEmitter = require("events").EventEmitter

SCALE_FACTOR = 1.5

IMAGE_HEIGHT = 422.22 * SCALE_FACTOR
IMAGE_WIDTH =  633.33 * SCALE_FACTOR
TOTAL_HEIGHT = 750 * SCALE_FACTOR
TOTAL_WIDTH = 2000 * SCALE_FACTOR
SPACER = 50 * SCALE_FACTOR

# Composites an array of four images into the final grid-based image asset.
class Landscape3x8Compositor

  defaults:
    # overlay_src: "public/images/overlay_david.png"
    tmp_dir: "public/temp"
    output_dir: "public/photos/generated"
    thumb_dir: "public/photos/generated/thumbs"

  constructor: (@opts=null) ->
    # console.log("img_src_list is: #{@img_src_list}")
    @opts = @defaults if @opts is null
    @img_src_list = []

  push: (image) ->
    @img_src_list.push image

  clearImages: ->
    console.log "clearImages"
    @img_src_list.length = 0

  init: ->
    emitter = new EventEmitter()
    emitter.on "composite", (overlay_src) =>
      convertArgs = [ "-size", TOTAL_WIDTH + "x" + TOTAL_HEIGHT, "canvas:white" ]
      utcSeconds = (new Date()).valueOf()
      IMAGE_GEOMETRY = "#{IMAGE_WIDTH}x#{IMAGE_HEIGHT}"
      OUTPUT_FILE_NAME = "#{utcSeconds}.jpg"
      FINAL_OUTPUT_PATH = "#{@opts.output_dir}/gen_#{OUTPUT_FILE_NAME}"
      FINAL_OUTPUT_THUMB_PATH = "#{@opts.thumb_dir}/thumb_#{OUTPUT_FILE_NAME}"

      for img, i in @img_src_list
        convertArgs.push img
        convertArgs.push "-geometry"
        convertArgs.push "#{IMAGE_WIDTH}x#{IMAGE_HEIGHT}+#{i * (IMAGE_WIDTH + SPACER)}+#{SPACER}" # TODO: use constants
        convertArgs.push "-composite"

      # convertArgs.push @opts.overlay_src
      # FIXME: remove the need for hardcoded public
      convertArgs.push "public" + overlay_src
      convertArgs.push "-geometry"
      convertArgs.push "#{TOTAL_WIDTH}x#{TOTAL_HEIGHT}+0+0"
      convertArgs.push "-composite"

      convertArgs.push "-duplicate"
      convertArgs.push "1"
      convertArgs.push "-append"

      convertArgs.push FINAL_OUTPUT_PATH

      console.log("executing: convert #{convertArgs.join(" ")}")

      im.convert(
        convertArgs,
        (err, stdout, stderr) ->
          throw err  if err
          emitter.emit "composited", FINAL_OUTPUT_PATH
          doGenerateThumb()
      )

      resizeCompressArgs = [ "-size", "25%", "-quality", "20", FINAL_OUTPUT_PATH, FINAL_OUTPUT_THUMB_PATH ]

      doGenerateThumb = =>
        console.log("executing: convert #{resizeCompressArgs.join(" ")}")
        im.convert resizeCompressArgs, (e, out, err) ->
          throw err  if err
          emitter.emit "generated_thumb", FINAL_OUTPUT_THUMB_PATH

    emitter

module.exports = Landscape3x8Compositor
