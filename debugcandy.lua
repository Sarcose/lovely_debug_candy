--quickly thrown together from my unorganized utility.lua
--[[
  uses a _c_ pseudonamespace, thrown into global, for colored console printing:
  _c_debug(str,level)  -- a string or a table of strings all printed one after another, level is the number of files back you want it to print in the trace. uses a default
  _c_warn, _c_error, _c_stop all use the same format. 
            I tend to use level 2-3 for _c_warn and _c_error because those come from data and i might need the files further up
            I usually use 1-2 for _c_debug because that's related to more immediate work I'm doing
  _c_todo{} just takes a table, it defaults to level 1. I use this because it's very in-my-face and serves as a reminder what I'm doing if I take a long break.
        --It parses t[1] as the date in format of "12/31/2024" or "12/31" and will supply a warning if the todolist hasn't been touched in a long time.
        --if the first option isn't in date format it'll just ignore that feature
        --it parses an X at the beginning of an item as a checked off option, and puts a [ ] or [X] conditionally.
--]]

_G.DEBUGMODE = true
_G.DEBUGBASELEVEL = 2   --for _c_ console print functions, this usually means [callingfile.lua:line][datafile.lua:line]
_G.TODOEXPIRATION = 5

--[[ my personal choices
	yellow: Warning
	red:	Error
	green:	Success
	blue: 	Debug
	cyan:	Todo
--]]
local function extractCallerInfo(level)
    local stack = debug.traceback("", 2)
    local lines = {}
    for line in stack:gmatch("[^\n]+") do
        table.insert(lines, line)
    end	--parse 4, 5, 6
	local ret = ""
	local parseStart = 4
	if level then
		for i=1, level do
			local n = (i-1)+parseStart
			local num
			local callerInfo = lines[n] -- lines[4] is the filename of the debug call, abstracted through this->getCallLine->_c_debug()
			if callerInfo then
				local file, line = callerInfo:match("([^:]+):(%d+)")
				if file and line then
					file = file:match("([^/\\]+)$") -- Matches just the file name
					file = string.gsub(file, "%s", "")
					num = tonumber(line)
				end
				if file and num then
					ret = ret.."["..tostring(file)..":"..tostring(num).."]"
				end
			end
		end
	end
    return ret
end
local function getCallLine(n,level)
	level = level or DEBUGBASELEVEL
	local line = extractCallerInfo(level)
	return n.." "..line..": "
end
local limit = 9--to avoid infinite recursion
local function getDeepest(t, refs, deep)
	deep = deep or 1
	if deep >= limit then deep = limit return deep, refs end
	refs = refs or {}
	refs[tostring(t)] = true
	local deepest = 1
	local d = 0
	for k,v in pairs(t) do
		if type(v) == "table" then
			--first, determine if it's a self reference
			if not refs[tostring(v)] then
				refs[tostring(v)] = true
				d, refs = getDeepest(v, refs, deepest)
				deepest = deepest + d
			end
			if deepest > deep then deep = deepest end
			if deep >= limit then deep = limit break end
			d = 0
		end
	end
	--_c_debug("refs: "..tostring(refs),0)
	return deep, refs
end

local function getSpacing(space, name)
	space = space or 9 --the size of a type label
	name = tostring(name)
	local spaces = ""
	local diff = space - #name
	for i = 1, diff do
		spaces = spaces.." "
	end
	return spaces
end
local function inspect(i, refs)
	local t = type(i)
	t = "("..t..")"
	local ret = ""
	local symbol = "= "
	if type(i) == "table" then
		symbol = ""
		local addr = string.gsub(tostring(i),"table: ","")
		--t = string.gsub(t,"table","t")
		ret = ret.."[ addr:"..tostring(addr)
		local ind, key
		if #i > 0 then
			ind = true
			ret = ret .. "   indices:"..#i
		end
		local n = 0
		local deep = 1
		local deepest = 1
		local d = 0
		refs = refs or {}
		refs[tostring(i)] = true
		for k,v in pairs(i) do
			deepest = 1
			if not tonumber(k) then n = n + 1 end
			if type(v) == "table" then
				d, refs = getDeepest(v, refs)
				deepest = deepest + d
			end
			if deepest > deep then deep = deepest end
			d = 0
		end

		if n > 0 then key = true ret = ret .. "   keys:"..n end
		if not ind and not key then
			ret = ret .. "   (Empty Table)"
		else
			if deep >= limit then
				ret = ret .. "   deep: >"..tostring(deep).." [PROBABLE RECURSION]"
			elseif deep > 1 then
				ret = ret .. "   deep:"..tostring(deep)
			end
		end
		ret = ret .. " ]"
	elseif type(i) == "function" then
		t = "(fn)"
		ret = string.gsub(tostring(i),"function: ","")
		ret = "addr:"..ret
		symbol = "  "

	else
		ret = tostring(i)
		if type(i) == "string" then
			ret = '"'..ret..'"'
		end
	end
	return t..getSpacing(nil,t)..symbol..ret
