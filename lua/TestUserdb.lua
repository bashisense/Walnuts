local log   = require("../modules/log")
local Userdb = require("Userdb")
local Utils  = require("Utils")
local ffi = require("ffi")

local sdb = nil

function TestInit()
    sdb = Userdb:New()
    os.remove("./TestUserdb.sdb")

    if sdb:Open("./TestUserdb.sdb") then
        log:info("--------TestUserdb Init--------")
    else
        log:info("--------TestUserdb Fail--------")
    end
end

function TestFini()
    sdb:Close()
    os.remove("./TestUserdb.sdb")

    log:info("--------TestUserdb Fini--------")
end

function DumpUser(user)
    log:info("----------------------")
    log:info("  user.userid:"..user.userid)
    log:info("  user.name:"..user.name)
    log:info("  user.desc:"..user.desc)
    log:info("  user.others:", user.others)
    log:info("  user.state:", user.state)
    log:info("  user.rule:", user.rule)
    log:info("  user.expire_datetime:"..os.date("%Y-%m-%d %H:%M:%S", user.expired))
    log:info("  user.create_datetime:"..user.create_datetime)
    log:info("  user.modify_datetime:"..user.modify_datetime)
    log:info("----------------------")
end

function TestUserCRUD()
    log:info("--------TestUserCRUD--------")
    
    local user = {}
    user.userid   = "userid-0x923ksldfs"
    user.name     = "Test User"
    user.desc     = "develop department"
    user.others   = nil
    user.state    = 0
    user.rule     = 1

    if sdb:Insert(user) then
        log:info("Insert Success")
    else
        log:warn("Insert Fail")
    end

    local u = sdb:Lookup(user.userid)
    if u ~= nil then
        log:info("Lookup Success")
        DumpUser(u)
    else
        log:warn("Lookup Fail")
    end

    user.name = "New Name"
    user.desc = nil
    user.others = "others"
    if sdb:Update(user) then
        log:info("Update Success")
    else
        log:warn("Update Fail")
    end

    if sdb:Delete(user.userid) then
        if not sdb:Lookup(user.userid) then
            log:info("Delete Success")
        else
            log:warn("Delete Fail")
        end
    else
        log:warn("Delete Fail")
    end

end

function TestUserFetch()
    local user = {}

    log:info("--------TestUserFetch--------")

    user.name     = "Test User"
    user.desc     = "develop department"
    user.others   = nil
    user.state    = 0
    user.rule     = 1

    for i = 1, 100, 1 do
        user.userid   = string.format("%s%d", "userid-random-", i)
        if not sdb:Insert(user) then
            log:warn("TestUserFetch Fail:"..user.userid)
        end
    end

    local count = 0
    for i = 1, 100, 10 do
        local ids, nr = sdb:Fetch(i-1, 10)
        if ids == nil then
            break
        end

        count = count + 1

        --for j = 1, nr, 1 do
        --    local u = ldb:Lookup(ids[1][j])
        --    if u ~= nil then
        --        DumpUser(u)
        --    end
        --end
    end

    if count ~= 10 then
        log:warn("TestUserFetch Fail:", count)
    else
        log:info("TestUserFetch Success")
    end
end

function NewRandomFeature(n)
    local s = {}
    s.data = ffi.new(ffi.typeof("char[?]"), n)
    s.len = ffi.sizeof("char[?]", n)

    -- need lua5.2 support __len
    setmetatable(s, {__len = function(t) return t.len end})

    for i =0, n - 1 do
        s.data[i] = math.random()
    end

    return s
end

function BytesCompare(a, b)
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

