
bones.registered_inventories = {}

function bones.register_inventory(id, def)
	if type(id) ~= "string" then
		core.log("error", "[bones] Invalid call to bones.register_inventory.")
		return
	end
	bones.registered_inventories[id] = def or {
		has_items = function(player)
			return not player:get_inventory():is_empty(id)
		end,
		take_items = function(player)
			local inv = player:get_inventory()
			local items = inv:get_list(id)
			inv:set_list(id, {})
			return items
		end,
		restore_items = function(player, items)
			local player_inv = player:get_inventory()
			if player_inv:is_empty(id) then
				player_inv:set_list(id, items)
				return {}
			end
			local list = player_inv:get_list(id)
			for i, stack in ipairs(list) do
				if items[i] and stack:is_empty() then
					list[i], items[i] = items[i], list[i]
				end
			end
			player_inv:set_list(id, list)
			for i, stack in ipairs(items) do
				if not stack:is_empty() then
					items[i] = player_inv:add_item(id, stack)
				end
			end
			return items
		end
	}
end

local function is_list_empty(list)
	for _,stack in ipairs(list) do
		if not stack:is_empty() then
			return false
		end
	end
	return true
end

function bones.has_any_items(player)
	for _,inv in pairs(bones.registered_inventories) do
		if inv.has_items(player) then
			return true
		end
	end
	return false
end

function bones.take_all_items(player)
	local inv_lists = {}
	for id, inv in pairs(bones.registered_inventories) do
		if inv.has_items(player) then
			inv_lists[id] = inv.take_items(player)
		end
	end
	return inv_lists
end

function bones.restore_all_items(player, inv_lists)
	local unknown_lists = {}
	for id, list in pairs(inv_lists) do
		local inv = bones.registered_inventories[id]
		if inv then
			inv_lists[id] = inv.restore_items(player, list)
			if is_list_empty(inv_lists[id]) then
				inv_lists[id] = nil
			end
		else
			unknown_lists[id] = list
		end
	end
	-- Dump items in any unknown lists into the main inventory
	if next(unknown_lists) then
		local player_inv = player:get_inventory()
		for id, list in pairs(unknown_lists) do
			for i, stack in ipairs(list) do
				if not stack:is_empty() then
					list[i] = player_inv:add_item("main", stack)
				end
			end
			if is_list_empty(list) then
				inv_lists[id] = nil
			end
		end
	end
	return next(inv_lists) == nil
end

function bones.add_all_items(player, inv_lists)
	local player_inv = player:get_inventory()
	for id, list in pairs(inv_lists) do
		for i, stack in ipairs(list) do
			if not stack:is_empty() then
				list[i] = player_inv:add_item("main", stack)
			end
		end
		if is_list_empty(list) then
			inv_lists[id] = nil
		end
	end
	return next(inv_lists) == nil
end
