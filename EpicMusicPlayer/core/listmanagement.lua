local EpicMusicPlayer = LibStub("AceAddon-3.0"):GetAddon("EpicMusicPlayer")
local L = LibStub("AceLocale-3.0"):GetLocale("EpicMusicPlayer")

local playlists = {}

local listnames = {}
local searchlist = {} --serach result
playedhistory = {}
playedhistory[1]= {ListName = "Playedhistory"}
local historymax = 10
local historypointer = 2
local db
local currentPlaylistVersion = "3.1"

--convert playlist from versions before 3.1 to 3.1
local function ConvertPlaylist(list)
	if #list > 1 then 
		list[1].Album = list[2].Album
		list[1].Song = list[2].Song
		list[1].Name = list[2].Name
		list[1].Length = list[2].Length
		list[1].Artist = list[2].Artist
		table.remove(list,2)
	end
	list[1].PlaylistVersion = "3.1"
	return list
end

local function getCopy(song)
	return {
		["Album"] = song.Album,
		["Song"] = song.Song,
		["Name"] = song.Name,
		["Length"] = song.Length,
		["Artist"] =  song.Artist,
	}
end

function EpicMusicPlayer:AddSavedPlayList()
	local musicdir
	-- put the list that will be saved and lists that will not be saved in one list
	if EpicMusicPlayer_PlayList then
		for i, list in ipairs(EpicMusicPlayer_PlayList) do
			if list[1] and list[1].PlaylistVersion and list[1].PlaylistVersion < currentPlaylistVersion then
				EpicMusicPlayer:Debug("converting list",list[1].ListName)
				list = ConvertPlaylist(list)
			end
			playlists[#playlists +1] = list
			if list[1].MusicDir then
				musicdir = list[1].MusicDir
			end
		end
	end
	EpicMusicPlayer.musicdir = musicdir
end

-- check playlist - is there a playlist, with content ?
function EpicMusicPlayer:CheckPlayList()
	db = EpicMusicPlayer.db.profile
	
	EpicMusicPlayer:AddSavedPlayList()
	if (table.getn(playlists) < 1) then
		self:Print(L["Playlist not found."])
		--no playlist found, create dummy playlist
		playlists = {
	        { -- list 1
	            {
	                ["ListName"] = "Common",
					["PlaylistVersion"] = "buildin",
					["MusicDir"] = "",
	            }, -- [1]
	            {
	                ["Album"] = "", 
					["Song"] = "See howto.html in the EpicMusicPlayer folder.",
					["Name"] = "nix",
					["Length"] = 10, 
					["Artist"] = "Playlist not found.",
	            }, -- [3]
	        },
		}
	end	
	
	if not musicdir then 
		musicdir = "MyMusic\\"
		--self:Print("Musicdir not set. Setting to: <wowdir>\\MyMusic\\")
	end
	
	if db.list > #playlists then db.list = 1 end
	if db.song > #playlists[db.list] then db.song = 1 end
	EpicMusicPlayer.playlists = playlists
	EpicMusicPlayer:UpdateListnames()
	EpicMusicPlayer.musicdir = musicdir
	return musicdir;
end

function EpicMusicPlayer:AddSongToHistory(song, listIndex,songIndex)
	if not song then return end
	song.listIndex = listIndex
	song.songIndex = songIndex
	table.insert(playedhistory,song)
	if #playedhistory > historymax+1 then
		table.remove(playedhistory,2)
	end
	historypointer = #playedhistory
	--[[
	--historypointer = historypointer + 1
	--if historypointer > 
	if historypointer > 1 and historypointer <= historymax then 
		song.listIndex = listIndex
		song.songIndex = songIndex
		playedhistory[historypointer] = song
		EpicMusicPlayer:Debug("AddSongToHistory",listIndex,listIndex)
	else
		historypointer = 2
		song = getCopy(song)
		song.listIndex = listIndex
		song.songIndex = songIndex
		EpicMusicPlayer:Debug("AddSongToHistory reset",listIndex,listIndex)
		playedhistory[2] = song
		--EpicMusicPlayer:Debug("AddSongToHistory reset","pointer",historypointer)
	end	
	--]]
end

function EpicMusicPlayer:GetNextSongFromHistory()
	if historypointer < #playedhistory then
		historypointer = historypointer + 1
		local song = playedhistory[historypointer]
		if song then	
			return song, song.listIndex, song.songIndex
		end
	end
	return nil
end

function EpicMusicPlayer:GetLastSongFromHistory()
	historypointer = historypointer - 1
	if historypointer < 2 then historypointer = 2 end
	local song = playedhistory[historypointer]
	if song then	
		return song, song.listIndex, song.songIndex
	end
	return nil
end

function EpicMusicPlayer:GetLastSong(listIndex,songIndex, loopList)
	songIndex = songIndex -1
	EpicMusicPlayer:Debug("listIndex",listIndex," songIndex",songIndex)
	if songIndex < 1 then songIndex = 1 end
	local song = EpicMusicPlayer:GetSong(listIndex,songIndex)
	if song then
		return song, listIndex,songIndex
	else
		return EpicMusicPlayer:GetSong(1, 1), 1,1	
	end
end

------------------------------------------------------------------------------------------- 
--  retern the next song from given index
-------------------------------------------------------------------------------------------
function EpicMusicPlayer:GetNextSong(listIndex,songIndex, loopList)
	--EpicMusicPlayer:Debug("GetNext","listIndex=",listIndex,"songIndex=",songIndex,"#playlists=",#playlists)
	--EpicMusicPlayer:Debug("loopList", loopList)
	if not listIndex or listIndex > #playlists or listIndex < 1 then
		listIndex = 1
		songIndex = 1
	end
	if not songIndex or songIndex < 1 then 
		songIndex = 1
	else
		songIndex = songIndex + 1 -- we want the next song	
	end
	if loopList then -- try to stay on list
		local list = playlists[listIndex]
		if list and songIndex > #list then 
			songIndex = 1 
		end
	end
	
	--list could be emty check until a list with a valid song is found
	for i = 1, 2 do
		-- loop all lists starting at given listIndex
		for listi = listIndex, #playlists do
			--EpicMusicPlayer:Debug("GetNext loop=",i,"listi=",listi)
			
			if EpicMusicPlayer:GetSong(listi,songIndex) then
				--EpicMusicPlayer:Debug("GetNext: returning","listi=",listi,"songIndex=",songIndex)
				return EpicMusicPlayer:GetSong(listi, songIndex), listi,songIndex
			end
			
			local list = playlists[listi]
			local first = list[1] 
			if first and (first.ListName == db.badlist) then --skip badlist
				listi = listi + 1
				--list = playlists[listi]
			end
			songIndex = 1
		end
		listIndex = 1 -- check remainig lists
	end
	
	--all lists checked still not good oO
	self:Print(L["Playlist error oO Playlist maybe empty."]);
	
	--this will set the buildin playlist 
	self:CheckPlayList()
	return EpicMusicPlayer:GetSong(1, 1), 1,1	
end

-- newList list or Index
function EpicMusicPlayer:CopySong(newList, song)
	local newListIndex
	if type(newList) == "number" then
		newList, newListIndex = playlists[newList]
	end

	if newList then 
		if #newList < 2 and not newList[1].Song then
			--add song to the playlist name entry
			newList[1]["Album"] = song.Album
			newList[1]["Song"] = song.Song
			newList[1]["Name"] = song.Name
			newList[1]["Length"] = song.Length
			newList[1]["Artist"] =  song.Artist
		else
			table.insert(newList,getCopy(song))
		end
		EpicMusicPlayer:Print(string.format(L["Copied song %s to List %s."],song.Song,newList[1].ListName))
		EpicMusicPlayer:PlayListGuiUpdate()
		return true
	else
		EpicMusicPlayer:Print(L["List not found"])
		return false
	end
end

function EpicMusicPlayer:MoveSong(oldListIndex, newListIndex, songIndex)
    if(oldListIndex == newListIndex)then
		self:Print(L["Song is already in that list."])
		return false
	end
	local oldlist = playlists[oldListIndex]
	local newlist = playlists[newListIndex]
	if oldlist and newlist then 
		local song = oldlist[songIndex]
		if song then 
			--table.remove(oldlist,songIndex)
			EpicMusicPlayer:RemoveSong(oldListIndex, songIndex, false)
			table.insert(newlist,getCopy(song))
			if not silent then
				EpicMusicPlayer:PlayListGuiUpdate()
				self:Print(string.format(L["Moved song %s from list %s to list %s."],song.Song,oldlist[1].ListName,newlist[1].ListName))
				return true
			end
		end
	end
	EpicMusicPlayer:PlayListGuiUpdate()
	return true
end

function EpicMusicPlayer:RemoveSong(listIndex, songIndex, silent)
	local list = playlists[listIndex]
	if list then 
		local song = list[songIndex]
		if song then 
			if #list == 1 then
				list[1]["Album"] = nil
				list[1]["Song"] = nil
				list[1]["Name"] = nil
				list[1]["Length"] = nil
				list[1]["Artist"] = nil
			elseif songIndex == 1 and #list > 1 then
				list[2].ListName = list[1].ListName
				list[2].PlaylistVersion = list[1].PlaylistVersion
				list[2].PlaylistType = list[1].PlaylistType
				list[2].MusicDir = list[1].MusicDir
				table.remove(list,songIndex)
			else
				table.remove(list,songIndex)
			end
			if not silent and song.Song then
				self:Print(L["Removed song"].."\""..song.Song..
				"\" "..L["from list"].." \""..list[1].ListName.."\".")
				return true
			end
			EpicMusicPlayer:PlayListGuiUpdate()
		end
	end	
	return false
end

-- add playlist
function EpicMusicPlayer:AddPlayList(name, newlist, save)
    local foundindex = EpicMusicPlayer:GetListIndex(name)
	if(foundindex) then
		self:Print(string.format(L["Playlist %s already exists."],name))
		return false;
	end
	
	if not newlist then
		newlist = { 
			{
				["ListName"] = name,
				["PlaylistVersion"] = currentPlaylistVersion
			}, -- [1]
		} -- [1]
    else
		if newlist[1] and newlist[1].PlaylistVersion and newlist[1].PlaylistVersion < currentPlaylistVersion then
			EpicMusicPlayer:Debug("converting list",newlist[1].ListName)
			newlist = ConvertPlaylist(newlist)
		end
	end
	
	if save then
		if not EpicMusicPlayer_PlayList then
			EpicMusicPlayer_PlayList = {}
		end
		table.insert(EpicMusicPlayer_PlayList, newlist)
	end
	--lastsearch should be last list
	local lastsearch, listIndex = EpicMusicPlayer:GetListByName("lastsearch")
	if lastsearch then
		playlists[listIndex] = newlist -- replace searchlist with new list
		playlists[#playlists+1] = lastsearch --append searchlist at the end
	else
		table.insert(playlists, newlist)
	end
	
	self:Print(string.format(L["Added playlist %s."],name))
	self:UpdateListnames()
	EpicMusicPlayer:PlayListGuiUpdate(true)
	return true
end

function EpicMusicPlayer:GetRandomSong(listIndex)
	db.shuffleAll = true --for testing
	
	local listnumber = listIndex
	local songnumber = songIndex
	--shuffle over multipe playlist's
	if db.shuffleAll then
		--count number of songs in each list
		local totalsongs = 0
		for i, list in ipairs(playlists) do
			totalsongs = totalsongs + #list
		end
		--get a random song out of all songs
		songnumber = math.random(1, totalsongs)
		--EpicMusicPlayer:Debug("totalsongs:",totalsongs, "  songnumber:",songnumber)
		--find the list with the just selected song
		
		for i, list in ipairs(playlists) do
			if songnumber > #list then
				songnumber = songnumber - #list	
			else
				listnumber = i
				break
			end
		end
		if songnumber < 1 then songnumber = 1 end 
		--EpicMusicPlayer:Debug("totalsongs:",totalsongs, "  songnumber:",songnumber)
	else
		songIndex = math.random(1, #playlists[listnumber])
	end
	
	return EpicMusicPlayer:GetSong(listnumber, songnumber), listnumber, songnumber
end

-- return the index of the list with the given name or nil if not found
function EpicMusicPlayer:GetListIndex(name)
	for i, list in ipairs(playlists) do
		if(string.lower(list[1].ListName)==string.lower(name))then
			return i
		end
	end
	return nil
end

-- remove playlist 
function EpicMusicPlayer:RemovePlayList(name)
    
	if #playlists < 2 then
		self:Print(L["Last playlist can not be removed."])
		return
	end
	
	local list, listIndex = self:GetListByName(name)
	if not list then
		self:Print(string.format(L["Playlist %s not found."],name))
		return
	end
	
	if list[1] and (list[1].PlaylistType == "generated" or list[1].PlaylistType == "gamemusic") then 
		StaticPopupDialogs["EPICMUSICPLAYER_REMOVEPLAYLIST"] = {
			text = L["You can only remove playlists created ingame or with the playlist manager (not the playlist generator)!"],
			button1 = ACCEPT,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
		}
		StaticPopup_Show("EPICMUSICPLAYER_REMOVEPLAYLIST")
	else
		StaticPopupDialogs["EPICMUSICPLAYER_REMOVEPLAYLIST"] = {
			text = string.format(L["Really remove playlist %s?"],name),
			button1 = ACCEPT,
			button2 = CANCEL,
			timeout = 0,
			whileDead = true,
			hideOnEscape = true,
			OnAccept = function()
				Debug("accept")

				if(listIndex == self:GetCurrentListIndex())then
					self:Stop()
				end

				table.remove(playlists, listIndex)
				
				-- remove from saved list if present
				if EpicMusicPlayer_PlayList then 
					for i, list in ipairs(EpicMusicPlayer_PlayList) do
						if(string.lower(list[1].ListName)==string.lower(name))then
							table.remove(EpicMusicPlayer_PlayList, i)
						end
					end
				end
				
				self:Print(string.format(L["Playlist %s removed."],name))
				self:UpdateListnames()
				EpicMusicPlayer:PlayListGuiUpdate(true)
				
			end,
		}
		StaticPopup_Show("EPICMUSICPLAYER_REMOVEPLAYLIST")
	end
end

-- update the list with the listnames
function EpicMusicPlayer:UpdateListnames()
	listnames = {};
	for i, list in ipairs(playlists) do
		listnames[list[1].ListName] = list[1].ListName
	end
end

------------------------------------------------------------------------------
-- search functions
-------------------------------------------------------------------------------
local temp = {}
local function contains(source, patterns)
	if source then
		source = string.lower(source)
		--local found = false
		for k, v in pairs(patterns) do
			if not string.find(source, v) then
				return false
				--found = found and true
			end
		end
	end
	return true
end

function EpicMusicPlayer:Search(pattern)
	if not pattern or pattern == "" then
        --self.IsSearching = false
        return
    end
    
    pattern = strtrim(string.lower(pattern))
	temp = { strsplit(" ", pattern) }

    searchlist = {
       { 
			["ListName"] = "lastsearch",
			["PlaylistType"] = "generated",
       } -- [1]
    }

	for x, list in ipairs(playlists) do
		if(list[1].ListName ~= "lastsearch")then
			for i, song in ipairs(list) do
				if contains(song.Song, temp) or contains(song.Artist, temp) or contains(song.Album, temp) then
					if i == 1 then
						local song = getCopy(song)
						song.ListName = "lastsearch"
						song.PlaylistType = "generated"
						table.insert(searchlist, song)
					else
						table.insert(searchlist, song)
					end
				end
				if(#searchlist>500) then break end 
			end
		end
		if(#searchlist>500) then break end 
	end
	
	--update the lastsearch list
    local lastsearch = EpicMusicPlayer:GetListIndex("lastsearch")
	if(lastsearch)then
		playlists[lastsearch] = searchlist
		selectedlist = lastsearch --set selected list
	else
		table.insert(playlists, searchlist)
		selectedlist = #playlists --set selected list
	end
end

------------------------------------------------------------------------------
-- get song/list info functions
-------------------------------------------------------------------------------

function EpicMusicPlayer:GetListByIndex(index)
	return playlists[index]
end

function EpicMusicPlayer:GetListByName(name)
	for i, list in ipairs(playlists) do
		if(string.lower(list[1].ListName)==string.lower(name))then
			return list, i
		end
	end
end

function EpicMusicPlayer.GetListnames()
	return listnames
end

function EpicMusicPlayer:GetListName(index)
	local list = playlists[index]
	if list then
		return list[1].ListName
	end
end

function EpicMusicPlayer:IsListLocked(index)
	local list = playlists[index]
	if list and list[1] and list[1].PlaylistType ~= "generated" and list[1].PlaylistType ~= "gamemusic" then
		return false
	end
	return true
end

function EpicMusicPlayer:GetSong(listIndex, songIndex)
	if not songIndex or notlistIndex then
		--EpicMusicPlayer:Debug("listIndex or songIndex not vaild.",listIndex, songIndex)
		return nil
	end
	local list = playlists[listIndex]
	if list then
		local song = list[songIndex]
		if song and song.Name then 
			return song
		else
			--EpicMusicPlayer:Debug("song", songIndex,"not found in list", listIndex)
		end
	else
		--EpicMusicPlayer:Debug("list", listIndex ,"not found.")
	end
end
