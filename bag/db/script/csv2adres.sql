-- Maak apart schema aan voor CSV import en set deze als default
CREATE SCHEMA IF NOT EXISTS csv;
set schema 'csv';
SET search_path = csv, public;

-- Maak de tabel aan waar de CSV data in geimporteerd wordt. De database Character Type, Encoding en Collation instellingen worden gebruikt bij de import.
DROP TABLE IF EXISTS adres CASCADE;
CREATE TABLE adres (
  openbareruimtenaam character varying(80),
  huisnummer numeric(5,0),
  huisletter character varying(1),
  huisnummertoevoeging character varying(4),
  postcode character varying(6),
  woonplaatsnaam character varying(80),
  gemeentenaam character varying(80),
  provincienaam character varying(16),
  adresseerbaarobject numeric(16,0),
  typeadresseerbaarobject character varying(3),
  nevenadres BOOLEAN DEFAULT FALSE,
  rd_x character varying(80),
  rd_y character varying(80),
  lon character varying(80),
  lat character varying(80),
  geopunt geometry(PointZ, 28992),
  textsearchable_adres tsvector
);

-- Laad de data uit het CSV bestand in de tabel (BAG default is UTF8 formaat)
-- laat 'HEADER' weg als er geen header regel is met kolom namen.
\COPY adres(openbareruimtenaam,huisnummer,huisletter,huisnummertoevoeging,postcode,woonplaatsnaam,gemeentenaam,provincienaam,adresseerbaarobject,typeadresseerbaarobject,nevenadres,rd_x,rd_y,lon,lat) FROM 'D:\Data\bagadres-Groningen-Org.csv' DELIMITER ';' CSV HEADER;
-- Vervang lege strings door NULL waarden
UPDATE adres SET huisnummertoevoeging = NULL WHERE huisnummertoevoeging = '';
UPDATE adres SET huisletter = NULL WHERE huisletter = '';

-- Converteer RD_(x,y) van string naar nummeriek en vervang eerst , door .
ALTER TABLE adres
  ALTER COLUMN rd_x TYPE numeric(9,3) USING translate(rd_x, ',', '.')::numeric,
  ALTER COLUMN rd_y TYPE numeric(9,3) USING translate(rd_y, ',', '.')::numeric,
  ALTER COLUMN lon TYPE numeric(15,14) USING translate(lon, ',', '.')::numeric,
  ALTER COLUMN lat TYPE numeric(15,13) USING translate(lat, ',', '.')::numeric;

-- Kies 1 van de 2 geopunt UPDATE regels!
-- Populate the "geopunt" column with values from the "rd_x" and "rd_y" columns
UPDATE adres SET geopunt = public.ST_SetSRID(public.ST_MakePoint(rd_x::numeric,rd_y::numeric,0),28992);
-- Populate the "geopunt" column with values from the "lon" and "lat" columns and transform from WG84 to to RD
--UPDATE adres SET geopunt = ST_Transform(ST_SetSRID(ST_MakePoint(lon::numeric,lat::numeric,0),4326),28992);

-- Verwijder de geimporteerde coordinaten colommen
ALTER TABLE adres
  DROP COLUMN IF EXISTS rd_x CASCADE,
  DROP COLUMN IF EXISTS rd_y CASCADE,
  DROP COLUMN IF EXISTS lat CASCADE,
  DROP COLUMN IF EXISTS lon CASCADE;

-- Vul de text vector kolom voor full text search
UPDATE adres set textsearchable_adres = to_tsvector(openbareruimtenaam||' '||huisnummer||' '||trim(coalesce(huisletter,'')||' '||coalesce(huisnummertoevoeging,''))||' '||woonplaatsnaam);

-- Maak indexen aan (betere performance)
CREATE INDEX adres_geom_idx ON adres USING gist (geopunt);
CREATE INDEX adres_adreseerbaarobject ON adres USING btree (adresseerbaarobject);
CREATE INDEX adresvol_idx ON adres USING gin (textsearchable_adres);

-- Voeg unieke index toe
DROP SEQUENCE IF EXISTS adres_gid_seq CASCADE;
CREATE SEQUENCE adres_gid_seq;
ALTER TABLE adres ADD gid integer UNIQUE;
ALTER TABLE adres ALTER COLUMN gid SET DEFAULT NEXTVAL('adres_gid_seq');
UPDATE adres SET gid = NEXTVAL('adres_gid_seq');
ALTER TABLE adres ADD PRIMARY KEY (gid);
