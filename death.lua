
local S = minetest.get_translator("bones")

local adjacent_positions = {
	vector.new( 1, 0, 0),
	vector.new(-1, 0, 0),
	vector.new( 0, 1, 0),
	vector.new( 0, 0, 1),
	vector.new( 0, 0,-1),
}

local function in_map(pos)  -- https://github.com/OgelGames/bones/issues/6
	local size = 30927
	return pos.x > -size and pos.x < size
	   and pos.y > -size and pos.y < size
	   and pos.z > -size and pos.z < size
end

local function can_replace(pos)
	if not in_map(pos) then
		return false
	end
	local node = minetest.get_node(pos)
	if node.name == "ignore" then
		return false  -- Never replace ignore
	end
	local def = minetest.registered_nodes[node.name]
	if not def then
		return false  -- Never replace unknown nodes
	end
	if def.buildable_to and not minetest.is_protected(pos, "") then
		return true  -- Replacing unprotected buildable_to nodes is okay
	end
	if def.liquidtype == "flowing" then
		return true  -- Flowing liquid can be replaced because it will regenerate
	end
	if def.liquidtype == "source" and def.liquid_renewable ~= false then
		-- Check if the source will regenerate
		local sources = 0
		for _,p in pairs(adjacent_positions) do
			if minetest.get_node(vector.add(pos, p)).name == node.name then
				sources = sources + 1
			end
			if sources > 1 then
				return true  -- There are enough adjacent sources, so okay to replace
			end
		end
	end
	return false
end

local function find_replaceable_pos(origin)
	-- First check for air or vacuum at player position
	if in_map(origin) then
		local node = minetest.get_node(origin)
		if node.name == "air" or node.name == "vacuum:vacuum" then
			return origin
		end
	end
	local above = vector.add(origin, vector.new(0, 1, 0))
	if in_map(above) then
		local above_node = minetest.get_node(above)
		if above_node.name == "air" or above_node.name == "vacuum:vacuum" then
			return above
		end
	end
	-- Then search for any nearby air or vacuum
	local found = minetest.find_node_near(origin, 5, {"air", "vacuum:vacuum"})
	if found and in_map(found) then
		return found
	end
	-- As a final attempt, check if any nearby node can be replaced
	local pos
	for x=-1,1 do for y=-1,1 do for z=-1,1 do
		pos = vector.add(origin, vector.new(x, y, z))
		if can_replace(pos) then
			return pos
		end
	end end end
end

local function get_all_items(player)
	local items = {}
	local player_inv = player:get_inventory()
	for _,inv in pairs(bones.registered_inventories) do
		local list
		if type(inv) == "function" then
			list = inv(player)
		else
			list = player_inv:get_list(inv)
			player_inv:set_list(inv, {})
		end
		if list then
			for _,stack in pairs(list) do
				if stack:get_count() > 0 then
					items[#items+1] = stack
				end
			end
		end
	end
	return items
end

local function drop_item(pos, stack)
	local obj = minetest.add_item(pos, stack)
	if obj then
		obj:set_velocity({
			x = math.random(-10, 10) / 10,
			y = math.random(  1, 20) / 10,
			z = math.random(-10, 10) / 10,
		})
	end
end

local function log_death(pos, name, action)
	local pos_str = minetest.pos_to_string(pos)
	if action == "keep" or action == "none" then
		minetest.log("action", name.." dies at "..pos_str..". No bones placed.")
	elseif action == "bones" then
		minetest.log("action", name.." dies at "..pos_str..". Bones placed.")
	elseif action == "drop" then
		minetest.log("action", name.." dies at "..pos_str..". Inventory dropped.")
	end
	if not bones.position_message then
		return
	end
	if action == "keep" or action == "none" then
		minetest.chat_send_player(name, S("You died at @1.", pos_str))
	elseif action == "bones" then
		minetest.chat_send_player(name, S("You died at @1. Bones were placed.", pos_str))
	elseif action == "drop" then
		minetest.chat_send_player(name, S("You died at @1. Your inventory was dropped.", pos_str))
	end
end

minetest.register_on_dieplayer(function(player)
	local pos = vector.round(player:get_pos())
	local name = player:get_player_name()
	-- Do nothing if keep inventory is set or player has creative
	if bones.mode == "keep" or minetest.is_creative_enabled(name) then
		log_death(pos, name, "keep")
		return
	end
	-- Check if it's possible to place bones
	local bones_pos
	if bones.mode == "bones" then
		bones_pos = find_replaceable_pos(pos)
	end
	-- Keep items if no pos is found and drops are disabled
	if bones.fallback_mode == true and not bones_pos then
		log_death(pos, name, "keep")
		return
	end
	-- Check if player has items, do nothing if they don't
	local items = get_all_items(player)
	if #items == 0 then
		log_death(pos, name, "none")
		return
	end
	-- Drop items on the ground
	if bones.mode == "drop" or (bones.fallback_mode == false and not bones_pos) then
		for _,stack in pairs(items) do
			drop_item(pos, stack)
		end
		drop_item(pos, "bones:bones")
		log_death(pos, name, "drop")
		return
	end
	-- Place bones
	local param2 = minetest.dir_to_facedir(player:get_look_dir())
	minetest.set_node(bones_pos, {name = "bones:bones", param2 = param2})
	local meta = minetest.get_meta(bones_pos)
	local inv = meta:get_inventory()
	inv:set_size("main", #items)
	inv:set_list("main", items)
	if bones.share_time > 0 then
		meta:set_string("infotext", S("@1's fresh bones", name))
		meta:set_string("owner", name)
		minetest.get_node_timer(bones_pos):start(10)
	else
		meta:set_string("infotext", S("@1's bones", name))
	end
	log_death(bones_pos, name, "bones")
	-- Add waypoint
	if bones.waypoint_time > 0 then
		bones.add_waypoint(bones_pos, player)
	end
end)
