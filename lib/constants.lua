local Constants = {}

Constants.LUA = {
  VERSION_STRING = "Lua 5.2",
  VERSION_MINOR = "5.2",
}

Constants.FACTESTIO = {
  RESULTS_ROOT = "factestio/results",
  ROOT_SAVE_NAME = "root-save.zip",
  CHILD_LOAD_BASENAME = "factestio-child-load",
  ROOT_SAVE_INIT_BASENAME = "factestio-root-save-init",
  DONE_FILE_NAME = "factestio.done",
  STDOUT_FILE_NAME = "factestio.stdout",
  STDERR_FILE_NAME = "factestio.stderr",
  PID_FILE_NAME = "factestio.pid",
  TEST_NAME_MANIFEST = "test_name.lua",
  TEST_FILES_MANIFEST = "test_files.lua",
  TEST_CONTEXT_MANIFEST = "test_context.lua",
  SERVER_SETTINGS_FILE = "server-settings.json",
  MAP_GEN_SETTINGS_FILE = "map-gen-settings.json",
  TMP_PID_FILE = "tmp/factestio.pid",
  TMP_SETUP_STDOUT = "tmp/setup-stdout.txt",
}

Constants.SCHEDULER = {
  RUN_TICK_OFFSET = 10,
  SAVE_TICK_OFFSET = 20,
  EXIT_TICK_OFFSET = 30,
}

Constants.RUNTIME = {
  DEFAULT_TEST_TIMEOUT = 8,
  POLL_INTERVAL_SECONDS = 0.1,
}

return Constants
