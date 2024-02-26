
local S = minetest.get_translator("bones")

local function is_owner(pos, name)
	local meta = minetest.get_meta(pos)
	if meta:get_int("time") >= bones.share_time then
		return true
	end
	local owner = meta:get_string("owner")
	if owner == "" or owner == name or minetest.check_player_privs(name, "protection_bypass") then
		return true
	end
	return false
end

minetest.register_node("bones:bones", {
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
		return minetest.get_meta(pos):get_inventory():is_empty("main")
	end,
	on_punch = function(pos, node, player)
		local meta = minetest.get_meta(pos)
		local name = player:get_player_name()
		if meta:get_string("infotext") == "" or not is_owner(pos, name) then
			return
		end
		-- Move as many items as possible to the player's inventory
		local inv = meta:get_inventory()
		local player_inv = player:get_inventory()
		for i=1, inv:get_size("main") do
			local stack = inv:get_stack("main", i)
			if player_inv:room_for_item("main", stack) then
				player_inv:add_item("main", stack)
				inv:set_stack("main", i, nil)
			end
		end
		-- Remove bones if they have been emptied
		if inv:is_empty("main") then
			if player_inv:room_for_item("main", "bones:bones") then
				player_inv:add_item("main", "bones:bones")
			else
				minetest.add_item(pos, "bones:bones")
			end
			minetest.remove_node(pos)
		end
		-- Log the bone-taking
		minetest.log("action", name.." takes items from bones at "..minetest.pos_to_string(pos))
	end,
	on_timer = function(pos, elapsed)
		local meta = minetest.get_meta(pos)
		local t = meta:get_int("time") + elapsed
		meta:set_int("time", t)
		if t < bones.share_time then
			return true
		else
			meta:set_string("infotext", S("@1's old bones", meta:get_string("owner")))
		end
	end,
	on_destruct = function(pos)
		if bones.waypoint_time <= 0 then
			return
		end
		local name = minetest.get_meta(pos):get_string("owner")
		local player = minetest.get_player_by_name(name)
		if player then
			bones.remove_waypoint(pos, player)
		end
	end,
	on_blast = function() end,
})
