#!/bin/bash

if [ $# != 1 ]
then
	echo "You must supply the config dir as a parameter"
	exit 1
fi

if [ ! -r $1 ]
then
	echo "Cannot read the file "$1
	exit 1
fi

# Load the configuration dynamically
SCRIPT_PATH="`dirname \"$0\"`"
source <(perl "$SCRIPT_PATH/../../common/scripts/gen_bash_conf.pl" "$1/master_config.txt")

COMMON="$SCRIPT_PATH/common.sh"

if [ -e  $COMMON ]
then
    echo $COMMON found!
    . "$COMMON"
else
        echo "Library $COMMON not found."
        exit 1
fi

SRUSCHEMA="$SCRIPT_PATH/sruSchema.sql"

check "PG_TSEARCH2_SCRIPT" 1
check "PG_POSTGIS_SCRIPT" 1
check "PG_POSTGIS_SYSREF_SCRIPT" 1
check "SRUSCHEMA" 1

# create DB
$DROPDB -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL $DBNAME
$CREATEDB -E UTF-8 -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL $DBNAME
echo "----------------- Database $DBNAME created ------------------"

echo "----------------- Allow PLSQL ------------------"
$PSQL -a -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME <<'EOF'
-- allow plpgsql
CREATE TRUSTED LANGUAGE plpgsql;
EOF

# install additional features
echo "----------- Trying to install Fulltext-search: tsearch2.sql --"
$PSQL -q -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME < $PG_TSEARCH2_SCRIPT
echo "----------------- Database Fulltext-search prepared ---------"
echo "----------- Trying to install PostGIS ---------------------"
$PSQL -q -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME < $PG_POSTGIS_SCRIPT
echo "----------- Trying to install PostGIS Coordinate systems ---------------------"
$PSQL -q -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME < $PG_POSTGIS_SYSREF_SCRIPT
echo "----------- Trying to install PostGIS Additional Coordinate systems ---------------------"
# this may be blank
$PSQL -a -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME <<EOT
$PG_POSTGIS_ADDITIONAL_SYSREF
EOT

# start creating tables and functions
#
$PSQL -a -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME <<EOF

-- drop eventuelly existing stuff
DROP TRIGGER IF EXISTS update_MD_content_fulltext ON Metadata;
DROP FUNCTION IF EXISTS update_MD_content_fulltext();
DROP FUNCTION IF EXISTS to_mmDefault_tsvector(text);
DROP FUNCTION IF EXISTS to_mmDefault_tsquery(text);
DROP LANGUAGE IF EXISTS plpgsql;

-- allow full-text search
-- pg < 8.2
GRANT SELECT ON pg_ts_cfg TO $PG_WEB_USER;
GRANT SELECT ON pg_ts_cfgmap TO $PG_WEB_USER;
-- pg >= 8.3
GRANT SELECT ON pg_ts_config TO $PG_WEB_USER;
GRANT SELECT ON pg_ts_config_map TO $PG_WEB_USER;
-- all pg
GRANT SELECT ON pg_ts_parser TO $PG_WEB_USER;
GRANT SELECT ON pg_ts_dict TO $PG_WEB_USER;

-- allow postgis
GRANT ALL ON geometry_columns TO $PG_WEB_USER;
GRANT SELECT ON spatial_ref_sys TO $PG_WEB_USER;

CREATE TABLE DataSet (
   DS_id              SERIAL,
   DS_name            VARCHAR(9999) UNIQUE NOT NULL,
   DS_parent          INTEGER       NOT NULL,
   DS_status          INTEGER       NOT NULL,
   DS_datestamp       TIMESTAMP     NOT NULL,
   DS_ownertag        VARCHAR(9999) NOT NULL,
   DS_creationDate    TIMESTAMP     NOT NULL,
   DS_metadataFormat  VARCHAR(128),
   DS_filePath        VARCHAR(1024),
   PRIMARY KEY (DS_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON DataSet TO $PG_WEB_USER;

-- extension column to Dataset, uncoupled
CREATE TABLE ProjectionInfo (
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PI_content         TEXT,
   UNIQUE (DS_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON ProjectionInfo TO $PG_WEB_USER;

-- extension column to Dataset, uncoupled
CREATE TABLE WMSInfo (
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   WI_content         TEXT,
   UNIQUE (DS_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON WMSInfo TO $PG_WEB_USER;

-- extension column to Dataset, uncoupled
CREATE TABLE OAIInfo (
   -- soft REFERENCE to DataSet, should not be deleted with dataset
   DS_id              INTEGER       UNIQUE NOT NULL,
   OAI_identifier     TEXT          UNIQUE
);
GRANT SELECT, INSERT, UPDATE, DELETE ON OAIInfo TO $PG_WEB_USER;

CREATE TABLE SearchCategory (
   SC_id              INTEGER       NOT NULL,
   SC_idname          VARCHAR(32)   UNIQUE NOT NULL,
   SC_type            VARCHAR(32)   NOT NULL,
   SC_fnc             VARCHAR(9999) NOT NULL,
   PRIMARY KEY (SC_id)
);
GRANT SELECT ON SearchCategory TO $PG_WEB_USER;

CREATE TABLE HierarchicalKey (
   HK_id              SERIAL,
   HK_parent          INTEGER,
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   HK_level           INTEGER       NOT NULL,
   HK_name            VARCHAR(9999) NOT NULL,
   UNIQUE (SC_id, HK_parent, HK_name),
   PRIMARY KEY (HK_id)
);
GRANT SELECT ON HierarchicalKey TO $PG_WEB_USER;

CREATE TABLE BasicKey (
   BK_id              SERIAL,
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   BK_name            VARCHAR(9999) NOT NULL,
   UNIQUE (SC_id, BK_name),
   PRIMARY KEY (BK_id)
);
GRANT SELECT ON BasicKey TO $PG_WEB_USER;

CREATE TABLE HK_Represents_BK (
   HK_id              INTEGER       NOT NULL REFERENCES HierarchicalKey ON DELETE CASCADE,
   BK_id              INTEGER       NOT NULL REFERENCES BasicKey ON DELETE CASCADE,
   PRIMARY KEY (HK_id, BK_id)
);
GRANT SELECT ON HK_Represents_BK TO $PG_WEB_USER;

CREATE TABLE BK_Describes_DS (
   BK_id              INTEGER       NOT NULL REFERENCES BasicKey ON DELETE CASCADE,
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PRIMARY KEY (BK_id, DS_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON BK_Describes_DS TO $PG_WEB_USER;

CREATE TABLE NumberItem (
   SC_id              INTEGER       NOT NULL REFERENCES SearchCategory ON DELETE CASCADE,
   NI_from            INTEGER       NOT NULL,
   NI_to              INTEGER       NOT NULL,
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PRIMARY KEY (SC_id, NI_from, NI_to, DS_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON NumberItem TO $PG_WEB_USER;

CREATE TABLE MetadataType (
   MT_name            VARCHAR(99),
   MT_share           BOOLEAN       NOT NULL,
   MT_def             VARCHAR(9999) NOT NULL,
   PRIMARY KEY (MT_name)
);
GRANT SELECT ON MetadataType TO $PG_WEB_USER;

CREATE TABLE Metadata (
   MD_id              SERIAL,
   MT_name            VARCHAR(99)   NOT NULL REFERENCES MetadataType,
   MD_content         VARCHAR(99999) NOT NULL,
   MD_content_vector  TSVECTOR, -- full-text vector
   PRIMARY KEY (MD_id)
);
GRANT SELECT, INSERT, UPDATE, DELETE ON Metadata TO $PG_WEB_USER;

-- create the full text index
CREATE INDEX MD_content_vector_idx
ON Metadata
USING gist(MD_content_vector);

CREATE FUNCTION to_mmDefault_tsvector(IN text) RETURNS tsvector AS \$\$
    BEGIN
        RETURN to_tsvector('$PG_TSEARCH_LANGUAGE', \$1);
    END;
\$\$ LANGUAGE plpgsql;

-- do not use this function, postgres will need to see the language, to determine index use
CREATE FUNCTION to_mmDefault_tsquery(IN text) RETURNS tsquery AS \$\$
    BEGIN
        RETURN to_tsquery('$PG_TSEARCH_LANGUAGE', \$1);
    END;
\$\$ LANGUAGE plpgsql;

CREATE FUNCTION update_MD_content_fulltext() RETURNS trigger AS \$\$
    BEGIN
        -- Check that name is given (error on delete!)
        IF NEW.MT_name IS NULL THEN
            RAISE EXCEPTION 'MT_name cannot be null';
        END IF;

        -- add the full-text vector
        NEW.MD_content_vector := to_mmDefault_tsvector(NEW.MD_content);
        RETURN NEW;
    END;
\$\$ LANGUAGE plpgsql;

CREATE TRIGGER update_MD_content_fulltext BEFORE INSERT OR UPDATE ON Metadata
    FOR EACH ROW EXECUTE PROCEDURE update_MD_content_fulltext();

CREATE TABLE DS_Has_MD (
   DS_id              INTEGER       NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   MD_id              INTEGER       NOT NULL REFERENCES Metadata ON DELETE CASCADE,
   PRIMARY KEY (DS_id, MD_id)
);
-- search on ds_has_md is most often executed query
-- table may fit completely in memory, so consider 'set random_page_cost = 2 (or even 1.5)' see postgresql.conf
CREATE INDEX idx_ds_has_md_mdid ON ds_has_md(md_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON DS_Has_MD TO $PG_WEB_USER;
CREATE TABLE Dataset_Location (DS_id INTEGER NOT NULL REFERENCES DataSet ON DELETE CASCADE) WITHOUT OIDS;
GRANT ALL ON Dataset_Location TO $PG_WEB_USER;

CREATE TABLE HarvestStatus (
   HS_application     VARCHAR(99)    NOT NULL,
   HS_url             VARCHAR(99999) NOT NULL,
   HS_time            TIMESTAMP      NOT NULL
);

\q
EOF

echo "----------------- ADD GEOMETRY COLUMNS FOR EACH COORD-SYSTEM -----------"
for i in $SRID_ID_COLUMNS; do
$PSQL -a -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME <<EOF
SELECT AddGeometryColumn('public', 'dataset_location', 'geom_$i', $i, 'GEOMETRY', 2);
CREATE INDEX Idx_Dataset_Location_geom_$i ON Dataset_Location USING GIST (geom_$i);
EOF
done

echo "----------------- ADDING SRU2JDBC SUPPORT -----------"
$PSQL -a --set PG_WEB_USER=$PG_WEB_USER -U $PG_ADMIN_USER $PG_CONNECTSTRING_SHELL -d $DBNAME < $SRUSCHEMA


date +'%Y-%m-%d %H:%M Database re-initialized, dynamic tables created'
