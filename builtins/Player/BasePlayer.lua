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

local BasePlayer = Class{}
BasePlayer:include(Unit)

function BasePlayer:init(args)
  self.enableVariableSpeed = args.enableVariableSpeed or false
  Unit.init(self,args)
end

function BasePlayer:onLoadGraph(pUnit,channelCount)
  self:loadBaseGraph(pUnit)
  if channelCount==2 then
    self:addStereoAdapter(pUnit)
  else
    self:addMonoAdapter(pUnit)
  end
end

function BasePlayer:loadBaseGraph(pUnit)
  local mono = self:createObject("MonoPlayHead","mono")
  local stereo = self:createObject("StereoPlayHead","stereo")

  local edge = self:createObject("Comparator","edge")
  local slice = self:createObject("GainBias","slice")
  local shift = self:createObject("GainBias","shift")
  local sliceRange = self:createObject("MinMax","sliceRange")
  local shiftRange = self:createObject("MinMax","shiftRange")

  -- Comparator input
  connect(edge,"Out",mono,"Trigger")
  connect(edge,"Out",stereo,"Trigger")
  -- Slicing
  connect(slice,"Out",mono,"Slice Select")
  connect(slice,"Out",stereo,"Slice Select")
  connect(slice,"Out",sliceRange,"In")
  -- Shifting
  connect(shift,"Out",mono,"Slice Shift")
  connect(shift,"Out",stereo,"Slice Shift")
  connect(shift,"Out",shiftRange,"In")

  tie(stereo,"Fade Time", mono, "Fade Time")
  tie(stereo,"Address", mono, "Address")
  tie(stereo,"How Much", mono, "How Much")
  tie(stereo,"How Often", mono, "How Often")
  tie(stereo,"Polarity", mono, "Polarity")

  -- register exported ports
  self:addBranch("trig","Trigger", edge, "In")
  self:addBranch("slice","Slice Select",slice,"In")
  self:addBranch("shift","Slice Shift",shift,"In")

  if self.enableVariableSpeed then
    mono:enableVariableSpeed();
    stereo:enableVariableSpeed();
    tie(stereo,"Interpolation", mono, "Interpolation")

    local tune = self:createObject("ConstantOffset","tune")
    local pitch = self:createObject("VoltPerOctave","pitch")
    local multiply = self:createObject("Multiply","multiply")
    local clipper = self:createObject("Clipper","clipper")
    clipper:setMaximum(64.0)
    clipper:setMinimum(-64.0)
    local speed = self:createObject("GainBias","speed")
    speed:hardSet("Bias",1.0)
    local tuneRange = self:createObject("MinMax","tuneRange")
    local speedRange = self:createObject("MinMax","speedRange")
    -- Pitch and Linear FM
    connect(tune,"Out",pitch,"In")
    connect(tune,"Out",tuneRange,"In")
    connect(pitch,"Out",multiply,"Left")
    connect(speed,"Out",multiply,"Right")
    connect(speed,"Out",speedRange,"In")
    connect(multiply,"Out",clipper,"In")
    connect(clipper,"Out",mono,"Speed")
    connect(clipper,"Out",stereo,"Speed")
    -- register exported ports
    self:addBranch("speed","Speed", speed, "In")
    self:addBranch("V/oct","Pitch", tune, "In")
  end
end

function BasePlayer:addMonoAdapter(pUnit)
  local mono = self.objects.mono
  local stereo = self.objects.stereo

  local s2m = self:createObject("StereoToMono","s2m")
  local sum = self:createObject("Sum","sum")

  -- add mono and stereo outputs
  connect(mono,"Out",sum,"Left")
  connect(stereo,"Left Out",s2m,"Left In")
  connect(stereo,"Right Out",s2m,"Right In")
  connect(s2m,"Out",sum,"Right")
  connect(sum,"Out",pUnit,"Out1")
end

function BasePlayer:addStereoAdapter(pUnit)
  local mono = self.objects.mono
  local stereo = self.objects.stereo

  local sum1 = self:createObject("Sum","sum1")
  local sum2 = self:createObject("Sum","sum2")

  -- connect objects
  connect(stereo,"Left Out",sum1,"Left")
  connect(stereo,"Right Out",sum2,"Left")
  connect(mono,"Out",sum1,"Right")
  connect(mono,"Out",sum2,"Right")
  connect(sum1,"Out",pUnit,"Out1")
  connect(sum2,"Out",pUnit,"Out2")
end

function BasePlayer:getHead()
  local sample = self.sample
  if sample then
    local channelCount = sample:getChannelCount()
    if channelCount==1 then
      return self.objects.mono
    else
      return self.objects.stereo
    end
  end
end

