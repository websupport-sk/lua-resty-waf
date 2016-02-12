local _M = {}

_M.version = "0.6.0"

local ac       = require("inc.load_ac")
local cidr_lib = require("lib.cidr")
local iputils  = require("inc.resty.iputils")
local logger   = require("lib.log")

-- module-level cache of aho-corasick dictionary objects
local _ac_dicts = {}

function _M.equals(a, b)
	local equals

	if (type(a) == "table") then
		for _, v in ipairs(a) do
			equals = _M.equals(v, b)
			if (equals) then
				break
			end
		end
	else
		equals = a == b
	end

	return equals
end

function _M.greater(a, b)
	local greater

	if (type(a) == "table") then
		for _, v in ipairs(a) do
			greater = _M.greater(v, b)
			if (greater) then
				break
			end
		end
	else
		greater = a > b
	end

	return greater
end

function _M.regex_match(FW, subject, pattern)
	local opts = FW._pcre_flags
	local from, to, err
	local match

	if (type(subject) == "table") then
		for _, v in ipairs(subject) do
			match = _M.regex_match(FW, v, pattern, opts)

			if (match) then
				break
			end
		end
	else
		from, to, err = ngx.re.find(subject, pattern, opts)

		if err then
			ngx.log(ngx.WARN, "error in regex_match: " .. err)
		end

		if from then
			match = string.sub(subject, from, to)
		end
	end

	return match
end

function _M.ac_lookup(needle, haystack, ctx)
	local id = ctx.id
	local match, _ac

	-- dictionary creation is expensive, so we use the id of
	-- the rule as the key to cache the created dictionary
	if (not _ac_dicts[id]) then
		_ac = ac.create_ac(haystack)
		_ac_dicts[id] = _ac
	else
		_ac = _ac_dicts[id]
	end

	if (type(needle) == "table") then
		for _, v in ipairs(needle) do
			match = _M.ac_lookup(v, haystack, ctx)

			if (match) then
				break
			end
		end
	else
		match = ac.match(_ac, needle)
	end

	return match
end

function _M.cidr_match(ip, cidr_pattern)
	local t = {}
	local n = 1

	if (type(cidr_pattern) ~= "table") then
		cidr_pattern = { cidr_pattern }
	end

	for _, v in ipairs(cidr_pattern) do
		t[n] = cidr_lib.cidrs[v]
		n = n + 1
	end

	return iputils.ip_in_cidrs(ip, t)
end

return _M
