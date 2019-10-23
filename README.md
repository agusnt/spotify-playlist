# Spotify Playlist Generator

A bash script that generate an Spotify Playlist of a genre (1st parameter) in
your account. The tracks selected are the top tracks of your follow artists.

Also I develop a mood playlist generator (depressed, sad, normal, happy, euphoric).

## Requirements

* nc
* jq
* curl

## How to use?

Example:

```bash
./spotify-playlist.sh jazz

./mood-playlist.sh normal
```

## Other stuff...

Yes, the token management is terrible.

I want to improve the mood playlist generator... when I have free time.