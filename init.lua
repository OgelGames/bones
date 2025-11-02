
bones = {
	redo = true,
	share_time = tonumber(core.settings:get("bones_share_time")) or 1200,
	waypoint_time = tonumber(core.settings:get("bones_waypoint_time")) or 3600,
	mode = core.settings:get("bones_mode") or "bones",
	position_message = core.settings:get_bool("bones_position_message", true),
}

if bones.mode ~= "bones" and bones.mode ~= "drop" and bones.mode ~= "keep" then
	bones.mode = "bones"
end

bones.waypoints = bones.waypoint_time > 0

local MP = core.get_modpath("bones")

if bones.waypoints then
	dofile(MP.."/waypoints.lua")
end

dofile(MP.."/bones.lua")
dofile(MP.."/death.lua")
dofile(MP.."/inventories.lua")

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
			return not inv:is_empty("armor")
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
					armor:run_callbacks("on_unequip", player, i, stack)
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
