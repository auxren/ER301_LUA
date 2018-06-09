-- GLOBALS: app, os, verboseLevel
local app = app
local Env = require "Env"
local Class = require "Base.Class"
local Signal = require "Signal"
local SpottedStrip = require "SpottedStrip"
local Section = require "SpottedStrip.Section"
local SpottedControl = require "SpottedStrip.Control"
local Keyboard = require "Keyboard"
local Customizations = require "builtins.custom.Customizations"
local ply = app.SECTION_PLY

--------------------------------------------------
local Header = Class{}
Header:include(SpottedControl)

function Header:init(name,type)
  SpottedControl.init(self)
  self:setClassName("Header")
  local panel = app.TextPanel(string.format("%s %s",name,type),1)
  panel:setBorderColor(app.WHITE)
  self:setControlGraphic(panel)
  self:addSpot{center = 0.5*ply, radius = ply}

  self.name = name
  self.type = type
  self.panel = panel

  self.menuGraphic = app.Graphic(0,0,128,64)
  self.menuGraphic:addChild(app.TextPanel("Rename Control",1))
  self.menuGraphic:addChild(app.TextPanel("Delete Control",2))
  self.movePanel = app.TextPanel("Hold to Move",3)
  self.menuGraphic:addChild(self.movePanel)
end

function Header:onRename(oldName,newName)
  self.panel:setText(string.format("%s %s",newName,self.type))
  self.name = newName
end

function Header:onCursorEnter()
  local window = self:getWindow()
  window:addSubGraphic(self.menuGraphic)
  self:grabFocus("subReleased","subPressed")
end

function Header:onCursorLeave()
  local window = self:getWindow()
  window:removeSubGraphic(self.menuGraphic)
  self:releaseFocus("subReleased","subPressed","encoder")
  self.controlGraphic:setBorder(0)
  self.movePanel:setText("Hold to Move")
end

function Header:subPressed(i,shifted)
  if shifted then return false end
  if i==3 then
    self:grabFocus("encoder")
    self.controlGraphic:setBorder(3)
    self.movePanel:setText("Place with Knob")
  end
  return true
end

function Header:subReleased(i,shifted)
  self:releaseFocus("encoder")
  self.controlGraphic:setBorder(0)
  self.movePanel:setText("Hold to Move")
  if shifted then return false end
  if i==1 then
    self:sendUp("doRenameControl",self.name)
  elseif i==2 then
    self:sendUp("doDeleteControl",self.name)
  elseif i==3 then

  end
  return true
end

local threshold = Env.EncoderThreshold.Default
local encoderSum = 0
function Header:encoder(change,shifted)
  encoderSum = encoderSum + change
  if encoderSum > threshold then
    encoderSum = 0
    self:sendUp("doMoveControlRight",self.name)
  elseif encoderSum < -threshold then
    encoderSum = 0
    self:sendUp("doMoveControlLeft",self.name)
  end
  return true
end

--------------------------------------------------
local Insert = Class{}
Insert:include(SpottedControl)

local savedListIndex = 0

function Insert:init(text)
  SpottedControl.init(self)
  self:setClassName("Insert")
  if text then
    self:setControlGraphic(app.TextPanel(text,1))
    self:addSpot{center = 0.5*ply, radius = ply}
  else
    self:addSpot{center = 0, radius =  ply}
  end
  self.menuGraphic = app.Graphic(0,0,128,64)
  self.list = app.SlidingList(0,0,2*ply,64)
  self.list:setTextSize(10)
  self.list:setJustification(app.justifyLeft)
  self.list:setMargin(7)
  self.menuGraphic:addChild(self.list)
  for i,czd in ipairs(Customizations.descriptors) do
    self.list:add(czd.description)
  end
  self.panel = app.TextPanel("Insert Control",3)
  self.menuGraphic:addChild(self.panel)
end

function Insert:onSelectionChanged()
  local index = self.list:selectedIndex()+1
  local czd = Customizations.descriptors[index]
  self.panel:setText(string.format("Insert %s Control",czd.description))
end

function Insert:onCursorEnter()
  local window = self:getWindow()
  window:addSubGraphic(self.menuGraphic)
  self:grabFocus("subReleased","subPressed")
  self.list:select(savedListIndex)
  self:onSelectionChanged()
end

function Insert:onCursorLeave()
  local window = self:getWindow()
  window:removeSubGraphic(self.menuGraphic)
  self:releaseFocus("subReleased","subPressed","encoder")
  self:setSubCursorController(nil)
end

function Insert:subPressed(i,shifted)
  if shifted then return false end
  if i==1 or i==2 then
    self:grabFocus("encoder")
    self:setSubCursorController(self.list)
  end
  return true
end

function Insert:subReleased(i,shifted)
  self:releaseFocus("encoder")
  self:setSubCursorController(nil)
  if shifted then return false end
  if i==3 then
    local index = self.list:selectedIndex()+1
    local czd = Customizations.descriptors[index]
    self:sendUp("doInsertControl",czd.type)
  end
  return true
end

local threshold = Env.EncoderThreshold.SlidingList
function Insert:encoder(change,shifted)
  if self.list:encoder(change,shifted,threshold) then
    savedListIndex = self.list:selectedIndex()
    self:onSelectionChanged()
  end
  return true
end

--------------------------------------------------
local Filler = Class{}
Filler:include(Section)

function Filler:init(name,type)
  Section.init(self,app.sectionEnd)
  self:setClassName("ControlEditor.Filler")
  self:addView("default")
  self:addControl("default",Insert("Add Control Here"))
  self:switchView("default")
end

--------------------------------------------------
local Item = Class{}
Item:include(Section)

