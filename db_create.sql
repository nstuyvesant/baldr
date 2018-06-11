-- Meant to be run from PSQL:
-- $ psql -d postgres -f db_create.sql

-- Create user if doesn't exist
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT                       -- SELECT list can stay empty for this
      FROM   pg_catalog.pg_roles
      WHERE  rolname = 'postgres') THEN

      CREATE ROLE postgres LOGIN PASSWORD 'mysecret123';
   END IF;
END
$do$;

ALTER ROLE postgres SUPERUSER CREATE;

-- Forcefully disconnect anyone
SELECT pid, pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'vr' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS vr;

-- Create database
CREATE DATABASE vr
    WITH 
    OWNER = postgres
    ENCODING = 'UTF8'
    LC_COLLATE = 'en_US.UTF-8'
    LC_CTYPE = 'en_US.UTF-8'
    TABLESPACE = pg_default
    CONNECTION LIMIT = -1;

COMMENT ON DATABASE vr
    IS 'Value Realization';

-- Connect to vr database
\connect vr

CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Add tables

CREATE TABLE public.clouds (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    fqdn character varying(255) UNIQUE,
    email_recipients character varying(4000)
);

COMMENT ON COLUMN public.clouds.fqdn IS 'Fully-qualified domain name of the Perfecto cloud';
COMMENT ON COLUMN public.clouds.email_recipients IS 'Comma-separated list of email recipients for the report (typically Champion, VRC, BB, and DAs)';

CREATE TABLE public.snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cloud_id uuid NOT NULL REFERENCES clouds(id),
    snapshot_date date,
    success_last24h smallint,
    success_last7d smallint,
    success_last30d smallint,
    lab_issues bigint,
    orchestration_issues bigint,
    scripting_issues bigint,
    UNIQUE (cloud_id, snapshot_date)
);

COMMENT ON COLUMN public.snapshots.cloud_id IS 'Foreign key to cloud';
COMMENT ON COLUMN public.snapshots.success_last24h IS 'Success rate for last 24 hours expressed as an integer between 0 and 100 (not as decimal < 1)';
COMMENT ON COLUMN public.snapshots.success_last7d IS 'Success percentage over the last 7 days expressed as an integer from 0 to 100 (not as decimal < 1)';
COMMENT ON COLUMN public.snapshots.success_last30d IS 'Success percentage over the last 30 days expressed as an integer from 0 to 100 (not as decimal < 1)';
COMMENT ON COLUMN public.snapshots.lab_issues IS 'The number of script failures due to device or browser issues in the lab over the last 24 hours';
COMMENT ON COLUMN public.snapshots.orchestration_issues IS 'The number of script failures due to attempts to use the same device';
COMMENT ON COLUMN public.snapshots.scripting_issues IS 'The number of script failures due to a problem with the script or framework over the past 24 hours';

CREATE TABLE public.devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES snapshots(id),
    rank smallint DEFAULT 1 NOT NULL,
    model character varying(255) NOT NULL,
    os character varying(255) NOT NULL,
    device_id character varying(255) NOT NULL,
    errors_last7d bigint NOT NULL,
    UNIQUE (snapshot_id, rank)
);

COMMENT ON COLUMN public.devices.snapshot_id IS 'Foreign key to snapshot record';
COMMENT ON COLUMN public.devices.rank IS 'Report ranking of the importance of the problematic device';
COMMENT ON COLUMN public.devices.model IS 'Model of the device such as "iPhone X" (manufacturer not needed)';
COMMENT ON COLUMN public.devices.os IS 'Name of operating system and version number such as "iOS 11.3"';
COMMENT ON COLUMN public.devices.device_id IS 'The device ID such as the UUID of an Apple iOS device or the serial number of an Android device';
COMMENT ON COLUMN public.devices.errors_last7d IS 'The number of times the device has gone into error over the last 7 days';

CREATE TABLE public.recommendations (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES snapshots(id),
    rank smallint DEFAULT 1 NOT NULL,
    recommendation character varying(2000) NOT NULL,
    impact_percentage smallint DEFAULT 0 NOT NULL,
    impact_message character varying(2000),
    UNIQUE (snapshot_id, rank)
);

