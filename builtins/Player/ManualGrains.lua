-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Env = require "Env"
local Class = require "Base.Class"
local Unit = require "Unit"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Slices = require "Sample.Slices"
local Encoder = require "Encoder"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local ply = app.SECTION_PLY

-- Player
local ManualGrains = Class{}
ManualGrains:include(Unit)

local id = 1

function ManualGrains:init(args)
  args.title = "Manual Grains"
  args.mnemonic = "MG"
  Unit.init(self,args)
end

function ManualGrains:onLoadGraph(pUnit,channelCount)
  local head = self:createObject("GranularHead","head",channelCount)

  local start = self:createObject("ParameterAdapter","start")
  local duration = self:createObject("ParameterAdapter","duration")
  duration:hardSet("Bias",0.1)
  local gain = self:createObject("ParameterAdapter","gain")
  local squash = self:createObject("ParameterAdapter","squash")
  tie(head,"Duration",duration,"Out")
  tie(head,"Start",start,"Out")
  tie(head,"Gain",gain,"Out",head,"Gain")
  tie(head,"Squash",squash,"Out")

  local trig = self:createObject("Comparator","trig")
  local speed = self:createObject("GainBias","speed")
  local tune = self:createObject("ConstantOffset","tune")
  local pitch = self:createObject("VoltPerOctave","pitch")
  local multiply = self:createObject("Multiply","multiply")
  local clipper = self:createObject("Clipper","clipper")
  clipper:setMaximum(64.0)
  clipper:setMinimum(-64.0)

  local tuneRange = self:createObject("MinMax","tuneRange")
  local speedRange = self:createObject("MinMax","speedRange")

    -- Pitch and Linear FM
  connect(tune,"Out",pitch,"In")
  connect(tune,"Out",tuneRange,"In")
  connect(pitch,"Out",multiply,"Left")
  connect(speed,"Out",multiply,"Right")
  connect(speed,"Out",speedRange,"In")
  connect(multiply,"Out",clipper,"In")
  connect(clipper,"Out",head,"Speed")

  connect(trig,"Out",head,"Trigger")
  connect(head,"Left Out",pUnit,"Out1")

  self:addBranch("speed","Speed", speed, "In")
  self:addBranch("V/oct","Pitch", tune, "In")
  self:addBranch("trig","Trigger", trig, "In")
  self:addBranch("start","Start", start, "In")
  self:addBranch("dur","Duration", duration, "In")
  self:addBranch("gain","Gain", gain, "In")
  self:addBranch("squash","Squash", squash, "In")

  if channelCount>1 then
    local pan = self:createObject("ParameterAdapter","pan")
    tie(head,"Pan",pan,"Out")
    connect(head,"Right Out",pUnit,"Out2")
    self:addBranch("pan","Pan", pan, "In")
  end

end

function ManualGrains:serialize()
  local t = Unit.serialize(self)
  local sample = self.sample
  if sample then
    t.sample = SamplePool.serializeSample(sample)
  end
  return t
end

function ManualGrains:deserialize(t)
  Unit.deserialize(self,t)
  if t.sample then
    local sample = SamplePool.deserializeSample(t.sample)
    if sample then
      self:setSample(sample)
    else
      local Utils = require "Utils"
      app.log("%s:deserialize: failed to load sample.",self)
      Utils.pp(t.sample)
    end
  end
end

function ManualGrains:setSample(sample)
  if self.sample then
    self.sample:release()
    self.sample = nil
  end

  -- construct a new slices object when the sample changes
  if sample==nil or sample:getChannelCount()==0 then
    self.objects.head:setSample(nil)
  else
    self.objects.head:setSample(sample.pSample)
    self.sample = sample
    self.sample:claim()
  end
end

function ManualGrains:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function ManualGrains:doAttachSampleFromCard()
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached sample: %s",sample.name)
      self:setSample(sample)
    end
  end
  local Pool = require "Sample.Pool"
  Pool.chooseFileFromCard(self.loadInfo.id,task)
end

