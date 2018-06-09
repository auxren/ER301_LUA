-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Comparator = require "Unit.ViewControl.Comparator"
local Fader = require "Unit.ViewControl.Fader"
local Encoder = require "Encoder"
local ply = app.SECTION_PLY

local AliasingSawUnit = Class{}
AliasingSawUnit:include(Unit)

function AliasingSawUnit:init(args)
  args.title = "Aliasing Saw"
  args.mnemonic = "Sw"
  Unit.init(self,args)
end

function AliasingSawUnit:onLoadGraph(pUnit,channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function AliasingSawUnit:loadMonoGraph(pUnit)
  -- create objects
  local osc = self:createObject("SawtoothOscillator","osc")
  local tune = self:createObject("ConstantOffset","tune")
  local tuneRange = self:createObject("MinMax","tuneRange")
  local f0 = self:createObject("GainBias","f0")
  local f0Range = self:createObject("MinMax","f0Range")
  local vca = self:createObject("Multiply","vca")
  local level = self:createObject("GainBias","level")
  local levelRange = self:createObject("MinMax","levelRange")

  local sync = self:createObject("Comparator","sync")
  sync:setTriggerMode()

  connect(sync,"Out",osc,"Sync")

  connect(tune,"Out",tuneRange,"In")
  connect(tune,"Out",osc,"V/Oct")

  connect(f0,"Out",osc,"Fundamental")
  connect(f0,"Out",f0Range,"In")

  connect(level,"Out",levelRange,"In")
  connect(level,"Out",vca,"Left")

  connect(osc,"Out",vca,"Right")
  connect(vca,"Out",pUnit,"Out1")

  self:addBranch("level","Level",level,"In")
  self:addBranch("V/oct","V/Oct",tune,"In")
  self:addBranch("sync","Sync",sync,"In")
  self:addBranch("f0","Fundamental",f0,"In")
end

function AliasingSawUnit:loadStereoGraph(pUnit)
  self:loadMonoGraph(pUnit)
  connect(self.objects.vca,"Out",pUnit,"Out2")
end

local views = {
  expanded = {"tune","freq","sync","level"},
  collapsed = {},
}

function AliasingSawUnit:onLoadViews(objects,controls)
  controls.tune = PitchControl {
    button = "V/oct",
    branch = self:getBranch("V/Oct"),
    description = "V/oct",
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.freq = GainBias {
    button = "f0",
    description = "Fundamental",
    branch = self:getBranch("Fundamental"),
    gainbias = objects.f0,
    range = objects.f0Range,
    biasMap = Encoder.getMap("oscFreq"),
    biasUnits = app.unitHertz,
    initialBias = 27.5,
    gainMap = Encoder.getMap("freqGain"),
    scaling = app.octaveScaling
  }

  controls.level = GainBias {
    button = "level",
    description = "Level",
    branch = self:getBranch("Level"),
    gainbias = objects.level,
    range = objects.levelRange,
    initialBias = 0.5,
  }

  controls.sync = Comparator {
    button = "sync",
    description = "Sync",
    branch = self:getBranch("Sync"),
    edge = objects.sync,
  }

  return views
end

function AliasingSawUnit:deserialize(t)
  Unit.deserialize(self,t)
  if self:getPresetVersion(t) < 1 then
    -- handle legacy preset (<v0.2.12)
    local Serialization = require "Persist.Serialization"
    local f0 = Serialization.get("objects/osc/params/Fundamental",t)
    if f0 then
      app.log("%s:deserialize:legacy preset detected:setting f0 bias to %s",self,f0)
      self.objects.f0:hardSet("Bias", f0)
    end
  end
end

return AliasingSawUnit
