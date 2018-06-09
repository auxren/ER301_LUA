-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Env = require "Env"
local Class = require "Base.Class"
local Unit = require "Unit"
local SlicingView = require "SlicingView"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Slices = require "Sample.Slices"
local Encoder = require "Encoder"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local PitchControl = require "Unit.ViewControl.PitchControl"
local GainBias = require "Unit.ViewControl.GainBias"
local WaveForm = require "builtins.Player.WaveForm"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local ply = app.SECTION_PLY

-- Player
local GrainPlayer = Class{}
GrainPlayer:include(Unit)

local id = 1

function GrainPlayer:init(args)
  args.title = "Grain Stretch"
  args.mnemonic = "GS"
  Unit.init(self,args)
end

function GrainPlayer:onLoadGraph(pUnit,channelCount)
  local head = self:createObject("GrainStretch","head",channelCount,8)
  local trig = self:createObject("Comparator","trig")
  local tune = self:createObject("ParameterAdapter","tune")
  tune:hardSet("Gain",1.0)
  local duration = self:createObject("ParameterAdapter","duration")
  local speed = self:createObject("GainBias","speed")
  speed:hardSet("Bias",1.0)
  local slice = self:createObject("GainBias","slice")
  local shift = self:createObject("GainBias","shift")
  local sliceRange = self:createObject("MinMax","sliceRange")
  local shiftRange = self:createObject("MinMax","shiftRange")
  local speedRange = self:createObject("MinMax","speedRange")

  tie(head,"Grain Pitch",tune,"Out")
  tie(head,"Grain Duration",duration,"Out")

  connect(speed,"Out",head,"Speed")
  connect(speed,"Out",speedRange,"In")

  connect(trig,"Out",head,"Trigger")

  connect(slice,"Out",head,"Slice Select")
  connect(slice,"Out",sliceRange,"In")
  connect(shift,"Out",head,"Slice Shift")
  connect(shift,"Out",shiftRange,"In")

  connect(head,"Left Out",pUnit,"Out1")

  self:addBranch("speed","Speed", speed, "In")
  self:addBranch("V/oct","Pitch", tune, "In")
  self:addBranch("duration","Duration", duration, "In")
  self:addBranch("trig","Trigger", trig, "In")
  self:addBranch("slice","Slice Select",slice,"In")
  self:addBranch("shift","Slice Shift",shift,"In")

  if channelCount>1 then
    connect(head,"Right Out",pUnit,"Out2")
  end

end

function GrainPlayer:serialize()
  local t = Unit.serialize(self)
  local sample = self.sample
  if sample then
    t.sample = SamplePool.serializeSample(sample)
    local head = self.objects.head
    t.activeSliceIndex = head:getActiveSliceIndex()
    t.activeSliceShift = head:getActiveSliceShift()
    t.samplePosition = head:getPosition()
  end
  return t
end

function GrainPlayer:deserialize(t)
  Unit.deserialize(self,t)
  if t.sample then
    local sample = SamplePool.deserializeSample(t.sample)
    if sample then
      self:setSample(sample)
      local head = self.objects.head
      local sliceIndex = t.activeSliceIndex
      local sliceShift = t.activeSliceShift or 0
      local samplePosition = t.samplePosition
      if sliceIndex and samplePosition then
        head:setActiveSlice(sliceIndex,sliceShift)
        head:setPosition(samplePosition)
      end
    else
      local Utils = require "Utils"
      app.log("%s:deserialize: failed to load sample.",self)
      Utils.pp(t.sample)
    end
  end
end

function GrainPlayer:setSample(sample)
  if self.sample then
    self.sample:release()
    self.sample = nil
  end
  self.sample = sample
  if self.sample then
    self.sample:claim()
  end

  -- construct a new slices object when the sample changes
  if sample==nil or sample:getChannelCount()==0 then
    self.objects.head:setSample(nil)
    self.objects.head:setSlices(nil)
  else
    self.objects.head:setSample(sample.pSample)
    self.objects.head:setSlices(sample.slices.pSlices)
  end

  if self.slicingView then
    self.slicingView:setPlayHead(self.objects.head)
    self.slicingView:setSample(sample)
  end
  self:notifyControls("setPlayHead",self.objects.head)
  self:notifyControls("setSample",sample)
