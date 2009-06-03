alter table Metadata add column MD_content_vector tsvector;

# create the full text index
CREATE INDEX MD_content_vector_idx 
ON Metadata 
USING gist(MD_content_vector);

CREATE FUNCTION update_MD_content_fulltext() RETURNS trigger AS $$
    BEGIN
        -- Check that name is given (error on delete!)
        IF NEW.MT_name IS NULL THEN
            RAISE EXCEPTION 'MT_name cannot be null';
        END IF;

        -- Remember who changed the payroll when
        NEW.MD_content_vector := to_tsvector(NEW.MD_content);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_MD_content_fulltext BEFORE INSERT OR UPDATE ON Metadata
    FOR EACH ROW EXECUTE PROCEDURE update_MD_content_fulltext();
