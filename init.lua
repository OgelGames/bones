
bones = {
	redo = true,
	share_time = tonumber(core.settings:get("bones_share_time")) or 1800,
	waypoint_time = tonumber(core.settings:get("bones_waypoint_time")) or 3600,
	mode = core.settings:get("bones_mode") or "bones",
	fallback = core.settings:get("bones_fallback_mode") or "entity",
	position_message = core.settings:get_bool("bones_position_message", true),
	pickup = core.settings:get_bool("bones_pickup", true),
	obituary = core.settings:get_bool("bones_obituary", true),
}

bones.waypoints = bones.waypoint_time > 0
bones.sharing = bones.share_time > 0

-- Some checks for bad settings
if bones.mode ~= "bones" and bones.mode ~= "entity" and bones.mode ~= "drop" and bones.mode ~= "keep" then
	bones.mode = "bones"
end
if bones.fallback ~= "entity" and bones.fallback ~= "drop" and bones.fallback ~= "keep" then
	bones.fallback = "entity"
end
if bones.mode == "entity" and bones.fallback ~= "keep" then
	bones.fallback = "drop"
end
if bones.mode == "drop" then
	bones.fallback = "keep"
end

local MP = core.get_modpath("bones")

if bones.waypoints then
	dofile(MP.."/waypoints.lua")
end

dofile(MP.."/bones.lua")
dofile(MP.."/entity.lua")
dofile(MP.."/obituary.lua")
dofile(MP.."/death.lua")
dofile(MP.."/inventories.lua")
dofile(MP.."/functions.lua")

bones.register_inventory("main")
bones.register_inventory("craft")

if core.get_modpath("3d_armor") then
	-- Remove 3d_armor's on_dieplayer function
	-- Uses the undocumented (but very useful) core.callback_origins to find the correct function
	for i,func in pairs(core.registered_on_dieplayers) do
		if core.callback_origins[func].mod == "3d_armor" then
			core.callback_origins[func] = nil
			table.remove(core.registered_on_dieplayers, i)
			break
		end
	end
	-- Register the armor inventory
	bones.register_inventory("armor", {
		has_items = function(player)
			local name, inv = armor:get_valid_player(player)
			if not name then
				return
			end
			for i, stack in ipairs(inv:get_list("armor")) do
				if not stack:is_empty() and core.get_item_group(stack:get_name(), "soulbound") == 0 then
					return true
				end
			end
			return false
		end,
		take_items = function(player)
			local name, inv = armor:get_valid_player(player)
			if not name then
				return
			end
			local items = inv:get_list("armor")
			inv:set_list("armor", {})
			for i, stack in ipairs(items) do
				if not stack:is_empty() then
					if core.get_item_group(stack:get_name(), "soulbound") ~= 0 then
						inv:set_stack("armor", i, stack)
						items[i] = ItemStack()
					else
						armor:run_callbacks("on_unequip", player, i, stack)
					end
				end
			end
			armor:save_armor_inventory(player)
			armor:set_player_armor(player)
			return items
		end,
		restore_items = function(player, items)
			local name = armor:get_valid_player(player)
			if not name then
				return items
			end
			for i, stack in ipairs(items) do
				if not stack:is_empty() then
					items[i] = armor:equip(player, stack)
				end
			end
			return items
		end
	})
end
