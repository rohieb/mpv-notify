mpv-notify
==========

Adds desktop notifications to the [mpv](http://mpv.io) media player, which show
metadata like artist, album name and track name when the track changes.

Features
--------

* shows artist, title and album name (as far as detected by mpv)
* tries to find load cover art in the same folder, or loads it from
	coverartarchive.org and caches it locally.

Requirements
------------

* [mpv](http://mpv.io) (>= 0.3.6)
* [Lua](http://lua.org) (>= 5.2)
* [lua-socket](http://w3.impa.br/~diego/software/luasocket/)
* `notify-send` from [libnotify](https://github.com/GNOME/libnotify)
* `convert` from [ImageMagick](http://www.imagemagick.org)

On recent Debians, do a `sudo apt-get install lua-socket libnotify-bin
imagemagick`

Installation
------------

Just drop `notify.lua` into the folder `~/.mpv/lua` (create it when neccessary),
and mpv will find it. Optionally, you can add it to mpv's command line:

    mpv --lua=/path/to/notify.lua <files and options>

License
-------

mpv-notify was written by Roland Hieber <rohieb at rohieb.name>, you can use it
under the terms of the [MIT license](http://choosealicense.com/licenses/mit/).
