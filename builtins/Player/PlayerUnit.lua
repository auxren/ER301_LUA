
local Class = require "Base.Class"
local BasePlayer = require "builtins.Player.BasePlayer"

local PlayerUnit = Class{}
PlayerUnit:include(BasePlayer)

function PlayerUnit:init(args)
  args.title = "Sample Player"
  args.mnemonic = "SP"
  args.enableVariableSpeed = true
  BasePlayer.init(self,args)
end

return PlayerUnit
