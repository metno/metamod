#!/bin/sh
DBNAME=[==DATABASE_NAME==]
PSQL=[==PSQL==]
CREATEDB=[==CREATEDB==]
DROPDB=[==DROPDB==]
$DROPDB -U admin [==PG_CONNECTSTRING_SHELL==] $DBNAME
$CREATEDB -U admin [==PG_CONNECTSTRING_SHELL==] $DBNAME
echo "----------------- Database $DBNAME created ------------------"
$PSQL -a -U admin [==PG_CONNECTSTRING_SHELL==] -d $DBNAME <<EOF

CREATE TABLE DataSet (
   DS_id              SERIAL,
   DS_name            VARCHAR(9999) UNIQUE NOT NULL,
   DS_parent          INTEGER       NOT NULL,
   DS_status          INTEGER       NOT NULL,
   DS_datestamp       DATE          NOT NULL,
   DS_ownertag        VARCHAR(9999) NOT NULL,
   PRIMARY KEY (DS_id)
);
GRANT SELECT ON DataSet TO webuser;

CREATE TABLE SearchCategory (
   SC_id              INTEGER       NOT NULL,
   SC_type            INTEGER       NOT NULL,
   SC_fnc             VARCHAR(9999) NOT NULL,
   PRIMARY KEY (SC_id)
);
GRANT SELECT ON SearchCategory TO webuser;

CREATE TABLE HierarchicalKey (
   HK_id              SERIAL,
   HK_parent          INTEGER,
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   HK_level           INTEGER       NOT NULL,
   HK_name            VARCHAR(9999) NOT NULL,
   UNIQUE (SC_id, HK_parent, HK_name),
   PRIMARY KEY (HK_id)
);
GRANT SELECT ON HierarchicalKey TO webuser;

CREATE TABLE BasicKey (
   BK_id              SERIAL,
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   BK_name            VARCHAR(9999) NOT NULL,
   UNIQUE (SC_id, BK_name),
   PRIMARY KEY (BK_id)
);
GRANT SELECT ON BasicKey TO webuser;

CREATE TABLE HK_Represents_BK (
   HK_id              INTEGER       NOT NULL REFERENCES HierarchicalKey ON DELETE CASCADE,
   BK_id              INTEGER       NOT NULL REFERENCES BasicKey ON DELETE CASCADE,
   PRIMARY KEY (HK_id, BK_id)
);
GRANT SELECT ON HK_Represents_BK TO webuser;

CREATE TABLE BK_Describes_DS (
   BK_id              INTEGER       NOT NULL REFERENCES BasicKey ON DELETE CASCADE,
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PRIMARY KEY (BK_id, DS_id)
);
GRANT SELECT ON BK_Describes_DS TO webuser;

CREATE TABLE NumberItem (
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   NI_from            INTEGER       NOT NULL,
   NI_to              INTEGER       NOT NULL,
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PRIMARY KEY (SC_id, NI_from, NI_to, DS_id)
);
GRANT SELECT ON NumberItem TO webuser;

CREATE TABLE GeographicalArea (
   GA_id              SERIAL,
   GA_name            VARCHAR(9999),
   PRIMARY KEY (GA_id)
);
GRANT SELECT ON GeographicalArea TO webuser;

CREATE TABLE GA_Contains_GD (
   GA_id              INTEGER       NOT NULL REFERENCES GeographicalArea ON DELETE CASCADE,
   GD_id              VARCHAR(9999) NOT NULL,
   PRIMARY KEY (GA_id, GD_id)
);
GRANT SELECT ON GA_Contains_GD TO webuser;

CREATE TABLE GA_Describes_DS (
   GA_id              INTEGER       NOT NULL,
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PRIMARY KEY (GA_id, DS_id)
);
GRANT SELECT ON GA_Describes_DS TO webuser;

CREATE TABLE MetadataType (
   MT_name            VARCHAR(99),
   MT_share           BOOLEAN       NOT NULL,
   MT_def             VARCHAR(9999) NOT NULL,
   PRIMARY KEY (MT_name)
);
GRANT SELECT ON MetadataType TO webuser;

CREATE TABLE Metadata (
   MD_id              SERIAL,
   MT_name            VARCHAR(99)   NOT NULL REFERENCES MetadataType,
   MD_content         VARCHAR(99999) NOT NULL,
   PRIMARY KEY (MD_id)
);
GRANT SELECT ON Metadata TO webuser;

CREATE TABLE DS_Has_MD (
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   MD_id              INTEGER       NOT NULL REFERENCES Metadata ON DELETE CASCADE,
   PRIMARY KEY (DS_id, MD_id)
);
GRANT SELECT ON DS_Has_MD TO webuser;

CREATE TABLE Sessions (
   sessionid          VARCHAR(9999)NOT NULL,
   accesstime         VARCHAR(9999)NOT NULL,
   sessionstate       VARCHAR(99999) NOT NULL,
   PRIMARY KEY (sessionid)
);
GRANT ALL ON Sessions TO webuser;
\q
EOF
date +'%Y-%m-%d %H:%M Database re-initialized, dynamic tables created' >>[==LOGFILE==]
