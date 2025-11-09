
local S = core.get_translator("bones")

-- From builtin/game/falling.lua, but only for the values returned from core.dir_to_facedir
local facedir_to_euler = {
	[ 0] = {y = 0, x = 0, z = 0},
	[ 1] = {y = -math.pi/2, x = 0, z = 0},
	[ 2] = {y = math.pi, x = 0, z = 0},
	[ 3] = {y = math.pi/2, x = 0, z = 0},
	[ 4] = {y = math.pi/2, x = -math.pi/2, z = math.pi/2},
	[ 6] = {y = math.pi/2, x = math.pi/2, z = math.pi/2},
	[ 8] = {y = -math.pi/2, x = math.pi/2, z = math.pi/2},
	[10] = {y = -math.pi/2, x = -math.pi/2, z = math.pi/2},
	[13] = {y = 0, x = -math.pi/2, z = math.pi/2},
	[15] = {y = 0, x = math.pi/2, z = math.pi/2},
	[17] = {y = math.pi, x = math.pi/2, z = math.pi/2},
	[19] = {y = math.pi, x = -math.pi/2, z = math.pi/2},
}

core.register_entity("bones:entity", {
	initial_properties = {
		visual = "cube",
		visual_size = {x = 1.001, y = 1.001, z = 1.001},  -- Avoid Z-fighting if placed inside a node
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
	param2 = 0,
	items = {},
	owner = "",
	timer = 0,
	create = function(self, param2, owner, items)
		self.param2 = param2 or 0
		self.owner = owner or ""
		self.items = items or {}
		local infotext
		if bones.sharing then
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
		local euler = facedir_to_euler[param2]
		if euler then
			self.object:set_rotation(euler)
		end
	end,
	get_staticdata = function(self)
		local data = {
			param2 = self.param2,
			owner = self.owner,
			items = bones.stacks_to_strings(self.items),
			timer = self.timer,
			punched = self.punched,
		}
		return core.serialize(data)
	end,
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		local data = core.deserialize(staticdata)
		if data and data.param2 and data.owner and data.items then
			self.timer = data.timer
			self.punched = data.punched
			self:create(data.param2, data.owner, bones.strings_to_stacks(data.items))
		end
	end,
	on_punch = function(self, player)
		local name = player:get_player_name()
		if not bones.can_collect(name, self.owner, self.timer) then
			core.chat_send_player(name, S("These bones belong to @1.", self.owner))
			return
		end
		local pos = self.object:get_pos()
		if bones.pickup and player:get_player_control().sneak then
			if bones.pickup_bones(pos, self.items, self.owner, player) then
				self.object:remove()
			end
			return
		end
		if bones.collect_bones(pos, player, self.owner, self.items, self.punched) then
			self.object:remove()
		else
			self.punched = 1
		end
		return true
	end,
	on_step = bones.sharing and function(self, dtime)
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
