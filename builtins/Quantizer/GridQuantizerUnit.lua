-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local GridQuantizerUnit = Class{}
GridQuantizerUnit:include(Unit)

function GridQuantizerUnit:init(args)
  args.title = "Grid Quantize"
  args.mnemonic = "GQ"
  Unit.init(self,args)
end

-- creation/destruction states

function GridQuantizerUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function GridQuantizerUnit:loadMonoGraph(pUnit)
  -- create objects
  local quantizer = self:createObject("GridQuantizer","quantizer")
  connect(pUnit,"In1",quantizer,"In")
  connect(quantizer,"Out",pUnit,"Out1")
end

function GridQuantizerUnit:loadStereoGraph(pUnit)
  -- create objects
  local quantizer1 = self:createObject("GridQuantizer","quantizer1")
  local quantizer2 = self:createObject("GridQuantizer","quantizer2")
  connect(pUnit,"In1",quantizer1,"In")
  connect(quantizer1,"Out",pUnit,"Out1")
  connect(pUnit,"In2",quantizer2,"In")
  connect(quantizer2,"Out",pUnit,"Out2")

  -- alias
  tie(quantizer2,"Pre-Scale",quantizer1,"Pre-Scale")
  tie(quantizer2,"Post-Scale",quantizer1,"Post-Scale")
  tie(quantizer2,"Levels",quantizer1,"Levels")
  self.objects.quantizer = quantizer1
end

local views = {
  expanded = {"pre","levels","post"},
  collapsed = {},
}

function GridQuantizerUnit:onLoadViews(objects,controls)
  controls.pre = Fader {
    button = "pre",
    description = "Pre-Scale",
    param = objects.quantizer:getParameter("Pre-Scale"),
    monitor = self,
    map = Encoder.getMap("[-10,10]"),
    units = app.unitNone
  }

  controls.levels = Fader {
    button = "levels",
    description = "Levels",
    param = objects.quantizer:getParameter("Levels"),
    monitor = self,
    map = Encoder.getMap("int[1,256]"),
    units = app.unitInteger
  }

  controls.post = Fader {
    button = "post",
    description = "Post-Scale",
    param = objects.quantizer:getParameter("Post-Scale"),
    monitor = self,
    map = Encoder.getMap("[-10,10]"),
    units = app.unitNone
  }

  return views
end

return GridQuantizerUnit
