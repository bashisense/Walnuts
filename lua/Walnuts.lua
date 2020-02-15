
local ffi   = require("ffi")
local sql   = require("../modules/sqlite3")
local json  = require("../modules/json")
local log   = require("../modules/log")
local Confdb =  require("../lua/Confdb")
local Utils = require("../lua/Utils")

local http = ffi.C

------------------
local cfgdb
------------------

ffi.cdef[[
    const char *GetPath(void *request);
    int GetMethod(void *request);
    void ReplyToClient(void *request, const char *rspjson);
]]

function WnInit(initstr)
    log:info("Walnuts luajit init ...")
    cfgdb = Confdb:New()
    cfgdb:Open("./walnuts-cfg.sdb")
    error("throw")
end

function WnErrorHandler(errStr)
    print(string.format("\27[35m[FATAL %s] %s \27[0m", os.date("%H:%M:%S"), "---------ErrorHandler---------"))
    log:fatal(errStr)
    log:fatal(debug.traceback())
    print(string.format("\27[35m[FATAL %s] %s \27[0m", os.date("%H:%M:%S"), "---------EndofHandler---------"))
end


function WnLocalDispatch(req, body)
    local method = http.GetMethod(req)
    local path = ffi.string(http.GetPath(req))

    local paths = Utils:SplitToTable(path, "/")

    error("throw")
    --log:info(string.format("Walnuts Local Dispatch: method %d, body {%s}", method, body))

    local bj = json.decode(body)

    local action = bj["action"]
    local params = bj["params"]

    -- Utils:DumpTable(params)

    if action == "get" then
        for i, item in ipairs(params) do
            print(cfgdb:Get(item))
        end
    elseif action == "set" then
        for i, item in ipairs(params) do
            for k,v in pairs(item) do
                cfgdb:Set(k, v)
            end
        end
    end

    log:info(string.format( "action:%s", action))


    local rsp = "{ \"retcode\" = 0 }"

    http.ReplyToClient(req, rsp)

    return 0
end

function WnCloudDispatch()
    io.write("luajit:walnuts_cloud_dispatch enter ...\n")
end

function WnFini(finistr)
    log:info("Walnuts luajit fini ...")
end