function Item:init(name,type)
  Section.init(self,app.sectionSimple)
  self:setClassName("ControlEditor.Item")
  self:addView("default")
  self:addControl("default",Insert())
  self:addControl("default",Header(name,type))
  self:switchView("default")
end

--------------------------------------------------
local MenuHeader = Class{}
MenuHeader:include(SpottedControl)

function MenuHeader:init(title)
  SpottedControl.init(self)
  self:setClassName("MenuHeader")
  local panel = app.TextPanel(title,1)
  panel:setBackgroundColor(app.GRAY2)
  panel:setOpaque(true)
  self:setControlGraphic(panel)
  self:addSpot{center = 0.5 * ply, radius =  ply}
  self.menuGraphic = app.Graphic(0,0,128,64)
  self.menuGraphic:addChild(app.TextPanel("Clear All",1))
end

function MenuHeader:onCursorEnter()
  local window = self:getWindow()
  window:addSubGraphic(self.menuGraphic)
  self:grabFocus("subReleased")
end

function MenuHeader:onCursorLeave()
  local window = self:getWindow()
  window:removeSubGraphic(self.menuGraphic)
  self:releaseFocus("subReleased")
end

function MenuHeader:subReleased(i,shifted)
  if shifted then return false end
  if i==1 then
    self:sendUp("doDeleteAllControls")
  elseif i==2 then
  elseif i==3 then
  end
  return true
end

--------------------------------------------------
local BeginMenu = Class{}
BeginMenu:include(Section)

function BeginMenu:init(title)
  Section.init(self,app.sectionBegin)
  self:setClassName("ControlEditor.BeginMenu")
  self:addView("default")
  self:addControl("default",MenuHeader(title))
  self:switchView("default")
end

--------------------------------------------------
local ControlEditor = Class{}
ControlEditor:include(SpottedStrip)

function ControlEditor:init(unit)
  SpottedStrip.init(self)
  self:setClassName("ControlEditor")
  self:setInstanceName(unit.title)
  self:appendSection(BeginMenu(unit.title))
  self:appendSection(Filler())
  self.unit = unit
  self.items = {}

  -- fill in the existing controls
  for i,cz in ipairs(unit.customizations) do
    self:insert(cz.type,i,cz.id)
  end
end

function ControlEditor:insert(type,position,name)
  local item = Item(name,type)
  self.items[name] = item
  -- load before the currently selected parameter
  if position==self:getSectionCount() then
    self:insertSection(item,position)
  else
    self:insertSection(item,position+1)
  end
end

function ControlEditor:move(item,position)
  if position==self:getSectionCount() then
    self:moveSection(item,position)
  else
    self:moveSection(item,position+1)
  end
end

function ControlEditor:doInsertControl(type)
  local czd = Customizations.lookup(type)
  local candidate = self.unit:generateUniqueControlName(czd.prefix)
  local index = self:getSelectedSectionPosition() - 1
  local kb = Keyboard("Name the control.", candidate, true)
  kb:setValidator(function(text)
    return self.unit:validateControlName(text)
  end)
  local task = function(name)
    if name then
      self.unit:insertCustomization(type,index,name)
      self:insert(type,index,name)
    end
  end
  kb:subscribe("done",task)
  kb:activate()
end

function ControlEditor:doRenameControl()
  local index = self:getSelectedSectionPosition() - 1
  local cz = self.unit:getCustomization(index)
  if cz then
    local kb = Keyboard("Rename the control.", cz.id, true)
    kb:setValidator(function(text)
      return self.unit:validateControlName(text)
    end)
    local task = function(newName)
      if newName then
        local item = self.items[cz.id]
        if item then
          self.items[cz.id] = nil
          self.items[newName] = item
          item:notifyControls("onRename",cz.id,newName)
        end
        self.unit:renameCustomization(index,newName)
      end
    end
    kb:subscribe("done",task)
    kb:activate()
  end
end

function ControlEditor:doDeleteControl()
  local index = self:getSelectedSectionPosition() - 1
  local cz = self.unit:getCustomization(index)
  if cz then
    local item = self.items[cz.id]
    if item then
      self:removeSection(item)
      self.items[cz.id] = nil
    end
    self.unit:removeCustomization(index)
  end
end

function ControlEditor:doDeleteAllControls()
  local Verification = require "Verification"
  local dlg = Verification.Main("Deleting all controls.","Are you sure?")
  local task = function(ok)
    if ok then
      for id,item in pairs(self.items) do
        self:removeSection(item)
      end
      self.items = {}
      self.unit:removeAllCustomizations()
    end
  end
  dlg:subscribe("done",task)
  dlg:activate()
end

function ControlEditor:doMoveControlRight()
  local index = self:getSelectedSectionPosition() - 1
  if index == self:getSectionCount()-2 then
    -- cannot move the last section right
    return
  end
  local cz = self.unit:getCustomization(index)
  if cz then
    local item = self.items[cz.id]
    if item then
      local newIndex = index+1
      self:move(item,newIndex)
      self.unit:moveCustomization(index,newIndex)
    end
  end
end

function ControlEditor:doMoveControlLeft()
  local index = self:getSelectedSectionPosition() - 1
  if index == 1 then
    -- cannot move the first section left
    return
  end
  local cz = self.unit:getCustomization(index)
  if cz then
    local item = self.items[cz.id]
    if item then
      local newIndex = index-1
      self:move(item,newIndex)
      self.unit:moveCustomization(index,newIndex)
    end
  end
end

function ControlEditor:upReleased(shifted)
  if shifted then return false end
  self:deactivate()
  return true
end

function ControlEditor:homeReleased(shifted)
  if shifted then return false end
  self:deactivate()
  return true
end

return ControlEditor
