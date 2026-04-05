local Constants = require("lib.constants")
local Shell = require("lib.shell")

local ProjectLinks = {}

local function mods_dir(data_path)
  return data_path .. Constants.FACTESTIO.FACTORIO_MODS_DIR_NAME .. "/"
end

local function factestio_mod_link(data_path)
  return mods_dir(data_path) .. Constants.FACTESTIO.FACTESTIO_MOD_NAME
end

local function sut_mod_link(data_path, mod_name)
  return mods_dir(data_path) .. mod_name
end

local function replace_symlink(target, link_path)
  local current_target = Shell.readlink(link_path)
  if Shell.test_exists_or_symlink(link_path) and not current_target then
    return nil, "Error: refusing to replace non-symlink path: " .. link_path .. "\n"
  end
  if current_target then
    Shell.rm_rf(link_path)
  end
  Shell.ln_s(target, link_path)
  return true
end

local function ensure_symlink(link_path, expected_target, created_message, updated_message, ok_message, quiet)
  local target = Shell.readlink(link_path)
  local abs_expected = Shell.realpath(expected_target) or expected_target
  local abs_target = target and Shell.realpath(target) or nil

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

  if Shell.test_exists_or_symlink(link_path) then
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
  local target = Shell.readlink(link_path)
  if target then
    Shell.rm_rf(link_path)
    if not quiet then
      print(removed_message)
    end
    return true
  end

  if Shell.test_exists_or_symlink(link_path) then
    return nil, "Error: refusing to remove non-symlink path: " .. link_path .. "\n"
  end

  return true
end

function ProjectLinks.verify_mod_root(root, data_path)
  local mods_link = factestio_mod_link(data_path)
  local mods_target = Shell.readlink(mods_link)
  if not mods_target then
    return true
  end

  local expected_root = Shell.realpath(root:gsub("/$", ""))
  local actual_root = Shell.realpath(mods_target)
  if expected_root and actual_root and expected_root ~= actual_root then
    return nil,
      "Error: factestio CLI/mod mismatch detected.\n"
        .. "CLI root: "
        .. expected_root
        .. "\n"
        .. Constants.FACTESTIO.FACTORIO_MODS_DIR_NAME
        .. "/"
        .. Constants.FACTESTIO.FACTESTIO_MOD_NAME
        .. " -> "
        .. actual_root
        .. "\nRun `factestio activate` using the factestio binary you intend to use,"
        .. " or invoke the matching binary directly.\n"
  end

  return true
end

function ProjectLinks.ensure_mod_symlink(root, data_path, quiet)
  local mods_link = factestio_mod_link(data_path)
  return ensure_symlink(
    mods_link,
    root:gsub("/$", ""),
    "Created mod symlink: " .. mods_link,
    "Updated mod symlink: " .. mods_link,
    "factestio symlink already exists: " .. mods_link,
    quiet
  )
end

function ProjectLinks.ensure_sut_symlink(mod_dir, mod_name, data_path, quiet)
  local mods_link = sut_mod_link(data_path, mod_name)
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
  local link_path = root .. Constants.FACTESTIO.SCENARIO_PROJECT_LINK
  local real_mod_dir = Shell.realpath(mod_dir)
  local expected = (real_mod_dir and (real_mod_dir .. "/" .. Constants.FACTESTIO.PROJECT_DIR_NAME))
    or (mod_dir .. Constants.FACTESTIO.PROJECT_DIR_NAME)
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
  local link_path = root .. Constants.FACTESTIO.SCENARIO_PROJECT_LINK
  return remove_symlink(link_path, "Removed symlink: " .. link_path, quiet)
end

function ProjectLinks.remove_mod_symlink(data_path, quiet)
  local mods_link = factestio_mod_link(data_path)
  return remove_symlink(mods_link, "Removed mod symlink: " .. mods_link, quiet)
end

function ProjectLinks.remove_sut_symlink(data_path, mod_name, quiet)
  local mods_link = sut_mod_link(data_path, mod_name)
  return remove_symlink(mods_link, "Removed SUT symlink: " .. mods_link, quiet)
end

return ProjectLinks
