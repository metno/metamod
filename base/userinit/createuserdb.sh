#!/bin/sh
DBNAME=[==USERBASE_NAME==]
PSQL=[==PSQL==]
CREATEDB=[==CREATEDB==]
DROPDB=[==DROPDB==]
$DROPDB -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] $DBNAME
$CREATEDB -E UTF-8 -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] $DBNAME
echo "----------------- Database $DBNAME created ------------------"

$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $DBNAME <<'EOF'

CREATE TABLE UserTable (
   u_id               SERIAL,
   a_id               VARCHAR(9999) NOT NULL,
   u_name             VARCHAR(9999),
   u_email            VARCHAR(9999) NOT NULL,
   u_loginname        VARCHAR(9999) NOT NULL,
   u_password         VARCHAR(9999),
   u_institution      VARCHAR(9999),
   u_telephone        VARCHAR(9999),
   u_session          VARCHAR(9999),
   UNIQUE (a_id, u_loginname),
   PRIMARY KEY (u_id)
);
GRANT ALL PRIVILEGES ON UserTable TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON UserTable_u_id_seq TO "[==PG_WEB_USER==]";

CREATE TABLE DataSet (
   ds_id              SERIAL,
   u_id               INTEGER       NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   a_id               VARCHAR(9999) NOT NULL,
   ds_name            VARCHAR(9999) NOT NULL,
   UNIQUE (a_id, ds_name),
   PRIMARY KEY (ds_id)
);
GRANT ALL PRIVILEGES ON DataSet TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON DataSet_ds_id_seq TO "[==PG_WEB_USER==]";

CREATE TABLE InfoDS (
   i_id               SERIAL,
   ds_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   i_type             VARCHAR(9999) NOT NULL,
   i_content          TEXT NOT NULL,
   PRIMARY KEY (ds_id, i_type)
);
GRANT ALL PRIVILEGES ON InfoDS TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON InfoDS_i_id_seq TO "[==PG_WEB_USER==]";

CREATE TABLE InfoUDS (
   i_id               SERIAL,
   u_id               INTEGER       NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   ds_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   i_type             VARCHAR(9999) NOT NULL,
   i_content          TEXT NOT NULL,
   PRIMARY KEY (i_id)
);
GRANT ALL PRIVILEGES ON InfoUDS TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON InfoUDS_i_id_seq TO "[==PG_WEB_USER==]";

CREATE TABLE File (
   ds_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   f_name             VARCHAR(9999) NOT NULL,
   f_timestamp        VARCHAR(9999),
   f_size             INTEGER,
   f_status           VARCHAR(9999),
   f_errurl           VARCHAR(9999),
   PRIMARY KEY (ds_id, f_name)
);
GRANT ALL PRIVILEGES ON File TO "[==PG_WEB_USER==]";

\q
EOF

date +'%Y-%m-%d %H:%M Userbase re-initialized, dynamic tables created' >>[==USERBASELOG==]
