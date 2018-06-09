-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local ClockedDopplerDelay = Class{}
ClockedDopplerDelay:include(Unit)

function ClockedDopplerDelay:init(args)
  args.title = "Clocked Doppler Delay"
  args.mnemonic = "CD"
  Unit.init(self,args)
end

function ClockedDopplerDelay:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function ClockedDopplerDelay:loadMonoGraph(pUnit)
  -- create objects
  local delay = self:createObject("DopplerDelay","delay",2.0)
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

  local period = self:createObject("Constant","period")
  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  local split = self:createObject("Spread","split")

  local spread = self:createObject("GainBias","spread")
  local spreadRange = self:createObject("MinMax","spreadRange")

  tie(tap,"Multiplier",multiplier,"Out")
  tie(tap,"Divider",divider,"Out")
  tie(period,"Value",tap,"Derived Period")
  connect(period,"Out",split,"In")
  connect(split,"Left Out",delay,"Delay")
  connect(spread,"Out",split,"Spread")
  connect(spread,"Out",spreadRange,"In")

  -- connect objects
  connect(tapEdge,"Out",tap,"In")

  connect(delay,"Out",xfade,"A")
  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  connect(snap,"Out",feedback,"In")
  connect(feedback,"Out",delay,"Feedback")
  connect(feedback,"Out",feedbackRange,"In")

  connect(pUnit,"In1",xfade,"B")
  connect(pUnit,"In1",delay,"In")
  connect(xfade,"Out",pUnit,"Out1")

  self:addBranch("clock","Clock",tapEdge,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("mult","Multiplier",multiplier,"In")
  self:addBranch("div","Divider",divider,"In")
  self:addBranch("feedback","Feedback",snap,"In")
  self:addBranch("spread","Spread",spread,"In")
end

function ClockedDopplerDelay:loadStereoGraph(pUnit)
  -- create objects
  local delayL = self:createObject("DopplerDelay","delayL",2.0)
  local delayR = self:createObject("DopplerDelay","delayR",2.0)

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

  local period = self:createObject("Constant","period")
  local multiplier = self:createObject("ParameterAdapter","multiplier")
  local divider = self:createObject("ParameterAdapter","divider")
  local split = self:createObject("Spread","split")

  local spread = self:createObject("GainBias","spread")
  local spreadRange = self:createObject("MinMax","spreadRange")

  connect(tapEdge,"Out",tap,"In")
  tie(tap,"Multiplier",multiplier,"Out")
  tie(tap,"Divider",divider,"Out")
  tie(period,"Value",tap,"Derived Period")
  connect(period,"Out",split,"In")
  connect(split,"Left Out",delayL,"Delay")
  connect(split,"Right Out",delayR,"Delay")
  connect(spread,"Out",split,"Spread")
  connect(spread,"Out",spreadRange,"In")

  connect(delayL,"Out",xfade,"Left A")
  connect(delayR,"Out",xfade,"Right A")
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

  self:addBranch("clock","Clock",tapEdge,"In")
  self:addBranch("wet","Wet/Dry",fader,"In")
  self:addBranch("mult","Multiplier",multiplier,"In")
  self:addBranch("div","Divider",divider,"In")
  self:addBranch("feedback","Feedback",snap,"In")
  self:addBranch("spread","Spread",spread,"In")
end


local views = {
  expanded = {"clock","mult","div","spread","feedback","wet"},
  collapsed = {},
}


function ClockedDopplerDelay:onLoadViews(objects,controls)

  controls.clock = Comparator {
    button = "clock",
    branch = self:getBranch("Clock"),
    description = "Clock",
    edge = objects.tapEdge,
  }

  controls.mult = GainBias {
    button = "mult",
    branch = self:getBranch("Multiplier"),
    description = "Multiplier",
    gainbias = objects.multiplier,
    range = objects.multiplier,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1
  }

  controls.div = GainBias {
    button = "div",
    branch = self:getBranch("Divider"),
    description = "Divider",
    gainbias = objects.divider,
    range = objects.divider,
    biasMap = Encoder.getMap("int[1,32]"),
    gainMap = Encoder.getMap("[-20,20]"),
    initialBias = 1
  }

  -- other spots
  if self.channelCount==2 then

    controls.spread = GainBias {
      button = "spread",
      branch = self:getBranch("Spread"),
      description = "Stereo Spread",
      gainbias = objects.spread,
      range = objects.spreadRange,
      biasMap = Encoder.getMap("[-1,1]"),
    }

  else

    controls.spread = GainBias {
      button = "nudge",
      branch = self:getBranch("Spread"),
      description = "Nudge",
      gainbias = objects.spread,
      range = objects.spreadRange,
      biasMap = Encoder.getMap("[-1,1]"),
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

function ClockedDopplerDelay:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    -- v0.3.04: Changed Feedback from Constant to GainBias
    local pData = t.objects.feedback and t.objects.feedback.params
    if pData and pData.Value then
      local param = self.objects.feedback and self.objects.feedback:getParameter("Bias")
      if param then
        app.log("ClockedDopplerDelay:deserialize: porting legacy parameter, feedback.Value.")
        param:softSet(pData.Value)
      end
    end
  end
end

return ClockedDopplerDelay
