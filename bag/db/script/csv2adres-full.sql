-- Maak apart schema aan voor CSV import en set deze als default
CREATE SCHEMA IF NOT EXISTS csv;
set schema 'csv';
SET search_path = csv, public;

-- Maak de tabel aan waar de CSV data in geimporteerd wordt. De database Character Type, Encoding en Collation instellingen worden gebruikt bij de import.
DROP TABLE IF EXISTS adres_full CASCADE;
CREATE TABLE adres_full (
  openbareruimtenaam character varying(80),
  huisnummer numeric(5,0),
  huisletter character varying(1),
  huisnummertoevoeging character varying(4),
  postcode character varying(6),
  woonplaatsnaam character varying(80),
  gemeentenaam character varying(80),
  provincienaam character varying(16),
  -- 7311SZ 264 len = 178
  verblijfsobjectgebruiksdoel character varying,
  oppervlakteverblijfsobject numeric(6,0) DEFAULT 0,
  verblijfsobjectstatus character varying,
  typeadresseerbaarobject character varying(3),
  adresseerbaarobject numeric(16,0),
  pandid numeric(16,0),
  pandstatus character varying,
  pandbouwjaar numeric(4,0),
  nummeraanduiding numeric(16,0),
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
\COPY adres_full(openbareruimtenaam,huisnummer,huisletter,huisnummertoevoeging,postcode,woonplaatsnaam,gemeentenaam,provincienaam,nummeraanduiding,verblijfsobjectgebruiksdoel,oppervlakteverblijfsobject,verblijfsobjectstatus,adresseerbaarobject,typeadresseerbaarobject,nevenadres,pandid,pandstatus,pandbouwjaar,rd_x,rd_y,lon,lat) FROM 'D:\Data\bagadres-Full-Groningen.csv' DELIMITER ';' CSV HEADER;
-- Vervang lege strings door NULL waarden
UPDATE adres_full SET huisnummertoevoeging = NULL WHERE huisnummertoevoeging = '';
UPDATE adres_full SET huisletter = NULL WHERE huisletter = '';

-- Converteer RD_(x,y) van string naar nummeriek en vervang eerst , door .
ALTER TABLE adres_full
  ALTER COLUMN rd_x TYPE numeric(9,3) USING translate(rd_x, ',', '.')::numeric,
  ALTER COLUMN rd_y TYPE numeric(9,3) USING translate(rd_y, ',', '.')::numeric,
  ALTER COLUMN lon TYPE numeric(15,14) USING translate(lon, ',', '.')::numeric,
  ALTER COLUMN lat TYPE numeric(15,13) USING translate(lat, ',', '.')::numeric;

-- Kies 1 van de 2 geopunt UPDATE regels!
-- Populate the "geopunt" column with values from the "rd_x" and "rd_y" columns
UPDATE adres_full SET geopunt = public.ST_SetSRID(public.ST_MakePoint(rd_x::numeric,rd_y::numeric,0),28992);
-- Populate the "geopunt" column with values from the "lon" and "lat" columns and transform from WG84 to to RD
--UPDATE adres_full SET geopunt = ST_Transform(ST_SetSRID(ST_MakePoint(lon::numeric,lat::numeric,0),4326),28992);

-- Verwijder de geimporteerde coordinaten colommen
ALTER TABLE adres_full
  DROP COLUMN IF EXISTS rd_x CASCADE,
  DROP COLUMN IF EXISTS rd_y CASCADE,
  DROP COLUMN IF EXISTS lat CASCADE,
  DROP COLUMN IF EXISTS lon CASCADE;

-- Vul de text vector kolom voor full text search
UPDATE adres_full set textsearchable_adres = to_tsvector(openbareruimtenaam||' '||huisnummer||' '||trim(coalesce(huisletter,'')||' '||coalesce(huisnummertoevoeging,''))||' '||woonplaatsnaam);

-- Maak indexen aan (betere performance)
CREATE INDEX adres_full_geom_idx ON adres_full USING gist (geopunt);
CREATE INDEX adres_full_adreseerbaarobject ON adres_full USING btree (adresseerbaarobject);
CREATE INDEX adres_full_nummeraanduiding ON adres_full USING btree (nummeraanduiding);
CREATE INDEX adres_full_pandid ON adres_full USING btree (pandid);
CREATE INDEX adres_full_idx ON adres_full USING gin (textsearchable_adres);

-- Voeg unieke index toe
DROP SEQUENCE IF EXISTS adres_full_gid_seq;
CREATE SEQUENCE adres_full_gid_seq;
ALTER TABLE adres_full ADD gid integer UNIQUE;
ALTER TABLE adres_full ALTER COLUMN gid SET DEFAULT NEXTVAL('adres_full_gid_seq');
UPDATE adres_full SET gid = NEXTVAL('adres_full_gid_seq');
ALTER TABLE adres_full ADD PRIMARY KEY (gid);
