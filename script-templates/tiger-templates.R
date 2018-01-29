template_header <- '
set TMPDIR=\\gisdata\\temp\\
set UNZIPTOOL="C:\\Program Files\\7-Zip\\7z.exe"
set WGETTOOL="C:\\Program Files (x86)\\GnuWin32\\bin\\wget.exe"
set PGBIN=C:\\Program Files\\PostgreSQL\\9.3\\bin\\
set PGPORT=5432
set PGHOST=localhost
set PGUSER=postgres
set PGPASSWORD=postgres
set PGDATABASE=postgres
set PSQL="%PGBIN%psql"
set SHP2PGSQL="%PGBIN%shp2pgsql"
'

tiger_template <- "
cd \\gisdata/ftp2.census.gov/geo/tiger/TIGER{{year}}/{{GEOGRAPHY}}
del %TMPDIR%\\*.* /Q
%PSQL% -c \"DROP SCHEMA IF EXISTS tiger_staging CASCADE;\"
%PSQL% -c \"CREATE SCHEMA tiger_staging;\"
%PSQL% -c \"DO language 'plpgsql' $$ BEGIN IF NOT EXISTS (SELECT * FROM information_schema.schemata WHERE schema_name = 'tiger_data' ) THEN CREATE SCHEMA tiger_data; END IF;  END $$\"
for /r %%z in (tl_*_{{fips}}*_{{geography}}.zip ) do %UNZIPTOOL% e %%z  -o%TMPDIR% 
cd %TMPDIR%
%PSQL% -c \"CREATE TABLE tiger_data.{{usps}}_{{geography}}(CONSTRAINT pk_{{usps}}_{{geography}} PRIMARY KEY ({{geography}}_id) ) INHERITS(tiger.{{geography}}); \" 
%SHP2PGSQL% -c -s 4269 -g the_geom   -W \"latin1\" tl_{{year}}_{{fips}}_{{geography}}.dbf tiger_staging.{{usps}}_{{geography}} | %PSQL%
%PSQL% -c \"ALTER TABLE tiger_staging.{{usps}}_{{geography}} RENAME geoid TO {{geography}}_id;  SELECT loader_load_staged_data(lower('{{usps}}_{{geography}}'), lower('{{usps}}_{{geography}}')); \"
%PSQL% -c \"CREATE INDEX tiger_data_{{usps}}_{{geography}}_the_geom_gist ON tiger_data.{{usps}}_{{geography}} USING gist(the_geom);\"
%PSQL% -c \"VACUUM ANALYZE tiger_data.{{usps}}_{{geography}};\"
%PSQL% -c \"ALTER TABLE tiger_data.{{usps}}_{{geography}} ADD CONSTRAINT chk_statefp CHECK (statefp = '{{fips}}');\"
"
