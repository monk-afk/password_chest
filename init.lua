-- Mod: Password Chest
-- Created by ynong123

dofile(minetest.get_modpath("password_chest") .. "/account.lua")

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
      minetest.show_formspec(name, "password_chest:database", account.formspec())
      minetest.register_on_player_receive_fields(
        function(player, formname, fields)
          if formname ~= "password_chest:database" then
            return false, ""
          end
          if fields.close then
            return true, ""
          end
        end
      )
    end
  end
})

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
    default.get_hotbar_bg(0,4.85) ..
    "button[0,9;8,1;change_password;Change Password]"
  return formspec
end

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
    if meta:get_int("id") == 0 then
        minetest.show_formspec(player:get_player_name(), "password_chest:setup", 
        "size[8, 4]" ..
        "label[0, 0;Password Chest Setup]" ..
        "pwdfield[0.5,2;7.5,1;password;Password:]" ..
        "button_exit[0,3;2,1;lock;Lock]"
        )
      minetest.register_on_player_receive_fields(
          function(player, formname, fields)
              if formname ~= "password_chest:setup" then
                return false
            end
          if fields.password == nil then
            return false
          end
          if fields.password == "" then
            return false
          end
          meta:set_string("infotext", "Password Chest (owned by " .. player:get_player_name() .. ")")
          meta:set_int("id", account.new(fields.password, pos))
          meta:set_string("owner", player:get_player_name())
          minetest.chat_send_player(player:get_player_name(), "Your chest has been locked.")
          return true
          end
      )
    else
      minetest.show_formspec(player:get_player_name(), "password_chest:unlock",
        "size[4, 4]" ..
        "label[0, 0;Unlock Chest]" ..
        "pwdfield[0.5, 2;3.5, 1;password;Password:]" ..
        "button_exit[0, 3;2, 1;open;Open]"
      )
      minetest.register_on_player_receive_fields(
        function(player, formname, fields)
          if formname ~= "password_chest:unlock" then
            return false
          end
          if fields.password == nil then
            return false
          end
          if fields.password == "" then
            return false
          end
          if account.check(meta:get_int("id"), fields.password) then
            minetest.show_formspec(
              player:get_player_name(),
              "password_chest:password_chest_formspec",
              password_chest_formspec(pos)
            )
            minetest.register_on_player_receive_fields(function(player, formname, fields)
              if formname ~= "password_chest:password_chest_formspec" then
                return false
              end
              if fields.change_password then
                minetest.show_formspec(player:get_player_name(), "password_chest:change_password", 
                  "size[5,8]" ..
                  "label[0,0;Change Password]" ..
                  "pwdfield[0.5,2;4.5,1;old_password;Old Password:]" ..
                  "pwdfield[0.5,4;4.5,1;new_password;New Password:]" ..
                  "pwdfield[0.5,6;4.5,1;confirm_password;Confirm Password:]" ..
                  "button_exit[0,7;2,1;save;Save]"
                )
                minetest.register_on_player_receive_fields(function(player, formname, fields)
                  if formname == "password_chest:change_password" then
                    if fields.old_password and #fields.old_password > 0 then
                      if fields.new_password and #fields.new_password > 0 then
                        if fields.new_password == fields.confirm_password then
                          if account.change(meta:get_int("id"), fields.old_password, fields.new_password) then
                            return true, minetest.chat_send_player(player:get_player_name(), "Updated password chest.")
                          end
                          minetest.chat_send_player(player:get_player_name(), "Your password is incorrect. Please type again.")
                          return false
                        end
                        minetest.chat_send_player(player:get_player_name(), "Password confirmation mismatch.")
                        return false
                      end
                      minetest.chat_send_player(player:get_player_name(), "Password field is empty.")
                      return false
                    end
                    minetest.chat_send_player(player:get_player_name(), "Password field is empty.")
                    return false
                  end
                end)
              end
            end)
          else
            minetest.chat_send_player(player:get_player_name(), "Your password is incorrect. Please type again.")
          end
          return true
        end
      )
    end
  end,
  can_dig = function(pos, player)
    local meta = minetest.get_meta(pos);
    local inv = meta:get_inventory()
    return inv:is_empty("main") and player:get_player_name() == meta:get_string("owner")
  end,
  after_dig_node = function(pos, oldnode, oldmetadata, digger)
    account.delete(oldmetadata.fields.id)
    return true
  end
})

minetest.register_craft({
  output = "password_chest:password_chest",
  recipe = {
    {"group:wood", "default:mese", "group:wood"},
    {"group:wood", "default:gold_ingot", "group:wood"},
      {"group:wood", "group:wood", "group:wood"}
  }
})
