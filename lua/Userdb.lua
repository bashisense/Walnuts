--
-- Copyright (c) 2019, Bashi Tech. All rights reserved.
--

local sql   = require("../modules/sqlite3")
local log   = require("../modules/log")
local ffi   = require("ffi")

Userdb = {
    _dbs = nil,      -- sqlite3  opened db instance
    _state = 0,      -- state of this object, 0 - uninited, 1 - inited
    _stmt = nil,     -- stmt for user fetch next
}

-- User = {
--    userid      = nil,
--    name        = nil,
--    desc        = nil,
--    others      = nil,
--    state       = 0,
--    rule        = 0,
--    expired     = 0,    -- seconds form 1970,1,1
--    created     = nil,
--    modified    = nil
-- }

function Userdb:New(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end


function Userdb:Open(dbfile)
    self._dbs = sql.open(dbfile)

    if self._dbs ~= nil then
        self._dbs:exec[[
            CREATE TABLE IF NOT EXISTS fdr_visitor(
                vcid INTEGER  PRIMARY KEY,
                visicode   VARCHAR(16),
                started INTEGER,
                expired INTEGER,
                create_datetime VARCHAR(32) DEFAULT CURRENT_TIMESTAMP NOT NULL);
            
            CREATE TABLE IF NOT EXISTS fdr_user(
                userid  VARCHAR(32) PRIMARY KEY,
                name    VARCHAR(16),
                desc    VARCHAR(32),
                others  VARCHAR(32),
                state   INTEGER,
                rule    INTEGER,
                expire_datetime INTEGER,
                create_datetime VARCHAR(32),
                modify_datetime VARCHAR(32) DEFAULT CURRENT_TIMESTAMP NOT NULL);
                
            CREATE TABLE IF NOT EXISTS fdr_feature(
                userid  VARCHAR(32),
                algmv   VARCHAR(32),
                feature BLOB,
                PRIMARY KEY (userid, algmv));
        ]]

        self._state = 1

        return true
    end

    return false
end

function Userdb:Close()
    if self._state < 1 then
        return 
    end

    self._dbs:close()
    self._state = 0
end

function Userdb:exist(userid)
    if self._state < 1 then
        return nil
    end
    
    local stmt = self._dbs:prepare("SELECT * FROM fdr_user WHERE userid = ?")
    local val = stmt:reset():bind(userid):step()
    stmt:close()

    return val
end

function Userdb:checkMaxValid(user)
    if user == nil then
        return false
    end

    if user.userid == nil then
        return false
    end

    if user.name == nil then
        return false
    end

    if user.desc == nil then
        return false
    end

    if user.rule == nil then
        user.rule = 1
    end

    if user.expired == nil then
        user.expired = os.time() + 24*60*60*365
    end

    return true
end

function Userdb:checkMinValid(user)
    if user == nil then
        return false
    end

    if user.userid == nil then
        return false
    end

    return true
end

function Userdb:Insert(user)
    if self._state < 1 then
        return false
    end

    if not self:checkMaxValid(user) then
        log:warn("Insert -> check user fail")
        return false
    end

    local u = self:exist(user.userid)
    if u ~= nil then
        log:warn("Insert -> user exist")
        return false
    end

    local stmt = self._dbs:prepare("INSERT INTO fdr_user VALUES(?1, ?2, ?3, ?4,?5, ?6, ?7,   \
                datetime(CURRENT_TIMESTAMP, 'localtime'), datetime(CURRENT_TIMESTAMP, 'localtime'))")
    local val = stmt:reset():bind(user.userid, user.name, user.desc, user.others, 0, user.rule, user.expired):step()
    stmt:close()

    if val == nil then
        return true
    end

    return false
end

function RowToTable(user)
    if user == nil then
        log:warn("RowToTable -> input is nil")
        return nil
    end

    local u = {}

    u.userid  = user[1]
    u.name    = user[2]
    u.desc    = user[3]
    u.others  = user[4]
    u.state   = tonumber(user[5])
    u.rule    = tonumber(user[6])
    u.expired = tonumber(user[7])   -- expire_datetime in db
    u.create_datetime = user[8]
    u.modify_datetime = user[9]

    return u
end

function Userdb:Lookup(userid)
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_user WHERE userid = ?1")
    local user = stmt:reset():bind(userid):step()
    stmt:close()

    if user == nil then
        -- log:warn("Lookup -> lookup "..userid.."not exist")
        return nil
    end

    return RowToTable(user)
end

function Userdb:Delete(userid)
    if self._state < 1 then
        return false
    end

    local stmt = self._dbs:prepare("DELETE FROM fdr_user WHERE userid = ?1")
    local done = stmt:reset():bind(userid):step()
    stmt:close()

    if done == nil then
        return true
    else
        return false
    end
end

function Userdb:Update(user)
    if self._state < 1 then
        return false
    end

    if not self:checkMinValid(user) then
        log:warn("Update -> check user fail")
        return false
    end

    local u = self:Lookup(user.userid)
    if u == nil then
        log:warn("Update -> user not exist:"..user.userid)
        return false
    end

    user.name = user.name or u.name
    user.desc = user.desc or u.desc
    user.others = user.others or u.others
    user.state = user.state or u.state
    user.rule = user.rule or u.rule
    user.expired = user.expired or u.expired

    local stmt = self._dbs:prepare("UPDATE fdr_user SET name = ?1, desc = ?2, others = ?3, state = ?4,  \
                        rule = ?5, expire_datetime = ?6, modify_datetime = datetime(CURRENT_TIMESTAMP, 'localtime') where userid = ?7")
    local val = stmt:reset():bind(user.name, user.desc, user.others, user.state, user.rule, user.expired, user.userid):step()
    stmt:close()

    if val == nil then
        return true
    end

    return false
end

function Userdb:Fetch(offset, limit)    
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT userid FROM fdr_user LIMIT ?1 OFFSET ?2")
    local userids, nr = stmt:reset():bind(limit, offset):resultset()
    stmt:close()

    return userids, nr
end

function Userdb:existFeature(userid, algmv)
    if self._state < 1 then
        return false
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_feature WHERE (userid = ?1 AND algmv = ?2)")
    local val = stmt:reset():bind(userid, algmv):step()
    stmt:close()

    if val == nil then
        return false
    end

    return true
end

function Userdb:InsertFeature(userid, algmv, feature)
    if self._state < 1 then
        return false
    end

    local exist = self:existFeature(userid, algmv)
    if exist then
        log:warn("InsertFeature -> exist")
        return false
    end

    local stmt = self._dbs:prepare("INSERT INTO fdr_feature VALUES(?1, ?2, ?3)")
    local val = stmt:reset():bind(userid, algmv, sql.blob(feature)):step()
    stmt:close()

    if val == nil then
        return true
    end

    return false
end


function Userdb:LookupFeature(userid, algmv)
    if self._state < 1 then
        return nil
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_feature WHERE (userid = ?1 AND algmv = ?2)")
    local val = stmt:reset():bind(userid, algmv):step()
    stmt:close()

    if val == nil then
        return nil
    end

    return val[3]
end

function Userdb:UpdateFeature(userid, algmv, feature)
    if self._state < 1 then
        return false
    end

    local stmt = self._dbs:prepare("UPDATE fdr_feature SET feature = ?1  WHERE (userid = ?2 AND algmv = ?3)")
    stmt:reset():bind(sql.blob(feature), userid, algmv):step()
    stmt:close()
    
    return true
end

function Userdb:DeleteFeature(userid, algmv)
    if self._state < 1 then
        return false
    end

    local stmt = self._dbs:prepare("DELETE FROM fdr_feature WHERE (userid = ?1 AND algmv = ?2)")
    stmt:reset():bind(userid, algmv):step()
    stmt:close()
    
    return true
end

function Userdb:InsertVisitorCode(vcid, visicode, started, expired)
    if self._state < 1 then
        return false
    end

    if vcid == nil or visicode == nil then
        return false
    end

    local stmt = self._dbs:prepare("SELECT * FROM fdr_visitor WHERE vcid = ?1")
    local val = stmt:reset():bind(vcid):step()
    stmt:close()

    if val ~= nil then
        return false
    end

    started = started or os.time()              -- default : from now
    expired = expired or os.time() + 24*60*60   -- default : 24 hours
    
    stmt = self._dbs:prepare("INSERT INTO fdr_visitor VALUES(?1, ?2, ?3, ?4, datetime(CURRENT_TIMESTAMP, 'localtime'))")
    val = stmt:reset():bind(vcid, visicode, started, expired):step()
    stmt:close()

    if val == nil then
        return true
    end

    return false
end

function Userdb:LookupVisitorCode(visicode, ocur)
    if self._state < 1 then
        return false
    end

    if visicode == nil then
        return false
    end

    ocur = ocur or os.time()
    local stmt = self._dbs:prepare("SELECT * FROM fdr_visitor WHERE (visicode = ?1 and started <= ?2 and expired >= ?3)")
    local val = stmt:reset():bind(visicode, ocur, ocur):step()
    stmt:close()

    if val ~= nil then
        return true
    end

    return false
end

function Userdb:DeleteVisitorCode(vcid)
    if self._state < 1 then
        return false
    end

    if vcid == nil then
        return false
    end

    local stmt = self._dbs:prepare("DELETE FROM fdr_visitor WHERE vcid = ?1")
    local val = stmt:reset():bind(vcid):step()
    stmt:close()

    return true
end

function Userdb:CleanVisitorCode(expired)
    if self._state < 1 then
        return false
    end

    expired = expired or os.time()

    local stmt = self._dbs:prepare("DELETE FROM fdr_visitor WHERE expired < ?1")
    local val = stmt:reset():bind(expired):step()
    stmt:close()

    return true
end


function Userdb:BytesCompare(a, b)
    if a == nil  or a.data == nil then return false end
    if b == nil  or b.data == nil then return false end

    if a.len ~= b.len then return false end
    if ffi.typeof(a.data) ~= ffi.typeof(b.data) then return false end
    
    for i = 0, a.len - 1 do
        if a.data[i] ~= b.data[i] then
            return false
        end
    end
    
    return true
end

function Userdb:NewRandomFeature(n)
    local s = {}
    s.data = ffi.new(ffi.typeof("char[?]"), n)
    s.len = ffi.sizeof("char[?]", n)

    setmetatable(s, {__len = function(t) return t.len end})

    return s
end


return Userdb
