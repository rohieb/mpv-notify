-- notify.lua -- Desktop notifications for mpv.
-- Just put this file into your ~/.mpv/lua folder and mpv will find it.
-- Author: Roland Hieber <rohieb at rohieb.name>

-- string.urlescape()
-- Author: daurnimator
-- License: MIT/X11 
-- From: http://snippets.luacode.org/?p=snippets/stringurlescape_89
local save__index = function ( func )
	return function ( t , k  )
		local v = func ( t , k )
		rawset ( t , k ,  v )
		return v
	end
end
local byte_tbl = setmetatable ( { } , { __index = save__index ( function ( t , k ) return ("%%%02x"):format ( c:byte ( ) ) end ) } )
function string.urlescape ( str )
	return string.gsub(str, "([^/A-Za-z0-9_])", byte_tbl)
end

-- escape string for shell inclusion
function string.htmlescape(str)
	str = string.gsub(str, "<", "&lt;")
	str = string.gsub(str, ">", "&gt;")
	str = string.gsub(str, "&", "&amp;")
	str = string.gsub(str, "\"", "&quot;")
	str = string.gsub(str, "'", "&apos;")
	return str
end

-- escape string for shell inclusion
function string.shellescape(str)
	return "'"..string.gsub(str, "'", "'\"'\"'").."'"
end

function notify_current_track()
	data = mp.get_property_native("metadata")
	----------------------- debugging
	for k,v in pairs(data) do
		print(k .. ":" .. v)
	end

	title = ""
	artist = ""
	album = ""

	if(data["artist"] and string.len(data["artist"]) > 0) then
		artist = data["artist"]
	end
	if(data["album"] and string.len(data["album"]) > 0) then
		album = data["album"]
	end
	if(data["title"] and string.len(data["title"]) > 0) then
		title = data["title"]
	else
		title = mp.get_property_native("filename")
	end

	header = string.shellescape(string.htmlescape(artist))
	body = string.shellescape(string.htmlescape(title))

	if(string.len(header) < 1) then
		header = "Now playing:"
	end
	if(string.len(album) > 1) then
		body = string.shellescape(string.htmlescape(title)
			.."<br/><i>"..string.htmlescape(album).."</i>")
		--body = string.shellescape(title).."'<br/><i>'"
			--..string.shellescape(album).."'</i>'"
	end

	command = "notify-send -a mpv -- "..header.." "..body
	print("command:", command)
	os.execute(command)
end

mp.register_event("file-loaded", notify_current_track)
