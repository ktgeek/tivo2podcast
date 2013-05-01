begin;

pragma foreign_keys = on;

-- Remove some ancient old shit we don't need anymore.
delete from configs where config_name in ('alphas', 'glee', '30rock', 'decoded', 'fringe', 'lie', 'beavis', 'gl', 'revolution', 'booze');

-- Create the new tables
CREATE TABLE rss_files (
       id               INTEGER    PRIMARY KEY AUTOINCREMENT NOT NULL,
       filename         TEXT       UNIQUE NOT NULL,
       owner_name       TEXT,
       owner_email      TEXT,
       base_url         TEXT,
       link             TEXT,
       feed_title       TEXT,
       feed_description TEXT);

CREATE TABLE configs_rss_files (
       config_id INTEGER NOT NULL,
       rss_file_id INTEGER NOT NULL,
       foreign key(config_id) references configs(id) ON DELETE RESTRICT,
       foreign key(rss_file_id) references rss_files(id) ON DELETE RESTRICT
);
create index configs_rss_files_config_index on configs_rss_files(config_id);
create index configs_rss_files_rss_file_index on configs_rss_files(rss_file_id);

-- Build the new rss_file to simulate the aggregated feed
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('aggregated.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://example.com/', 'Aggregated Show Feed', 'This feed is a culmination of everything I wanted jammed into a single feed.  Deal with it.');

-- Take all items in the old config that were marked as aggregated and build an association
insert into configs_rss_files(config_id, rss_file_id) select c.id, r.id from configs c, rss_files r where c.aggregate=1 and r.filename='aggregated.xml';

-- Create new config table
CREATE TABLE new_configs(
       id                   INTEGER   PRIMARY KEY AUTOINCREMENT NOT NULL,
       config_name          TEXT      UNIQUE NOT NULL,
       show_name            TEXT      NOT NULL,
       ep_to_keep           INTEGER,
       encode_crop          TEXT,
       encode_audio_bitrate INTEGER,
       encode_video_bitrate INTEGER,
       encode_decomb        INTEGER,
       max_width            INTEGER,
       max_height           INTEGER
);

-- copy old config data minus the columns we're dropping into the new config table
insert into new_configs(id, config_name, show_name, ep_to_keep, encode_crop, encode_audio_bitrate, encode_video_bitrate, encode_decomb, max_width, max_height) select id, config_name, show_name, ep_to_keep, encode_crop, encode_audio_bitrate, encode_video_bitrate, encode_decomb, max_width, max_height from configs;

pragma foreign_keys = off;

-- Swap the config tables
drop table configs;
alter table new_configs rename to configs;

pragma foreign_keys = on;

-- Create the daily show feed and parings
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('tds.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://www.thedailyshow.com/', 'The Daily Show with John Stewart', 'The Best F#@king News Team');

insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where c.config_name='TheDailyShow' and r.filename='tds.xml';

-- Create the colbert report feed and parings
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('colbert.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://www.colbertnation.com/', 'The Colbert Report', 'An American for a Better Tomorrow, Tomorrow');

insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where c.config_name='colbert' and r.filename='colbert.xml';

-- Create a comedy central news feed and parings
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('ccnews.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://www.comedycentral.com', 'The Comedy Central News Shows', 'The Daily Show and The Colbert Report, together forever.');

insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where (c.config_name='colbert' OR c.config_name='TheDailyShow') and r.filename='ccnews.xml';

-- Create a pair of the walking and talking dead
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('dead.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://www.amctv.com/shows/the-walking-dead', 'The Walking/Talking Dead', 'The Walking Dead and its discussion show, The Talking Dead.');

insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where (c.config_name='wdead' OR c.config_name='tdead') and r.filename='dead.xml';

-- Create a Soup feed
insert into rss_files(filename, owner_name, owner_email, base_url, link, feed_title, feed_description) values ('soup.xml', 'Keith T. Garner', 'kgarner@kgarner.com', 'http://temp.kgarner.com/podcasts/', 'http://www.thesouptv.com/', 'The Soup', 'Soooooooooooo meaty!');

insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where c.config_name='soup' and r.filename='soup.xml';

-- Add Nerdist to the aggregate feed
insert into configs_rss_files(config_id, rss_file_id) select c.id,r.id from configs c, rss_files r where c.config_name='nerdist' and r.filename='aggregated.xml';
