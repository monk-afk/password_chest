-- account.lua
-- Thanks for rubenwardy for these code.

account = {
  password = {},
  salt = {},
  pos = {},
  counter = 0
}

local function formspec_value(value)
  return minetest.formspec_escape(tostring(value or ""))
end

function account.genSalt()
  local chars = {}
  for loop = 0, 255 do
    chars[loop + 1] = string.char(loop)
  end
  local str = table.concat(chars)
  local built = {["."] = chars}
  
  local AddLookup = function(charset)
    local substitute = string.gsub(str, "[^" .. charset .. "]", "")
    local lookup = {}
    for loop = 1, string.len(substitute) do
      lookup[loop] = string.sub(substitute, loop, loop)
    end
    built[charset] = lookup
    
    return lookup
  end

  local function srandom(length, charset)
    local charset = charset or "."
    if charset == "" then
      return ""
    else
      local result = {}
      local lookup = built[charset] or AddLookup(charset)
      local range = #lookup
      for loop = 1, length do
        result[loop] = lookup[math.random(1, range)]
      end
      
      return table.concat(result)
    end
  end

  return srandom(32, "%l%d")
end

function account.init()
  local file = io.open(minetest.get_worldpath() .. "/password_chest_data.txt", "r")
  if file then
    local data = minetest.deserialize(file:read("*all"))
    file:close()
    if type(data) == "table" then
      account.password = data.password or {}
      account.salt = data.salt or {}
      account.pos = data.pos or {}
      account.counter = tonumber(data.counter) or 0
    end
  end
end

function account.save()
  local file = io.open(minetest.get_worldpath() .. "/password_chest_data.txt", "w")
  if file then
    file:write(
      minetest.serialize({
        password = account.password,
        salt = account.salt,
        pos = account.pos,
        counter = account.counter
      })
    )
    file:close()
  end
end

function account.new(password, pos)
  local salt = account.genSalt()
  account.counter = account.counter + 1
  account.password[account.counter] = minetest.get_password_hash(salt, password)
  account.salt[account.counter] = salt
  account.pos[account.counter] = {
    x = pos.x,
    y = pos.y,
    z = pos.z
  }
  account.save()
  return account.counter
end

function account.delete(id)
  if type(id) ~= "number" or id < 1 or id > account.counter then
    return false
  end

  for i = id, account.counter - 1, 1 do
    account.password[i] = account.password[i + 1]
    account.salt[i] = account.salt[i + 1]
    account.pos[i] = account.pos[i + 1]
    if account.pos[i] then
      local meta = minetest.get_meta(account.pos[i])
      meta:set_int("id", i)
    end
  end

  account.password[account.counter] = nil
  account.salt[account.counter] = nil
  account.pos[account.counter] = nil
  account.counter = account.counter - 1
  account.save()
  return true
end

function account.change(id, old_password, new_password)
  local salt = account.salt[id]
  if not salt or not account.password[id] then
    return false
  end

  local old_password_hashed = minetest.get_password_hash(salt, old_password)
  local new_password_hashed = minetest.get_password_hash(salt, new_password)
  if old_password_hashed ~= account.password[id] then
    return false
  end
  account.password[id] = new_password_hashed
  account.save()
  return true
end

function account.reset()
  account.password = {}
  account.salt = {}
  account.pos = {}
  account.counter = 0
  account.save()
end

function account.check(id, password)
  local salt = account.salt[id]
  if not salt or not account.password[id] then
    return false
  end

  local password_hashed = minetest.get_password_hash(salt, password)
  return password_hashed == account.password[id]
end

function account.formspec()
  local ret = "size[12,8]label[0,0;Password Chest Database]"
  ret = ret .. "tablecolumns[text;text;text;text;text;text;text;text]"
  ret = ret .. "table[0.5,1;10.5,6;table;ID,,Player,X,Y,Z,Salt,Password (Hashed)"
  for i = 1, account.counter, 1 do
    local meta = minetest.get_meta(account.pos[i])
    ret = ret ..
      "," .. formspec_value(i) ..
      ",," ..
      formspec_value(meta:get_string("owner")) ..
      "," .. formspec_value(account.pos[i].x) ..
      "," .. formspec_value(account.pos[i].y) ..
      "," .. formspec_value(account.pos[i].z) ..
      "," .. formspec_value(account.salt[i]) ..
      "," .. formspec_value(account.password[i])
  end
  ret = ret .. ";-1]"
  ret = ret .. "button_exit[0.5,7;2,1;close;Close]"
  return ret
end

account.init()
