-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Encoder = require "Encoder"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local GainBias = require "Unit.ViewControl.GainBias"
local SamplePool = require "Sample.Pool"
local WaveForm = require "builtins.Looper.WaveForm"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local ply = app.SECTION_PLY

local FeedbackLooper = Class{}
FeedbackLooper:include(Unit)

function FeedbackLooper:init(args)
  args.title = "Feedback Looper"
  args.mnemonic = "FL"
  Unit.init(self,args)
end

function FeedbackLooper:onLoadGraph(pUnit, channelCount)
  local head = self:createObject("FeedbackLooper","head",channelCount)
  local reset = self:createObject("Comparator","reset")

  local punch = self:createObject("Comparator","punch")
  punch:setToggleMode()

  local engage = self:createObject("Comparator","engage")
  engage:setToggleMode()

  local feedback = self:createObject("GainBias","feedback")
  local feedbackRange = self:createObject("MinMax","feedbackRange")
  local feedbackClipper = self:createObject("Clipper","feedbackClipper")
  feedbackClipper:setMaximum(1.0)
  feedbackClipper:setMinimum(0.0)

  local start = self:createObject("ParameterAdapter","start")
  tie(head,"Start",start,"Out")

  connect(reset,"Out",head,"Reset")
  connect(punch,"Out",head,"Punch")
  connect(engage,"Out",head,"Engage")

  connect(feedback,"Out",feedbackClipper,"In")
  connect(feedbackClipper,"Out",head,"Feedback")
  connect(feedbackClipper,"Out",feedbackRange,"In")

  local wet = self:createObject("GainBias","wet")
  local wetRange = self:createObject("MinMax","wetRange")
  connect(wet,"Out",wetRange,"In")

  if channelCount < 2 then
    local xfade = self:createObject("CrossFade","xfade")
    connect(pUnit,"In1",head,"Left In")
    connect(head,"Left Out",xfade,"A")
    connect(pUnit,"In1",xfade,"B")
    connect(wet,"Out",xfade,"Fade")
    connect(xfade,"Out",pUnit,"Out1")
  else
    local xfade = self:createObject("StereoCrossFade","xfade")
    connect(pUnit,"In1",head,"Left In")
    connect(pUnit,"In2",head,"Right In")
    connect(head,"Left Out",xfade,"Left A")
    connect(head,"Right Out",xfade,"Right A")
    connect(pUnit,"In1",xfade,"Left B")
    connect(pUnit,"In2",xfade,"Right B")
    connect(wet,"Out",xfade,"Fade")
    connect(xfade,"Left Out",pUnit,"Out1")
    connect(xfade,"Right Out",pUnit,"Out2")
  end

  self:addBranch("reset","Reset",reset,"In")
  self:addBranch("engage","Engage",engage,"In")
  self:addBranch("punch","Punch",punch,"In")
  self:addBranch("feedback","Feedback",feedback,"In")
  self:addBranch("wet","Wet/Dry",wet,"In")
  self:addBranch("start","Loop Start",start,"In")
end

function FeedbackLooper:setSample(sample)
  if self.sample then
    self.sample:release()
  end
  self.sample = sample
  if self.sample then
    self.sample:claim()
    self.objects.head:setSample(sample.pSample)
  end
  self:notifyControls("setSample",sample)
end

function FeedbackLooper:doCreateBuffer()
  local Creator = require "Sample.Pool.Creator"
  local creator = Creator(self.channelCount)
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached buffer: %s",sample.name)
      self:setSample(sample)
    end
  end
  creator:subscribe("done",task)
  creator:activate()
end

function FeedbackLooper:doAttachBufferFromPool()
  local chooser = SamplePoolInterface(self.loadInfo.id)
  chooser:setDefaultChannelCount(self.channelCount)
  chooser:highlight(self.sample)
  local task = function(sample)
    if sample then
      local SystemGraphic = require "SystemGraphic"
      SystemGraphic.mainFlashMessage("Attached buffer: %s",sample.name)
      self:setSample(sample)
    end
  end
  chooser:subscribe("done",task)
  chooser:activate()
