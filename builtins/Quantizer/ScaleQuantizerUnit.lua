-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchCircle = require "builtins.Quantizer.PitchCircle"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ScaleQuantizerUnit = Class{}
ScaleQuantizerUnit:include(Unit)

function ScaleQuantizerUnit:init(args)
  args.title = "Scale Quantize"
  args.mnemonic = "SQ"
  Unit.init(self,args)
end

-- creation/destruction states

function ScaleQuantizerUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function ScaleQuantizerUnit:loadMonoGraph(pUnit)
  -- create objects
  local quantizer = self:createObject("ScaleQuantizer","quantizer")
  connect(pUnit,"In1",quantizer,"In")
  connect(quantizer,"Out",pUnit,"Out1")

  local pre = self:createObject("ParameterAdapter","pre")
  tie(quantizer,"Pre-Transpose",pre,"Out")

  self:addBranch("pre","Pre",pre,"In")

  local post = self:createObject("ParameterAdapter","post")
  tie(quantizer,"Post-Transpose",post,"Out")

  self:addBranch("post","Post",post,"In")
end

function ScaleQuantizerUnit:loadStereoGraph(pUnit)
  -- create objects
  local quantizer1 = self:createObject("ScaleQuantizer","quantizer1")
  local quantizer2 = self:createObject("ScaleQuantizer","quantizer2")
  connect(pUnit,"In1",quantizer1,"In")
  connect(quantizer1,"Out",pUnit,"Out1")
  connect(pUnit,"In2",quantizer2,"In")
  connect(quantizer2,"Out",pUnit,"Out2")

  local pre = self:createObject("ParameterAdapter","pre")
  tie(quantizer1,"Pre-Transpose",pre,"Out")
  tie(quantizer2,"Pre-Transpose",pre,"Out")

  self:addBranch("pre","Pre",pre,"In")

  local post = self:createObject("ParameterAdapter","post")
  tie(quantizer1,"Post-Transpose",post,"Out")
  tie(quantizer2,"Post-Transpose",post,"Out")

  self:addBranch("post","Post",post,"In")

  -- alias
  self.objects.quantizer = quantizer1
end

local views = {
  expanded = {"pre","scale","post"},
  collapsed = {},
}

function ScaleQuantizerUnit:onLoadViews(objects,controls)
  controls.pre = GainBias {
    button = "pre",
    description = "Pre-Transpose",
    branch = self:getBranch("Pre"),
    gainbias = objects.pre,
    range = objects.pre,
    biasMap = Encoder.getMap("cents"),
    biasUnits = app.unitCents,
  }

  controls.post = GainBias {
    button = "post",
    description = "Post-Transpose",
    branch = self:getBranch("Post"),
    gainbias = objects.post,
    range = objects.post,
    biasMap = Encoder.getMap("cents"),
    biasUnits = app.unitCents,
  }

  controls.scale = PitchCircle {
    name = "scale",
    width = 2*ply,
    quantizer = objects.quantizer
  }
  return views
end

return ScaleQuantizerUnit
