-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local LinearVcaUnit = Class{}
LinearVcaUnit:include(Unit)

function LinearVcaUnit:init(args)
  args.title = "Linear VCA"
  args.mnemonic = "LV"
  Unit.init(self,args)
end

-- creation/destruction states

function LinearVcaUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function LinearVcaUnit:loadMonoGraph(pUnit)
  -- create objects
  local vca = self:createObject("Multiply","vca")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")

  -- connect objects
  connect(level,"Out",levelRange,"In")
  connect(level,"Out",vca,"Left")

  -- connect inputs/outputs
  connect(pUnit,"In1",vca,"Right")
  connect(vca,"Out",pUnit,"Out1")

  -- register exported ports
  self:addBranch("level","Level",level,"In")
end

function LinearVcaUnit:loadStereoGraph(pUnit)
  -- create objects
  local vca1 = self:createObject("Multiply","vca1")
  local vca2 = self:createObject("Multiply","vca2")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")

  local balance = self:createObject("StereoPanner","balance")
  local pan = self:createObject("GainBias","pan")
  local panRange = self:createObject("MinMax","panRange")

  -- connect objects
  connect(level,"Out",levelRange,"In")
  connect(level,"Out",vca1,"Left")
  connect(level,"Out",vca2,"Left")

  connect(pUnit,"In1",vca1,"Right")
  connect(pUnit,"In2",vca2,"Right")

  connect(vca1,"Out",balance,"Left In")
  connect(balance,"Left Out",pUnit,"Out1")
  connect(vca2,"Out",balance,"Right In")
  connect(balance,"Right Out",pUnit,"Out2")

  connect(pan,"Out",balance,"Pan")
  connect(pan,"Out",panRange,"In")

  -- register exported ports
  self:addBranch("level","Level",level,"In")
  self:addBranch("pan","Pan", pan, "In")
end

function LinearVcaUnit:onLoadViews(objects,controls)
  local views = {
    expanded = {"level"},
    collapsed = {},
  }

  controls.level = GainBias {
    button = "level",
    branch = self:getBranch("Level"),
    description = "Level",
    gainbias = objects.level,
    range = objects.levelRange,
    biasMap = Encoder.getMap("[-5,5]"),
    biasUnits = app.unitNone,
    initialBias = 0.0,
    gainMap = Encoder.getMap("gain"),
  }

  if objects.pan then
    controls.pan = GainBias {
      button = "pan",
      branch = self:getBranch("Pan"),
      description = "Pan",
      gainbias = objects.pan,
      range = objects.panRange,
      biasMap = Encoder.getMap("default"),
      biasUnits = app.unitNone,
    }

    views.expanded[2] = "pan"
  end

  return views
end

return LinearVcaUnit