end

function GrainPlayer:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function GrainPlayer:doAttachSampleFromCard()
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

function GrainPlayer:doAttachSampleFromPool()
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

function GrainPlayer:showSlicingView()
  if self.sample then
    if self.slicingView==nil then
      self.slicingView = SlicingView(self)
      self.slicingView:setPlayHead(self.objects.head)
      self.slicingView:setSample(self.sample)
    end
    self.slicingView:activate()
  else
    local SystemGraphic = require "SystemGraphic"
    SystemGraphic.mainFlashMessage("You must first select a sample.")
  end
end

local menu = {
  "sampleHeader",
  "pool",
  "card",
  "detach",
  "slice",

  "optionsHeader",
  "howOften",
  "howMuch",
  "polarity",
  "address",

  "infoHeader","rename","load","save"
}

function GrainPlayer:onLoadMenu(objects,controls)

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

  controls.slice = Task {
    description = "Slice",
    task = function() self:showSlicingView() end
  }

  controls.optionsHeader = MenuHeader {
    description = "Playback Options"
  }

  controls.howOften = ModeSelect {
    description = "Play Count",
    option = objects.head:getOption("How Often"),
    choices = {"once","loop"}
  }

  controls.howMuch = ModeSelect {
    description = "Play Extent",
    option = objects.head:getOption("How Much"),
    choices = {"all", "slice"},
  }

  controls.polarity = ModeSelect {
    description = "Slice Polarity",
    option = objects.head:getOption("Polarity"),
    choices = {"left","both","right"}
  }

  controls.address = ModeSelect {
    description = "CV-to-Slice Mapping",
    option = objects.head:getOption("Address"),
    choices = {"nearest","index","12TET"},
    descriptionWidth = 2
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

local views = {
  expanded = {"pitch","speed","trigger","slice","shift","duration","jitter"},
  collapsed = {},
  pitch = {"wave","pitch"},
  speed = {"wave","speed"},
  trigger = {"wave","trigger"},
  slice = {"wave","slice"},
  shift = {"wave","shift"},
  duration = {"wave","duration"},
  jitter = {"wave","jitter"},
}

function GrainPlayer:onLoadViews(objects,controls)
  controls.pitch = PitchControl {
    button = "V/oct",
    description = "V/oct",
    branch = self:getBranch("Pitch"),
    offset = objects.tune,
    range = objects.tune
  }

  controls.speed = GainBias {
    button = "speed",
    description = "Speed",
    branch = self:getBranch("Speed"),
    gainbias = objects.speed,
    range = objects.speedRange,
    biasMap = Encoder.getMap("[-10,10]"),
    --biasMap = Encoder.getMap("speedFactors"),
  }

  controls.trigger = Comparator {
    button = "trig",
    description = "Trigger",
    branch = self:getBranch("Trigger"),
    edge = objects.trig,
  }

  controls.slice = GainBias {
    button = "slice",
    description = "Slice Select",
    branch = self:getBranch("Slice Select"),
    gainbias = objects.slice,
    range = objects.sliceRange,
    biasMap = Encoder.getMap("unit"),
  }

  controls.shift = GainBias {
    button = "shift",
    description = "Slice Shift",
    branch = self:getBranch("Slice Shift"),
    gainbias = objects.shift,
    range = objects.shiftRange,
    biasMap = Encoder.getMap("[-5,5]"),
    biasUnits = app.unitSecs
  }

  controls.duration = GainBias {
    button = "dur",
    description = "Duration",
    branch = self:getBranch("Duration"),
    gainbias = objects.duration,
    range = objects.duration,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitSecs,
    initialBias = 0.07
  }

  controls.jitter = Fader {
    button = "jitter",
    description = "Grain Jitter",
    param = objects.head:getParameter("Grain Jitter"),
    monitor = self,
    map = Encoder.getMap("unit"),
    units = app.unitNone
  }

  controls.wave = WaveForm{
    width = 4*ply,
    destinationWindow = self.slicingView,
    destinationButton = "slice"
  }

  return views
end


function GrainPlayer:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end

return GrainPlayer
