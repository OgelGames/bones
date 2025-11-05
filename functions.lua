
local S = core.get_translator("bones")

function bones.stacks_to_strings(inventory)
	for _,list in pairs(inventory) do
		for i, stack in ipairs(list) do
			list[i] = stack:to_string()
		end
	end
	return inventory
end

function bones.strings_to_stacks(inventory)
	for _,list in pairs(inventory) do
		for i, str in ipairs(list) do
			list[i] = ItemStack(str)
		end
	end
	return inventory
end

function bones.can_collect(name, owner, elapsed)
	if bones.share_time > 0 and elapsed >= bones.share_time then
		return true
	end
	if owner == "" or owner == name or core.check_player_privs(name, "protection_bypass") then
		return true
	end
	return false
end

function bones.collect_bones(pos, player, owner, items, punched)
	-- Move as many items as possible to the player's inventory
	local name = player:get_player_name()
	local empty
	if owner == name and not punched then
		empty = bones.restore_all_items(player, items)
	else
		empty = bones.add_all_items(player, items)
	end
	-- Remove bones if they have been emptied
	local pos_string = core.pos_to_string(pos)
	if empty then
		local player_inv = player:get_inventory()
		if player_inv:room_for_item("main", "bones:bones") then
			player_inv:add_item("main", "bones:bones")
		else
			core.add_item(pos, "bones:bones")
		end
		if owner ~= name then
			core.chat_send_player(name, S("You collected @1's bones at @2.", owner, pos_string))
		end
		core.log("action", name.." removes bones at "..pos_string)
		core.sound_play("bones_dug", {gain = 0.8}, true)
		return true
	end
	-- Log the bone-taking
	core.log("action", name.." takes items from bones at "..pos_string)
	return false
end
