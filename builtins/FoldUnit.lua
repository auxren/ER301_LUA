-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local FoldUnit = Class{}
FoldUnit:include(Unit)

function FoldUnit:init(args)
  args.title = "Fold"
  args.mnemonic = "F"
  Unit.init(self,args)
end

-- creation/destruction states

function FoldUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function FoldUnit:loadMonoGraph(pUnit)
  local fold = self:createObject("Fold","fold")

  local upper = self:createObject("GainBias","upper")
  local upperRange = self:createObject("MinMax","upperRange")
  local lower = self:createObject("GainBias","lower")
  local lowerRange = self:createObject("MinMax","lowerRange")

  local threshold = self:createObject("GainBias","threshold")
  local thresholdRange = self:createObject("MinMax","thresholdRange")

  -- connect objects
  connect(threshold,"Out",thresholdRange,"In")
  connect(threshold,"Out",fold,"Threshold")
  connect(upper,"Out",upperRange,"In")
  connect(upper,"Out",fold,"Upper Gain")
  connect(lower,"Out",lowerRange,"In")
  connect(lower,"Out",fold,"Lower Gain")

  -- connect inputs/outputs
  connect(pUnit,"In1",fold,"In")
  connect(fold,"Out",pUnit,"Out1")

  -- register exported ports
  self:addBranch("threshold","Threshold",threshold,"In")
  self:addBranch("upper","Upper",upper,"In")
  self:addBranch("lower","Lower",lower,"In")
end

function FoldUnit:loadStereoGraph(pUnit)
  local fold1 = self:createObject("Fold","fold1")
  local fold2 = self:createObject("Fold","fold2")

  local upper = self:createObject("GainBias","upper")
  local upperRange = self:createObject("MinMax","upperRange")
  local lower = self:createObject("GainBias","lower")
  local lowerRange = self:createObject("MinMax","lowerRange")

  local threshold = self:createObject("GainBias","threshold")
  local thresholdRange = self:createObject("MinMax","thresholdRange")

  -- connect objects
  connect(threshold,"Out",thresholdRange,"In")
  connect(threshold,"Out",fold1,"Threshold")
  connect(threshold,"Out",fold2,"Threshold")
  connect(upper,"Out",upperRange,"In")
  connect(upper,"Out",fold1,"Upper Gain")
  connect(upper,"Out",fold2,"Upper Gain")
  connect(lower,"Out",lowerRange,"In")
  connect(lower,"Out",fold1,"Lower Gain")
  connect(lower,"Out",fold2,"Lower Gain")

  -- connect inputs/outputs
  connect(pUnit,"In1",fold1,"In")
  connect(fold1,"Out",pUnit,"Out1")
  connect(pUnit,"In2",fold2,"In")
  connect(fold2,"Out",pUnit,"Out2")

  -- register exported ports
  self:addBranch("threshold","Threshold",threshold,"In")
  self:addBranch("upper","Upper",upper,"In")
  self:addBranch("lower","Lower",lower,"In")
end

local views = {
  expanded = {"threshold","upper","lower"},
  collapsed = {},
  threshold = {"scope","threshold"},
  upper = {"scope","upper"},
  lower = {"scope","lower"},
}

function FoldUnit:onLoadViews(objects,controls)
  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.threshold = GainBias {
    button = "thresh",
    branch = self:getBranch("Threshold"),
    description = "Threshold",
    gainbias = objects.threshold,
    range = objects.thresholdRange,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.0,
    gainMap = Encoder.getMap("gain"),
  }

  controls.upper = GainBias {
    button = "upper",
    branch = self:getBranch("Upper"),
    description = "Upper Gain",
    gainbias = objects.upper,
    range = objects.upperRange,
    biasMap = Encoder.getMap("[-5,5]"),
    biasUnits = app.unitNone,
    initialBias = 1.0,
    gainMap = Encoder.getMap("gain"),
  }

  controls.lower = GainBias {
    button = "lower",
    branch = self:getBranch("Lower"),
    description = "Lower Gain",
    gainbias = objects.lower,
    range = objects.lowerRange,
    biasMap = Encoder.getMap("[-5,5]"),
    biasUnits = app.unitNone,
    initialBias = 1.0,
    gainMap = Encoder.getMap("gain"),
  }

  return views
end

return FoldUnit
