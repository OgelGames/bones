
local S = core.get_translator("bones")

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
	items = {},
	owner = "",
	timer = 0,
	create = function(self, rotation, owner, items)
		self.rotation = rotation or 0
		self.owner = owner or ""
		self.items = items or {}
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
			items = bones.stacks_to_strings(self.items),
			timer = self.timer,
			punched = self.punched,
		}
		return core.serialize(data)
	end,
	on_activate = function(self, staticdata)
		self.object:set_armor_groups({immortal = 1})
		local data = core.deserialize(staticdata)
		if data and data.rotation and data.owner and data.items then
			self.timer = data.timer
			self.punched = data.punched
			self:create(data.rotation, data.owner, bones.strings_to_stacks(data.items))
		end
	end,
	on_punch = function(self, player)
		local name = player:get_player_name()
		if not bones.can_collect(name, self.owner, self.timer) then
			core.chat_send_player(name, S("These bones belong to @1.", self.owner))
			return
		end
		local pos = self.object:get_pos()
		if bones.collect_bones(pos, player, self.owner, self.items, self.punched) then
			self.object:remove()
		else
			self.punched = 1
		end
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