COMMENT ON COLUMN public.recommendations.snapshot_id IS 'Foreign key to snapshot record';
COMMENT ON COLUMN public.recommendations.rank IS 'Report ranking of the importance of the recommendation';
COMMENT ON COLUMN public.recommendations.recommendation IS 'Specific recommendation such as "Replace top 5 failing devices" or "Remediate TransferMoney test"';
COMMENT ON COLUMN public.recommendations.impact_percentage IS 'Percentage of improvement to success rate if the recommendation is implemented (use 0 to 100 rather than decimal < 1)';
COMMENT ON COLUMN public.recommendations.impact_message IS 'For recommendations that do not have a clear impact such as "Ensure tests use Digitalzoom API" (impact should equal 0 for those)';

CREATE TABLE public.tests (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES snapshots(id),
    rank smallint DEFAULT 1 NOT NULL,
    test_name character varying(4000) NOT NULL,
    age bigint NOT NULL,
    failures_last7d bigint NOT NULL,
    passes_last7d bigint NOT NULL,
    UNIQUE (snapshot_id, rank)
);

COMMENT ON COLUMN public.tests.snapshot_id IS 'Foreign key to snapshot record';
COMMENT ON COLUMN public.tests.rank IS 'Report ranking of the importance of the problematic test';
COMMENT ON COLUMN public.tests.test_name IS 'Name of the test having issues';
COMMENT ON COLUMN public.tests.age IS 'How many days Digitalzoom has known about this test (used to select out tests that are newly created)';
COMMENT ON COLUMN public.tests.failures_last7d IS 'Number of failures of the test for the last 7 days';
COMMENT ON COLUMN public.tests.passes_last7d IS 'The number of times the test has passed over the last 7 days';

-- Add indices

CREATE INDEX fki_clouds_fkey ON public.snapshots USING btree (cloud_id);
CREATE INDEX fki_devices_snapshots_fkey ON public.devices USING btree (snapshot_id);
CREATE INDEX fki_recommendations_snapshots_fkey ON public.recommendations USING btree (snapshot_id);
CREATE INDEX fki_tests_snapshots_fkey ON public.tests USING btree (snapshot_id);

-- Use stored procedures to interact with DB (never direct queries) - allows us to change schema without breaking things

-- Insert cloud record or update email recipients if one exists
CREATE OR REPLACE FUNCTION cloud_upsert(cloud_fqdn character varying(255), emails character varying(4000), OUT cloud_id uuid) AS $$
BEGIN
    INSERT INTO clouds(fqdn, email_recipients) VALUES (cloud_fqdn, emails)
        ON CONFLICT (fqdn) DO UPDATE SET email_recipients = emails
        RETURNING id INTO cloud_id;
END;
$$ LANGUAGE plpgsql;

-- Create snapshot or update if one exists
CREATE OR REPLACE FUNCTION snapshot_add(uuid, date, integer, integer, integer, integer, integer, integer, OUT snapshot_id uuid) AS $$
BEGIN
    INSERT INTO snapshots(cloud_id, snapshot_date, success_last24h, success_last7d, success_last30d, lab_issues, orchestration_issues, scripting_issues)
        VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            ON CONFLICT (cloud_id, snapshot_date)
                DO UPDATE SET success_last24h = $3, success_last7d = $4, success_last30d = $5, lab_issues = $6, orchestration_issues = $7, scripting_issues = $8
            RETURNING id INTO snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Add a device to the snapshot
CREATE OR REPLACE FUNCTION device_add(uuid, integer, character varying(255), character varying(255), character varying(255), integer, OUT devices_id uuid) AS $$
BEGIN
    INSERT INTO devices(snapshot_id, rank, model, os, device_id, errors_last7d) VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id INTO devices_id;
END;
$$ LANGUAGE plpgsql;

-- Add a test to the snapshot
CREATE OR REPLACE FUNCTION test_add(uuid, integer, character varying(4000), integer, integer, integer, OUT test_id uuid) AS $$
BEGIN
    INSERT INTO tests(snapshot_id, rank, test_name, age, failures_last7d, passes_last7d) VALUES ($1, $2, $3, $4, $5, $6)
        RETURNING id INTO test_id;
END;
$$ LANGUAGE plpgsql;

-- Add a recommendation to the snapshot
CREATE OR REPLACE FUNCTION recommendation_add(uuid, integer, character varying(2000), integer, character varying(2000), OUT recommendation_id uuid) AS $$
BEGIN
    INSERT INTO recommendations(snapshot_id, rank, recommendation, impact_percentage, impact_message) VALUES ($1, $2, $3, $4, $5);
END;
$$ LANGUAGE plpgsql;

