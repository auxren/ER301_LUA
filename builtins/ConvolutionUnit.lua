-- GLOBALS: app, os, verboseLevel, connect
local app = app
local Class = require "Base.Class"
local SamplePool = require "Sample.Pool"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Unit = require "Unit"
local Task = require "Unit.MenuControl.Task"
local MenuHeader = require "Unit.MenuControl.Header"
local Encoder = require "Encoder"
local GainBias = require "Unit.ViewControl.GainBias"
local ply = app.SECTION_PLY

local ConvolutionUnit = Class{}
ConvolutionUnit:include(Unit)

function ConvolutionUnit:init(args)
  args.title = "Exact Convo- lution"
  args.mnemonic = "Co"
  Unit.init(self,args)
end

function ConvolutionUnit:onLoadGraph(pUnit, channelCount)

  if channelCount==2 then
    self:loadStereoGraph(pUnit)
  else
    self:loadMonoGraph(pUnit)
  end
end

function ConvolutionUnit:loadMonoGraph(pUnit)
  local convolve = self:createObject("MonoConvolution","convolve")
  local xfade = self:createObject("CrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  connect(pUnit,"In1",convolve,"In")
  connect(convolve,"Out",xfade,"A")
  connect(pUnit,"In1",xfade,"B")
  connect(xfade,"Out",pUnit,"Out1")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  self:addBranch("wet","Wet/Dry",fader,"In")
end

function ConvolutionUnit:loadStereoGraph(pUnit)
  local convolve = self:createObject("StereoConvolution","convolve")
  local xfade = self:createObject("StereoCrossFade","xfade")
  local fader = self:createObject("GainBias","fader")
  local faderRange = self:createObject("MinMax","faderRange")

  connect(pUnit,"In1",convolve,"Left In")
  connect(pUnit,"In2",convolve,"Right In")
  connect(convolve,"Left Out",xfade,"Left A")
  connect(convolve,"Right Out",xfade,"Right A")
  connect(pUnit,"In1",xfade,"Left B")
  connect(pUnit,"In2",xfade,"Right B")
  connect(xfade,"Left Out",pUnit,"Out1")
  connect(xfade,"Right Out",pUnit,"Out2")

  connect(fader,"Out",xfade,"Fade")
  connect(fader,"Out",faderRange,"In")

  self:addBranch("wet","Wet/Dry",fader,"In")
end

function ConvolutionUnit:setSample(sample)
  if self.sample then
    self.sample:release()
  end

  self.sample = sample
  if self.sample then
    self.sample:claim()
  end

  if sample then
    if sample:isPending() then
      local Timer = require "Timer"
      local handle = Timer.every(0.5,
        function()
          if self.sample==nil then
            return false
          elseif sample.path~=self.sample.path then
            return false
          elseif not sample:isPending() then
            self.objects.convolve:setSample(sample.pSample)
            return false
          end
        end
      )
    else
      self.objects.convolve:setSample(sample.pSample)
    end
  end

end

function ConvolutionUnit:serialize()
  local t = Unit.serialize(self)
  local sample = self.sample
  if sample then
    t.sample = SamplePool.serializeSample(sample)
  end
  return t
end

function ConvolutionUnit:deserialize(t)
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

function ConvolutionUnit:doDetachSample()
  local SystemGraphic = require "SystemGraphic"
  SystemGraphic.mainFlashMessage("Sample detached.")
  self:setSample()
end

function ConvolutionUnit:doAttachSampleFromCard()
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

function ConvolutionUnit:doAttachSampleFromPool()
  local chooser = SamplePoolInterface(self.loadInfo.id)
  chooser:setDefaultChannelCount(self.channelCount)
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

  "infoHeader","rename","load","save"
}

function ConvolutionUnit:onLoadMenu(objects,controls)
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

local views = {
  collapsed = {},
  expanded = {"wet"}
}

function ConvolutionUnit:onLoadViews(objects,controls)
  controls.wet = GainBias {
    button = "wet",
    description = "Wet/Dry Amount",
    branch = self:getBranch("Wet/Dry"),
    gainbias = objects.fader,
    range = objects.faderRange,
    biasMap = Encoder.getMap("unit"),
    initialBias = 0.5,
  }
  return views
end

function ConvolutionUnit:onRemove()
  self:setSample(nil)
  Unit.onRemove(self)
end

return ConvolutionUnit
