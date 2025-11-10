
local S = core.get_translator("bones")

local adjacent_positions = {
	vector.new( 1, 0, 0),
	vector.new(-1, 0, 0),
	vector.new( 0, 1, 0),
	vector.new( 0, 0, 1),
	vector.new( 0, 0,-1),
}

local function in_map(pos)  -- https://github.com/OgelGames/bones/issues/6
	local size_positive = 30927
	local size_negative = -30912
	return pos.x >= size_negative and pos.x <= size_positive
	   and pos.y >= size_negative and pos.y <= size_positive
	   and pos.z >= size_negative and pos.z <= size_positive
end

local function can_replace(pos)
	if not in_map(pos) then
		return false
	end
	local node = core.get_node(pos)
	if node.name == "ignore" then
		return false  -- Never replace ignore
	end
	local def = core.registered_nodes[node.name]
	if not def then
		return false  -- Never replace unknown nodes
	end
	if def.buildable_to and not core.is_protected(pos, "") then
		return true  -- Replacing unprotected buildable_to nodes is okay
	end
	if def.liquidtype == "flowing" then
		return true  -- Flowing liquid can be replaced because it will regenerate
	end
	if def.liquidtype == "source" and def.liquid_renewable ~= false then
		-- Check if the source will regenerate
		local sources = 0
		for _,p in pairs(adjacent_positions) do
			if core.get_node(vector.add(pos, p)).name == node.name then
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
	-- Load the area to be checked, in case the death was in or near an unloaded area
	local offset = vector.new(5, 5, 5)
	core.load_area(vector.subtract(origin, offset), vector.add(origin, offset))
	-- First check for air or vacuum at player position
	if in_map(origin) then
		local node = core.get_node(origin)
		if node.name == "air" or node.name == "vacuum:vacuum" then
			return origin
		end
	end
	local above = vector.add(origin, vector.new(0, 1, 0))
	if in_map(above) then
		local above_node = core.get_node(above)
		if above_node.name == "air" or above_node.name == "vacuum:vacuum" then
			return above
		end
	end
	-- Then search for any nearby air or vacuum
	local found = core.find_node_near(origin, 5, {"air", "vacuum:vacuum"})
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

local function drop_item(pos, stack)
	local obj = core.add_item(pos, stack)
	if obj then
		obj:set_velocity({
			x = math.random(-10, 10) / 10,
			y = math.random(  1, 20) / 10,
			z = math.random(-10, 10) / 10,
		})
		return true
	end
	return false
end

local function log_death(pos, name, action, items, player)
	local pos_str = core.pos_to_string(pos)
	if action == "keep" or action == "none" then
		core.log("action", name.." dies at "..pos_str..".")
	elseif action == "bones" then
		core.log("action", name.." dies at "..pos_str..". Bones placed.")
	elseif action == "entity" then
		core.log("action", name.." dies at "..pos_str..". Entity created.")
	elseif action == "drop" then
		core.log("action", name.." dies at "..pos_str..". Inventory dropped.")
	end
	if bones.position_message then
		if action == "keep" or action == "none" then
			core.chat_send_player(name, S("You died at @1.", pos_str))
		elseif action == "bones" or action == "entity" then
			core.chat_send_player(name, S("You died at @1. Bones were placed.", pos_str))
		elseif action == "drop" then
			core.chat_send_player(name, S("You died at @1. Your inventory was dropped.", pos_str))
		end
	end
	if action == "keep" or action == "none" then
		return
	end
	if bones.obituary and items and player:get_meta():get("bones_obituary") ~= "0" then
		local obituary = bones.create_obituary(pos_str, name, items)
		player:get_inventory():add_item("main", obituary)
	end
end

core.register_on_dieplayer(function(player)
	-- Move pos up to get the node the player is standing in.
	local pos = vector.round(vector.add(player:get_pos(), vector.new(0, 0.25, 0)))
	local name = player:get_player_name()
	-- Do nothing if keep inventory is set or player has creative
	if bones.mode == "keep" or core.is_creative_enabled(name) then
		log_death(pos, name, "keep")
		return
	end
	-- Check if player has items, do nothing if they don't
	if not bones.has_any_items(player) then
		log_death(pos, name, "none")
		return
	end
	local param2 = core.dir_to_facedir(vector.multiply(player:get_look_dir(), -1), true)
	-- Check if it's possible to place bones
	local bones_pos
	if bones.mode == "bones" then
		bones_pos = find_replaceable_pos(pos)
	end
	-- Create bones entity
	if bones.mode == "entity" or (not bones_pos and bones.fallback == "entity") then
		local entity = core.add_entity(pos, "bones:entity")
		if entity then
			local items = bones.take_all_items(player)
			entity:get_luaentity():create(param2, name, items)
			log_death(pos, name, "entity", items, player)
			if bones.waypoints then
				bones.add_waypoint(pos, player)
			end
			return
		end
	end
	-- Drop items on the ground
	if bones.mode == "drop" or (not bones_pos and bones.fallback == "drop") then
		if drop_item(pos, "bones:bones") then
			local items = bones.take_all_items(player)
			for _,list in pairs(items) do
				for _,stack in ipairs(list) do
					if not stack:is_empty() then
						drop_item(pos, stack)
					end
				end
			end
			log_death(pos, name, "drop", items, player)
			return
		end
	end
	if not bones_pos then
		log_death(pos, name, "keep")
		return
	end
	-- Place bones node
	local replaced = core.get_node(bones_pos)
	core.set_node(bones_pos, {name = "bones:bones", param2 = param2})
	local meta = core.get_meta(bones_pos)
	local items = bones.take_all_items(player)
	meta:get_inventory():set_lists(items)
	meta:set_string("owner", name)
	if replaced.name ~= "air" then
		meta:set_string("replaced", core.serialize(replaced))
	end
	if bones.sharing then
		meta:set_string("infotext", S("@1's fresh bones", name))
		core.get_node_timer(bones_pos):start(10)
	else
		meta:set_string("infotext", S("@1's bones", name))
	end
	log_death(bones_pos, name, "bones", items, player)
	if bones.waypoints then
		bones.add_waypoint(bones_pos, player)
	end
end)
