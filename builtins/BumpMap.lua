-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local BumpMap = Class{}
BumpMap:include(Unit)

function BumpMap:init(args)
  args.title = "Bump Scanner"
  args.mnemonic = "BS"
  Unit.init(self,args)
end

-- creation/destruction states

function BumpMap:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function BumpMap:loadMonoGraph(pUnit)
  local bump = self:createObject("BumpMap","bump1")
  local center = self:createObject("ParameterAdapter","center")
  local width = self:createObject("ParameterAdapter","width")
  local height = self:createObject("ParameterAdapter","height")
  local fade = self:createObject("ParameterAdapter","fade")

  connect(pUnit,"In1",bump,"In")
  connect(bump,"Out",pUnit,"Out1")

  tie(bump,"Center",center,"Out")
  tie(bump,"Width",width,"Out")
  tie(bump,"Height",height,"Out")
  tie(bump,"Fade",fade,"Out")

  self:addBranch("center","Center",center,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("height","Height",height,"In")
  self:addBranch("fade","Fade",fade,"In")
end

function BumpMap:loadStereoGraph(pUnit)
  local bump1 = self:createObject("BumpMap","bump1")
  local bump2 = self:createObject("BumpMap","bump2")
  local center = self:createObject("ParameterAdapter","center")
  local width = self:createObject("ParameterAdapter","width")
  local height = self:createObject("ParameterAdapter","height")
  local fade = self:createObject("ParameterAdapter","fade")

  connect(pUnit,"In1",bump1,"In")
  connect(pUnit,"In2",bump2,"In")
  connect(bump1,"Out",pUnit,"Out1")
  connect(bump2,"Out",pUnit,"Out2")

  tie(bump1,"Center",center,"Out")
  tie(bump1,"Width",width,"Out")
  tie(bump1,"Height",height,"Out")
  tie(bump1,"Fade",fade,"Out")
  tie(bump2,"Center",center,"Out")
  tie(bump2,"Width",width,"Out")
  tie(bump2,"Height",height,"Out")
  tie(bump2,"Fade",fade,"Out")

  self:addBranch("center","Center",center,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("height","Height",height,"In")
  self:addBranch("fade","Fade",fade,"In")
end

local views = {
  expanded = {"center","width","height","fade"},
  collapsed = {},
  center = {"scope","center"},
  width = {"scope","width"},
  height = {"scope","height"},
  fade = {"scope","fade"},
}

function BumpMap:onLoadViews(objects,controls)
  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.center = GainBias {
    button = "center",
    branch = self:getBranch("Center"),
    description = "Center",
    gainbias = objects.center,
    range = objects.center,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.0,
    gainMap = Encoder.getMap("gain"),
  }

  controls.width = GainBias {
    button = "width",
    branch = self:getBranch("Width"),
    description = "Width",
    gainbias = objects.width,
    range = objects.width,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
    gainMap = Encoder.getMap("gain"),
  }

  controls.height = GainBias {
    button = "height",
    branch = self:getBranch("Height"),
    description = "Height",
    gainbias = objects.height,
    range = objects.height,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
    gainMap = Encoder.getMap("gain"),
  }

  controls.fade = GainBias {
    button = "fade",
    branch = self:getBranch("Fade"),
    description = "Fade",
    gainbias = objects.fade,
    range = objects.fade,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.25,
    gainMap = Encoder.getMap("gain"),
  }
  return views
end

return BumpMap
