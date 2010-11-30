#!/bin/sh

COMMON="[==TARGET_DIRECTORY==]/init/common.sh"

if [ -e  $COMMON ]
then
    echo $COMMON found!
    . "$COMMON"
else
        echo "Library $COMMON not found."
        exit 1
fi

USERBASE_NAME=[==USERBASE_NAME==]
check "USERBASE_NAME"

$DROPDB -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] $USERBASE_NAME
$CREATEDB -E UTF-8 -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] $USERBASE_NAME
echo "----------------- Database $USERBASE_NAME created ------------------"

$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $USERBASE_NAME <<'EOF'

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
   u_id               INTEGER       NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   f_name             VARCHAR(9999) NOT NULL,
   f_timestamp        VARCHAR(9999),
   f_size             INTEGER,
   f_status           VARCHAR(9999),
   f_errurl           VARCHAR(9999),
   PRIMARY KEY (u_id, f_name)
);
GRANT ALL PRIVILEGES ON File TO "[==PG_WEB_USER==]";

\q
EOF
