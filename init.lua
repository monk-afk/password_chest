-- Mod: Password Chest
-- Created by ynong123

dofile(minetest.get_modpath("password_chest") .. "/account.lua")

local FORMNAME_DATABASE = "password_chest:database"
local FORMNAME_SETUP = "password_chest:setup"
local FORMNAME_UNLOCK = "password_chest:unlock"
local FORMNAME_CHEST = "password_chest:password_chest_formspec"
local FORMNAME_CHANGE_PASSWORD = "password_chest:change_password"

local player_sessions = {}

local function copy_pos(pos)
  return {
    x = pos.x,
    y = pos.y,
    z = pos.z
  }
end

local function same_pos(a, b)
  return a
    and b
    and a.x == b.x
    and a.y == b.y
    and a.z == b.z
end

local function set_player_session(player_name, pos, formname, authenticated)
  player_sessions[player_name] = {
    authenticated = authenticated or false,
    formname = formname,
    pos = copy_pos(pos)
  }
end

local function clear_player_session(player_name)
  player_sessions[player_name] = nil
end

local function show_setup_formspec(player_name, pos)
  set_player_session(player_name, pos, FORMNAME_SETUP, false)
  minetest.show_formspec(
    player_name,
    FORMNAME_SETUP,
    "size[8,4]" ..
      "label[0,0;Password Chest Setup]" ..
      "pwdfield[0.5,2;7.0,1;password;Password:]" ..
      "button[0,3;3.9,1;lock;Lock]" ..
      "button_exit[4.1,3;3.9,1;cancel;Cancel]"
  )
end

local function show_unlock_formspec(player_name, pos)
  set_player_session(player_name, pos, FORMNAME_UNLOCK, false)
  minetest.show_formspec(
    player_name,
    FORMNAME_UNLOCK,
    "size[4,4]" ..
      "label[0,0;Unlock Chest]" ..
      "pwdfield[0.5,2;3.0,1;password;Password:]" ..
      "button[0,3;1.9,1;open;Open]" ..
      "button_exit[2.1,3;1.9,1;cancel;Cancel]"
  )
end

local function password_chest_formspec(pos)
  local spos = pos.x .. "," .. pos.y .. "," .. pos.z
  local formspec =
    "size[8,10]" ..
    default.gui_bg ..
    default.gui_bg_img ..
    default.gui_slots ..
    "list[nodemeta:" .. spos .. ";main;0,0.3;8,4;]" ..
    "list[current_player;main;0,4.85;8,1;]" ..
    "list[current_player;main;0,6.08;8,3;8]" ..
    "listring[nodemeta:" .. spos .. ";main]" ..
    "listring[current_player;main]" ..
    default.get_hotbar_bg(0, 4.85) ..
    "button[0,9;8,1;change_password;Change Password]"
  return formspec
end

local function show_password_chest_formspec(player_name, pos)
  set_player_session(player_name, pos, FORMNAME_CHEST, true)
  minetest.show_formspec(player_name, FORMNAME_CHEST, password_chest_formspec(pos))
end

local function show_change_password_formspec(player_name, pos)
  set_player_session(player_name, pos, FORMNAME_CHANGE_PASSWORD, true)
  minetest.show_formspec(
    player_name,
    FORMNAME_CHANGE_PASSWORD,
    "size[5,8]" ..
      "label[0,0;Change Password]" ..
      "pwdfield[0.5,2;4.0,1;old_password;Old Password:]" ..
      "pwdfield[0.5,4;4.0,1;new_password;New Password:]" ..
      "pwdfield[0.5,6;4.0,1;confirm_password;Confirm Password:]" ..
      "button[0,7;2,1;save;Save]" ..
      "button_exit[3,7;2,1;cancel;Cancel]"
  )
end

local function can_access_chest(pos, player)
  if not player or not player:is_player() then
    return false
  end

  local session = player_sessions[player:get_player_name()]
  local meta = minetest.get_meta(pos)
  return session
    and session.authenticated
    and session.formname == FORMNAME_CHEST
    and same_pos(session.pos, pos)
    and meta:get_int("id") ~= 0
    and meta:get_string("owner") ~= ""
end

minetest.register_chatcommand("password_chest", {
  params = "[reset|database]",
  description = "Use \"/password_chest reset\" to reset all of the password chests and \"/password_chest database\" to get the password database.",
  privs = {
    server = true
  },
  func = function(name, param)
    if param == "reset" then
      for i = 1, account.counter, 1 do
        local meta = minetest.get_meta(account.pos[i])
        meta:set_string("infotext", "Password Chest (unconfigured)")
        meta:set_string("owner", "")
        meta:set_int("id", 0)
      end
      account.reset()
      return true, "Password Chest Database has been reset successfully. All password chests will become unconfigured."
    elseif param == "database" then
      minetest.show_formspec(name, FORMNAME_DATABASE, account.formspec())
      return true, ""
    end

    return false, "Usage: /password_chest [reset|database]"
  end
})

