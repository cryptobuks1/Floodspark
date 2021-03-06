local fs_functions = {}

local function route()
	if ngx.var.mode == "honeypot" then
		ngx.var.target = "snare:80"
		return
	end
	if ngx.var.mode == "block" then
		return ngx.exit(ngx.HTTP_UNAUTHORIZED)
	end
end

function fs_functions.check_list(ip)
        local redis = require "resty.redis"
        local red = redis:new()
        red:set_timeouts(1000, 1000, 1000) -- 1 sec

        local ok, err = red:connect("redis", 6379)
        if not ok then
--                ngx.say("failed to connect: ", err)
--              failing open:
		return
        end
      
        local res, err = red:hget(ip, "list")
        if not res then
--		ngx.say("failed to check list", err)
--              failing open:
		return
        end

        if res == ngx.null then
--        	ngx.say("ip wasn't known")
        	return
	elseif res == "black" then
--		ngx.log(ngx.STDERR, "ip is in blacklist")
		route()
	elseif res == "white" then
		return "white"
        end
end

function fs_functions.list(ip, list)
	local redis = require "resty.redis"
	local red = redis:new()
	red:set_timeouts(1000, 1000, 1000) -- 1 sec

	local ok, err = red:connect("redis", 6379)
	if not ok then
--		ngx.say("failed to connect: ", err)
		return
	end

	ok, err = red:hset(ip,"list",list)
	if not ok then
--		ngx.say("failed to set ip: ", err)
		return
	end

	result = red:expire(ip, 600)
	if result ~= 1 then
--		ngx.log(ngx.STDERR, "error setting expiration")
		return
	end

	if list == "black" then
		route()
	end
--	ngx.say("set result: ", ok)
end

function fs_functions.confirm_googlebot(ip)
	local resolver = require "resty.dns.resolver"
	local r, err = resolver:new{
		nameservers = {"8.8.8.8", {"8.8.4.4", 53} },
		retrans = 5,  -- 5 retransmissions on receive timeout
		timeout = 2000,  -- 2 sec
	}

	if not r then
		ngx.log(ngx.STDERR, 'failed to instantiate the resolver')
		return
	end

	local answer, err = r:reverse_query(ip)
	if not answer then
		ngx.log(ngx.STDERR, 'failed to query the DNS server')
		return
	end
	if answer.errcode then
		ngx.log(ngx.STDERR, 'there was an errcode')
		ngx.log(ngx.STDERR, answer.errcode)
		return
	end
        ptrdname = answer[1].ptrdname
	if string.find(ptrdname, "googlebot.com", -13) then
		return	
	elseif string.find(ptrdname, "google.com", -10) then
 		return
	else
		return false
	end
end

return fs_functions
