assert = require('assert')

LandscapeTwoByTwo = require("./image_compositor")
PortraitOneByFour = require("./double_image_compositor")
LandscapeOneByThree = require("./landscape_3x8_compositor")

Template = require("./template")

class TemplateControl
  # TODO: Use eval?
  compositors:
    PortraitOneByFour: PortraitOneByFour
    LandscapeOneByThree: LandscapeOneByThree
    LandscapeTwoByTwo: LandscapeTwoByTwo

  constructor:  (@name) ->
    @availableTemplates = Object.keys(@compositors)
    this.setTemplate(@name)

  setTemplate: (name) ->
    assert(name in @availableTemplates, "unknown template #{name}")

    overlay = "/images/#{name}.png"

    @template = new Template({
      overlayImage: overlay,
      photoView: name,
      compositor: new (this.compositors[name])})

    @printerEnabled = !!@template.printerEnabled
    @printer = @template.printer
    @compositor = @template.compositor
    @overlayImage = @template.overlayImage

module.exports = TemplateControl
