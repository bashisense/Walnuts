
local log   = require("../modules/log")
local Logrdb = require("Logrdb")

local sdb = nil

function TestInit()
  	sdb = Logrdb:New()
  	os.remove("./TestLogrdb.sdb")

  	if sdb:Open("./TestLogrdb.sdb") then
      	log:info("--------TestLogrdb Init--------")
  	else
      	log:info("--------TestLogrdb Fail--------")
  	end
end

function TestFini()
  	sdb:Close()
  	os.remove("./TestLogrdb.sdb")

  	log:info("--------TestLogrdb Fini--------")
end

function DumpLogr(logr)
    if logr == nil then
        return 
    end

    log:info("---------------")
    log:info("  logr.seqnum:",  logr.seqnum)
    log:info("  logr.occtime:", logr.occtime)

    log:info("  logr.face_x:", logr.face_x)
    log:info("  logr.face_y:", logr.face_y)
    log:info("  logr.face_w:", logr.face_w)
    log:info("  logr.face_h:", logr.face_h)

    log:info("  logr.sharp:", logr.sharp)
    log:info("  logr.score:", logr.score)
    log:info("  logr.bbt:",   logr.bbt)

    log:info("  logr.userid:"..logr.userid)
    log:info("---------------")
end

function TestLogrdb()

    local seq = sdb:MaxSeqence()
    if not seq then
        log:info("MaxSeqence Success")
    else
		log:warn("MaxSeqence Fail"..tostring(seq))
    end

    seq = sdb:MinSeqence()
    if not seq then
        log:info("MinSeqence Success")
    else
		log:warn("MinSeqence Fail")
    end

    local count = sdb:Count()
    if count == 0 then
        log:info("Count Success")
    else
		log:warn("Count Fail")
    end

    local logr = {}
    logr.occtime    = os.time()*1000
    logr.face_x     = math.random() % 100
    logr.face_y     = math.random() % 100
    logr.face_w     = math.random() % 1000
    logr.face_h     = math.random() % 1000

    logr.sharp      = 0.98626
    logr.score      = 0.8600
    logr.bbt        = 37.5

    logr.userid     = "USERID0X928="

    if sdb:Append(logr) then
        log:info("Append Success")
    else
		log:warn("Append Fail")
    end

    seq = sdb:MaxSeqence()
    if seq <= 0 then
		log:warn("MaxSeqence Fail")
    end

    for i = 1, 100, 1 do
        logr.occtime = (os.time() + i) * 1000 + i
        logr.userid  = "USERID0X928="..tostring(i)

        sdb:Append(logr)
    end

    local item = sdb:Lookup(20)
    if item == nil then
        log:warn("Lookup Fail")
    else
		log:info("Lookup Success")
    end

    DumpLogr(item)

    if sdb:Clean(20) then
        log:info("Clean Success")
    else
		log:warn("Clean Fail")
    end

    seq = sdb:MaxSeqence()
    log:info("MaxSeqence => "..tostring(seq))

    seq = sdb:MinSeqence()
    log:info("MinSeqence => "..tostring(seq))

    seq = sdb:Count()
    log:info("Count => "..tostring(seq))
end

TestInit()

TestLogrdb()

TestFini()
