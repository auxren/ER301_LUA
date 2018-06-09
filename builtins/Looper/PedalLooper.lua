-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Unit = require "Unit"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Fader = require "Unit.ViewControl.Fader"
local Comparator = require "Unit.ViewControl.Comparator"
local StateMachineView = require "Unit.ViewControl.StateMachineView"
local GainBias = require "Unit.ViewControl.GainBias"
local SamplePool = require "Sample.Pool"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local ModeSelect = require "Unit.MenuControl.ModeSelect"
local FlagSelect = require "Unit.MenuControl.FlagSelect"
local TimeChooser = require "builtins.Looper.TimeChooser"
local Encoder = require "Encoder"
local Utils = require "Utils"
local SystemGraphic = require "SystemGraphic"
local ply = app.SECTION_PLY

local PedalLooper = Class{}
PedalLooper:include(Unit)

function PedalLooper:init(args)
  args.title = "Pedal Looper"
  args.mnemonic = "PL"
  Unit.init(self,args)
end

function PedalLooper:onLoadGraph(pUnit, channelCount)
  -- create objects
  app.collectgarbage()
  local looper = self:createObject("PedalLooper","looper",channelCount)
  looper:allocateTimeUpTo(30)
  local record = self:createObject("Comparator","record")
  local stop = self:createObject("Comparator","stop")
  local undo = self:createObject("Comparator","undo")
  local feedback = self:createObject("ParameterAdapter","feedback")

  connect(pUnit,"In1",looper,"Left In")
  connect(looper,"Left Out",pUnit,"Out1")
  if channelCount > 1 then
    connect(pUnit,"In2",looper,"Right In")
    connect(looper,"Right Out",pUnit,"Out2")
  end

  connect(record,"Out",looper,"Record")
  connect(stop,"Out",looper,"Stop")
  connect(undo,"Out",looper,"Undo")
  tie(looper,"Feedback",feedback,"Out")

  self:addBranch("record","Record",record,"In")
  self:addBranch("stop","Stop",stop,"In")
  self:addBranch("Undo","Undo",undo,"In")
  self:addBranch("feedback","Feedback",feedback,"In")
end

function PedalLooper:setMaxLoopTime(secs)
  self.objects.looper:allocateTimeUpTo(secs)
end

function PedalLooper:copyToNewBuffer()
  local sample, msg = SamplePool.createBuffer{
    root = "loop",
    samples = self.objects.looper:getLoopLengthInSamples(),
    channels = self.channelCount
  }

  if sample then
    if self.objects.looper:fillSample(sample.pSample) > 0 then
      SystemGraphic.mainFlashMessage("Copied to: %s",sample.name)
      self.lastCopyPath = sample.path
    else
      SamplePool.delete(sample)
      SystemGraphic.mainFlashMessage("Failed to copy audio.")
    end
  else
    SystemGraphic.mainFlashMessage("Copy failed: %s", msg)
  end
end

function PedalLooper:copyToExistingBuffer()
  local chooser = SamplePoolInterface(self.loadInfo.id)
  chooser:setDefaultChannelCount(self.channelCount)
  chooser:highlight(self.sample)
  local task = function(sample)
    if sample then
      if self.objects.looper:fillSample(sample.pSample) > 0 then
        SystemGraphic.mainFlashMessage("Copied to: %s",sample.name)
        self.lastCopyPath = sample.path
      else
        SamplePool.delete(sample)
        SystemGraphic.mainFlashMessage("Failed to copy audio.")
      end
    end
  end
  chooser:subscribe("done",task)
  chooser:activate()
end

function PedalLooper:copyTo(sample)
  if sample then
    if self.objects.looper:fillSample(sample.pSample) > 0 then
      SystemGraphic.mainFlashMessage("Copied to: %s",sample.name)
      self.lastCopyPath = sample.path
    else
      SamplePool.delete(sample)
      SystemGraphic.mainFlashMessage("Failed to copy audio.")
    end
  else
    SystemGraphic.mainFlashMessage("Buffer not found.")
  end
end

local menu = {
  "copyHeader",
  "copyToExisting",
  "copyToNew",
  "copyToLast",
  "setHeader",
  "set10s",
  "set30s",
  "set60s",
  "setCustom",
  "behaviorHeader",
  "afterRec",
  "passInput",
  "infoHeader",
  "rename",
  "load",
  "save",
}