function BasePlayer:serialize()
  local t = Unit.serialize(self)
  local sample = self.sample
  if sample then
    t.sample = SamplePool.serializeSample(sample)
    local head = self:getHead()
    t.activeSliceIndex = head:getActiveSliceIndex()
    t.activeSliceShift = head:getActiveSliceShift()
    t.samplePosition = head:getPosition()
  end
  return t
end

function BasePlayer:deserialize(t)
  Unit.deserialize(self,t)
  if t.sample then
    local sample = SamplePool.deserializeSample(t.sample)
    if sample then
      self:setSample(sample)
      local head = self:getHead()
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

function BasePlayer:setSample(sample)
  if self.sample then
    self.sample:release()
  end
  self.sample = sample
  if self.sample then
    self.sample:claim()
  end

  if sample==nil or sample:getChannelCount()==0 then
    self.objects.mono:setSample(nil)
    self.objects.mono:setSlices(nil)
    self.objects.stereo:setSample(nil)
    self.objects.stereo:setSlices(nil)
    self.activeHead = nil
  elseif sample:getChannelCount()==1 then
    self.objects.mono:setSample(sample.pSample)
    self.objects.mono:setSlices(sample.slices.pSlices)
    self.objects.stereo:setSample(nil)
    self.objects.stereo:setSlices(nil)
    self.activeHead = self.objects.mono
  else -- 2 or more channels
    self.objects.stereo:setSample(sample.pSample)
    self.objects.stereo:setSlices(sample.slices.pSlices)
    self.objects.mono:setSample(nil)
    self.objects.mono:setSlices(nil)
    self.activeHead = self.objects.stereo
  end

  if self.slicingView then
    self.slicingView:setPlayHead(self.activeHead)
    self.slicingView:setSample(sample)
  end
  self:notifyControls("setPlayHead",self.activeHead)
  self:notifyControls("setSample",sample)
end

function BasePlayer:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function BasePlayer:doAttachSampleFromCard()
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

function BasePlayer:doAttachSampleFromPool()
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

function BasePlayer:showSlicingView()
  if self.sample then
    if self.slicingView==nil then
      self.slicingView = SlicingView(self)
      self.slicingView:setPlayHead(self.activeHead)
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
  "routing",
  "interpolation",

  "infoHeader","rename","load","save"
}

function BasePlayer:onLoadMenu(objects,controls)

  controls.sampleHeader = MenuHeader {
    description = "Sample Operations"
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
    option = objects.mono:getOption("How Often"),
    choices = {"once","loop"}
  }

  controls.howMuch = ModeSelect {
    description = "Play Extent",
    option = objects.mono:getOption("How Much"),
    choices = {"all", "slice"},
  }

  controls.polarity = ModeSelect {
    description = "Slice Polarity",
    option = objects.mono:getOption("Polarity"),
    choices = {"left","both","right"}
  }

  controls.address = ModeSelect {
    description = "CV-to-Slice Mapping",
    option = objects.mono:getOption("Address"),
    choices = {"nearest","index","12TET"},
    descriptionWidth = 2
  }

  if objects.s2m then
    controls.routing = ModeSelect {
      description = "Stereo-to-Mono Routing",
      option = objects.s2m:getOption("Routing"),
      choices = {"left","sum","right"},
      descriptionWidth = 2
    }
  end

  if self.enableVariableSpeed then
    controls.interpolation = ModeSelect {
      description = "Interpolation Quality",
      option = objects.mono:getOption("Interpolation"),
      choices = {"none","linear","2nd order"},
      descriptionWidth = 2
    }
  end

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

function BasePlayer:onLoadViews(objects,controls)

  controls.trigger = Comparator {
    button = "trig",
    description = "Trigger",
    branch = self:getBranch("Trigger"),
    edge = objects.edge,
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

  controls.fade = Fader {
    button = "fade",
    description = "Fade Time",
    param = objects.mono:getParameter("Fade Time"),
    monitor = self,
    map = Encoder.getMap("[0,0.25]"),
    units = app.unitSecs
  }

  controls.wave = WaveForm()

  if self.enableVariableSpeed then
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
    }

    return {
      expanded = {"pitch","speed","trigger","slice","shift","fade"},
      collapsed = {},
      pitch = {"wave","pitch"},
      speed = {"wave","speed"},
      trigger = {"wave","trigger"},
      slice = {"wave","slice"},
      shift = {"wave","shift"},
      fade = {"wave","fade"},
    }
  else
    return {
      expanded = {"trigger","slice","shift","fade"},
      collapsed = {},
      trigger = {"wave","trigger"},
      slice = {"wave","slice"},
      shift = {"wave","shift"},
      fade = {"wave","fade"},
    }
  end
end

function BasePlayer:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end

return BasePlayer
