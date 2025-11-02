
local S = core.get_translator("bones")

local function is_owner(pos, name)
	local meta = core.get_meta(pos)
	if meta:get_int("time") >= bones.share_time then
		return true
	end
	local owner = meta:get_string("owner")
	if owner == "" or owner == name or core.check_player_privs(name, "protection_bypass") then
		return true
	end
	return false
end

core.register_node("bones:bones", {
	description = S("Bones"),
	tiles = {
		"bones_top.png^[transform2",
		"bones_bottom.png",
		"bones_side.png",
		"bones_side.png^[transform4",
		"bones_rear.png",
		"bones_front.png"
	},
	paramtype2 = "facedir",
	groups = {dig_immediate = 2},
	is_ground_content = false,
	sounds = {
		footstep = {name = "bones_footstep", gain = 1.1},
		dig = {name = "bones_dig", gain = 0.9},
		dug = {name = "bones_dug", gain = 0.8},
		place = {name = "bones_place", gain = 0.7},
	},
	can_dig = function(pos, player)
		return core.get_meta(pos):get_inventory():is_empty("main")
	end,
	on_punch = function(pos, node, player)
		local meta = core.get_meta(pos)
		local name = player:get_player_name()
		if meta:get_string("infotext") == "" or not is_owner(pos, name) then
			return
		end
		-- Move as many items as possible to the player's inventory
		local inv = meta:get_inventory()
		local inv_lists = inv:get_lists()
		local empty
		if meta:get_string("owner") == name then
			empty = bones.restore_all_items(player, inv_lists)
		else
			empty = bones.add_all_items(player, inv_lists)
		end
		-- Remove bones if they have been emptied
		if empty then
			local player_inv = player:get_inventory()
			if player_inv:room_for_item("main", "bones:bones") then
				player_inv:add_item("main", "bones:bones")
			else
				core.add_item(pos, "bones:bones")
			end
			core.remove_node(pos)
		else
			inv:set_lists(inv_lists)
		end
		-- Log the bone-taking
		core.log("action", name.." takes items from bones at "..core.pos_to_string(pos))
	end,
	on_timer = function(pos, elapsed)
		local meta = core.get_meta(pos)
		local t = meta:get_int("time") + elapsed
		meta:set_int("time", t)
		if t < bones.share_time then
			return true
		else
			meta:set_string("infotext", S("@1's old bones", meta:get_string("owner")))
		end
	end,
	on_destruct = bones.waypoints and function(pos)
		local name = core.get_meta(pos):get_string("owner")
		local player = core.get_player_by_name(name)
		if player then
			bones.remove_waypoint(pos, player)
		end
	end or nil,
	on_movenode = bones.waypoints and function(from_pos, to_pos)
		local meta = core.get_meta(to_pos)
		local owner = meta:get_string("owner")
		-- Ignore empty (decorative) bones.
		if owner == "" then
			return
		end
		local player = core.get_player_by_name(owner)
		if player then
			bones.remove_waypoint(from_pos, player)
			bones.add_waypoint(to_pos, player)
		end
		local from = core.pos_to_string(from_pos)
		local to = core.pos_to_string(to_pos)
		core.log("action", "Bones of "..owner.." moved from "..from.." to "..to)
	end or nil,
	on_blast = function() end,
})