function PedalLooper:onLoadMenu(objects,controls)
  local L = self.objects.looper:getLoopLengthInSamples()

  if L > 0 then
    local T = self.objects.looper:getLoopLengthInSeconds()
    T = Utils.round(T,1)

    controls.copyHeader = MenuHeader {
      description = string.format("Copy %0.1fs of audio to...",T)
    }

    if self.lastCopyPath and SamplePool.samples[self.lastCopyPath] then
      local sample = SamplePool.samples[self.lastCopyPath]
      controls.copyToLast = Task {
        description = string.format("Recent: %s",sample.name),
        task = function() self:copyTo(sample) end
      }
    end

    controls.copyToNew = Task {
      description = "New Buffer",
      task = function() self:copyToNewBuffer() end
    }

    controls.copyToExisting = Task {
      description = "Existing Buffer",
      task = function() self:copyToExistingBuffer() end
    }

  end

  controls.setHeader = MenuHeader {
    description = "Set Maximum Loop Time:"
  }

  controls.set10s = Task {
    description = "10s",
    task = function() self:setMaxLoopTime(10) end
  }

  controls.set30s = Task {
    description = "30s",
    task = function() self:setMaxLoopTime(30) end
  }

  controls.set60s = Task {
    description = "60s",
    task = function() self:setMaxLoopTime(60) end
  }

  controls.setCustom = Task {
    description = "Custom Time",
    task = function()
      local chooser = TimeChooser(self.channelCount)
      local subTask = function(secs)
        if secs then
          self:setMaxLoopTime(secs)
        end
      end
      chooser:subscribe("done",subTask)
      chooser:activate()
    end
  }

  controls.behaviorHeader = MenuHeader {
    description = "Behavior"
  }

  controls.afterRec = ModeSelect {
    description = "After Record",
    option = objects.looper:getOption("After Record"),
    choices = {"play","overdub"},
    boolean = true
  }

  controls.passInput = FlagSelect {
    description = "Pass Input",
    option = objects.looper:getOption("Pass Input"),
    flags = {"empty","record","play","overdub","stop"}
  }

  local allocated = self.objects.looper:maximumLoopTime()
  allocated = Utils.round(allocated,1)
  local sub = {
    {
      position = app.GRID5_LINE2+5,
      justify = app.justifyCenter,
      text = "Maximum",
      fontSize = 10
    },
    {
      position = app.GRID5_LINE3+5,
      justify = app.justifyCenter,
      text = "Loop Time",
      fontSize = 10
    },
    {
      position = app.GRID4_LINE3,
      justify = app.justifyCenter,
      text = string.format("%0.1fs",allocated),
      fontSize = 12
    },
  }

  return menu, sub
end

local views = {
  expanded = {"record","stop","undo","feedback"},
  collapsed = {},
}

function PedalLooper:onLoadViews(objects,controls)

  controls.record = StateMachineView {
    button = "mode",
    description = "Rec/Play/Ovr",
    branch = self:getBranch("Record"),
    edge = objects.record,
    stateMachine = objects.looper:getStateMachine("Record"),
  }

  controls.stop = StateMachineView {
    button = "stop",
    description = "Stop/Clear",
    branch = self:getBranch("Stop"),
    edge = objects.stop,
    stateMachine = objects.looper:getStateMachine("Stop")
  }

  controls.undo = StateMachineView {
    button = "undo",
    description = "Undo/Redo",
    branch = self:getBranch("Undo"),
    edge = objects.undo,
    stateMachine = objects.looper:getStateMachine("Undo"),
    showStateValue = true
  }

  controls.feedback = GainBias {
    button = "fdbk",
    description = "Feedback",
    branch = self:getBranch("Feedback"),
    gainbias = objects.feedback,
    range = objects.feedback,
    biasMap = Encoder.getMap("feedback"),
    biasUnits = app.unitDecibels,
    initialBias = 1
  }
  controls.feedback:setTextBelow(-35.9,"-inf dB")

  return views
end

function PedalLooper:serialize()
  local t = Unit.serialize(self)
  t.maximumLoopTime = self.objects.looper:maximumLoopTime()
  return t
end

function PedalLooper:deserialize(t)
  Unit.deserialize(self,t)
  local time = t.maximumLoopTime
  if time and time > 0 then
    self:setMaxLoopTime(time)
  end
end

function PedalLooper:onRemove()
  self.objects.looper:deallocate()
  Unit.onRemove(self)
end

return PedalLooper
