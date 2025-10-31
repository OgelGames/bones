
bones = {
	redo = true,
	registered_inventories = {},
	share_time = tonumber(core.settings:get("bones_share_time")) or 1200,
	waypoint_time = tonumber(core.settings:get("bones_waypoint_time")) or 3600,
	mode = core.settings:get("bones_mode") or "bones",
	position_message = core.settings:get_bool("bones_position_message", true),
}

if bones.mode ~= "bones" and bones.mode ~= "drop" and bones.mode ~= "keep" then
	bones.mode = "bones"
end

local MP = core.get_modpath("bones")

if bones.waypoint_time > 0 then
	dofile(MP.."/waypoints.lua")
end

dofile(MP.."/bones.lua")
dofile(MP.."/death.lua")

-- API to register inventories to be placed in bones on death
-- Can either be the name of a list in the player's inventory, or a function that returns a list
function bones.register_inventory(inv)
	if type(inv) == "string" or type(inv) == "function" then
		table.insert(bones.registered_inventories, inv)
	end
end

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
	-- Register the inventory function
	bones.register_inventory(function(player)
		local name, inv = armor:get_valid_player(player, "[on_dieplayer]")
		if not name then
			return
		end
		local items = inv:get_list("armor")
		for i,stack in pairs(items) do
			if stack:get_count() > 0 then
				armor:run_callbacks("on_unequip", player, i, stack)
			end
		end
		inv:set_list("armor", {})
		armor:save_armor_inventory(player)
		armor:set_player_armor(player)
		return items
	end)
end
