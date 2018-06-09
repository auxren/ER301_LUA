-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local BranchMeter = require "Unit.ViewControl.BranchMeter"
local GainBias = require "Unit.ViewControl.GainBias"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local MixerUnit = Class{}
MixerUnit:include(Unit)

function MixerUnit:init(args)
  args.title = "Mixer Channel"
  args.mnemonic = "Mx"
  Unit.init(self,args)
end

function MixerUnit:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function MixerUnit:loadMonoGraph(pUnit)
  -- create objects
  local sum = self:createObject("Sum","sum")
  local gain = self:createObject("ConstantGain","gain")
  gain:setClampInDecibels(-59.9)
  gain:hardSet("Gain",1.0)

  -- connect objects
  connect(pUnit,"In1",sum,"Left")
  connect(gain,"Out",sum,"Right")
  connect(sum,"Out",pUnit,"Out1")

  -- register exported ports
  self:addBranch("input","Input", gain, "In")
end

function MixerUnit:loadStereoGraph(pUnit)
  -- create objects
  local sum1 = self:createObject("Sum","sum1")
  local gain1 = self:createObject("ConstantGain","gain1")
  gain1:setClampInDecibels(-59.9)
  gain1:hardSet("Gain",1.0)
  local sum2 = self:createObject("Sum","sum2")
  local gain2 = self:createObject("ConstantGain","gain2")
  gain2:setClampInDecibels(-59.9)
  gain2:hardSet("Gain",1.0)
  local balance = self:createObject("StereoPanner","balance")
  local pan = self:createObject("GainBias","pan")
  local panRange = self:createObject("MinMax","panRange")

  -- connect objects
  connect(pUnit,"In1",sum1,"Left")
  connect(gain1,"Out",balance,"Left In")
  connect(balance,"Left Out",sum1,"Right")
  connect(sum1,"Out",pUnit,"Out1")

  connect(pUnit,"In2",sum2,"Left")
  connect(gain2,"Out",balance,"Right In")
  connect(balance,"Right Out",sum2,"Right")
  connect(sum2,"Out",pUnit,"Out2")

  connect(pan,"Out",balance,"Pan")
  connect(pan,"Out",panRange,"In")

  tie(gain2,"Gain",gain1,"Gain")

  -- register exported ports
  self:addBranch("input","Input", gain1, "In", gain2, "In")
  self:addBranch("pan","Pan", pan, "In")

  -- alias
  self.objects.gain = self.objects.gain1
end

function MixerUnit:onLoadViews(objects,controls)
  local views = {
    expanded = {"gain"},
    collapsed = {},
  }

  controls.gain = BranchMeter {
    button = "gain",
    branch = self:getBranch("Input"),
    faderParam = objects.gain:getParameter("Gain")
  }
  self:addToMuteGroup(controls.gain)

  if objects.pan then
    controls.pan = GainBias {
      button = "pan",
      branch = self:getBranch("Pan"),
      description = "Pan",
      gainbias = objects.pan,
      range = objects.panRange,
      biasMap = Encoder.getMap("default"),
    }
    views.expanded[2] = "pan"
  end

  return views
end

function MixerUnit:serialize()
  local t = Unit.serialize(self)
  t.mute = self.controls.gain:isMuted()
  t.solo = self.controls.gain:isSolo()
  return t
end

function MixerUnit:deserialize(t)
  Unit.deserialize(self,t)
  if t.mute then
    self.controls.gain:mute()
  end
  if t.solo then
    self.controls.gain:solo()
  end
end

return MixerUnit
