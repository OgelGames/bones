
local S = core.get_translator("bones")

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
	can_dig = function(pos)
		local inv = core.get_meta(pos):get_inventory()
		for name in pairs(inv:get_lists()) do
			if not inv:is_empty(name) then
				return false
			end
		end
		return true
	end,
	on_punch = function(pos, node, player)
		local meta = core.get_meta(pos)
		local owner = meta:get("owner")
		if not owner then
			return  -- Ignore empty (decorative) bones.
		end
		local name = player:get_player_name()
		if not bones.can_collect(name, owner, meta:get_int("time")) then
			core.chat_send_player(name, S("These bones belong to @1.", owner))
			return
		end
		local inv = meta:get_inventory()
		local items = inv:get_lists()
		if bones.collect_bones(pos, player, owner, items, meta:get("punched")) then
			local replaced = core.deserialize(meta:get_string("replaced"))
			if replaced then
				core.set_node(pos, replaced)
			else
				core.remove_node(pos)
			end
		else
			meta:set_int("punched", 1)
			inv:set_lists(items)
		end
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
	on_destruct = bones.waypoint_time > 0 and function(pos)
		local name = core.get_meta(pos):get_string("owner")
		local player = core.get_player_by_name(name)
		if player then
			bones.remove_waypoint(pos, player)
		end
	end or nil,
	on_movenode = bones.waypoint_time > 0 and function(from_pos, to_pos)
		local meta = core.get_meta(to_pos)
		local owner = meta:get("owner")
		if not owner then
			return  -- Ignore empty (decorative) bones.
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
