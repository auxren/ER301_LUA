-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local Utils = require "Utils"
local ply = app.SECTION_PLY

local ClockedDelayUnit = Class{}
ClockedDelayUnit:include(Unit)

function ClockedDelayUnit:init(args)
  args.title = "Clocked Delay"
  args.mnemonic = "CD"
  Unit.init(self,args)
end

function ClockedDelayUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function ClockedDelayUnit:loadMonoGraph(pUnit)
  -- create objects
  local delay = self:createObject("Delay","delay",1)
  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  local tap = self:createObject("TapTempo","tap")
  tap:setBaseTempo(120)
  local tapEdge = self:createObject("Comparator","tapEdge")

  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  tie(tap,"Multiplier",multiplier,"Out")
  tie(tap,"Divider",divider,"Out")

  local nudge = self:createObject("ParameterAdapter","nudge")
  tie(delay,"Left Delay",tap,"Derived Period")
  tie(delay,"Spread",nudge,"Out")

  -- connect objects
  connect(tapEdge,"Out",tap,"In")

  connect(delay,"Left Out",xfade,"A")
  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delay,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"B")
  connect(pUnit,"In1",delay,"Left In")
  connect(xfade,"Out",pUnit,"Out1")

  self:addBranch("clock","Clock",tapEdge,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")
  self:addBranch("nudge","Nudge",nudge,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

function ClockedDelayUnit:loadStereoGraph(pUnit)
  -- create objects
  local delay = self:createObject("Delay","delay",2)

  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  local tap = self:createObject("TapTempo","tap")
  tap:setBaseTempo(120)
  local tapEdge = self:createObject("Comparator","tapEdge")

  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  tie(tap,"Multiplier",multiplier,"Out")
  tie(tap,"Divider",divider,"Out")

  local spread = self:createObject("ParameterAdapter","spread")
  tie(delay,"Left Delay",tap,"Derived Period")
  tie(delay,"Right Delay",tap,"Derived Period")
  tie(delay,"Spread",spread,"Out")

  -- connect objects
  connect(tapEdge,"Out",tap,"In")

  connect(delay,"Left Out",xfade,"Left A")
  connect(delay,"Right Out",xfade,"Right A")
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

  self:addBranch("clock","Clock",tapEdge,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("multiplier","Multiplier",multiplier,"In")
  self:addBranch("divider","Divider",divider,"In")
  self:addBranch("spread","Spread",spread,"In")
  self:addBranch("feedback","Feedback",snap,"In")
end

function ClockedDelayUnit:setMaxDelayTime(secs)
  local requested = math.floor(secs + 0.5)
  self.objects.delay:allocateTimeUpTo(requested)
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

function ClockedDelayUnit:onLoadMenu(objects,controls)
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

function ClockedDelayUnit:onLoadViews(objects,controls)

  local views = {
    collapsed = {},
  }

  controls.clock = Comparator {
    button = "clock",
    branch = self:getBranch("Clock"),
    description = "Clock",
    edge = objects.tapEdge,
  }

  -- other spots
  if self.channelCount==2 then

    views.expanded = {"clock","mult","div","spread","feedback","wet"}

    controls.spread = GainBias {
      button = "spread",
      branch = self:getBranch("Spread"),
      description = "Stereo Spread",
      gainbias = objects.spread,
      range = objects.spread,
      biasMap = Encoder.getMap("[-1,1]"),
    }

  else
    views.expanded = {"clock","mult","div","nudge","feedback","wet"}

    controls.nudge = GainBias {
      button = "nudge",
      branch = self:getBranch("Nudge"),
      description = "Nudge",
      gainbias = objects.nudge,
      range = objects.nudge,
      biasMap = Encoder.getMap("[-1,1]"),
    }

  end

  controls.mult = GainBias {
    button = "mult",
    branch = self:getBranch("Multiplier"),
    description = "Clock Multiplier",
    gainbias = objects.multiplier,
    range = objects.multiplier,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasUnits = app.unitInteger
  }

  controls.div = GainBias {
    button = "div",
    branch = self:getBranch("Divider"),
    description = "Clock Divider",
    gainbias = objects.divider,
    range = objects.divider,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1,
    biasUnits = app.unitInteger
  }

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

function ClockedDelayUnit:deserializeLegacyPreset(t)
  -- v0.3.04: Changed Feedback from Constant to GainBias
  local pData = t.objects.feedback and t.objects.feedback.params
  if pData and pData.Value then
    local param = self.objects.feedback and self.objects.feedback:getParameter("Bias")
    if param then
      app.log("ClockedDelayUnit:deserialize: porting legacy parameter, feedback.Value.")
      param:softSet(pData.Value)
    end
  end
end

function ClockedDelayUnit:serialize()
  local t = Unit.serialize(self)
  t.maximumDelayTime = self.objects.delay:maximumDelayTime()
  return t
end

function ClockedDelayUnit:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    self:deserializeLegacyPreset(t)
  end
  local time = t.maximumDelayTime
  if time and time > 0 then
    self:setMaxDelayTime(time)
  end
end

return ClockedDelayUnit
