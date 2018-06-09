-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Task = require "Unit.MenuControl.Task"
local Encoder = require "Encoder"
local GainBias = require "Unit.ViewControl.GainBias"
local ply = app.SECTION_PLY

local FreeverbUnit = Class{}
FreeverbUnit:include(Unit)

function FreeverbUnit:init(args)
  args.title = "Freeverb"
  args.mnemonic = "FV"
  Unit.init(self,args)
end

-- creation/destruction states

function FreeverbUnit:onLoadGraph(pUnit, channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end

  local verb = self.objects.verb

  local size = self:createObject("ParameterAdapter","size")
  tie(self.objects.verb,"Size",size,"Out")
  self:addBranch("size","Size",size,"In")

  local damp = self:createObject("ParameterAdapter","damp")
  tie(self.objects.verb,"Damp",damp,"Out")
  self:addBranch("damp","Damp",damp,"In")

  local width = self:createObject("ParameterAdapter","width")
  tie(self.objects.verb,"Width",width,"Out")
  self:addBranch("width","Width",width,"In")

end

function FreeverbUnit:loadMonoGraph(pUnit)
  local verb = self:createObject("Freeverb","verb")
  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  -- connect inputs/outputs
  connect(pUnit,"In1",verb,"Left In")
  connect(pUnit,"In1",verb,"Right In")
  connect(verb,"Left Out",xfade,"A")
  connect(pUnit,"In1",xfade,"B")
  connect(xfade,"Out",pUnit,"Out1")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  self:addBranch("wet","Wet/Dry",fader,"In")
end

function FreeverbUnit:loadStereoGraph(pUnit)
  local verb = self:createObject("Freeverb","verb")
  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  -- connect inputs/outputs
  connect(pUnit,"In1",verb,"Left In")
  connect(pUnit,"In2",verb,"Right In")
  connect(verb,"Left Out",xfade,"Left A")
  connect(verb,"Right Out",xfade,"Right A")
  connect(pUnit,"In1",xfade,"Left B")
  connect(pUnit,"In2",xfade,"Right B")
  connect(xfade,"Left Out",pUnit,"Out1")
  connect(xfade,"Right Out",pUnit,"Out2")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  self:addBranch("wet","Wet/Dry",fader,"In")

end

local views = {
  collapsed = {},
  expanded = {"size","damp","width","wet"}
}

function FreeverbUnit:onLoadViews(objects,controls)

  controls.size = GainBias {
    button = "size",
    description = "Room Size",
    branch = self:getBranch("Size"),
    gainbias = objects.size,
    range = objects.size,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
  }

  controls.damp = GainBias {
    button = "damp",
    description = "Damping",
    branch = self:getBranch("Damp"),
    gainbias = objects.damp,
    range = objects.damp,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
  }

  controls.width = GainBias {
    button = "width",
    description = "Width",
    branch = self:getBranch("Width"),
    gainbias = objects.width,
    range = objects.width,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 1.0,
  }

  controls.wet = GainBias {
    button = "wet",
    description = "Wet/Dry Amount",
    branch = self:getBranch("Wet/Dry"),
    gainbias = objects.fader,
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0.5,
  }

  return views
end

return FreeverbUnit
