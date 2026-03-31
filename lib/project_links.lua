local System = require("lib.system")

local ProjectLinks = {}

local function replace_symlink(target, link_path)
  if System.lexists(link_path) then
    os.execute("rm -rf " .. System.shell_quote(link_path))
  end
  os.execute("ln -s " .. System.shell_quote(target) .. " " .. System.shell_quote(link_path))
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
        .. "\nRun `factestio --on` using the factestio binary you intend to use,"
        .. " or invoke the matching binary directly.\n"
  end

  return true
end

function ProjectLinks.ensure_mod_symlink(root, data_path, quiet)
  local mods_link = data_path .. "mods/factestio"
  local mods_target = System.symlink_target(mods_link)
  local abs_mods_target = mods_target and System.realpath(mods_target) or nil
  local abs_expected_root = System.realpath(root:gsub("/$", "")) or root:gsub("/$", "")

  if mods_target then
    if abs_mods_target ~= abs_expected_root then
      replace_symlink(abs_expected_root, mods_link)
      if not quiet then
        print("Updated mod symlink: " .. mods_link)
      end
      return true
    end

    if not quiet then
      print("Mod symlink already exists: " .. mods_link)
    end
    return true
  end

  replace_symlink(abs_expected_root, mods_link)
  if not quiet then
    print("Created mod symlink: " .. mods_link)
  end
  return true
end

function ProjectLinks.ensure_project_symlink(root, mod_dir, quiet)
  local link_path = root .. "scenarios/factestio/factestio"
  local target = System.symlink_target(link_path)
  local abs_expected = System.realpath(mod_dir) and (System.realpath(mod_dir) .. "/factestio")
    or (mod_dir .. "factestio")
  local abs_target = target and System.realpath(target) or nil

  if target then
    if abs_target ~= abs_expected then
      replace_symlink(abs_expected, link_path)
      if not quiet then
        print("Updated symlink: " .. link_path .. " -> " .. abs_expected)
      end
      return true
    end

    if not quiet then
      print("factestio symlink already correct")
    end
    return true
  end

  replace_symlink(abs_expected, link_path)
  if not quiet then
    print("Created symlink: " .. link_path .. " -> " .. abs_expected)
  end
  return true
end

function ProjectLinks.remove_project_symlink(root, quiet)
  local link_path = root .. "scenarios/factestio/factestio"
  if System.lexists(link_path) then
    os.execute("rm -rf " .. System.shell_quote(link_path))
    if not quiet then
      print("Removed symlink: " .. link_path)
    end
  end
  return true
end

function ProjectLinks.remove_mod_symlink(data_path, quiet)
  local mods_link = data_path .. "mods/factestio"
  if System.lexists(mods_link) then
    os.execute("rm -rf " .. System.shell_quote(mods_link))
    if not quiet then
      print("Removed mod symlink: " .. mods_link)
    end
  end
  return true
end

return ProjectLinks
