local Json = require("lib.factestio_json")
local System = require("lib.system")

local function dirname(path)
  return path:match("^(.*)/[^/]+$")
end

local source = debug.getinfo(1, "S").source
local module_path = source:sub(1, 1) == "@" and source:sub(2) or source
local repo_root = dirname(dirname(module_path))
local content = assert(System.read_file(repo_root .. "/constants.json"))
local decoded = Json.decode(content, repo_root .. "/constants.json")

local Constants = {
  LUA = {
    VERSION_STRING = decoded.lua.version_string,
    VERSION_MINOR = decoded.lua.version_minor,
  },
  FACTESTIO = {
    PROJECT_DIR_NAME = decoded.factestio.project_dir_name,
    SCENARIO_PROJECT_LINK = decoded.factestio.scenario_project_link,
    SCENARIO_LOAD_TARGET = decoded.factestio.scenario_load_target,
    RESULTS_ROOT = decoded.factestio.results_root,
    ROOT_SAVE_NAME = decoded.factestio.root_save_name,
    CHILD_LOAD_BASENAME = decoded.factestio.child_load_basename,
    ROOT_SAVE_INIT_BASENAME = decoded.factestio.root_save_init_basename,
    DONE_FILE_NAME = decoded.factestio.done_file_name,
    STDOUT_FILE_NAME = decoded.factestio.stdout_file_name,
    STDERR_FILE_NAME = decoded.factestio.stderr_file_name,
    PID_FILE_NAME = decoded.factestio.pid_file_name,
    TEST_NAME_MANIFEST = decoded.factestio.test_name_manifest,
    TEST_SEED_MANIFEST = decoded.factestio.test_seed_manifest,
    TEST_FILES_MANIFEST = decoded.factestio.test_files_manifest,
    TEST_CONTEXT_MANIFEST = decoded.factestio.test_context_manifest,
    TEST_CONSTANTS_MANIFEST = decoded.factestio.test_constants_manifest,
    SERVER_SETTINGS_FILE = decoded.factestio.server_settings_file,
    MAP_GEN_SETTINGS_FILE = decoded.factestio.map_gen_settings_file,
    TMP_PID_FILE = decoded.factestio.tmp_pid_file,
    TMP_SETUP_STDOUT = decoded.factestio.tmp_setup_stdout,
    TMP_INTERRUPT_FILE = decoded.factestio.tmp_interrupt_file,
    SESSION_DIR = decoded.factestio.session_dir,
    SESSION_SNAPSHOT_FILE = decoded.factestio.session_snapshot_file,
    SESSION_META_FILE = decoded.factestio.session_meta_file,
  },
  SCHEDULER = {
    RUN_TICK_OFFSET = decoded.scheduler.run_tick_offset,
    SAVE_TICK_OFFSET = decoded.scheduler.save_tick_offset,
    EXIT_TICK_OFFSET = decoded.scheduler.exit_tick_offset,
  },
  RUNTIME = {
    DEFAULT_TEST_TIMEOUT = decoded.runtime.default_test_timeout,
    POLL_INTERVAL_SECONDS = decoded.runtime.poll_interval_seconds,
  },
}

return Constants
