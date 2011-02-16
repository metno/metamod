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

CREATE TABLE InfoU (
   i_id               SERIAL,
   u_id               INTEGER       NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   i_type             VARCHAR(9999) NOT NULL,
   i_content          TEXT NOT NULL,
   PRIMARY KEY (i_id)
);
GRANT ALL PRIVILEGES ON InfoUDS TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON InfoU_i_id_seq TO "[==PG_WEB_USER==]";

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

CREATE TABLE funcmap (
        funcid SERIAL PRIMARY KEY,
        funcname       VARCHAR(255) NOT NULL,
        UNIQUE(funcname)
);

GRANT ALL PRIVILEGES ON funcmap TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON funcmap_funcid_seq TO "[==PG_WEB_USER==]";

CREATE TABLE job (
        jobid           SERIAL PRIMARY KEY,
        funcid          INT NOT NULL,
        arg             BYTEA,
        uniqkey         VARCHAR(255) NULL,
        insert_time     INTEGER,
        run_after       INTEGER NOT NULL,
        grabbed_until   INTEGER NOT NULL,
        priority        SMALLINT,
        coalesce        VARCHAR(255)
);

CREATE UNIQUE INDEX job_funcid_uniqkey ON job (funcid, uniqkey);
CREATE INDEX job_funcid_runafter ON job (funcid, run_after);
CREATE INDEX job_funcid_coalesce ON job (funcid, coalesce);

GRANT ALL PRIVILEGES ON job TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON job_jobid_seq TO "[==PG_WEB_USER==]";

CREATE TABLE note (
        jobid           BIGINT NOT NULL,
        notekey         VARCHAR(255),
        PRIMARY KEY (jobid, notekey),
        value           BYTEA
);

GRANT ALL PRIVILEGES ON note TO "[==PG_WEB_USER==]";

CREATE TABLE error (
        error_time      INTEGER NOT NULL,
        jobid           BIGINT NOT NULL,
        message         VARCHAR(255) NOT NULL,
        funcid          INT NOT NULL DEFAULT 0
);

GRANT ALL PRIVILEGES ON error TO "[==PG_WEB_USER==]";

CREATE INDEX error_funcid_errortime ON error (funcid, error_time);
CREATE INDEX error_time ON error (error_time);
CREATE INDEX error_jobid ON error (jobid);

CREATE TABLE exitstatus (
        jobid           BIGINT PRIMARY KEY NOT NULL,
        funcid          INT NOT NULL DEFAULT 0,
        status          SMALLINT,
        completion_time INTEGER,
        delete_after    INTEGER
);

CREATE INDEX exitstatus_funcid ON exitstatus (funcid);
CREATE INDEX exitstatus_deleteafter ON exitstatus (delete_after);

GRANT ALL PRIVILEGES ON exitstatus TO "[==PG_WEB_USER==]";

\q
EOF