function ManualGrains:doAttachSampleFromPool()
  local chooser = SamplePoolInterface(self.loadInfo.id)
  chooser:setDefaultChannelCount(self.channelCount)
  chooser:highlight(self.sample)
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached sample: %s",sample.name)
      self:setSample(sample)
    end
  end
  chooser:subscribe("done",task)
  chooser:activate()
end

local menu = {
  "sampleHeader",
  "pool",
  "card",
  "detach",

  "infoHeader",
  "rename",
  "load",
  "save"
}

function ManualGrains:onLoadMenu(objects,controls)

  controls.sampleHeader = MenuHeader {
    description = "Sample Menu"
  }

  controls.pool = Task {
    description = "Select from Card",
    task = function() self:doAttachSampleFromCard() end
  }

  controls.card = Task {
    description = "Select from Pool",
    task = function() self:doAttachSampleFromPool() end
  }

  controls.detach = Task {
    description = "Detach",
    task = function() self:doDetachSample() end
  }

  local sub = {}
  if self.sample then
    sub[1] = {
      position = app.GRID5_LINE1,
      justify = app.justifyLeft,
      text = "Attached Sample:"
    }
    sub[2] = {
      position = app.GRID5_LINE2,
      justify = app.justifyLeft,
      text = "+ "..self.sample:getFilenameForDisplay(24)
    }
    sub[3] = {
      position = app.GRID5_LINE3,
      justify = app.justifyLeft,
      text = "+ "..self.sample:getDurationText()
    }
    sub[4] = {
      position = app.GRID5_LINE4,
      justify = app.justifyLeft,
      text = string.format("+ %s %s %s",self.sample:getChannelText(), self.sample:getSampleRateText(), self.sample:getMemorySizeText())
    }
  else
    sub[1] = {
      position = app.GRID5_LINE3,
      justify = app.justifyCenter,
      text = "No sample attached."
    }
  end

  return menu, sub
end

function ManualGrains:onLoadViews(objects,controls)

  controls.pitch = PitchControl {
    button = "V/oct",
    description = "V/oct",
    branch = self:getBranch("Pitch"),
    offset = objects.tune,
    range = objects.tuneRange
  }

  controls.speed = GainBias {
    button = "speed",
    description = "Speed",
    branch = self:getBranch("Speed"),
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("speed"),
    initialBias = 1.0
  }

  controls.trigger = Comparator {
    button = "trig",
    description = "Trigger",
    branch = self:getBranch("Trigger"),
    edge = objects.trig,
  }

  controls.start = GainBias {
    button = "start",
    description = "Start",
    branch = self:getBranch("Start"),
    gainbias = objects.start,
    range = objects.start,
    biasMap = Encoder.getMap("unit"),
  }

  controls.duration = GainBias {
    button = "dur",
    description = "Duration",
    branch = self:getBranch("Duration"),
    gainbias = objects.duration,
    range = objects.duration,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs
  }

  controls.gain = GainBias {
    button = "gain",
    description = "Gain",
    branch = self:getBranch("Gain"),
    gainbias = objects.gain,
    range = objects.gain,
    initialBias = 1.0
  }

  controls.squash = GainBias {
    button = "squash",
    description = "Squash",
    branch = self:getBranch("Squash"),
    gainbias = objects.squash,
    range = objects.squash,
    biasMap = Encoder.getMap("gain36dB"),
    biasUnits = app.unitDecibels,
    initialBias = 1.0
  }

  if objects.pan then
    controls.pan = GainBias {
      button = "pan",
      branch = self:getBranch("Pan"),
      description = "Pan",
      gainbias = objects.pan,
      range = objects.pan,
      biasMap = Encoder.getMap("default"),
      biasUnits = app.unitNone,
    }

    return {
      expanded = {"trigger","pitch","speed","start","duration","pan","gain","squash"},
      collapsed = {},
    }
  else
    return {
      expanded = {"trigger","pitch","speed","start","duration","gain","squash"},
      collapsed = {},
    }
  end
end

function ManualGrains:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end

return ManualGrains
