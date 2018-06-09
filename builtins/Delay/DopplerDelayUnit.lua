-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY
local aliases = {
  secs = {"secsL", "secsR"},
  secsL = {"secsL"}
}

local DopplerDelayUnit = Class{}
DopplerDelayUnit:include(Unit)

function DopplerDelayUnit:init(args)
  args.title = "Doppler Delay"
  args.mnemonic = "DD"
  args.aliases = aliases
  Unit.init(self,args)
end

function DopplerDelayUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function DopplerDelayUnit:loadMonoGraph(pUnit)
  -- create objects
  local delay = self:createObject("DopplerDelay","delay",2.0)
  local secs = self:createObject("GainBias","secs")
  local secsRange = self:createObject("MinMax","secsRange")

  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  -- connect objects
  connect(delay,"Out",xfade,"A")
  connect(secs,"Out",delay,"Delay")
  connect(secs,"Out",secsRange,"In")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delay,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"B")
  connect(pUnit,"In1",delay,"In")
  connect(xfade,"Out",pUnit,"Out1")

  self:addBranch("delay","Delay",secs,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

function DopplerDelayUnit:loadStereoGraph(pUnit)
  -- create objects
  local delayL = self:createObject("DopplerDelay","delayL",2.0)
  local secsL = self:createObject("GainBias","secsL")
  local secsLRange = self:createObject("MinMax","secsLRange")

  local delayR = self:createObject("DopplerDelay","delayR",2.0)
  local secsR = self:createObject("GainBias","secsR")
  local secsRRange = self:createObject("MinMax","secsRRange")

  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  -- connect objects
  connect(delayL,"Out",xfade,"Left A")
  connect(secsL,"Out",delayL,"Delay")
  connect(secsL,"Out",secsLRange,"In")

  connect(delayR,"Out",xfade,"Right A")
  connect(secsR,"Out",delayR,"Delay")
  connect(secsR,"Out",secsRRange,"In")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delayL,"Feedback")
  connect(feedback,"Out",delayR,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"Left B")
  connect(pUnit,"In1",delayL,"In")

  connect(pUnit,"In2",xfade,"Right B")
  connect(pUnit,"In2",delayR,"In")

  connect(xfade,"Left Out",pUnit,"Out1")
  connect(xfade,"Right Out",pUnit,"Out2")

  self:addBranch("delay(L)","Left Delay",secsL,"In")
  self:addBranch("delay(R)","Right Delay",secsR,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

function DopplerDelayUnit:onLoadViews(objects,controls)

  local views = {
    collapsed = {},
  }

  if self.channelCount==2 then

    views.expanded = {"leftDelay","rightDelay","feedback","wet"}

    controls.leftDelay = GainBias {
      button = "delay(L)",
      branch = self:getBranch("Left Delay"),
      description = "Left Delay",
      gainbias = objects.secsL,
      range = objects.secsLRange,
      biasMap = Encoder.getMap("[0,2]"),
      biasUnits = app.unitSecs
    }

    controls.rightDelay = GainBias {
      button = "delay(R)",
      branch = self:getBranch("Right Delay"),
      description = "Right Delay",
      gainbias = objects.secsR,
      range = objects.secsRRange,
      biasMap = Encoder.getMap("[0,2]"),
      biasUnits = app.unitSecs
    }

  else

    views.expanded = {"delay","feedback","wet"}

    controls.delay = GainBias {
      button = "delay",
      branch = self:getBranch("Delay"),
      description = "Delay",
      gainbias = objects.secs,
      range = objects.secsRange,
      biasMap = Encoder.getMap("[0,2]"),
      biasUnits = app.unitSecs
    }
  end

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = self:getBranch("Feedback"),
    gainbias = objects.feedback,
    range = objects.feedbackRange,
    biasMap = Encoder.getMap("feedback"),
    biasUnits = app.unitDecibels
  }
  controls.feedback:setTextBelow(-35.9,"-inf dB")

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

function DopplerDelayUnit:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    -- v0.1.5p10: Changed Wet/Dry from ConstantOffset to GainBias
    local pData = t.objects.fader and t.objects.fader.params
    if pData and pData.Offset then
      local param = self.objects.fader and self.objects.fader:getParameter("Bias")
      if param then
        app.log("DopplerDelayUnit:deserialize: porting legacy parameter, fader.Offset.")
        param:softSet(pData.Offset)
      end
    end
    -- v0.3.04: Changed Feedback from ConstantOffset to GainBias
    local pData = t.objects.feedback and t.objects.feedback.params
    if pData and pData.Offset then
      local param = self.objects.feedback and self.objects.feedback:getParameter("Bias")
      if param then
        app.log("DopplerDelayUnit:deserialize: porting legacy parameter, feedback.Offset.")
        param:softSet(pData.Offset)
      end
    end
  end
end

return DopplerDelayUnit
