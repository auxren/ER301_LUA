-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local StressUnit = Class{}
StressUnit:include(Unit)

function StressUnit:init(args)
  args.title = "Stress"
  args.mnemonic = "St"
  Unit.init(self,args)
end

-- creation/destruction states

function StressUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function StressUnit:loadMonoGraph(pUnit)
  -- create objects
  local stress = self:createObject("Stress","stress")
  local map = self:createObject("ParameterAdapter","map")
  map:clamp(0,1)

  -- connect inputs/outputs
  connect(pUnit,"In1",stress,"In")
  connect(stress,"Out",pUnit,"Out1")
  tie(stress,"Load",map,"Out")

  self:addBranch("load","Load",map,"In")
end

function StressUnit:loadStereoGraph(pUnit)
  -- create objects
  local stress1 = self:createObject("Stress","stress1")
  local stress2 = self:createObject("Stress","stress2")
  local map = self:createObject("ParameterAdapter","map")
  map:clamp(0,1)

  -- connect inputs/outputs
  connect(pUnit,"In1",stress1,"In")
  connect(pUnit,"In2",stress2,"In")
  connect(stress1,"Out",pUnit,"Out1")
  connect(stress2,"Out",pUnit,"Out2")
  tie(stress1,"Load",map,"Out")
  tie(stress2,"Load",map,"Out")

  self.objects.stress = self.objects.stress1
  stress1:setAdjustment(0.5)
  stress2:setAdjustment(0.5)

  self:addBranch("load","Load",map,"In")
end

local views = {
  expanded = {"cpu"},
  collapsed = {},
}


function StressUnit:onLoadViews(objects,controls)
  controls.cpu = GainBias {
    button = "load",
    description = "CPU Load",
    branch = self:getBranch("Load"),
    gainbias = objects.map,
    range = objects.map,
    biasMap = Encoder.getMap("unit"),
  }
  return views
end

return StressUnit
