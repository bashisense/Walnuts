
local log   = require("../modules/log")
local Confdb = require("Confdb")

local sdb = nil

function TestInit()
  	sdb = Confdb:New()
  	os.remove("./TestConfdb.sdb")

  	if sdb:Open("./TestConfdb.sdb") then
      	log:info("--------TestConfdb Init--------")
  	else
      	log:info("--------TestConfdb Fail--------")
  	end
end

function TestFini()
  	sdb:Close()
  	os.remove("./TestConfdb.sdb")

  	log:info("--------TestConfdb Fini--------")
end

function TestConfdb()

  	if sdb:Set("key001", "val001") then
		log:info("Set Success")
  	else
		log:warn("Set Fail")
		return false
	end

  	if sdb:Set("key002", "val002-2") then
		log:info("Set Success")
  	else
		log:warn("Set Fail")
		return false
	end

	local row = sdb:Get("key002")
	if row == nil then
		log:warn("Get Fail")
		return false
	end
	
	if row ~= "val002-2" then
		log:warn("Get Fail")
		return false
	end

	log:info("Get Success")
	
	local rows, nr = sdb:List()
	  
	if nr ~= 2 then
		log:warn("List Fail")
		return false
	end

  	for i = 1,nr,1 do
    	log:info("key="..rows[1][i]..",	value="..rows[2][i])
  	end
end

TestInit()

TestConfdb()

TestFini()
