# TiVo2Podcast collection

This is my package of two scripts I wrote up to download content from my TiVo to my linux box.

---

## TiVo2Disk

TiVo2Disk is a simple downloading application. It downloads the shows requested, and pipes them through
[tivolibre](https://github.com/fflewddur/tivolibre) (if installed) so you end with a useful mpg/ts file. By default it
will not give you the choice to download copy protected content.

---

## TiVo2Podcast

TiVo2Podcast is my attempt to pipeline downloading shows, transcoding them to be iPhone friendly, and then put them into
an podcast friendly RSS feed for easy loading and unloading into iTunes/iPhone/etc.

TiVo2Podcast requires:
 * [tivolibre](https://github.com/fflewddur/tivolibre)
 * [AtomicParsley](http://atomicparsley.sourceforge.net/)
 * [HandBrakeCLI](http://handbrake.fr/)

For commercial skipping you'll need:
 * [libmp4v2](https://github.com/sergiomb2/libmp4v2) which is used via an ffi call
 * [comskip](http://www.kaashoek.com/comskip/)

You'll want to copy doc/tivo2podcast.conf.sample to ~/.tivo2podcast.conf to make sure that TiVo2Podcast can find all the
helper applications and ini files it needs.

By default, the script will use dnnsd/ZeroConf/Bonjour to locate a TiVo on your network. This assumes you have all that
stuff set up correctly on your host computer. If this doesn't work, or you have multiple TiVos and you want to specify a
particular one, you can also pass the IP and/or hostname to your tivo to the script via the -t flag which bypasses using
dnssd, or the -n flag which looks for a TiVo with a specific name via dnssd. You can also specify the TiVo's address in
the tivo2podcast.conf file.  You don't need the dnnsd gem if you always configure the conf file or pass a -t.

You'll need to run TiVo2Podcast once to create the sqlite database that TiVo2Podcast uses to store its data. This
database is at ~/.tivo2podcast.db, but you can move it by defining the environmental variable TIVO2PODCASTDIR putting
the file in $TIVO2PODCASTDIR/.tivo2podcast.db

After the database is created, you can use the sqlite command line tool to open the database and edit the 'configs'
table to set up a show or use the rails-like console to create and save Config objects.

---

*This README needs to be updated greatly.*
