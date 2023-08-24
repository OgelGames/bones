
bones = {
	redo = true,
	registered_inventories = {},
	share_time = tonumber(minetest.settings:get("bones_share_time")) or 1200,
	waypoint_time = tonumber(minetest.settings:get("bones_waypoint_time")) or 3600,
	mode = minetest.settings:get("bones_mode") or "bones",
	position_message = minetest.settings:get_bool("bones_position_message", true),
	fallback_mode = minetest.settings:get_bool("bones_fallback_mode", false),
}

if bones.mode ~= "bones" and bones.mode ~= "drop" and bones.mode ~= "keep" then
	bones.mode = "bones"
end

if bones.mode ~= "bones" and bones.fallback_mode ~= false then
	bones.fallback_mode = false
end

local MP = minetest.get_modpath("bones")

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

if minetest.get_modpath("3d_armor") then
	-- Remove 3d_armor's on_dieplayer function
	-- Uses the undocumented (but very useful) minetest.callback_origins to find the correct function
	for i,func in pairs(minetest.registered_on_dieplayers) do
		if minetest.callback_origins[func].mod == "3d_armor" then
			minetest.callback_origins[func] = nil
			table.remove(minetest.registered_on_dieplayers, i)
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
