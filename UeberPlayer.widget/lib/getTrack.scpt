#!/usr/bin/osascript

--- -- ~ PRE-SETUP ~ -- ---

-- Global vars
global playingState, appName, trackName, artistName, albumName, artworkURL, artworkFilename, trackDuration, mypath, artExtension, plist_filepath

set spotifyInstalled to false
set playingState to false
set appName to ""
set trackName to ""
set artistName to ""
set albumName to ""
set artworkURL to ""
set artworkFilename to ""
set trackDuration to 0
set timeElapsed to 0
set musicError to false

set artExtension to ""

-- Setup `mypath`
try
  set mypath to POSIX path of (path to me)
  set AppleScript's text item delimiters to "/"
	set mypath to (mypath's text items 1 thru -2 as string) & "/"
	set AppleScript's text item delimiters to ""
on error e
  error "Couldn't set up mypath!" & e
end try

-- Use a .plist file to detect changes
set plist_filepath to (mypath & "currentTrack.plist" as string)

--- -- - MAIN ROUTINE - -- ---

-- Check if Spotify is installed
try
  tell application "Finder" to get application file id "com.spotify.client"
  set spotifyInstalled to true
on error
  set spotifyInstalled to false
end try

-- Get Spotify track data if playing
if spotifyInstalled then
  if application "Spotify" is running then
    tell application "Spotify"
      set appName to "Spotify"

      using terms from application "Music"
        if player state is playing then
          set playingState to true
        end if

        if playingState is true then
          set trackName to the name of current track
          set artistName to the artist of current track
          set albumName to the album of current track
          set artworkURL to the artwork url of current track
          set trackDuration to the (duration of current track) / 1000
          set timeElapsed to the player position

          set artExtension to ".jpg"
        end if  
      end using terms from
    end tell
  end if
end if

-- Get default Apple music app data if playing
if playingState is false and application "Music" is running then
  tell application "Music"
    set appName to "Music"

    if player state is playing then
      set playingState to true
      try
        set trackName to the name of current track
        set artistName to the artist of current track
        set albumName to the album of current track
        set artworkURL to ""
        set trackDuration to the duration of current track
        set timeElapsed to the player position

        if format of item 1 of artworks in current track is «class PNG » then
          set artExtension to ".png"
        else
          set artExtension to ".jpg"
        end if
      on error e
        set musicError to true
      end try
    end if
  end tell
end if

-- Get any other music data if playing
if playingState is false then
  set nowplaying_cli_out to do shell script (mypath & "/nowplaying-cli get title album artist duration elapsedTime artworkMIMEType playbackRate" as string)
  set nowplaying_cli_out to paragraphs of nowplaying_cli_out
  if (count of nowplaying_cli_out) is 7 then
    set playingState to item 7 of nowplaying_cli_out is "1"
    if playingState is true then
      set appName to "Other"

      set trackName to item 1 of nowplaying_cli_out
      set albumName to item 2 of nowplaying_cli_out
      set artistName to item 3 of nowplaying_cli_out
      set trackDuration to item 4 of nowplaying_cli_out
      set timeElapsed to item 5 of nowplaying_cli_out
      set artworkURL to ""
      if item 6 of nowplaying_cli_out is "image/png" then
        set artExtension to ".png"
      else
        set artExtension to ".jpg"
      end if
    end if
  end if
end if

set artworkFilename to generateArtFilename(albumName as string, trackName as string, artistName & artExtension as string)

-- Trigger extra changes if song changed
if playingState and my songChanged() then
  -- Setup local artwork filename and location
  set cache_file to (mypath & "cache/" & artworkFilename as string)

  -- Download artwork if necessary, touch it otherwise
  if my fileExists(cache_file) then
    set command to "touch \"./UeberPlayer.widget/cache/" & artworkFilename & "\""
    do shell script command
  else
    try
      if appName is "Spotify" then
        my extractSpotifyArt()
      else if appName is "Music" and not musicError then
        my extractMusicArt()
      else if appName is "Other" then
        my extractOtherArt()
      end if
    end try
  end if
end if

-- Return results
set retList to {playingState, appName, trackName, artistName, albumName, artworkURL, artworkFilename, trackDuration, timeElapsed, musicError}
set AppleScript's text item delimiters to " @@ "
set retStr to retList as string
set AppleScript's text item delimiters to ""
return retStr

--- -- - SUBROUTINES - -- ---

-- Function to determine if a song changed happened
on songChanged()
  tell application "System Events"
    try
      tell property list file plist_filepath
        if (value of property list item "album" is not albumName) or (value of property list item "artist" is not artistName)
          set value of property list item "album" to albumName
          set value of property list item "artist" to artistName
          return true
        else
          return false
        end if
      end tell
    on error e
      error e
    end try
  end tell
end songChanged

-- Simple function to return if a file exists or not
on fileExists(f)
  tell application "System Events"
    if exists file f then
      return true
    else
      return false
    end if
  end tell
end fileExists

on checkString(str)
  set charsToCheck to characters of str
  set retList to {}
  repeat with i from 1 to count charsToCheck
    if {charsToCheck's item i} is not in {" ", "\"", "/", ",", ":", "?"} then
      set retList's end to charsToCheck's item i
    end if
  end repeat
  return retList as string
end checkString

-- Generate a "safe" filename for cached artwork (no whitespace nor quotation marks)
on generateArtFilename(albumName, trackName, rest)
  set cleanAlbumName to my checkString(albumName)
  set cleanTrackName to my checkString(trackName)
  set cleanRest to my checkString(rest)
  set charsToCheck to characters of albumName
  if cleanAlbumName is not "" then
    return cleanAlbumName & " - " & cleanRest as string
  else
    return cleanTrackName & " - " & cleanRest as string
  end if
end generateArtFilename

-- Extract artwork file from Spotify
on extractSpotifyArt()
  set command to "curl " & artworkURL & " --create-dirs -o \"./UeberPlayer.widget/cache/" & artworkFilename & "\""
  try
    do shell script command
  end try
end extractSpotifyArt

-- Extract artwork from Apple Music
on extractMusicArt()
  tell application "Music" to tell artwork 1 of current track
    set srcBytes to raw data
  end tell

  -- Use alternate way of getting the path because the other one doesn't work for some reason?
  set myAltPath to POSIX path of (path to me)
	set AppleScript's text item delimiters to "/"
	set myAltPath to (myAltPath's text items 1 thru -3 as string) & "/"
	set AppleScript's text item delimiters to ""
  set myAltPath to (myAltPath as POSIX file) & "cache:" & artworkFilename as string

  set outFile to open for access file myAltPath with write permission
  set eof outFile to 0
  write srcBytes to outFile starting at eof
  close access outFile
end extractMusicArt

-- Extract artwork from other music apps
on extractOtherArt()
    do shell script "mkdir -p \"./UeberPlayer.widget/cache/\" && /usr/local/bin/nowplaying-cli get artworkData | base64 -d > \"./UeberPlayer.widget/cache/" & artworkFilename & "\""
end extractOtherArt