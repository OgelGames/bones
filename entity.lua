
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
	},
	rotation = 0,
	inventory = {},
	timer = 0,
	create = function(self, rotation, owner, inventory)
		self.rotation = rotation
		self.owner = owner
		self.inventory = inventory
		local infotext
		if bones.share_time > 0 then
			infotext = S("@1's fresh bones", owner)
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
		}
		return core.serialize(data)
	end,
	on_activate = function(self, staticdata)
		local data = core.deserialize(staticdata)
		if data and data.rotation and data.owner and data.inventory then
			self:create(data.rotation, data.owner, to_stacks(data.inventory))
			self.timer = data.timer
		end
	end,
	on_punch = function(self, player)
		local name = player:get_player_name()
		if not is_owner(self, name) then
			return true
		end
		local pos = self.object:get_pos()
		-- Move as many items as possible to the player's inventory
		local empty
		if self.owner == name then
			empty = bones.restore_all_items(player, self.inventory)
		else
			empty = bones.add_all_items(player, self.inventory)
		end
		-- Remove bones if they have been emptied
		if empty then
			local player_inv = player:get_inventory()
			if player_inv:room_for_item("main", "bones:bones") then
				player_inv:add_item("main", "bones:bones")
			else
				core.add_item(pos, "bones:bones")
			end
			self.object:remove()
		end
		-- Log the bone-taking
		core.log("action", name.." takes items from bones at "..core.pos_to_string(pos))
		return true
	end,
	on_deactivate = bones.waypoints and function(self, removal)
		if not removal then
			return
		end
		local player = core.get_player_by_name(self.owner)
		if player then
			bones.remove_waypoint(self.object:get_pos(), player)
		end
	end or nil,
})
