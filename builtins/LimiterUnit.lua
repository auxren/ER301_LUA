-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local Fader = require "Unit.ViewControl.Fader"
local ModeSelect = require "Unit.ViewControl.ModeSelect"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local LimiterUnit = Class{}
LimiterUnit:include(Unit)

function LimiterUnit:init(args)
  args.title = "Limiter"
  args.mnemonic = "LR"
  Unit.init(self,args)
end

-- creation/destruction states

function LimiterUnit:onLoadGraph(pUnit, channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
  self.objects.inGain:hardSet("Gain",1.0)
  self.objects.outGain:hardSet("Gain",1.0)
end

function LimiterUnit:loadMonoGraph(pUnit)
  -- create objects
  local inGain = self:createObject("ConstantGain","inGain")
  local outGain = self:createObject("ConstantGain","outGain")
  local limiter = self:createObject("Limiter","limiter")
  -- connect inputs/outputs
  connect(pUnit,"In1",inGain,"In")
  connect(inGain,"Out",limiter,"In")
  connect(limiter,"Out",outGain,"In")
  connect(outGain,"Out",pUnit,"Out1")
end

function LimiterUnit:loadStereoGraph(pUnit)
  -- create objects
  local inGain1 = self:createObject("ConstantGain","inGain1")
  local outGain1 = self:createObject("ConstantGain","outGain1")
  local limiter1 = self:createObject("Limiter","limiter1")
  -- connect inputs/outputs
  connect(pUnit,"In1",inGain1,"In")
  connect(inGain1,"Out",limiter1,"In")
  connect(limiter1,"Out",outGain1,"In")
  connect(outGain1,"Out",pUnit,"Out1")

  -- create objects
  local inGain2 = self:createObject("ConstantGain","inGain2")
  local outGain2 = self:createObject("ConstantGain","outGain2")
  local limiter2 = self:createObject("Limiter","limiter2")
  -- connect inputs/outputs
  connect(pUnit,"In2",inGain2,"In")
  connect(inGain2,"Out",limiter2,"In")
  connect(limiter2,"Out",outGain2,"In")
  connect(outGain2,"Out",pUnit,"Out2")

  tie(inGain2,"Gain",inGain1,"Gain")
  self.objects.inGain = inGain1

  tie(outGain2,"Gain",outGain1,"Gain")
  self.objects.outGain = outGain1

  tie(limiter2,"Type",limiter1,"Type")
  self.objects.limiter = limiter1
end

local views = {
  expanded = {"pre","type","post"},
  collapsed = {},
}

function LimiterUnit:onLoadViews(objects,controls)

  controls.pre = Fader {
    button = "pre",
    description = "Pre-Gain",
    param = objects.inGain:getParameter("Gain"),
    monitor = self,
    map = Encoder.getMap("decibel36"),
    units = app.unitDecibels
  }

  controls.post = Fader {
    button = "post",
    description = "Post-Gain",
    param = objects.outGain:getParameter("Gain"),
    monitor = self,
    map = Encoder.getMap("decibel36"),
    units = app.unitDecibels
  }

  controls.type = ModeSelect {
    button = "o",
    description = "Type",
    option = objects.limiter:getOption("Type"),
    choices = {"inv sqrt","cubic","hard"}
  }

  if self.channelCount==1 then
    local outlet = objects.inGain:getOutput("Out")
    controls.pre:setMonoMeterTarget(outlet)
  else
    local left = objects.inGain1:getOutput("Out")
    local right = objects.inGain2:getOutput("Out")
    controls.pre:setStereoMeterTarget(left,right)
  end

  if self.channelCount==1 then
    local outlet = objects.outGain:getOutput("Out")
    controls.post:setMonoMeterTarget(outlet)
  else
    local left = objects.outGain1:getOutput("Out")
    local right = objects.outGain2:getOutput("Out")
    controls.post:setStereoMeterTarget(left,right)
  end

  return views
end

return LimiterUnit
