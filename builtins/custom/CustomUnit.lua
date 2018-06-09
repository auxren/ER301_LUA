-- GLOBALS: app, os, verboseLevel, connect, tie
local app = app
local Class = require "Base.Class"
local Utils = require "Utils"
local Unit = require "Unit"
local PatchMeter = require "Unit.ViewControl.PatchMeter"
local Patch = require "Chain.Patch"
local Task = require "Unit.MenuControl.Task"
local ControlEditor = require "builtins.custom.ControlEditor"
local Encoder = require "Encoder"
local Customizations = require "builtins.custom.Customizations"
local ply = app.SECTION_PLY

local CustomUnit = Class{}
CustomUnit:include(Unit)

function CustomUnit:init(args)
  args.title = "Custom Unit"
  args.mnemonic = "CU"
  args.custom = true
  Unit.init(self,args)
  self.customizations = {}
end

function CustomUnit:doEditControls()
  local editor = ControlEditor(self)
  editor:activate()
end

function CustomUnit:insertForeignControl(index,id,control,viewName)
  local controls = self.controls
  control.id = id
  control.viewName = viewName
  controls[id] = control
  self:addChildWidget(control)
  control:onInsert()
  local viewInfo = self:addView(viewName)
  -- skip the insert, header and patch meter
  table.insert(viewInfo.controls,index+3,control)
  if self.currentView == viewName then
    self:rebuildView()
  end
end

function CustomUnit:moveForeignControl(id,oldIndex,newIndex)
  local control = self.controls[id]
  if control then
    local viewInfo = self:getViewInfo(control.viewName)
    table.remove(viewInfo.controls,oldIndex+3)
    table.insert(viewInfo.controls,newIndex+3,control)
    if self.currentView == control.viewName then
      self:rebuildView()
    end
  end
end

function CustomUnit:renameForeignControl(id,name)
  local controls = self.controls
  local control = controls[id]
  if control then
    controls[id] = nil
    controls[name] = control
    control:rename(name)
    control.id = name
  end
end

function CustomUnit:removeForeignControl(id)
  local controls = self.controls
  local control = controls[id]
  if control and control.viewName then
    local viewInfo = self:getViewInfo(control.viewName)
    for i,control2 in ipairs(viewInfo.controls) do
      if control2 == control then
        table.remove(viewInfo.controls,i)
        break
      end
    end
    controls[id] = nil
    if self.currentView == control.viewName then
      self:rebuildView()
    end
    self:removeChildWidget(control)
    control:onRemove()
  end
end

function CustomUnit:generateUniqueControlName(prefix)
  local suffix = 1
  local name
  local exists = true
  while exists do
    name = prefix..tostring(suffix)
    exists = false
    for i,cz in ipairs(self.customizations) do
      if name==cz.id then
        exists = true
        suffix = suffix + 1
        break
      end
    end
  end
  return name
end

function CustomUnit:validateControlName(name)
  if name=="" then
    return false, "Blank names are not allowed."
  end
  for i,cz in ipairs(self.customizations) do
    if name==cz.id then
      return false, name.." already exists."
    end
  end
  return true
end

function CustomUnit:insertCustomization(type,index,id,description)
  local czd = Customizations.lookup(type)
  if czd==nil then
    app.log("Unknown customization type: "..type)
    return
  end

  id = id or self:generateUniqueControlName(czd.prefix)
  description = description or czd.description
  local control,source,branch = czd.create(self,id,description)
  self.patch:addLocalSource(source)
  self.pUnit:lock()
  self.pUnit:compile()
  self.pUnit:unlock()
  self:insertForeignControl(index,id,control,"expanded")
  if self.started then
    branch:start()
  end

  local cz = {
    id = id,
    description = description,
    type = type,
  }

  table.insert(self.customizations,index,cz)
end

function CustomUnit:getCustomizationObjects(id)
  local found = {}
  local objects = self.objects
  local key = id.."_"
  for oname,o in pairs(objects) do
    if Utils.startsWith(oname,key) then
      found[oname] = o
    end
  end
  return found
end

function CustomUnit:renameCustomization(index,name)
  local cz = self.customizations[index]
  if cz then
    self:renameForeignControl(cz.id,name)
    self.patch:renameLocalSource(cz.id,name)
    -- rename objects
    local found = self:getCustomizationObjects(cz.id)
    for oname,o in pairs(found) do
      self.objects[oname] = nil
      oname = oname:gsub(cz.id,name)
      self.objects[oname] = o
      o:setName(oname)
    end
    -- rename branch
    self:renameBranch(cz.id,name)
    -- finally rename the customization
    cz.id = name
  end
