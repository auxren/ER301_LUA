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

local SpreadDelayUnit = Class{}
SpreadDelayUnit:include(Unit)

function SpreadDelayUnit:init(args)
  args.title = "Spread Delay"
  args.mnemonic = "SD"
  Unit.init(self,args)
end

function SpreadDelayUnit:onLoadGraph(pUnit,channelCount)
  if channelCount~=2 then
    app.error("%s: can only load into a stereo chain.")
  end

  -- create objects
  local delay = self:createObject("Delay","delay",2)

  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local snap = self:createObject("SnapToZero","snap")
  snap:setThresholdInDecibels(-35.9)

  local secs = self:createObject("ParameterAdapter","secs")
  local spread = self:createObject("ParameterAdapter","spread")

  tie(delay,"Left Delay",secs,"Out")
  tie(delay,"Right Delay",secs,"Out")
  tie(delay,"Spread",spread,"Out")

  -- connect objects
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

  self:addBranch("delay","Delay",secs,"In")
  self:addBranch("spread","Spread",spread,"In")
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

function SpreadDelayUnit:setMaxDelayTime(secs)
  local requested = math.floor(secs + 0.5)
  local allocated = self.objects.delay:allocateTimeUpTo(requested)
  allocated = math.floor(allocated + 0.5)
  if allocated > 0 then
    local map = timeMap(allocated,100)
    self.controls.delay:setBiasMap(app.unitSecs,map)
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

function SpreadDelayUnit:onLoadMenu(objects,controls)
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

function SpreadDelayUnit:onLoadViews(objects,controls)
  local views = {
    collapsed = {},
    expanded = {"delay","spread","feedback","wet"}
  }

  controls.delay = GainBias {
    button = "delay",
    branch = self:getBranch("Delay"),
    description = "Delay",
    gainbias = objects.secs,
    range = objects.secs,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs
  }

  controls.spread = GainBias {
    button = "spread",
    branch = self:getBranch("Spread"),
    description = "Stereo Spread",
    gainbias = objects.spread,
    range = objects.spread,
    biasMap = Encoder.getMap("[-1,1]"),
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

function SpreadDelayUnit:serialize()
  local t = Unit.serialize(self)
  t.maximumDelayTime = self.objects.delay:maximumDelayTime()
  return t
end

function SpreadDelayUnit:deserialize(t)
  Unit.deserialize(self,t)
  local time = t.maximumDelayTime
  if time and time > 0 then
    self:setMaxDelayTime(time)
  end
end

local function factory(args)
  local chain = args.chain or app.error("SpreadDelayUnit.factory: chain is missing.")
  if chain.channelCount==2 then
    return SpreadDelayUnit(args)
  else
    local Factory = require "Unit.Factory"
    local loadInfo = Factory.getBuiltin("Delay.DelayUnit")
    return Factory.instantiate(loadInfo,args)
  end
end

return factory
