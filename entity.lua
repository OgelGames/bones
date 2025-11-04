
local S = core.get_translator("bones")

local function is_owner(self, name)
	if self.timer >= bones.share_time then
		return true
	end
	if self.owner == "" or self.owner == name or core.check_player_privs(name, "protection_bypass") then
		return true
	end
	return false
end

local function to_strings(inventory)
	for _,list in pairs(inventory) do
		for i, stack in ipairs(list) do
			list[i] = stack:to_string()
		end
	end
	return inventory
end

local function to_stacks(inventory)
	for _,list in pairs(inventory) do
		for i, str in ipairs(list) do
			list[i] = ItemStack(str)
		end
	end
	return inventory
end

core.register_entity("bones:entity", {
	initial_properties = {
		visual = "cube",
		textures = {
			"bones_top.png^[transform2",
			"bones_bottom.png",
			"bones_side.png",
			"bones_side.png^[transform4",
			"bones_rear.png",
			"bones_front.png"
		},
		collisionbox = {-0.5, -0.5, -0.5, 0.5, 0.5, 0.5},
		physical = true,
		collide_with_objects = true,
		damage_texture_modifier = "",
	},
	rotation = 0,
	inventory = {},
	owner = "",
	timer = 0,
	create = function(self, rotation, owner, inventory)
		self.rotation = rotation or 0
		self.owner = owner or ""
		self.inventory = inventory or {}
		local infotext
		if bones.share_time > 0 then
			if self.timer >= bones.share_time then
				infotext = S("@1's old bones", owner)
			else
				infotext = S("@1's fresh bones", owner)
			end
		else
			infotext = S("@1's bones", owner)
		end
		self.object:set_properties({
			infotext = infotext,
		})
	end,
	get_staticdata = function(self)
		local data = {
			rotation = self.rotation,
			owner = self.owner,
			inventory = to_strings(self.inventory),
			timer = self.timer,
			punched = self.punched,
		}
		return core.serialize(data)
	end,
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		local data = core.deserialize(staticdata)
		if data and data.rotation and data.owner and data.inventory then
			self.timer = data.timer
			self.punched = data.punched
			self:create(data.rotation, data.owner, to_stacks(data.inventory))
		end
	end,
	on_punch = function(self, player)
		local name = player:get_player_name()
		if not is_owner(self, name) then
			core.chat_send_player(name, S("These bones belong to @1.", self.owner))
			return true
		end
		-- Move as many items as possible to the player's inventory
		local pos = self.object:get_pos()
		local empty
		if self.owner == name and not self.punched then
			empty = bones.restore_all_items(player, self.inventory)
		else
			empty = bones.add_all_items(player, self.inventory)
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
			self.object:remove()
			core.sound_play("bones_dug", {gain = 0.8}, true)
			if self.owner ~= name then
				core.chat_send_player(name, S("You collected @1's bones at @2.", self.owner, pos_string))
			end
			core.log("action", name.." removes bones at "..pos_string)
			return
		else
			self.punched = 1
			core.sound_play("bones_dig", {gain = 0.9}, true)
		end
		-- Log the bone-taking
		core.log("action", name.." takes items from bones at "..pos_string)
		return true
	end,
	on_step = bones.share_time > 0 and function(self, dtime)
		if self.timer >= bones.share_time then
			return
		end
		self.timer = self.timer + dtime
		if self.timer >= bones.share_time then
			self.object:set_properties({
				infotext = S("@1's old bones", self.owner),
			})
		end
	end or nil,
	on_deactivate = bones.waypoint_time > 0 and function(self, removal)
		if not removal then
			return
		end
		local player = core.get_player_by_name(self.owner)
		if player then
			bones.remove_waypoint(self.object:get_pos(), player)
		end
	end or nil,
})
