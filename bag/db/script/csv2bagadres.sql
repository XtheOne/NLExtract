# Create the table to import the data to. Note that the default storage engine, character set and collation will be used
CREATE TABLE bagadres (
  object_id BIGINT(16) NOT NULL,
  openbareruimte VARCHAR(80) DEFAULT NULL,
  huisnummer INT(5) DEFAULT NULL,
  huisletter CHAR(1) DEFAULT NULL,
  huisnummertoevoeging VARCHAR(4) DEFAULT NULL,
  postcode CHAR(6) DEFAULT NULL,
  woonplaats VARCHAR(80) DEFAULT NULL,
  gemeente VARCHAR(80) DEFAULT NULL,
  provincie VARCHAR(16) DEFAULT NULL,
  object_type CHAR(3) NOT NULL DEFAULT '',
  nevenadres VARCHAR(1) DEFAULT NULL,
  x DECIMAL(9,3) DEFAULT NULL,
  y DECIMAL(9,3) DEFAULT NULL,
  lon DECIMAL(10,8) NOT NULL,
  lat DECIMAL(11,8) NOT NULL,
  point POINT DEFAULT NULL
);

# Load the data from the CSV file into the table
LOAD DATA LOCAL INFILE '/absolute/path/to/your/file/bagadres.csv'
INTO TABLE bagadres
FIELDS TERMINATED by ';'
LINES TERMINATED BY '\n'
IGNORE 1 LINES;

# MySQL uses 0 and 1 to represent BOOLEAN values
UPDATE bagadres SET nevenadres = 0 WHERE nevenadres = 'f';
UPDATE bagadres SET nevenadres = 1 WHERE nevenadres = 't';
ALTER TABLE bagadres CHANGE nevenadres nevenadres BOOLEAN NOT NULL;

# Replace empty strings with NULL values
UPDATE bagadres SET huisnummertoevoeging = NULL WHERE huisnummertoevoeging = '';
UPDATE bagadres SET huisletter = NULL WHERE huisletter = '';

# Populate the "point" column with values from the "lat" and "lon" columns
UPDATE bagadres SET point = POINT(lat, lon);

# To increase performance of searching, some indices might be useful
ALTER TABLE bagadres ADD INDEX (postcode);
ALTER TABLE bagadres ADD INDEX (object_id);
#ALTER TABLE bagadres ADD UNIQUE INDEX (object_id); #Adding a unique index fails due to a duplicate object_id "363010000785105"...