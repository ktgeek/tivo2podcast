begin;

pragma foreign_keys = on;

-- Create new shows table, without boolean default, but changing it to not null
CREATE TABLE new_shows (
       id INTEGER PRIMARY KEY AUTOINCREMENT,
       configid TEXT NOT NULL,
       s_name TEXT,
       s_ep_title TEXT,
       s_ep_number TEXT,
       s_ep_description TEXT,
       s_ep_length INTEGER,
       s_ep_timecap INTEGER,
       filename TEXT UNIQUE,
       s_ep_programid TEXT,
       on_disk boolean NOT NULL,
       FOREIGN KEY(configid) REFERENCES configs(id)
);

insert into new_shows(id, configid, s_name, s_ep_title, s_ep_number, s_ep_description, s_ep_length, s_ep_timecap, filename, s_ep_programid, on_disk) select id, configid, s_name, s_ep_title, s_ep_number, s_ep_description, s_ep_length, s_ep_timecap, filename, s_ep_programid, on_disk from shows;

pragma foreign_keys = off;

drop table shows;
alter table new_shows rename to shows;

pragma foreign_keys = on;

CREATE INDEX shows_configid_index on shows(configid);
CREATE INDEX shows_programid_index on shows(s_ep_programid);


