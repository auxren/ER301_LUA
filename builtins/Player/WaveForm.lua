-- GLOBALS: app, os, verboseLevel
local app = app
local Env = require "Env"
local Class = require "Base.Class"
local ViewControl = require "Unit.ViewControl"
local SamplePoolInterface = require "Sample.Pool.Interface"
local Encoder = require "Encoder"

local ply = app.SECTION_PLY
local col1 = app.BUTTON1_CENTER
local col2 = app.BUTTON2_CENTER
local col3 = app.BUTTON3_CENTER

-- WaveForm
local WaveForm = Class{}
WaveForm:include(ViewControl)

function WaveForm:init(args)
  ViewControl.init(self)
  self:setClassName("Player.WaveForm")
  local width = 4 * ply
  local graphic
  graphic = app.Graphic(0,0,width,64)
  self.mainDisplay = app.PlayHeadDisplay(0,0,width,64)
  graphic:addChild(self.mainDisplay)
  self:setMainCursorController(self.mainDisplay)
  self:setControlGraphic(graphic)
  local button = app.MainButton("zoom",4,true)
  graphic:addChild(button)
  button = app.MainButton("slice",3,true)
  graphic:addChild(button)

  -- add spots
  for i = 1, (width/ply) do
    self:addSpot{center = (i-0.5)*ply}
  end
  self.divider = width

  -- sub display
  self.subGraphic = app.Graphic(0,0,128,64)

  self.subDisplay = app.PlayHeadSubDisplay()
  self.subDisplay:setMainDisplay(self.mainDisplay)
  self.subGraphic:addChild(self.subDisplay)

  self.subButton1 = app.SubButton("|<<", 1)
  self.subGraphic:addChild(self.subButton1)

  self.subButton2 = app.SubButton("> / ||", 2)
  self.subGraphic:addChild(self.subButton2)

  self.subButton3 = app.SubButton("", 3)
  self.subGraphic:addChild(self.subButton3)

  self.zooming = false
  self.encoderState = Encoder.Horizontal
end

function WaveForm:setPlayHead(head)
  self.mainDisplay:setPlayHead(head)
  self.head = head
end

function WaveForm:setSample(sample)
  if sample then
    self.subDisplay:setName(sample.name)
  end
end

function WaveForm:onCursorLeave(spot)
  ViewControl.onCursorLeave(self,spot)
  self.zooming = false
  self.mainDisplay:hideZoomGadget()
end

function WaveForm:dialReleased(shifted)
  if self.encoderState==Encoder.Vertical then
    self.encoderState = Encoder.Horizontal
    if self.zooming then
      self.mainDisplay:showTimeZoomGadget()
    end
  else
    self.encoderState = Encoder.Vertical
    if self.zooming then
      self.mainDisplay:showGainZoomGadget()
    end
  end
  Encoder.set(self.encoderState)
end

function WaveForm:spotPressed(i,shifted,isFocusedPress)
  if shifted then return false end
  if i==4 then
    self:grabFocus("encoder")
    self.zooming = true
    if self.encoderState==Encoder.Vertical then
      self.mainDisplay:showGainZoomGadget()
    else
      self.mainDisplay:showTimeZoomGadget()
    end
  end
  return true
end

function WaveForm:spotReleased(i,shifted)
  if shifted then return false end
  if i==3 then
    self:callUp("showSlicingView")
  elseif i==4  then
    self.zooming = false
    self:releaseFocus("encoder")
    self.mainDisplay:hideZoomGadget()
  end
  return true
end

function WaveForm:subReleased(i,shifted)
  if shifted then
    return false
  elseif self.head then
    if i==1 then
      self.head:reset()
    elseif i==2 then
      self.head:toggle()
    elseif i==3 then

    end
  end
  return true
end

local threshold = Env.EncoderThreshold.Default
function WaveForm:encoder(change,shifted)
  if self.zooming then
    self.mainDisplay:encoderZoom(change,shifted,threshold)
  end
  return true
end

return WaveForm
