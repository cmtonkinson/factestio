return function(F)
  F.registry = {}
  F.DEBUG = false
  F.TEST_TIMEOUT = 8

  -- These will be set at runtime.
  F.FACTORIO_BINARY = ""
  F.FACTORIO_DATA_PATH = ""
  F.DONE_FILE = ""
  F.ROOT = ""
  F.SETTINGS = ""
  F.SAVES = ""

  -------------------------------------------------------------------------------
  function F.init(root)
    F.ROOT = root
    F.SCRIPT_OUTPUT = F.FACTORIO_DATA_PATH .. "script-output/"
    F.SETTINGS = F.ROOT .. "server-settings.json"
    F.SAVES = F.ROOT .. "saves"
    F.TEST_NAME_FILE = F.ROOT .. "scenarios/factestio/test_name.lua"
    F.DONE_FILE = F.SCRIPT_OUTPUT .. "factestio.done"
    F.TEST_STDOUT = F.SCRIPT_OUTPUT .. "factestio.stdout"
    F.TEST_STDERR = F.SCRIPT_OUTPUT .. "factestio.stderr"
    F.PID_FILE = F.SCRIPT_OUTPUT .. "factestio.pid"
  end

  return F
end
