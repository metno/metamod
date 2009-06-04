-- allow full-text search
GRANT SELECT ON pg_ts_cfg TO "[==PG_WEB_USER==]";
GRANT SELECT ON pg_ts_cfgmap TO "[==PG_WEB_USER==]";
GRANT SELECT ON pg_ts_parser TO "[==PG_WEB_USER==]";
GRANT SELECT ON pg_ts_dict TO "[==PG_WEB_USER==]";

alter table Metadata add column MD_content_vector tsvector;

# create the full text index
CREATE INDEX MD_content_vector_idx 
ON Metadata 
USING gist(MD_content_vector);

CREATE TRUSTED LANGUAGE plpgsql;

CREATE FUNCTION update_MD_content_fulltext() RETURNS trigger AS $$
    BEGIN
        -- Check that name is given (error on delete!)
        IF NEW.MT_name IS NULL THEN
            RAISE EXCEPTION 'MT_name cannot be null';
        END IF;

        -- add full-text vector information
        NEW.MD_content_vector := to_tsvector(NEW.MD_content);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_MD_content_fulltext BEFORE INSERT OR UPDATE ON Metadata
    FOR EACH ROW EXECUTE PROCEDURE update_MD_content_fulltext();
