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
    # Parameters:
    #   [1] : Music genre
    #
    # Return: string with the songs ID
    #
    allsongs=""

    # Test that the artist file exists
    if [ ! -f $fartists ]; then 
        >&2 echo "Generate Artist list first (-artist)"
        exit
    fi

    # Get all artist of a giving music genre
    for i in $(cat $fartists | grep $1 | awk -F '\" ' '{print $3}')
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
    #   [1] : Name of the genre
    #

    playlistid=$(createPlayListAPI $1 2>/dev/null)

    # Get top tracks
    topTracks $1 > .tracks.tmp

    # Get size of the file
    size=$(du -k .tracks.tmp | cut -f1)
    while [ $size -ne 0 ]; do
        # Get the first 100 songs
        songs=$(cat .tracks.tmp | head -n 100 | tr '\n' ',')
        # Remove the first 100 songs
        sed -i '1,100d' .tracks.tmp
        # Add tracks
        addTrack $playlistid $songs 2>/dev/null
        # Get new size
        size=$(du -k .tracks.tmp | cut -f1)
    done

    rm .tracks.tmp

}

###### Main

echo "OK" | nc -l -p 8080 > /dev/null 2>&1 &
# Generate token
echo "Open on browser and copy access_token parameter (https://accounts.spotify.com/authorize?client_id=b8b2063f8ca24e82844384f43f54d3cd&redirect_uri=http://127.0.0.1:8080&scope=playlist-modify-public%20playlist-modify-private%20user-follow-read&response_type=token&state=123)"
read -p "access_token parameter: " token
echo $token

generateArtists
createPlayList $1
rm $fartists
