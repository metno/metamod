-- allow full-text search
-- pg < 8.2
GRANT SELECT ON pg_ts_cfg TO "[==PG_WEB_USER==]"; 
GRANT SELECT ON pg_ts_cfgmap TO "[==PG_WEB_USER==]";
-- pg >= 8.3
GRANT SELECT ON pg_ts_config TO "[==PG_WEB_USER==]"; 
GRANT SELECT ON pg_ts_config_map TO "[==PG_WEB_USER==]";
-- all pg
GRANT SELECT ON pg_ts_parser TO "[==PG_WEB_USER==]";
GRANT SELECT ON pg_ts_dict TO "[==PG_WEB_USER==]";

alter table Metadata add column MD_content_vector tsvector;

-- create the full text index
DROP INDEX IF EXISTS MD_content_vector_idx;
CREATE INDEX MD_content_vector_idx 
ON Metadata 
USING gist(MD_content_vector);

-- create index for better performance
CREATE INDEX idx_ds_has_md_mdid ON ds_has_md(md_id);


DROP TRIGGER IF EXISTS update_MD_content_fulltext ON Metadata;
DROP FUNCTION IF EXISTS update_MD_content_fulltext();
DROP FUNCTION IF EXISTS to_mmDefault_tsvector(text);
DROP FUNCTION IF EXISTS to_mmDefault_tsquery(text);
DROP LANGUAGE IF EXISTS plpgsql;

CREATE TRUSTED LANGUAGE plpgsql;

CREATE FUNCTION to_mmDefault_tsvector(IN text) RETURNS tsvector AS $$
    BEGIN
        RETURN to_tsvector('[==PG_TSEARCH_LANGUAGE==]', $1);
    END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION to_mmDefault_tsquery(IN text) RETURNS tsquery AS $$
    BEGIN
        RETURN to_tsquery('[==PG_TSEARCH_LANGUAGE==]', $1);
    END;
$$ LANGUAGE plpgsql;

CREATE FUNCTION update_MD_content_fulltext() RETURNS trigger AS $$
    BEGIN
        -- Check that name is given (error on delete!)
        IF NEW.MT_name IS NULL THEN
            RAISE EXCEPTION 'MT_name cannot be null';
        END IF;

        -- add full-text vector information
        NEW.MD_content_vector := to_mmDefault_tsvector(NEW.MD_content);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_MD_content_fulltext BEFORE INSERT OR UPDATE ON Metadata
    FOR EACH ROW EXECUTE PROCEDURE update_MD_content_fulltext();


-- extension column to Dataset, uncoupled
CREATE TABLE ProjectionInfo (
   DS_id              INTEGER       UNIQUE NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   PI_content         TEXT
);
GRANT SELECT ON ProjectionInfo TO "[==PG_WEB_USER==]";

-- extension column to Dataset, uncoupled
CREATE TABLE WMSInfo (
   DS_id              INTEGER       UNIQUE NOT NULL REFERENCES DataSet ON DELETE CASCADE,
   WI_content         TEXT
);
GRANT SELECT ON WMSInfo TO "[==PG_WEB_USER==]";