-- Load test data dependencies
CREATE OR REPLACE FUNCTION populate_test_data(OUT done boolean) AS $$
DECLARE
    cloud_id uuid := cloud_upsert('acme.perfectomobile.com', 'nates@perfectomobile.com,ranb@perfectomobile.com');
    snapshot_id uuid := snapshot_add(cloud_id, '2018-06-10'::DATE, 37, 72, 55, 10, 20, 30);
BEGIN
    PERFORM device_add(snapshot_id, 1, 'iPhone-5S', 'iOS 9.2.1', '544cc6c6026af23c11f5ed6387df5d5f724f60fb', 494);
    PERFORM device_add(snapshot_id, 2, 'Galaxy S5', 'Android 5.0', 'B5DED881', 397);
    PERFORM device_add(snapshot_id, 3, 'Galaxy Note III', 'Android 4.4', '61F1BF00', 303);
    PERFORM device_add(snapshot_id, 4, 'Nexus 5', 'Android 5.0', '06B25936007418BB', 298);
    PERFORM device_add(snapshot_id, 5, 'iPhone-6', 'iOS 9.1', '8E1CBC7E90168A3A7CFDA2712A8C20DD15517F89', 147);
    PERFORM test_add(snapshot_id, 1, 'TransferMoney', 230, 75, 0);
    PERFORM test_add(snapshot_id, 2, 'FindBranch', 200, 71, 3);
    PERFORM test_add(snapshot_id, 3, 'HonkHorn', 4, 68, 13);
    PERFORM test_add(snapshot_id, 4, 'InsuranceSearch', 47, 7, 0);
    PERFORM test_add(snapshot_id, 5, 'RemoteStart', 132, 41, 25);
    PERFORM recommendation_add(snapshot_id, 1, 'Replace top 5 failing devices', 30, NULL);
    PERFORM recommendation_add(snapshot_id, 2, 'Use smart check for busy devices', 15, NULL);
    PERFORM recommendation_add(snapshot_id, 3, 'Remediate TransferMoney test', 12, NULL);
    PERFORM recommendation_add(snapshot_id, 4, 'Remediate FindBranch test', 6, NULL);
    PERFORM recommendation_add(snapshot_id, 5, 'Ensure tests use Digitalzoom API', 0, 'Eliminate 720 Unknowns');
    done := true;
END;
$$ LANGUAGE plpgsql;

-- Nice view to simplify main inner join
CREATE VIEW clouds_snapshots AS
    SELECT
        fqdn,
        email_recipients,
        snapshots.id AS snapshot_id,
        snapshot_date,
        success_last24h,
        success_last7d,
        success_last30d,
        lab_issues,
        orchestration_issues,
        scripting_issues
    FROM clouds
    INNER JOIN
        snapshots ON clouds.id = snapshots.cloud_id;

-- Return a complete snapshot for a cloud on a particular date in JSON format
CREATE OR REPLACE FUNCTION cloudSnapshots(date) RETURNS json AS $$
    SELECT array_to_json(array_agg(row_to_json(s))) FROM (
        SELECT
            fqdn, email_recipients AS "emailRecipients", snapshot_date AS "snapshotDate", success_last24h AS last24h,
            success_last7d AS last7d, success_last30d AS last30d, lab_issues AS lab, orchestration_issues AS orchestration,
            scripting_issues AS scripting,
            (
                SELECT array_to_json(array_agg(row_to_json(r)))
                FROM (
                    SELECT rank, recommendation, impact_percentage AS impact, impact_message AS "impactMessage"
                    FROM recommendations
                    WHERE recommendations.snapshot_id = clouds_snapshots.snapshot_id
                    ORDER BY rank ASC
                ) r
            ) AS recommendations,
            (
                SELECT array_to_json(array_agg(row_to_json(d)))
                FROM (
                    SELECT rank, model, os, device_id AS id, errors_last7d AS errors
                    FROM devices
                    WHERE devices.snapshot_id = clouds_snapshots.snapshot_id
                    ORDER BY rank ASC
                ) d
            ) AS "topProblematicDevices",
            (
                SELECT array_to_json(array_agg(row_to_json(t)))
                FROM (
                    SELECT rank, test_name AS test, age, failures_last7d AS failures, passes_last7d as passes
                    FROM tests
                    WHERE tests.snapshot_id = clouds_snapshots.snapshot_id
                    ORDER BY rank ASC
                ) t
            ) AS "topFailingTests"
        FROM clouds_snapshots
        WHERE snapshot_date = $1::DATE) s;
$$ LANGUAGE sql;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres; 

-- Run the function to populate the date
SELECT populate_test_data();

-- Show what the JSON looks like
SELECT cloudSnapshots('2018-06-10'::DATE);
