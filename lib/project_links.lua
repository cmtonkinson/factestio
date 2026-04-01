local System = require("lib.system")

local ProjectLinks = {}

local function replace_symlink(target, link_path)
  local current_target = System.symlink_target(link_path)
  if System.lexists(link_path) and not current_target then
    return nil, "Error: refusing to replace non-symlink path: " .. link_path .. "\n"
  end
  if current_target then
    os.execute("rm -rf " .. System.shell_quote(link_path))
  end
  os.execute("ln -s " .. System.shell_quote(target) .. " " .. System.shell_quote(link_path))
  return true
end

local function ensure_symlink(link_path, expected_target, created_message, updated_message, ok_message, quiet)
  local target = System.symlink_target(link_path)
  local abs_expected = System.realpath(expected_target) or expected_target
  local abs_target = target and System.realpath(target) or nil

  if target then
    if abs_target ~= abs_expected then
      local ok, err = replace_symlink(abs_expected, link_path)
      if not ok then
        return nil, err
      end
      if not quiet then
        print(updated_message)
      end
      return true
    end

    if not quiet and ok_message then
      print(ok_message)
    end
    return true
  end

  if System.lexists(link_path) then
    return nil, "Error: refusing to replace non-symlink path: " .. link_path .. "\n"
  end

  local ok, err = replace_symlink(abs_expected, link_path)
  if not ok then
    return nil, err
  end
  if not quiet then
    print(created_message)
  end
  return true
end

local function remove_symlink(link_path, removed_message, quiet)
  local target = System.symlink_target(link_path)
  if target then
    os.execute("rm -rf " .. System.shell_quote(link_path))
    if not quiet then
      print(removed_message)
    end
    return true
  end

  if System.lexists(link_path) then
    return nil, "Error: refusing to remove non-symlink path: " .. link_path .. "\n"
  end

  return true
end

function ProjectLinks.verify_mod_root(root, data_path)
  local mods_link = data_path .. "mods/factestio"
  local mods_target = System.symlink_target(mods_link)
  if not mods_target then
    return true
  end

  local expected_root = System.realpath(root:gsub("/$", ""))
  local actual_root = System.realpath(mods_target)
  if expected_root and actual_root and expected_root ~= actual_root then
    return nil,
      "Error: factestio CLI/mod mismatch detected.\n"
        .. "CLI root: "
        .. expected_root
        .. "\nmods/factestio -> "
        .. actual_root
        .. "\nRun `factestio activate` using the factestio binary you intend to use,"
        .. " or invoke the matching binary directly.\n"
  end

  return true
end

function ProjectLinks.ensure_mod_symlink(root, data_path, quiet)
  local mods_link = data_path .. "mods/factestio"
  return ensure_symlink(
    mods_link,
    root:gsub("/$", ""),
    "Created mod symlink: " .. mods_link,
    "Updated mod symlink: " .. mods_link,
    "Mod symlink already exists: " .. mods_link,
    quiet
  )
end

function ProjectLinks.ensure_sut_symlink(mod_dir, mod_name, data_path, quiet)
  local mods_link = data_path .. "mods/" .. mod_name
  return ensure_symlink(
    mods_link,
    mod_dir:gsub("/$", ""),
    "Created SUT symlink: " .. mods_link,
    "Updated SUT symlink: " .. mods_link,
    "SUT symlink already correct: " .. mods_link,
    quiet
  )
end

function ProjectLinks.ensure_project_symlink(root, mod_dir, quiet)
  local link_path = root .. "scenarios/factestio/factestio"
  local expected = (System.realpath(mod_dir) and (System.realpath(mod_dir) .. "/factestio")) or (mod_dir .. "factestio")
  return ensure_symlink(
    link_path,
    expected,
    "Created symlink: " .. link_path .. " -> " .. expected,
    "Updated symlink: " .. link_path .. " -> " .. expected,
    "factestio symlink already correct",
    quiet
  )
end

function ProjectLinks.remove_project_symlink(root, quiet)
  local link_path = root .. "scenarios/factestio/factestio"
  return remove_symlink(link_path, "Removed symlink: " .. link_path, quiet)
end

function ProjectLinks.remove_mod_symlink(data_path, quiet)
  local mods_link = data_path .. "mods/factestio"
  return remove_symlink(mods_link, "Removed mod symlink: " .. mods_link, quiet)
end

function ProjectLinks.remove_sut_symlink(data_path, mod_name, quiet)
  local mods_link = data_path .. "mods/" .. mod_name
  return remove_symlink(mods_link, "Removed SUT symlink: " .. mods_link, quiet)
end

return ProjectLinks
