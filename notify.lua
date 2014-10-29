-- notify.lua -- Desktop notifications for mpv.
-- Just put this file into your ~/.mpv/lua folder and mpv will find it.
-- Author: Roland Hieber <rohieb at rohieb.name>
-- Dependencies:
--  * lua >= 5.2
--  * lua-socket
--  * notify-send (Debian package: libnotify-bin)
--  * ImageMagick convert

-------------------------------------------------------------------------------
-- helper functions
-------------------------------------------------------------------------------

function print_debug(s)
	print("DEBUG: " .. s) -- comment out for no debug info
	return true
end

-- url-escape a string, per RFC 2396, Section 2
function string.urlescape(str)
	s, c = string.gsub(str, "([^A-Za-z0-9_.!~*'()/-])",
		function(c)
			return ("%%%02x"):format(c:byte())
		end)
	return s;
end

-- escape string for html
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

-- converts string to a valid filename on most (modern) filesystems
function string.safe_filename(str)
	s, c = string.gsub(str, "([^A-Za-z0-9_.-])",
		function(c)
			return ("%02x"):format(c:byte())
		end)
	return s;
end

-------------------------------------------------------------------------------
-- here we go.
-------------------------------------------------------------------------------

http = require("socket.http")
http.TIMEOUT = 3
http.USERAGENT = "mpv-notify/0.1"

local CACHE_DIR = os.getenv("XDG_CACHE_HOME")
CACHE_DIR = CACHE_DIR or os.getenv("HOME").."/.cache"
CACHE_DIR = CACHE_DIR.."/mpv/coverart"
print_debug("making " .. CACHE_DIR)
os.execute("mkdir -p -- " .. string.shellescape(CACHE_DIR))

-- fetch cover art from MusicBrainz/Cover Art Archive
-- @return file name of downloaded cover art, or nil in case of error
-- @param mbid optional MusicBrainz release ID
function fetch_musicbrainz_cover_art(artist, album, mbid)
	print_debug("fetch_musicbrainz_cover_art parameters:")
	print_debug("artist: " .. artist)
	print_debug("album: " .. album)
	print_debug("mbid: " .. mbid)

	output_filename = string.safe_filename(artist .. "_" .. album)
	output_filename = (CACHE_DIR .. "/%s.png"):format(output_filename)

	-- TODO: dirty hack, may only work on Linux.
	f, err = io.open(output_filename, "r")
	if f then
		print_debug("file is already in cache: " .. output_filename)
		return output_filename  -- exists and is readable
	elseif string.find(err, "[Pp]ermission denied") then
		print(("cannot read from cached file %s: %s"):format(output_filename, err))
		return nil
	end
	print_debug("fetching album art to " .. output_filename)

	valid_mbid = function(s)
		return s and string.len(s) > 0 and not string.find(s, "[^0-9a-fA-F-]")
	end

	-- fetch release MBID from MusicBrainz, needed for Cover Art Archive
	if not valid_mbid(mbid) then
		string.gsub(artist, '"', "")
		query = ("%s AND artist:%s"):format(album, artist)
		url = "http://musicbrainz.org/ws/2/release?limit=1&query="
			.. string.urlescape(query)
		print_debug("fetching " .. url)
		d, c, h = http.request(url)
		-- poor man's XML parsing:
		mbid = string.match(d or "",
			"<%s*release[^>]+id%s*=%s*['\"]%s*([0-9a-fA-F-]+)%s*['\"]")
		if not mbid or not valid_mbid(mbid) then
			print("MusicBrainz returned no match.")
			print_debug("content: " .. d)
			return nil
		end
	end
	print_debug("got MusicBrainz ID " .. mbid)

	-- fetch image from Cover Art Archive
	url = ("http://coverartarchive.org/release/%s/front-250"):format(mbid)
	print("fetching album cover from " .. url)
	d, c, h = http.request(url)
	if c ~= 200 then
		print(("Cover Art Archive returned HTTP %s for MBID %s"):format(c, mbid))
		return nil
	end
	if not d or string.len(d) < 1 then
		print(("Cover Art Archive returned no content for MBID %s"):format(mbid))
		print_debug("HTTP response: " .. d)
		return nil
	end

	tmp_filename = CACHE_DIR .. "/tmpfile" .. math.random(0,0xffff)
	f = io.open(tmp_filename, "w+")
	f:write(d)
	f:flush()
	f:close()

	-- make it a nice size
	convert_cmd = ("convert -scale x64 -- %s %s"):format(
		string.shellescape(tmp_filename), string.shellescape(output_filename))
	print_debug("executing " .. convert_cmd)
	result = os.execute(convert_cmd)

	if not os.remove(tmp_filename) then
		print("could not remove" .. tmp_filename .. ", please remove it manually")
	end

	if result then
		return output_filename
	else
		return nil
	end

	return nil
end

function notify_current_track()
	data = mp.get_property_native("metadata")

	function get_metadata(data, keys)
		for k,v in pairs(keys) do
			if data[v] and string.len(data[v]) > 0 then
				return data[v]
			end
		end
		return ""
	end
	-- srsly MPV, why do we have to do this? :-(
	artist = get_metadata(data, {"artist", "ARTIST"})
	album = get_metadata(data, {"album", "ALBUM"})
	album_mbid = get_metadata(data, {"MusicBrainz Album Id",
		"MUSICBRAINZ_ALBUMID"})
	title = get_metadata(data, {"title", "TITLE"})
	if title == "" then
		title = mp.get_property_native("filename")
	end

	print_debug("notify_current_track: relevant metadata:")
	print_debug("artist: " .. artist)
	print_debug("album: " .. album)
	print_debug("album_mbid: " .. album_mbid)

	header = string.shellescape(string.htmlescape(artist))
	body = string.shellescape(string.htmlescape(title))
	params = ""

	image = fetch_musicbrainz_cover_art(artist, album, album_mbid)
	if image and string.len(image) > 1  then
		print("found cover art in " .. image)
		params = " -i "..string.shellescape(image)
	end

	if(string.len(header) < 1) then
		header = "Now playing:"
	end
	if(string.len(album) > 1) then
		body = string.shellescape(string.htmlescape(title)
			.."<br/><i>"..string.htmlescape(album).."</i>")
	end

	command = "notify-send -a mpv "..params.." -- "..header.." "..body
	print_debug("command: " .. command)
	os.execute(command)
end


-- insert main() here

mp.register_event("file-loaded", notify_current_track)
