--
-- Copyright (c) 2019, Bashi Tech. All rights reserved.
--

local sql   = require("../modules/sqlite3")
local log   = require("../modules/log")

Logrdb = {
    _dbs = nil,      -- sqlite3  opened db instance
    _state = 0       -- state of this object, 0 - uninited, 1 - inited
}


function Logrdb:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function Logrdb:Open(dbfile)
    self._dbs = sql.open(dbfile)

    if self._dbs ~= nil then
        self._dbs:exec[[
            CREATE TABLE IF NOT EXISTS fdr_logmatch(
                seqnum  INTEGER PRIMARY KEY AUTOINCREMENT,
                occtime INT8,
                face_x  INT2, face_y  INT2, face_w  INT2, face_h  INT2,
                sharp   REAL, score   REAL,
                bbt REAL,
                userid  VARCHAR(16));           
        ]]

        self._state = 1

        return true
    end

    return false
end

function Logrdb:Close()
    if self._state < 1 then
        return 
    end

    self._dbs:close()
    self._state = 0
end

function Logrdb:MaxSeqence()
    if self._state < 1 then
        return 0
    end

    local lines, nr = self._dbs:exec[[
        SELECT MAX(seqnum) FROM fdr_logmatch;         
        ]]

    if nr ~= nil and nr ~= 0 then
        return tonumber(lines[1][1])
    end

    return 0
end


function Logrdb:MinSeqence()
    if self._state < 1 then
        return 0
    end

    local lines, nr = self._dbs:exec[[
        SELECT MIN(seqnum) FROM fdr_logmatch;      
        ]]

    if nr ~= nil and nr ~= 0 then
        return tonumber(lines[1][1])
    end
    
    return 0
end

function Logrdb:Count()
    if self._state < 1 then
        return 0
    end

    local lines, nr = self._dbs:exec[[
        SELECT COUNT(*) FROM fdr_logmatch;    
        ]]

    if nr ~= nil and nr ~= 0 then
        return tonumber(lines[1][1])
    end
        
    return 0
end

function Logrdb:Append(logr)
    if self._state < 1 then
        return false
    end

    if logr == nil and logr.occtime == nil then
        return false
    end

    logr.face_x = logr.face_x or 0
    logr.face_y = logr.face_y or 0
    logr.face_w = logr.face_w or 0
    logr.face_h = logr.face_h or 0

    logr.sharp  = logr.sharp or 0.0
    logr.score  = logr.score or 0.0
    logr.bbt    = logr.bbt or 0.0

    logr.userid = logr.userid or ("0000"..tostring(logr.occtime))

    local stmt = self._dbs:prepare("INSERT INTO fdr_logmatch(occtime, face_x, face_y, face_w, face_h, \
                                    sharp, score, bbt, userid) VALUES(?1, ?2, ?3, ?4,?5, ?6, ?7, ?8, ?9)")
    local val = stmt:reset():bind(logr.occtime, logr.face_x, logr.face_y, logr.face_w, logr.face_h,
                                logr.sharp, logr.score, logr.bbt,logr.userid):step()
    stmt:close()

    if val == nil then
        return true
    end

    return false
end

function Logrdb:Lookup(seqnum)
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_logmatch WHERE seqnum = ?1")
    local row = stmt:reset():bind(seqnum):step()
    stmt:close()

    if row == nil then
        return nil
    end

    local logr = {}
    logr.seqnum     = row[1]
    logr.occtime    = row[2]
    logr.face_x     = row[3]
    logr.face_y     = row[4]
    logr.face_w     = row[5]
    logr.face_h     = row[6]
    logr.sharp      = row[7]
    logr.score      = row[8]
    logr.bbt        = row[9]
    logr.userid     = row[10]

    return logr
end

function Logrdb:Clean(seqnum)
    if self._state < 1 then
        return false
    end

    local stmt = self._dbs:prepare("DELETE FROM fdr_logmatch WHERE seqnum < ?1")
    local row = stmt:reset():bind(seqnum):step()
    stmt:close()

    if row == nil then
        return true
    end

    return false
end

return  Logrdb