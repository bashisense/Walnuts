--
-- Copyright (c) 2019, Bashi Tech. All rights reserved.
--

local sql   = require("../modules/sqlite3")

Confdb = {
    _dbs = nil,      -- sqlite3  opened db instance
    _state = 0       -- state of this object, 0 - uninited, 1 - inited
}

function Confdb:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function Confdb:Open(dbfile)
    self._dbs = sql.open(dbfile)

    if self._dbs ~= nil then
        self._state = 1

        self._dbs:exec[[
            CREATE TABLE IF NOT EXISTS fdr_config(key TEXT PRIMARY KEY, val TEXT, modify_datetime VARCHAR(32) DEFAULT CURRENT_TIMESTAMP NOT NULL);
        ]]

        return true
    end

    return false
end

function Confdb:Close()
    if self._state < 1 then
        return false
    end

    self._dbs:close()
    self._state = 0

    return true
end

function Confdb:Set(keyStr, valStr)
    if self._state < 1 then
        return false
    end

    local stmt = nil
    local ret = nil
    local rows = Confdb:Get(keyStr)
    if rows ~= nil then
        stmt = self._dbs:prepare("REPLACE INTO  fdr_config VALUES(?1, ?2, datetime(CURRENT_TIMESTAMP, 'localtime'))")
        ret = stmt:reset():bind(keyStr, valStr):step()
    else

        stmt = self._dbs:prepare("INSERT INTO fdr_config VALUES(?1, ?2, datetime(CURRENT_TIMESTAMP, 'localtime'))")
        ret = stmt:reset():bind(keyStr, valStr):step()
    end

    stmt:close()

    if ret == nil then
        return true
    else
        return false
    end
end

function Confdb:Get(keyStr)
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_config WHERE key = ?1")
    local val = stmt:reset():bind(keyStr):step()
    stmt:close()

    if val == nil then
        return nil
    else
        return val[2]
    end
end

function Confdb:List()
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_config")
    local rows, nr =  stmt:resultset()
    stmt:close()

    return rows,nr
end

return Confdb