minetest.register_node("password_chest:password_chest", {
  description = "Password Chest",
  tiles = {
    "password_chest_top.png",
    "password_chest_top.png",
    "password_chest_side.png",
    "password_chest_side.png",
    "password_chest_side.png",
    "password_chest_front.png"
  },
  groups = {choppy = 2, oddly_breakable_by_hand = 2},
  paramtype2 = "facedir",
  legacy_facedir_simple = true,
  is_ground_content = false,

  on_construct = function(pos)
    local meta = minetest.get_meta(pos)
    meta:set_string("infotext", "Password Chest (unconfigured)")
    meta:set_int("id", 0)
    meta:set_string("owner", "")
    local inv = meta:get_inventory()
    inv:set_size("main", 8 * 4)
  end,

  on_rightclick = function(pos, node, player, itemstack, pointed_thing)
    local meta = minetest.get_meta(pos)
    local player_name = player:get_player_name()

    if meta:get_int("id") == 0 then
      show_setup_formspec(player_name, pos)
    else
      show_unlock_formspec(player_name, pos)
    end
  end,

  can_dig = function(pos, player)
    local meta = minetest.get_meta(pos)
    local inv = meta:get_inventory()
    local owner = meta:get_string("owner")

    if not inv:is_empty("main") then
      return false
    end

    if owner == "" then
      return true
    end

    return player and player:get_player_name() == owner
  end,

  allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
    if can_access_chest(pos, player) then
      return count
    end
    return 0
  end,

  allow_metadata_inventory_put = function(pos, listname, index, stack, player)
    if can_access_chest(pos, player) then
      return stack:get_count()
    end
    return 0
  end,

  allow_metadata_inventory_take = function(pos, listname, index, stack, player)
    if can_access_chest(pos, player) then
      return stack:get_count()
    end
    return 0
  end,

  after_dig_node = function(pos, oldnode, oldmetadata, digger)
    account.delete(tonumber(oldmetadata.fields.id))
    return true
  end
})

minetest.register_on_player_receive_fields(function(player, formname, fields)
  local player_name = player:get_player_name()
  local session = player_sessions[player_name]

  if formname == FORMNAME_DATABASE then
    return fields.quit or fields.close
  end

  if not session or session.formname ~= formname then
    return false
  end

  local pos = session.pos
  local meta = minetest.get_meta(pos)

  if formname == FORMNAME_SETUP then
    if fields.lock then
      local password = fields.password or ""

      if password == "" then
        minetest.chat_send_player(player_name, "Password field is empty.")
        return true
      end

      if meta:get_int("id") ~= 0 then
        minetest.chat_send_player(player_name, "This chest has already been configured.")
        show_unlock_formspec(player_name, pos)
        return true
      end

      meta:set_string("infotext", "Password Chest (owned by " .. player_name .. ")")
      meta:set_int("id", account.new(password, pos))
      meta:set_string("owner", player_name)
      clear_player_session(player_name)
      minetest.chat_send_player(player_name, "Your chest has been locked.")
      return true
    end

    if fields.quit then
      clear_player_session(player_name)
      return true
    end

    return false
  end

  if formname == FORMNAME_UNLOCK then
    if fields.open then
      local password = fields.password or ""

      if password == "" then
        minetest.chat_send_player(player_name, "Password field is empty.")
        return true
      end

      if account.check(meta:get_int("id"), password) then
        show_password_chest_formspec(player_name, pos)
      else
        minetest.chat_send_player(player_name, "Your password is incorrect. Please type again.")
      end

      return true
    end

    if fields.quit then
      clear_player_session(player_name)
      return true
    end

    return false
  end

  if formname == FORMNAME_CHEST then
    if fields.change_password then
      show_change_password_formspec(player_name, pos)
      return true
    end

    if fields.quit then
      clear_player_session(player_name)
      return true
    end

    return false
  end

  if formname == FORMNAME_CHANGE_PASSWORD then
    if fields.save then
      local old_password = fields.old_password or ""
      local new_password = fields.new_password or ""
      local confirm_password = fields.confirm_password or ""

      if old_password == "" or new_password == "" then
        minetest.chat_send_player(player_name, "Password field is empty.")
        return true
      end

      if new_password ~= confirm_password then
        minetest.chat_send_player(player_name, "Password confirmation mismatch.")
        return true
      end

      if account.change(meta:get_int("id"), old_password, new_password) then
        minetest.chat_send_player(player_name, "Updated password chest.")
        show_password_chest_formspec(player_name, pos)
      else
        minetest.chat_send_player(player_name, "Your password is incorrect. Please type again.")
      end

      return true
    end

    if fields.quit then
      clear_player_session(player_name)
      return true
    end
  end

  return false
end)

minetest.register_on_leaveplayer(function(player)
  clear_player_session(player:get_player_name())
end)

minetest.register_craft({
  output = "password_chest:password_chest",
  recipe = {
    {"group:wood", "default:mese", "group:wood"},
    {"group:wood", "default:gold_ingot", "group:wood"},
    {"group:wood", "group:wood", "group:wood"}
  }
})
