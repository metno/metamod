#!/bin/sh

# Script for upgrading userdatabase from METAMOD 2.6+ to 2.8.
# Will create new tables and encrypt all passwords < 40 chars.
# Should be safe to run repeatedly on same database w/o data loss
# (ignore all "xxx  already exists" error messages).

COMMON="[==TARGET_DIRECTORY==]/init/common.sh"

if [ -e  $COMMON ]
then
    . "$COMMON"
else
    echo "Library $COMMON not found."
    exit 1
fi

USERBASE_NAME=[==USERBASE_NAME==]
check "USERBASE_NAME"
PG_CRYPTO=[==PG_CONTRIB==]/pgcrypto.sql
check "PG_CRYPTO" 1

echo "----------------- Database $USERBASE_NAME created ------------------"

$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $USERBASE_NAME < $PG_CRYPTO

$PSQL -a -U [==PG_ADMIN_USER==] [==PG_CONNECTSTRING_SHELL==] -d $USERBASE_NAME <<'EOF'

-- let's assume all passwords less than 40 chars are plaintext and encrypt them

UPDATE usertable SET u_password = encode(digest(u_password, 'sha1'), 'hex') where length(u_password) < 40;

-- create the new tables needed for METAMOD 2.8

CREATE TABLE InfoU (
   i_id               SERIAL,
   u_id               INTEGER       NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   i_type             VARCHAR(9999) NOT NULL,
   i_content          TEXT NOT NULL,
   PRIMARY KEY (i_id)
);
GRANT ALL PRIVILEGES ON InfoU TO "[==PG_WEB_USER==]";
GRANT ALL PRIVILEGES ON InfoU_i_id_seq TO "[==PG_WEB_USER==]";

CREATE TABLE UserRole (
   u_id               INTEGER NOT NULL REFERENCES UserTable ON DELETE CASCADE,
   role               VARCHAR(15) NOT NULL,
   PRIMARY KEY (u_id, role)
);
GRANT ALL PRIVILEGES ON UserRole TO "[==PG_WEB_USER==]";

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
