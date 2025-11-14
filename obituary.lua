
local S = core.get_translator("bones")

local formspec = "formspec_version[2]"..
	"size[5.4,7.8]"..
	"background[-0.5,-0.1;6,8;bones_obituary_ui.png]"..
	"hypertext[0,0.2;5.4,2;;<style color=#0e0e0e><center><big>"..S("Obituary").."</big></center>]"..
	"style[*;textcolor=#0e0e0e]"..
	"label[0.25,1;"..S("Name")..":  %s]"..
	"label[0.25,1.5;"..S("Time")..":  %s]"..
	"label[0.25,2;"..S("Location")..":  X: %d  Y: %d  Z: %d]"..
	"label[0.25,2.5;"..S("Inventory at death")..":]"..
	"textarea[0.2,3;5.1,4.7;;%s;]"

local function show_obituary_formspec(stack, player)
	local meta = stack:get_meta()
	local name = meta:get_string("name")
	local time = os.date("%Y/%m/%d  %H:%M:%S", tonumber(meta:get_string("time")) or 0)
	local pos = core.string_to_pos(meta:get_string("pos")) or vector.zero
	local items = meta:get_string("items")
	local fs = formspec:format(name, time, pos.x, pos.y, pos.z, items)
	core.show_formspec(player:get_player_name(), "obituary", fs)
end

core.register_craftitem("bones:obituary", {
	description = S("Obituary"),
	inventory_image = "bones_obituary.png",
	groups = {flammable = 3},  -- Obituaries are made of paper which is flammable
	on_use = show_obituary_formspec,
	on_secondary_use = show_obituary_formspec,
	on_rightclick = show_obituary_formspec,
})

if core.get_modpath("xcompat") and xcompat.materials.paper ~= "" then
	core.register_craft({
		type = "shapeless",
		output = xcompat.materials.paper,
		recipe = {"bones:obituary"},
	})
end

-- Always register the obituary item, but stop here if obituaries are disabled.
if not bones.obituary then
	return
end

function bones.create_obituary(pos_str, name, items)
	local obituary = ItemStack("bones:obituary")
	local item_list = {}
	local count, desc
	for _,list in pairs(items) do
		for _,stack in ipairs(list) do
			count = stack:get_count()
			if count > 0 then
				-- Toolranks makes tool descriptions unusable but adds 'original_description'
				desc = stack:get_definition().original_description or stack:get_short_description()
				table.insert(item_list, desc..(count > 1 and " x"..count or ""))
			end
		end
	end
	local meta = obituary:get_meta()
	meta:set_string("pos", pos_str)
	meta:set_string("name", name)
	meta:set_string("items", table.concat(item_list, "\n"))
	meta:set_string("time", os.time())
	meta:set_string("description", S("Obituary of @1", name))
	return obituary
end

core.register_chatcommand("obituary", {
	description = S("Toggle receiving an obituary when you die."),
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false
		end
		local meta = player:get_meta()
		if meta:get("bones_obituary") ~= "0" then
			meta:set_int("bones_obituary", 0)
			return true, S("Obituary disabled.")
		else
			meta:set_int("bones_obituary", 1)
			return true, S("Obituary enabled.")
		end
	end,
})
