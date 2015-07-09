begin;

pragma foreign_keys = on;

-- Create new configs table dropping all the video config columns and
-- adding a Handbreak preset column
CREATE TABLE new_configs (
       id                   INTEGER   PRIMARY KEY AUTOINCREMENT NOT NULL,
       config_name          TEXT      UNIQUE NOT NULL,
       show_name            TEXT      NOT NULL,
       ep_to_keep           INTEGER,
       handbrake_preset	    TEXT
);

insert into new_configs(id, config_name, show_name, ep_to_keep) select id, config_name, show_name, ep_to_keep) from configs;

pragma foreign_keys = off;

drop table configs;
alter table new_configs rename to configs;

pragma foreign_keys = on;


