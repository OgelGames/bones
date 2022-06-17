
local S = minetest.get_translator("bones")

local function add_to_hud(player, waypoint)
	waypoint.id = player:hud_add({
		hud_elem_type = "waypoint",
		name = S("Bones"),
		text = "m",
		number = 0xFFFFFF,
		world_pos = waypoint.pos
	})
	-- Remove the waypoint after some time
	local name = player:get_player_name()
	minetest.after(waypoint.expiry - os.time(), function()
		player = minetest.get_player_by_name(name)
		if player then
			bones.remove_waypoint(waypoint.pos, player)
		end
	end)
end

function bones.add_waypoint(pos, player)
	local meta = player:get_meta()
	local waypoints = minetest.deserialize(meta:get_string("bone_waypoints")) or {}
	local pos_string = minetest.pos_to_string(pos)
	if not waypoints[pos_string] then
		waypoints[pos_string] = {
			pos = pos,
			expiry = os.time() + bones.waypoint_time,
		}
	end
	add_to_hud(player, waypoints[pos_string])
	meta:set_string("bone_waypoints", minetest.serialize(waypoints))
end

function bones.remove_waypoint(pos, player)
	local meta = player:get_meta()
	local waypoints = minetest.deserialize(meta:get_string("bone_waypoints")) or {}
	local pos_string = minetest.pos_to_string(pos)
	if waypoints[pos_string] then
		player:hud_remove(waypoints[pos_string].id)
		waypoints[pos_string] = nil
		meta:set_string("bone_waypoints", minetest.serialize(waypoints))
	end
end

minetest.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	local waypoints = minetest.deserialize(meta:get_string("bone_waypoints")) or {}
	local current_time = os.time()
	for pos_string, waypoint in pairs(waypoints) do
		if current_time < waypoint.expiry then
			local node = minetest.get_node_or_nil(waypoint.pos)
			if not node then
				minetest.load_area(waypoint.pos)
				node = minetest.get_node(waypoint.pos)
			end
			if node.name == "bones:bones" then
				add_to_hud(player, waypoint)
			else
				waypoints[pos_string] = nil
			end
		else
			waypoints[pos_string] = nil
		end
	end
	meta:set_string("bone_waypoints", minetest.serialize(waypoints))
end)