end

function FeedbackLooper:doDetachBuffer()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Buffer detached.")
  self:setSample()
end

function FeedbackLooper:doZeroBuffer()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Buffer zeroed.")
  self.objects.head:zeroBuffer()
end

local menu = {
  "bufferHeader","create","pool","card","detach","zero",
  "controlHeader","engage","punch",
  "infoHeader","rename","load","save"
}

function FeedbackLooper:onLoadMenu(objects,controls)
  controls.bufferHeader = MenuHeader {
    description = "Buffer Menu"
  }

  controls.create = Task {
    description = "Create New...",
    task = function() self:doCreateBuffer() end
  }

  controls.pool = Task {
    description = "Attach Existing...",
    task = function() self:doAttachBufferFromPool() end
  }

  controls.detach = Task {
    description = "Detach Buffer",
    task = function() self:doDetachBuffer() end
  }

  controls.zero = Task {
    description = "Zero Buffer",
    task = function() self:doZeroBuffer() end
  }

  controls.controlHeader = MenuHeader {
    description = "Control Configuration"
  }

  controls.engage = ModeSelect {
    description = "Engage Latch",
    option = objects.engage:getOption("Mode"),
    choices = {"on","off"}
  }

  controls.punch = ModeSelect {
    description = "Punch Latch",
    option = objects.punch:getOption("Mode"),
    choices = {"on","off"}
  }

  local sub = {}
  if self.sample then
    sub[1] = {
      position = app.GRID5_LINE1,
      justify = app.justifyLeft,
      text = "Attached Buffer:"
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
      text = "No buffer attached."
    }
  end

  return menu, sub
end

local views = {
  expanded = {"reset","engage","punch","start","feedback","wet","fade"},
  collapsed = {},
  reset = {"wave","reset"},
  engage = {"wave","engage"},
  punch = {"wave","punch"},
  start = {"wave","start"},
  feedback = {"wave","feedback"},
  wet = {"wave","wet"},
  fade = {"wave","fade"}
}

function FeedbackLooper:onLoadViews(objects,controls)

  controls.engage = Comparator {
    button = "engage",
    description = "Engage Motor",
    branch = self:getBranch("Engage"),
    edge = objects.engage,
  }

  controls.punch = Comparator {
    button = "punch",
    description = "Punch In/Out",
    branch = self:getBranch("Punch"),
    edge = objects.punch,
  }

  controls.reset = Comparator {
    button = "reset",
    description = "Reset",
    branch = self:getBranch("Reset"),
    edge = objects.reset,
  }

  controls.start = GainBias {
    button = "start",
    description = "Loop Start",
    branch = self:getBranch("Loop Start"),
    gainbias = objects.start,
    range = objects.start,
    biasMap = Encoder.getMap("default"),
    biasUnits = app.unitNone
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback Amount",
    branch = self:getBranch("Feedback"),
    gainbias = objects.feedback,
    range = objects.feedbackRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 1.0
  }

  controls.wet = GainBias {
    button = "wet",
    description = "Wet/Dry Amount",
    branch = self:getBranch("Wet/Dry"),
    gainbias = objects.wet,
    range = objects.wetRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0.5,
  }

  controls.fade = Fader {
    button = "fade",
    description = "Fade Time",
    param = objects.head:getParameter("Fade Time"),
    monitor = self,
    map = Encoder.getMap("[0,0.25]"),
    units = app.unitSecs
  }

  controls.wave = WaveForm{
    width = 4*ply,
    head = objects.head
  }

  return views
end

function FeedbackLooper:serialize()
  local t = Unit.serialize(self)
  if self.sample then
    t.sample = SamplePool.serializeSample(self.sample)
  end
  return t
end

function FeedbackLooper:deserialize(t)
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

function FeedbackLooper:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end

return FeedbackLooper