function TestFeature()
    log:info("--------TestFeature--------")

    local userid  = string.format("%s%d", "userid-random-", 20)
    local algmv   = "v2.2.1"
    local feature1 = NewRandomFeature(2048)
    local feature2 = NewRandomFeature(2048)

    print("NewRandomFeature :", #feature1)

    -- insert
    local ret = sdb:InsertFeature(userid, algmv, feature1)
    if not ret then
        log:warn("TestFeature -> InsertFeature Fail")
        return false
    else
        log:info("TestFeature -> InsertFeature Success")
    end

    -- lookup
    local fret = sdb:LookupFeature(userid, algmv)
    Utils:DumpTable(fret)
    
    if fret == nil then
      log:warn("TestFeature -> LookupFeature Fail-1")
      return false
    elseif BytesCompare(feature1,fret) then
      log:info("TestFeature -> LookupFeature Success")
    else
      log:warn("TestFeature -> LookupFeature Fail-2")
      return false
    end

    -- update
    ret = sdb:UpdateFeature(userid, algmv, feature2)
    if not ret then
        log:warn("TestFeature UpdateFeature Fail")
        return false
    end

    fret = sdb:LookupFeature(userid, algmv)
    if fret == nil then
      log:warn("TestFeature -> UpdateFeature Fail")
      return false
    elseif BytesCompare(fret,feature2) then
      log:info("TestFeature -> UpdateFeature Success")
    else
      log:warn("TestFeature -> UpdateFeature Fail")
      return false
    end

    --delete
    ret = sdb:DeleteFeature(userid, algmv)
    if not ret then
        log:warn("TestFeature DeleteFeature Fail")
        return false
    end

    fret = sdb:LookupFeature(userid, algmv)
    if fret == nil then
        log:info("TestFeature -> DeleteFeature Success")
    else
        log:warn("TestFeature -> DeleteFeature Fail")
        return false
    end
end


function TestVisitor()
    log:info("--------TestVisitor--------")

    local vcid = 100
    local visicode = "436789"
    local started  = os.time()
    local expired  = os.time() + 3600*24
    
    -- InsertVisitorCode
    if sdb:InsertVisitorCode(vcid, visicode, started, expired) then
        log:info("TestVisitor -> InsertVisitorCode Success")
    else
        log:warn("TestVisitor -> InsertVisitorCode Fail")
        return false
    end

    -- LookupVisitorCode
    if sdb:LookupVisitorCode(visicode) then
        log:info("TestVisitor -> LookupVisitorCode Success")
    else
        log:warn("TestVisitor -> LookupVisitorCode Fail")
        return false
    end

    if sdb:LookupVisitorCode(visicode, os.time() - 1024) then
        log:warn("TestVisitor -> LookupVisitorCode Fail")
        return false
    else
        log:info("TestVisitor -> LookupVisitorCode Success")
    end

    if sdb:LookupVisitorCode(visicode, os.time() + 10*24*3600) then
        log:warn("TestVisitor -> LookupVisitorCode Fail")
        return false
    else
        log:info("TestVisitor -> LookupVisitorCode Success")
    end

    -- DeleteVisitorCode
    if sdb:DeleteVisitorCode(vcid) then
        log:info("TestVisitor -> DeleteVisitorCode Success")
    else
        log:warn("TestVisitor -> DeleteVisitorCode Fail")
        return false
    end

    if sdb:LookupVisitorCode(visicode) then
        log:warn("TestVisitor -> DeleteVisitorCode Fail")
        return false
    else
        log:info("TestVisitor -> DeleteVisitorCode Success")
    end

    -- CleanVisitorCode
    for i = 1, 10, 1 do
        visicode = "2348"..tostring(i)
        sdb:InsertVisitorCode(vcid, visicode, started, expired)
    end

    if sdb:CleanVisitorCode(os.time() + 100*24*3600) then
        visicode = "2348"..tostring(5)
        if sdb:LookupVisitorCode(visicode) then
            log:warn("TestVisitor -> CleanVisitorCode Fail")
            return false
        else
            log:info("TestVisitor -> CleanVisitorCode Success")
        end
    else
        log:warn("TestVisitor -> CleanVisitorCode Fail")
        return false
    end
end


TestInit()

--TestUserCRUD()
--TestUserFetch()

TestFeature()

--TestVisitor()

TestFini()
