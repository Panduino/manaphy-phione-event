return function(mod)
  if mod.generation ~= 3 then return end

  local installed = false
  local function install()
    if installed then return true end

    local Runtime = require("src.core.game3.runtime")
    local Player = require("src.core.game3.player")
    local Field = require("src.core.game3.field")
    local MANAPHY_NAT, PHIONE_NAT = 490, 489
    local MANAPHY_SPECIES, PHIONE_SPECIES = MANAPHY_NAT + 64, PHIONE_NAT + 64
    local ROUTE5_DAYCARE = "FR_ROUTE_5_POKEMON_DAY_CARE"
    local manaphyGiftBusy = false

    local function manaphyState(session)
      session.modData = session.modData or {}
      session.modData[mod.id] = session.modData[mod.id] or {}
      local state = session.modData[mod.id]
      if not state._legacyMigrated then
        local legacy = session.modData.rtc_untamed_nationaldex_compat
        if type(legacy) == "table" and legacy.manaphyEggReceived == true then
          state.manaphyEggReceived = true
        end
        state._legacyMigrated = true
      end
      return state
    end

    local function partyHasSpace(session)
      local n = 0
      for i = 1, 6 do if session.party and session.party[i] then n = n + 1 end end
      return n < 6
    end

    local function giveManaphyEgg(session)
      if not session or not partyHasSpace(session) then return false end
      local Breeding = require("src.core.game3.breeding")
      local Daycare = require("src.core.game3.daycare")
      local egg = Breeding.createEgg(session, MANAPHY_SPECIES, false)
      if not egg then return false end
      egg.isEgg = true
      session.party = session.party or {}
      session.party[6] = egg
      Daycare.compactParty(session)
      manaphyState(session).manaphyEggReceived = true
      return true
    end

    local Breeding = require("src.core.game3.breeding")
    if not Breeding._manaphyPhioneEvent then
      Breeding._manaphyPhioneEvent = true
      local rawCompatibility = Breeding.compatibility
      Breeding.compatibility = function(dc, ...)
        local Daycare = require("src.core.game3.daycare")
        local a = tonumber(Daycare.speciesOf(Daycare.mon(dc, 1))) or 0
        local b = tonumber(Daycare.speciesOf(Daycare.mon(dc, 2))) or 0
        if (a == MANAPHY_SPECIES and b == 132) or (b == MANAPHY_SPECIES and a == 132) then
          return Breeding.PARENTS_MED_COMPATIBILITY
        end
        return rawCompatibility(dc, ...)
      end
      local rawParentSlots = Breeding.parentSlots
      Breeding.parentSlots = function(dc, ...)
        local Daycare = require("src.core.game3.daycare")
        local a = tonumber(Daycare.speciesOf(Daycare.mon(dc, 1))) or 0
        local b = tonumber(Daycare.speciesOf(Daycare.mon(dc, 2))) or 0
        if a == MANAPHY_SPECIES and b == 132 then return PHIONE_SPECIES, 1, 2 end
        if b == MANAPHY_SPECIES and a == 132 then return PHIONE_SPECIES, 2, 1 end
        return rawParentSlots(dc, ...)
      end
    end

    if not Field._manaphyPhioneDaycareGift then
      Field._manaphyPhioneDaycareGift = true
      local rawDaycareInteract = Field.interact
      Field.interact = function(...)
        local session = Runtime and Runtime.getSession and Runtime.getSession()
        if session and session.map == ROUTE5_DAYCARE and session.game_cleared == true
          and manaphyState(session).manaphyEggReceived ~= true and not manaphyGiftBusy then
          local P = Player
          local targetX, targetY = P.cellX, P.cellY
          if P.facing == "up" then targetY = targetY - 1
          elseif P.facing == "down" then targetY = targetY + 1
          elseif P.facing == "left" then targetX = targetX - 1
          elseif P.facing == "right" then targetX = targetX + 1 end
          if targetX == 4 and targetY == 4 then
            local Message = require("src.ui.game3.message")
            manaphyGiftBusy = true
            Field.locked = true
            Message.show("Ah, CHAMPION! I've been hoping you'd stop by.", function()
              Message.show("I found a very unusual POKEMON EGG.", function()
                Message.show("Something tells me it belongs with a TRAINER like you.", function()
                  if giveManaphyEgg(session) then
                    Message.show("{PLAYER} received the mysterious EGG!", function()
                      Message.show("Take good care of it. I wonder what will hatch...", function()
                        Field.locked = false
                        manaphyGiftBusy = false
                      end)
                    end)
                  else
                    Message.show("Oh! You don't have room for the EGG.", function()
                      Message.show("Come back when you have space in your party.", function()
                        Field.locked = false
                        manaphyGiftBusy = false
                      end)
                    end)
                  end
                end)
              end)
            end)
            return true
          end
        end
        return rawDaycareInteract(...)
      end
    end

    installed = true
    mod.log:info("Manaphy + Phione Event installed")
    return true
  end

  mod.events:on("game.ready", install, -40)
end
