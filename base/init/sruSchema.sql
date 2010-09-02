-- database schema for sru4jdbc from wmo.int

-- main schema

DROP SCHEMA sru CASCADE;
CREATE SCHEMA sru;

-- contacts
CREATE TABLE sru.meta_contact (
    id_contact      SERIAL,
    organization    TEXT, -- UPPER
    author          TEXT, -- UPPER
    PRIMARY KEY(id_contact)
);
GRANT SELECT ON sru.meta_contact TO "[==PG_WEB_USER==]";

-- main table
CREATE TABLE sru.products (
    id_product      SERIAL,
    dataset_name    TEXT,
    ownertag        TEXT, -- UPPER
    title           TEXT, -- UPPER
    abstract        TEXT, -- UPPER
    subject         TEXT, -- UPPER
    search_strings  TEXT, -- UPPER keywords space separated
    id_contact      INTEGER REFERENCES sru.meta_contact,
    beginDate       DATE,
    endDate         DATE,
    created         DATE, -- publicationDate
    updated         DATE, -- modificationDate
    -- bounds
    north           NUMERIC,
    south           NUMERIC,
    east            NUMERIC,
    west            NUMERIC,
    -- whole document
    metaxml         TEXT, -- with tags
    metatext        TEXT, -- without tags
    metatext_vector TSVECTOR, -- full-text vector

    PRIMARY KEY(id_product)
);
GRANT SELECT ON sru.products TO "[==PG_WEB_USER==]";

-- create the full text index
CREATE INDEX products_metatext_vector_idx ON sru.products USING gist(metatext_vector);

-- trigger function to fill fulltext index on sru.products
CREATE FUNCTION sru.update_metatext_fulltext() RETURNS trigger AS $$
    BEGIN
        -- Check that name is given (error on delete!)
        IF NEW.metatext IS NULL THEN
            RAISE EXCEPTION 'metatext cannot be null';
        END IF;

        -- add the full-text vector
        NEW.metatext_vector := to_tsvector('simple', NEW.metatext);
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_metatext_fulltext BEFORE INSERT OR UPDATE ON sru.products
    FOR EACH ROW EXECUTE PROCEDURE sru.update_metatext_fulltext();

