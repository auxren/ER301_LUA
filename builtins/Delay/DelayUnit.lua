-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local Utils = require "Utils"
local ply = app.SECTION_PLY

local DelayUnit = Class{}
DelayUnit:include(Unit)

function DelayUnit:init(args)
  args.title = "Delay"
  args.mnemonic = "D"
  Unit.init(self,args)
end

function DelayUnit:onLoadGraph(pUnit,channelCount)
  if channelCount>1 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function DelayUnit:loadMonoGraph(pUnit)
  local delay = self:createObject("Delay","delay",1)

  local secs = self:createObject("ParameterAdapter","secsL")

  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  connect(delay,"Left Out",xfade,"A")
  tie(delay,"Left Delay",secs,"Out")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delay,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"B")
  connect(pUnit,"In1",delay,"Left In")
  connect(xfade,"Out",pUnit,"Out1")

  self:addBranch("delay(L)","Left Delay",secs,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

function DelayUnit:loadStereoGraph(pUnit)
  local delay = self:createObject("Delay","delay",2)
  local secsL = self:createObject("ParameterAdapter","secsL")
  local secsR = self:createObject("ParameterAdapter","secsR")

  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  connect(delay,"Left Out",xfade,"Left A")
  tie(delay,"Left Delay",secsL,"Out")

  connect(delay,"Right Out",xfade,"Right A")
  tie(delay,"Right Delay",secsR,"Out")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delay,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"Left B")
  connect(pUnit,"In1",delay,"Left In")

  connect(pUnit,"In2",xfade,"Right B")
  connect(pUnit,"In2",delay,"Right In")

  connect(xfade,"Left Out",pUnit,"Out1")
  connect(xfade,"Right Out",pUnit,"Out2")

  self:addBranch("delay(L)","Left Delay",secsL,"In")
  self:addBranch("delay(R)","Right Delay",secsR,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

local function timeMap(max,n)
  local map = app.DialMap()
  map:clear(n+1)
  local scale = max/n
  for i=0,n do
    map:add(i*scale)
  end
  map:setZero(0,false)
  return map
end

function DelayUnit:setMaxDelayTime(secs)
  local requested = Utils.round(secs,1)
  local allocated = self.objects.delay:allocateTimeUpTo(requested)
  allocated = Utils.round(allocated,1)
  if allocated > 0 then
    local map = timeMap(allocated,100)
    self.controls.delayL:setBiasMap(app.unitSecs,map)
    self.controls.delayL:setFaderMap(app.unitSecs,map)
    if self.channelCount > 1 then
      self.controls.delayR:setBiasMap(app.unitSecs,map)
      self.controls.delayR:setFaderMap(app.unitSecs,map)
    end
  end
end

local menu = {
  "setHeader",
  "set100ms",
  "set1s",
  "set10s",
  "set30s",
  "infoHeader",
  "rename",
  "load",
  "save",
}

function DelayUnit:onLoadMenu(objects,controls)
  local allocated = self.objects.delay:maximumDelayTime()
  allocated = Utils.round(allocated,1)
  controls.setHeader = MenuHeader {
    description = string.format("Current Maximum Delay is %0.1fs.",allocated)
  }

  controls.set100ms = Task {
    description = "0.1s",
    task = function() self:setMaxDelayTime(0.1) end
  }

  controls.set1s = Task {
    description = "1s",
    task = function() self:setMaxDelayTime(1) end
  }

  controls.set10s = Task {
    description = "10s",
    task = function() self:setMaxDelayTime(10) end
  }

  controls.set30s = Task {
    description = "30s",
    task = function() self:setMaxDelayTime(30) end
  }

  return menu
end

local views = {
  expanded = {"delayL","delayR","feedback","wet"},
  collapsed = {},
}

function DelayUnit:onLoadViews(objects,controls)

  if self.channelCount>1 then
    controls.delayL = GainBias {
      button = "delay(L)",
      branch = self:getBranch("Left Delay"),
      description = "Left Delay",
      gainbias = objects.secsL,
      range = objects.secsL,
      biasMap = Encoder.getMap("unit"),
      biasUnits = app.unitSecs
    }

    controls.delayR = GainBias {
      button = "delay(R)",
      branch = self:getBranch("Right Delay"),
      description = "Right Delay",
      gainbias = objects.secsR,
      range = objects.secsR,
      biasMap = Encoder.getMap("unit"),
      biasUnits = app.unitSecs
    }
  else
    controls.delayL = GainBias {
      button = "delay",
      branch = self:getBranch("Left Delay"),
      description = "Delay",
      gainbias = objects.secsL,
      range = objects.secsL,
      biasMap = Encoder.getMap("unit"),
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

  self:setMaxDelayTime(1.0)

  return views
end

function DelayUnit:deserializeLegacyPreset(t)
  local Serialization = require "Persist.Serialization"
  -- v0.3.09: Changed Feedback from Constant to GainBias
  local fdbk = Serialization.get("objects/feedback/params/Value",t)
  if fdbk then
    app.log("%s:deserialize:legacy preset detected:setting feedback bias to %s",self,fdbk)
    self.objects.feedback:hardSet("Bias",fdbk)
  end
  -- v0.3.09: Changed Wet/Dry from Constant to GainBias
  local wet = Serialization.get("objects/fader/params/Value",t)
  if wet then
    app.log("%s:deserialize:legacy preset detected:setting wet bias to %s",self,wet)
    self.objects.fader:hardSet("Bias",wet)
  end
  -- v0.3.09: Changed Delay from parameter to ParameterAdapter
  local delay = Serialization.get("objects/delay/params/Delay",t)
  if delay then
    app.log("%s:deserialize:legacy preset detected:setting delay bias to %s",self,delay)
    self.objects.secsL:hardSet("Bias",delay)
    if self.channelCount>1 then
      self.objects.secsR:hardSet("Bias",delay)
    end
  end
  local delayL = Serialization.get("objects/delayL/params/Delay",t)
  if delayL then
    app.log("%s:deserialize:legacy preset detected:setting delayL bias to %s",self,delayL)
    self.objects.secsL:hardSet("Bias",delayL)
  end
  if self.channelCount>1 then
    local delayR = Serialization.get("objects/delayR/params/Delay",t)
    if delayR then
      app.log("%s:deserialize:legacy preset detected:setting delayR bias to %s",self,delayR)
      self.objects.secsR:hardSet("Bias",delayR)
    end
  end
end

function DelayUnit:serialize()
  local t = Unit.serialize(self)
  t.maximumDelayTime = self.objects.delay:maximumDelayTime()
  return t
end

function DelayUnit:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    self:deserializeLegacyPreset(t)
  end
  local time = t.maximumDelayTime
  if time and time > 0 then
    self:setMaxDelayTime(time)
  end
end

function DelayUnit:onRemove()
  self.objects.delay:deallocate()
  Unit.onRemove(self)
end

return DelayUnit