end

function CustomUnit:moveCustomization(oldIndex,newIndex)
  if newIndex < 1 then
    newIndex = 1
  elseif newIndex > #self.customizations then
    newIndex = #self.customizations
  end
  if oldIndex==newIndex then
    return
  end
  local cz = self.customizations[oldIndex]
  if cz then
    self:moveForeignControl(cz.id,oldIndex,newIndex)
    table.remove(self.customizations,oldIndex)
    table.insert(self.customizations,newIndex,cz)
  end
end

function CustomUnit:getCustomization(index)
  return self.customizations[index]
end

function CustomUnit:removeAllCustomizations()
  for i = 1,#self.customizations do
    -- keep removing the front element
    self:removeCustomization(1)
  end
end

function CustomUnit:removeCustomization(index)
  local cz = self.customizations[index]
  if cz then
    local branch = self:getBranch(cz.id)
    if branch then
      branch:stop()
      branch:releaseResources()
    end
    self:removeForeignControl(cz.id)
    self.patch:removeLocalSource(cz.id)
    self:removeBranch(cz.id)
    self.pUnit:lock()
    local found = self:getCustomizationObjects(cz.id)
    for oname,o in pairs(found) do
      self:removeObject(oname)
    end
    self.pUnit:compile()
    self.pUnit:unlock()
    table.remove(self.customizations,index)
  end
end

local menu = {
  "infoHeader",
  "rename",
  "load",
  "save",
  "edit"
}

function CustomUnit:onLoadMenu(objects,controls)
  controls.edit = Task {
    description = "Edit Controls",
    task = function() self:doEditControls() end
  }
  return menu
end

local views = {
  expanded = {"meter"},
  collapsed = {},
}

function CustomUnit:onLoadViews(objects,controls)
  self.patch = Patch {
    title = self.title,
    depth = self.depth,
    channelCount = self.channelCount,
    unit = self
  }

  controls.meter = PatchMeter {
    button = "patch",
    description = "Patch",
    patch = self.patch
  }

  return views
end

function CustomUnit:onRemove()
  for i = 1,#self.customizations do
    self:removeCustomization(i)
  end
  self.patch:stop()
  self.patch:releaseResources()
  Unit.onRemove(self)
end

function CustomUnit:onGenerateTitle()
  local Random = require "Random"
  self:setTitle(Random.generateName())
  self.hasUserTitle = true
end

function CustomUnit:collectLocalSources(t)
  t = self.patch:collectLocalSources(t or {})
  return Unit.collectLocalSources(self,t)
end

function CustomUnit:findLocalSource(name)
  return self.patch:findLocalSource(name) or Unit.findLocalSource(self,name)
end

function CustomUnit:serialize()
  local t = Unit.serialize(self)
  -- add customizations
  local data = {}
  for i,cz in ipairs(self.customizations) do
    data[i] = {
      controlName = cz.id,
      controlType = cz.type,
      description = cz.description,
    }
  end
  t.customizations = data
  -- add patch
  t.patch = self.patch:serialize()
  return t
end

local function fixLegacyData(data)
  if data then
    local keys = {}
    local prefixes = {
      ["Ax+B"] = "cv",
      ["Gate"] = "gate",
      ["V/oct"] = "V/oct",
      ["db(Ax+B)"] = "dB"
    }
    for i,czd in ipairs(data) do
      if czd.id==nil and czd.controlName==nil then
        local prefix = prefixes[czd.controlType]
        if prefix then
          czd.controlName = Utils.generateUniqueKey(keys,prefix)
          keys[czd.controlName] = true
        end
      end
    end
  end
  return data
end

function CustomUnit:deserialize(t)
  self:removeAllCustomizations()
  -- add customizations
  local data = fixLegacyData(t.customizations)
  if data then
    for i,czd in ipairs(data) do
      local name = czd.controlName or czd.id
      self:insertCustomization(czd.controlType,i,name,czd.description)
    end
  end
  -- add patch
  data = t.patch
  if data then
    self.patch:deserialize(data)
  end
  Unit.deserialize(self,t)
end

return CustomUnit
