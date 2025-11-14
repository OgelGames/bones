
local S = core.get_translator("bones")

local function add_to_hud(player, waypoint)
	waypoint.id = player:hud_add({
		[core.features.hud_def_type_field and "type" or "hud_elem_type"] = "waypoint",
		name = S("Bones"),
		text = "m",
		number = 0xFFFFFF,
		world_pos = waypoint.pos
	})
	-- Remove the waypoint after some time
	local name = player:get_player_name()
	core.after(waypoint.expiry - os.time(), function()
		player = core.get_player_by_name(name)
		if player then
			bones.remove_waypoint(waypoint.pos, player)
		end
	end)
end

function bones.add_waypoint(pos, player)
	local meta = player:get_meta()
	local waypoints = core.deserialize(meta:get_string("bone_waypoints")) or {}
	local pos_str = core.pos_to_string(pos):gsub("-0", "0")
	if not waypoints[pos_str] then
		waypoints[pos_str] = {
			pos = pos,
			expiry = os.time() + bones.waypoint_time,
		}
	end
	add_to_hud(player, waypoints[pos_str])
	meta:set_string("bone_waypoints", core.serialize(waypoints))
end

function bones.remove_waypoint(pos, player)
	local meta = player:get_meta()
	local waypoints = core.deserialize(meta:get_string("bone_waypoints")) or {}
	local pos_str = core.pos_to_string(pos):gsub("-0", "0")
	if waypoints[pos_str] then
		player:hud_remove(waypoints[pos_str].id)
		waypoints[pos_str] = nil
		meta:set_string("bone_waypoints", core.serialize(waypoints))
	end
end

core.register_on_joinplayer(function(player)
	local meta = player:get_meta()
	local waypoints = core.deserialize(meta:get_string("bone_waypoints")) or {}
	local current_time = os.time()
	for pos_str, waypoint in pairs(waypoints) do
		if current_time < waypoint.expiry then
			add_to_hud(player, waypoint)
		else
			waypoints[pos_str] = nil
		end
	end
	meta:set_string("bone_waypoints", core.serialize(waypoints))
end)
