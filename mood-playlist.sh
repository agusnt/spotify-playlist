#!/bin/bash

#
# Create Spotify playlist of a given genre.
#
# Requirements: curl, jq and netcat.
#
# Parameters:
#   [1] : Name of the genre
#
# @DATE: 21/10/2019
# @AUTHOR: Navarro Torres, Agustin
#

###### Constants
token=""
client_id="b8b2063f8ca24e82844384f43f54d3cd"
fartists=".artists.info"
ftrack=".tracks.tmp"

###### Alias

###### Functions

### Generate artist file
function getArtistsUser() {
    #
    # Get followed artists
    #
    # Parameters:
    #   [1] : Last artist ID retrieved
    #   [2] : Maximum number of items to return (Max: 50)

    url="https://api.spotify.com/v1/me/following?type=artist&after=$1&limit=$2"
    ret="$(curl -X "GET" $url -H "Accept: application/json" -H \
        "Content-Type: application/json" -H "Authorization: Bearer $token")" 
    echo "$ret" 
}

function generateArtists() {
    #
    # Get all followed artists by a user.
    #

    echo -n "" > $fartists

    artists=$(getArtistsUser 0 50 2>/dev/null) 
    next=$(echo $artists | jq -r '.artists.cursors.after')

    while [ "$next" != "null" ]; do

        for row in $(echo $artists | jq -r '.artists.items[] | @base64'); do
            # Iterate over the return values and get the useful information
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }

            echo -n "\"$(_jq '.name')\" " >> $fartists
            echo -n "\"$(_jq '.genres[]' | tr '\n"' ' ')\" " >> $fartists
            echo "$(_jq '.id')" >> $fartists
        done

        # We can only get 50 artist as maximum (API limit)
        artists=$(getArtistsUser $next 50 2>/dev/null) 
        next=$(echo $artists | jq -r '.artists.cursors.after')
    done
}

### Get artists top track
function getTopTracks() {
    #
    # Get the Top Track artists song (for US).
    #
    # Parameters:
    #   [1] : Music genre
    #   [2] : Country id
    #

    url="https://api.spotify.com/v1/artists/$1/top-tracks?country=$2"
    ret="$(curl -X "GET" $url -H "Accept: application/json" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $token")"
    echo $ret
}

function topTracks() {
    #
    # Get the Top Track artists song (for US).
    #
    # Return: string with the songs ID
    #
    allsongs=""

    # Test that the artist file exists
    if [ ! -f $fartists ]; then 
        >&2 echo "Generate Artist list first (-artist)"
        exit
    fi

    # Get all artis
    for i in $(cat $fartists | awk -F '\" ' '{print $3}')
    do
        songs=$(getTopTracks $i "US" 2>/dev/null) 

        for row in $(echo $songs | jq -r '.tracks[] | @base64'); do
            # Iterate over the return values and get the useful information
            _jq() {
                echo ${row} | base64 --decode | jq -r ${1}
            }

            echo "$allsongs$(_jq '.uri')"
        done
    done

    echo "$allsongs"
}

### Playlist
function addTrack() {
    #
    # Add track to a playlist
    #
    # Parameters:
    #   [1] : Playlist id
    #   [2] : List of song uris
    #
    url="https://api.spotify.com/v1/playlists/$1/tracks?uris=$2"
    ret=$(curl -X "POST" $url -H "Accept: application/json" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $token")
    echo $ret
}

function createPlayListAPI() {
    #
    # Create a new Playlist (API)
    #
    # Parameters:
    #   [1] : Name of the genre
    #
    # Return : Playlist id
    #

    url="https://api.spotify.com/v1/me/playlists"
    dat="{\"name\":\"ASPG-$1\",\"description\":\"ASPG $1\",\"public\":false}"
    ret="$(curl -X "POST" $url --data "$dat" -H "Accept: application/json" \
        -H "Content-Type: application/json" -H "Authorization: Bearer $token")"

    echo $ret | jq -r ".id"
}

function createPlayList() {
    #
    # Create a new Playlist (API)
    #
    # Parameters:
    #   [1] : Mood
    #   [2] : High value of the mood
    #   [3] : Low value of the mood

    playlistid=$(createPlayListAPI $1 2>/dev/null)

    # Get top tracks
    topTracks > .tracks.tmp

    # Get size of the file
    size=$(du -k .tracks.tmp | cut -f1)
    while [ $size -ne 0 ]; do
        # Get the first 100 songs
        song=""
        songs=$(cat .tracks.tmp | head -n 100)
        for i in $songs; do
            ret=$(getMood $(echo $i | cut -d ':' -f3) 2>/dev/null)
            value=$(echo $ret | jq ".valence")
            if (( $(echo "$value > $3 && $value < $2" | bc -l) )); then
                song="$song$i,"
            fi
        done
        # Remove the first 100 songs
        sed -i '1,100d' .tracks.tmp
        # Add tracks
        addTrack $playlistid $song 2>/dev/null
        # Get new size
        size=$(du -k .tracks.tmp | cut -f1)
    done

    rm .tracks.tmp

}

function getMood() {
    #
    # Get mood of a song
    #
    # Parameters:
    #   [1] : ID of a song
    #

    url="https://api.spotify.com/v1/audio-features/$1"
    ret=$(curl -X "GET" $url -H "Accept: application/json" -H \
        "Content-Type: application/json" -H "Authorization: Bearer $token")

    echo $ret
}

function mood() {
    #
    # Return the id of the song is match with the mood.
    #
    # I have to establish the mood, at the moment I only use valance with the
    # following values: depressed (0.0-0.2), sad (0.0-0.4), normal (0.4-0.6),
    # happy (0.6-1.0), euphoric (0.8-1.0)
    #
    # Parameters:
    #   [1] : Mood

    if [ "$1" == "depressed" ]; then
        h=0.2
        l=0.0
    elif [ "$1" == "sad" ]; then
        h=0.4
        l=0.0
    elif [ "$1" == "normal" ]; then
        h=0.6
        l=0.4
    elif [ "$1" == "happy" ]; then
        h=0.8
        l=0.6
    elif [ "$1" == "euphoric" ]; then
        h=1.0
        l=0.8
    else 
        exit
    fi
    createPlayList $1 $h $l
}

###### Main

echo "OK" | nc -l -p 8080 > /dev/null 2>&1 &
# Generate token
echo "Open on browser and copy access_token parameter (https://accounts.spotify.com/authorize?client_id=b8b2063f8ca24e82844384f43f54d3cd&redirect_uri=http://127.0.0.1:8080&scope=playlist-modify-public%20playlist-modify-private%20user-follow-read&response_type=token&state=123)"
read -p "access_token parameter: " token

generateArtists
mood $1
rm $fartists
