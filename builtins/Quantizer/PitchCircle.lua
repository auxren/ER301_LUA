-- GLOBALS: app, os, verboseLevel
local app = app
local Env = require "Env"
local Class = require "Base.Class"
local ViewControl = require "Unit.ViewControl"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Scales = require "builtins.Quantizer.Scales"
local ply = app.SECTION_PLY

-- PitchCircle
local PitchCircle = Class{}
PitchCircle:include(ViewControl)

function PitchCircle:init(args)
  local name = args.name or app.error("%s.init: name is missing.",self)
  local width = args.width or 2*ply
  local quantizer = args.quantizer or app.error("%s.init: quantizer is missing.", self)

  ViewControl.init(self,name)
  self:setClassName("PitchCircle")

  local graphic
  graphic = app.Graphic(0,0,width,64)
  self.pDisplay = app.PitchCircle(0,0,width,64)
  graphic:addChild(self.pDisplay)
  self:setMainCursorController(self.pDisplay)
  self:setControlGraphic(graphic)

  -- add spots
  for i = 1, (width/ply) do
    self:addSpot{center = (i-0.5)*ply}
  end

  -- sub display
  self.subGraphic = app.Graphic(0,0,128,64)
  self.scaleList = app.SlidingList(0,0,88,64)
  self.subGraphic:addChild(self.scaleList)
  self.notesList = app.SlidingList(88,0,40,64)
  self.subGraphic:addChild(self.notesList)

  local order = {
    "12-TET",
    "22-Shruti",
    "24-TET",
    "Major",
    "Harmonic Minor",
    "Natural Minor",
    "Major Pentatonic",
    "Minor Pentatonic",
    "Ionian",
    "Dorian",
    "Phrygian",
    "Lydian",
    "Mixolydian",
    "Aeolian",
    "Locrian",
    "Whole Tone",
  }

  for i,name in ipairs(order) do
    self.scaleList:add(name)
    self.notesList:add(#Scales[name])
  end

  self:setQuantizer(quantizer)
end

function PitchCircle:setQuantizer(q)
  self.pDisplay:setQuantizer(q)
  self.quantizer = q
  self:loadBuiltinScale(self.scaleList:selectedText())
end

function PitchCircle:loadScalaFile(filename)
  if self.quantizer and filename then
    self.quantizer:loadScalaFile(filename)
  end
end

function PitchCircle:serialize()
  local t = ViewControl.serialize(self)
  t.selectedScale = self.scaleList:selectedText()
  return t
end

function PitchCircle:deserialize(t)
  ViewControl.deserialize(self,t)
  if t.selectedScale then
    if self.scaleList:select(t.selectedScale) then
      self.notesList:select(self.scaleList:selectedIndex())
      self:loadBuiltinScale(t.selectedScale)
    else
      app.log("%s.deserialize:invalid scale:%s ",self,t.selectedScale)
    end
  else
    app.log("%s.deserialize:selectedScale missing",self)
  end
end

function PitchCircle:loadBuiltinScale(name)
  if self.quantizer and name then
    local scale = Scales[name]
    if scale then
      local quantizer = self.quantizer
      quantizer:beginScale()
      for i,pitch in ipairs(scale) do
        quantizer:addPitch(pitch)
      end
      quantizer:endScale()
    end
  end
end

function PitchCircle:subReleased(i,shifted)
  if shifted then
    return false
  else
    self:focus()
  end
  return true
end

local threshold = Env.EncoderThreshold.SlidingList
function PitchCircle:encoder(change,shifted)
  self.notesList:encoder(change,shifted,threshold)
  if self.scaleList:encoder(change,shifted,threshold) and self.quantizer then
    self:loadBuiltinScale(self.scaleList:selectedText())
  end
  return true
end

return PitchCircle
