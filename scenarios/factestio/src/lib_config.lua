return function(F)
  local Constants = _G.script == nil and require("lib.constants") or require("test_constants")

  F.registry = {}
  F.DEBUG = false
  F.TEST_TIMEOUT = Constants.RUNTIME.DEFAULT_TEST_TIMEOUT

  F.FACTORIO_BINARY = ""
  F.FACTORIO_DATA_PATH = ""
  F.RESULTS_ROOT = Constants.FACTESTIO.RESULTS_ROOT
  F.DONE_FILE = ""
  F.ROOT = ""
  F.SETTINGS = ""
  F.SAVES = ""

  -------------------------------------------------------------------------------
  function F.init(root)
    F.ROOT = root
    F.SCRIPT_OUTPUT = F.FACTORIO_DATA_PATH .. "script-output/"
    F.SETTINGS = F.ROOT .. Constants.FACTESTIO.SERVER_SETTINGS_FILE
    F.SAVES = F.ROOT .. "saves"
    F.TEST_NAME_FILE = F.ROOT .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_NAME_MANIFEST
    F.TEST_SEED_FILE = F.ROOT .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_SEED_MANIFEST
    F.TEST_FILES_MANIFEST = F.ROOT .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_FILES_MANIFEST
    F.TEST_CONTEXT_MANIFEST = F.ROOT .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_CONTEXT_MANIFEST
    F.TEST_CONSTANTS_MANIFEST = F.ROOT .. "scenarios/factestio/" .. Constants.FACTESTIO.TEST_CONSTANTS_MANIFEST
    F.DONE_FILE = F.SCRIPT_OUTPUT .. Constants.FACTESTIO.DONE_FILE_NAME
    F.TEST_STDOUT = F.SCRIPT_OUTPUT .. Constants.FACTESTIO.STDOUT_FILE_NAME
    F.TEST_STDERR = F.SCRIPT_OUTPUT .. Constants.FACTESTIO.STDERR_FILE_NAME
    F.PID_FILE = F.SCRIPT_OUTPUT .. Constants.FACTESTIO.PID_FILE_NAME
  end

  function F.sandbox_init()
    -- helpers.write_file() writes relative to script-output/, so use bare names.
    F.DONE_FILE = Constants.FACTESTIO.DONE_FILE_NAME
    F.TEST_STDOUT = Constants.FACTESTIO.STDOUT_FILE_NAME
    F.TEST_STDERR = Constants.FACTESTIO.STDERR_FILE_NAME
    F.PID_FILE = Constants.FACTESTIO.PID_FILE_NAME
    F.TEST_SEED_FILE = Constants.FACTESTIO.TEST_SEED_MANIFEST
  end

  return F
end