end
function _c_debug(_,level) -- print magenta to console, takes a string or table. Only when DEBUGMODE is on.
	if DEBUGMODE then
		local p = getCallLine("DEBUG",level)
		if type(_) ~= "table" then 
			p = p .._
		else
			local longestname = 0
			local refs = {}
			refs[tostring(_)] = true
			for k,v in pairs(_) do
				if type(k) == "string" then
					if #k > longestname then longestname = #k end
				end
			end
			for i=1, #_ do
				p = p.."\r\n  "
				p = p..getSpacing(longestname,i)..tostring(i).." : "..inspect(_[i], refs)
			end
			for k,v in pairs(_) do
				if not tonumber(k) then
					p = p.."\r\n  "
					p = p..getSpacing(longestname,k)..k.." : "..inspect(v, refs)
				end
			end
		end
		printC("blue",p)
	end
end

local function checkChecked(s)
    if string.sub(s, 1, 1) == "X" then
        -- Return the string without the "X" and true (indicating it started with "X")
        return string.sub(s, 2), true
    else
        -- Return the original string and false (indicating no leading "X")
        return s, false
    end
end
local function compareDate(inputString)
    local currentDate = os.date("*t")
    local currentYear = currentDate.year
    local month, day, year = inputString:match("^(%d%d)/(%d%d)/(%d%d%d%d)$")
    if month and day and year then
        month, day, year = tonumber(month), tonumber(day), tonumber(year)
    else
        month, day = inputString:match("^(%d%d)/(%d%d)$")
        if month and day then
            month, day = tonumber(month), tonumber(day)
            year = currentYear
        else
            return false, nil -- Not a valid date format
        end
    end
    if not (month >= 1 and month <= 12 and day >= 1 and day <= 31) then
        return false, nil -- Invalid date
    end
    local inputTime = os.time({year = year, month = month, day = day})
    local currentTime = os.time()
    local secondsPassed = currentTime - inputTime
    local daysPassed = math.floor(secondsPassed / (24 * 60 * 60)) -- Convert seconds to days
    return true, daysPassed
end
function _c_todo(_) --_c_todo{"Update date","XChecked Step 1","Unchecked Step 2","Unchecked Step 3"}
	local level = 1
	if DEBUGMODE then
		if type(_) ~= "table" then _ = {tostring(_)} end
		local p1 = getCallLine("TODO",level)
		local p2 = nil
		local p3 = ""
		local checked = "[X] "
		local unchecked = "[ ] "
		local checkbox = ""
		local exTimePassed
		for i=1, #_ do
			local item = _[i]
			local date, timePassed = compareDate(item)
			if date then
				exTimePassed = timePassed
				if timePassed >= TODOEXPIRATION then
					p2 = "     WARNING: "..tostring(timePassed).." days since this Todo list was updated!"
				end
			else
				local s, isChecked = checkChecked(tostring(_[i]))
				if isChecked then
					checkbox = checked
				else
					checkbox = unchecked
				end
				p3 = p3.."     "..checkbox..s
				if i < #_ then
					p3 = p3.."\r\n"
				end
			end
		end
		local warncolor = nil
		if exTimePassed then
			if exTimePassed >= (TODOEXPIRATION * 3) then
				warncolor = "red"
			elseif exTimePassed >= TODOEXPIRATION then
				warncolor = "yellow"
			end
		end
		printCTable({"cyan",warncolor,"cyan"},{p1,p2,p3})
	end
end
function _c_warn(_,level) --print yellow to console, takes a string or table
    if type(_) ~= "table" then _ = {_} end
	local p = getCallLine("WARN",level)
	for i=1, #_ do
		p = p..tostring(_[i])
		if i < #_ then
			p = p..", "
		end
    end
    printC("yellow",p)
end
function _c_stoperror(_,level) --print red to console then stop the program
	_c_error(_,level)
	error("See console output. Stacktrace:")
end
function _c_error(_,level) --print red to console, takes a string or table
    if type(_) ~= "table" then _ = {_} end
    local p = getCallLine("ERROR",level)
    for i=1, #_ do
		p = p..tostring(_[i])
		if i < #_ then
			p = p..", "
		end
    end
    printC("red",p)
end
local consolecolors = 
{reset = "\x1B[m", red = "\x1B[31m", 		--red: error
yellow = "\x1b[33m", green = "\x1B[32m", 	--yellow: warn (looks orange)  green: good stuff like "finished loading!" probably
blue = "\x1b[34m", cyan = "\x1b[36m"}		--blue: debug messages		cyan: TODO
function printCTable(cTable, sTable)	--print a table of strings with a table of colors, used in Todo list mainly
	for i=1, #sTable do
		local s = sTable[i]
		if s then
			local c = cTable[i]
			c = c or "reset"
			printC(c,s)
		end
	end
end
function printC(colour, ...)
	if not consolecolors[colour] then error("Undefined colour: " .. colour) end
	io.write(consolecolors[colour])
	if colour == "blue" then io.write("\x1b[1m") end
	print(...)
	io.write(consolecolors.reset)
end
--example implementation:
_c_todo{"11/31/2024","XChecked Option 1","Unchecked Option 2"}
_c_debug("debug message here",2)
_c_warn{"a bunch of things","stuff","and","other stuff"}
