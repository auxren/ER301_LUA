-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local PitchControl = require "Unit.ViewControl.PitchControl"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local GrainDelayUnit = Class{}
GrainDelayUnit:include(Unit)

function GrainDelayUnit:init(args)
  args.title = "Grain Delay"
  args.mnemonic = "GD"
  Unit.init(self,args)
end

-- creation/destruction states

function GrainDelayUnit:onLoadGraph(pUnit, channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function GrainDelayUnit:loadMonoGraph(pUnit)
  -- create objects
  local grainL = self:createObject("MonoGrainDelay","grainL",1.0)

  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")
  local multiply = self:createObject("Multiply","multiply")
  local pitch = self:createObject("VoltPerOctave","pitch")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local speed = self:createObject("GainBias","speed")
  speed:hardSet("Bias",1.0)
  local speedRange = self:createObject("MinMax","speedRange")
  local speedClipper = self:createObject("Clipper","speedClipper",-100,100)
  local delayL = self:createObject("GainBias","delayL")
  local delayLRange = self:createObject("MinMax","delayLRange")
  local delayLClipper = self:createObject("Clipper","delayLClipper",0,1)

  -- connect objects
  connect(grainL,"Out",xfade,"A")
  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(pUnit,"In1",xfade,"B")
  connect(pUnit,"In1",grainL,"In")
  connect(xfade,"Out",pUnit,"Out1")

  connect(tune,"Out",pitch,"In")
  connect(tune,"Out",tuneRange,"In")
  connect(pitch,"Out",multiply,"Left")
  connect(speed,"Out",multiply,"Right")
  connect(multiply,"Out",speedClipper,"In")
  connect(speed,"Out",speedRange,"In")
  connect(speedClipper,"Out",grainL,"Speed")

  connect(delayL,"Out",delayLClipper,"In")
  connect(delayL,"Out",delayLRange,"In")
  connect(delayLClipper,"Out",grainL,"Delay")

  -- register destinations
  self:addBranch("delay","Delay",delayL,"In")
  self:addBranch("speed","Speed", speed, "In")
  self:addBranch("V/oct","Pitch", tune, "In")
  self:addBranch("wet","Wet/Dry",fader,"In")
end

function GrainDelayUnit:loadStereoGraph(pUnit)
  -- create objects
  local grainL = self:createObject("MonoGrainDelay","grainL",1.0)
  local grainR = self:createObject("MonoGrainDelay","grainR",1.0)

  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")
  local multiply = self:createObject("Multiply","multiply")
  local pitch = self:createObject("VoltPerOctave","pitch")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local speed = self:createObject("GainBias","speed")
  speed:hardSet("Bias",1.0)
  local speedRange = self:createObject("MinMax","speedRange")
  local speedClipper = self:createObject("Clipper","speedClipper",-100,100)
  local delayL = self:createObject("GainBias","delayL")
  local delayLRange = self:createObject("MinMax","delayLRange")
  local delayLClipper = self:createObject("Clipper","delayLClipper",0,1)
  local delayR = self:createObject("GainBias","delayR")
  local delayRRange = self:createObject("MinMax","delayRRange")
  local delayRClipper = self:createObject("Clipper","delayRClipper",0,1)

  -- connect objects
  connect(grainL,"Out",xfade,"Left A")
  connect(grainR,"Out",xfade,"Right A")
  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(pUnit,"In1",xfade,"Left B")
  connect(pUnit,"In1",grainL,"In")

  connect(pUnit,"In2",xfade,"Right B")
  connect(pUnit,"In2",grainR,"In")

  connect(xfade,"Left Out",pUnit,"Out1")
  connect(xfade,"Right Out",pUnit,"Out2")

  connect(tune,"Out",pitch,"In")
  connect(tune,"Out",tuneRange,"In")
  connect(pitch,"Out",multiply,"Left")
  connect(speed,"Out",multiply,"Right")
  connect(multiply,"Out",speedClipper,"In")
  connect(speed,"Out",speedRange,"In")
  connect(speedClipper,"Out",grainL,"Speed")
  connect(speedClipper,"Out",grainR,"Speed")

  connect(delayL,"Out",delayLClipper,"In")
  connect(delayL,"Out",delayLRange,"In")
  connect(delayLClipper,"Out",grainL,"Delay")

  connect(delayR,"Out",delayRClipper,"In")
  connect(delayR,"Out",delayRRange,"In")
  connect(delayRClipper,"Out",grainR,"Delay")

  -- register destinations
  self:addBranch("delay(L)","Left Delay",delayL,"In")
  self:addBranch("delay(R)","Right Delay",delayR,"In")
  self:addBranch("speed","Speed", speed, "In")
  self:addBranch("V/oct","Pitch", tune, "In")
  self:addBranch("wet","Wet/Dry",fader,"In")
end

function GrainDelayUnit:onLoadViews(objects,controls)

  local views = {
    collapsed = {},
  }

  if self.channelCount==2 then

    views.expanded = {"leftDelay","rightDelay","pitch","speed","wet"}

    controls.leftDelay = GainBias {
      button = "delay(L)",
      branch = self:getBranch("Left Delay"),
      description = "Left Delay",
      gainbias = objects.delayL,
      range = objects.delayLRange,
      biasMap = Encoder.getMap("unit"),
      biasUnits = app.unitSecs
    }

    controls.rightDelay = GainBias {
      button = "delay(R)",
      branch = self:getBranch("Right Delay"),
      description = "Right Delay",
      gainbias = objects.delayR,
      range = objects.delayRRange,
      biasMap = Encoder.getMap("unit"),
      biasUnits = app.unitSecs
    }

  else

    views.expanded = {"delay","pitch","speed","wet"}

    controls.delay = GainBias {
      button = "delay",
      branch = self:getBranch("Delay"),
      description = "Delay",
      gainbias = objects.delayL,
      range = objects.delayLRange,
      biasMap = Encoder.getMap("unit"),
      biasUnits = app.unitSecs
    }
  end

  controls.pitch = PitchControl {
    button = "V/oct",
    description = "V/oct",
    branch = self:getBranch("Pitch"),
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.speed = GainBias {
    button = "speed",
    branch = self:getBranch("Speed"),
    description = "Speed",
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("speed"),
    biasUnits = app.unitNone
  }

  controls.wet = GainBias {
    button = "wet",
    branch = self:getBranch("Wet/Dry"),
    description = "Wet/Dry",
    gainbias = objects.fader,
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit")
  }

  return views
end

function GrainDelayUnit:deserialize(t)
  Unit.deserialize(self,t)
  -- v0.2.21: Changed Wet/Dry from ConstantOffset to GainBias
  local pData = t.objects.fader and t.objects.fader.params
  if pData and pData.Offset then
    local param = self.objects.fader and self.objects.fader:getParameter("Bias")
    if param then
      app.log("GrainDelayUnit:deserialize: porting legacy parameter, fader.Offset.")
      param:softSet(pData.Offset)
    end
  end
end

return GrainDelayUnit
