-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local GainBias = require "Unit.ViewControl.GainBias"
local OutputScope = require "Unit.ViewControl.OutputScope"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local SlicingView = require "SlicingView"
local ply = app.SECTION_PLY

local SampleScanner = Class{}
SampleScanner:include(Unit)

function SampleScanner:init(args)
  args.title = "Sample Scanner"
  args.mnemonic = "SS"
  Unit.init(self,args)
end

-- creation/destruction states

function SampleScanner:onLoadGraph(pUnit,channelCount)
  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function SampleScanner:loadMonoGraph(pUnit)
  local bump = self:createObject("BumpMap","bump1")
  local center = self:createObject("ParameterAdapter","center")
  local width = self:createObject("ParameterAdapter","width")
  local height = self:createObject("ParameterAdapter","height")
  local fade = self:createObject("ParameterAdapter","fade")
  local phase = self:createObject("GainBias","phase")
  local phaseRange = self:createObject("MinMax","phaseRange")

  connect(pUnit,"In1",bump,"In")
  connect(bump,"Out",pUnit,"Out1")
  connect(phase,"Out",bump,"Phase")
  connect(phase,"Out",phaseRange,"In")

  tie(bump,"Center",center,"Out")
  tie(bump,"Width",width,"Out")
  tie(bump,"Height",height,"Out")
  tie(bump,"Fade",fade,"Out")

  self:addBranch("center","Center",center,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("height","Height",height,"In")
  self:addBranch("fade","Fade",fade,"In")
  self:addBranch("phase","Phase",phase,"In")
end

function SampleScanner:loadStereoGraph(pUnit)
  local bump1 = self:createObject("BumpMap","bump1")
  local bump2 = self:createObject("BumpMap","bump2")
  local center = self:createObject("ParameterAdapter","center")
  local width = self:createObject("ParameterAdapter","width")
  local height = self:createObject("ParameterAdapter","height")
  local fade = self:createObject("ParameterAdapter","fade")
  local phase = self:createObject("GainBias","phase")
  local phaseRange = self:createObject("MinMax","phaseRange")

  connect(pUnit,"In1",bump1,"In")
  connect(pUnit,"In2",bump2,"In")
  connect(bump1,"Out",pUnit,"Out1")
  connect(bump2,"Out",pUnit,"Out2")
  connect(phase,"Out",bump1,"Phase")
  connect(phase,"Out",bump2,"Phase")
  connect(phase,"Out",phaseRange,"In")

  tie(bump1,"Center",center,"Out")
  tie(bump1,"Width",width,"Out")
  tie(bump1,"Height",height,"Out")
  tie(bump1,"Fade",fade,"Out")
  tie(bump2,"Center",center,"Out")
  tie(bump2,"Width",width,"Out")
  tie(bump2,"Height",height,"Out")
  tie(bump2,"Fade",fade,"Out")

  self:addBranch("center","Center",center,"In")
  self:addBranch("width","Width",width,"In")
  self:addBranch("height","Height",height,"In")
  self:addBranch("fade","Fade",fade,"In")
  self:addBranch("phase","Phase",phase,"In")
end

function SampleScanner:setSample(sample)
  if self.sample then
    self.sample:release()
    self.sample = nil
  end
  self.sample = sample
  if self.sample then
    self.sample:claim()
  end

  if self.channelCount==1 then
    if sample==nil or sample:getChannelCount()==0 then
      self.objects.bump1:setSample(nil, 0)
    elseif sample:getChannelCount()==1 then
      self.objects.bump1:setSample(sample.pSample, 0)
    else -- 2 or more channels
      self.objects.bump1:setSample(sample.pSample, 0)
    end
  else
    if sample==nil or sample:getChannelCount()==0 then
      self.objects.bump1:setSample(nil, 0)
      self.objects.bump2:setSample(nil, 0)
    elseif sample:getChannelCount()==1 then
      self.objects.bump1:setSample(sample.pSample, 0)
      self.objects.bump2:setSample(sample.pSample, 0)
    else -- 2 or more channels
      self.objects.bump1:setSample(sample.pSample, 0)
      self.objects.bump2:setSample(sample.pSample, 1)
    end
  end
  if self.sampleEditor then
    self.fakePlayHead:setSample(sample and sample.pSample)
    self.sampleEditor:setSample(sample)
  end
  self:notifyControls("setSample",sample)
end

function SampleScanner:showSampleEditor()
  if self.sample then
    if self.sampleEditor==nil then
      self.sampleEditor = SlicingView(self,true)
      self.fakePlayHead = app.PlayHead("fake")
      self.fakePlayHead:setSample(self.sample and self.sample.pSample)
      self.fakePlayHead:setSlices(self.sample and self.sample.slices.pSlices)
      self.sampleEditor:setPlayHead(self.fakePlayHead)
      self.sampleEditor:setSample(self.sample)
    end
    self.sampleEditor:activate()
  else
    local SystemGraphic = require "SystemGraphic"
    SystemGraphic.mainFlashMessage("You must first select a sample.")
  end
end

function SampleScanner:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function SampleScanner:doAttachSampleFromCard()
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

function SampleScanner:doAttachSampleFromPool()
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
  "edit",

  "infoHeader","rename","load","save"
}

function SampleScanner:onLoadMenu(objects,controls)
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

  controls.edit = Task {
    description = "Edit Sample",
    task = function() self:showSampleEditor() end
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
  expanded = {"center","width","height","fade","phase"},
  collapsed = {},
  center = {"scope","center"},
  width = {"scope","width"},
  height = {"scope","height"},
  fade = {"scope","fade"},
  phase = {"scope","phase"}
}

function SampleScanner:onLoadViews(objects,controls)
  controls.scope = OutputScope {
    monitor = self,
    width = 4*ply,
  }

  controls.center = GainBias {
    button = "center",
    branch = self:getBranch("Center"),
    description = "Center",
    gainbias = objects.center,
    range = objects.center,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.0,
    gainMap = Encoder.getMap("gain"),
  }

  controls.width = GainBias {
    button = "width",
    branch = self:getBranch("Width"),
    description = "Width",
    gainbias = objects.width,
    range = objects.width,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
    gainMap = Encoder.getMap("gain"),
  }

  controls.height = GainBias {
    button = "height",
    branch = self:getBranch("Height"),
    description = "Height",
    gainbias = objects.height,
    range = objects.height,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0.5,
    gainMap = Encoder.getMap("gain"),
  }

  controls.fade = GainBias {
    button = "fade",
    branch = self:getBranch("Fade"),
    description = "Fade",
    gainbias = objects.fade,
    range = objects.fade,
    biasMap = Encoder.getMap("unit"),
    biasUnits = app.unitNone,
    initialBias = 0.25,
    gainMap = Encoder.getMap("gain"),
  }

  controls.phase = GainBias {
    button = "phase",
    branch = self:getBranch("Phase"),
    description = "Phase",
    gainbias = objects.phase,
    range = objects.phaseRange,
    biasMap = Encoder.getMap("[-1,1]"),
    biasUnits = app.unitNone,
    initialBias = 0,
    gainMap = Encoder.getMap("gain"),
  }
  return views
end

function SampleScanner:serialize()
  local t = Unit.serialize(self)
  local sample = self.sample
  if sample then
    t.sample = SamplePool.serializeSample(sample)
  end
  return t
end

function SampleScanner:deserialize(t)
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

function SampleScanner:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end


return SampleScanner
