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

ALTER ROLE postgres SUPERUSER;

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
    fqdn character varying(255) UNIQUE
);

COMMENT ON COLUMN public.clouds.fqdn IS 'Fully-qualified domain name of the Perfecto cloud';

CREATE TABLE public.snapshots (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    cloud_id uuid NOT NULL REFERENCES clouds(id),
    snapshot_date date,
    success_rate smallint,
    lab_issues bigint,
    orchestration_issues bigint,
    scripting_issues bigint,
    unknowns bigint,
  UNIQUE (cloud_id, snapshot_date)
);

COMMENT ON COLUMN public.snapshots.cloud_id IS 'Foreign key to cloud';
COMMENT ON COLUMN public.snapshots.success_rate IS 'Success rate for last 24 hours expressed as an integer between 0 and 100 (not as decimal < 1)';
COMMENT ON COLUMN public.snapshots.lab_issues IS 'The number of script failures due to device or browser issues in the lab over the last 24 hours';
COMMENT ON COLUMN public.snapshots.orchestration_issues IS 'The number of script failures due to attempts to use the same device';
COMMENT ON COLUMN public.snapshots.scripting_issues IS 'The number of script failures due to a problem with the script or framework over the past 24 hours';
COMMENT ON COLUMN public.snapshots.unknowns IS 'The number of unknown scripts over the past 24 hours';

CREATE TABLE public.devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES snapshots(id),
    rank smallint DEFAULT 1 NOT NULL,
    model character varying(255) NOT NULL,
    os character varying(255) NOT NULL,
    device_id character varying(255) NOT NULL,
    passed_executions_last24h bigint NOT NULL,
    failed_executions_last24h bigint NOT NULL,
    errors_last24h bigint NOT NULL,
    UNIQUE (snapshot_id, rank)
);

COMMENT ON COLUMN public.devices.snapshot_id IS 'Foreign key to snapshot record';
COMMENT ON COLUMN public.devices.rank IS 'Report ranking of the importance of the problematic device';
COMMENT ON COLUMN public.devices.model IS 'Model of the device such as "iPhone X" (manufacturer not needed)';
COMMENT ON COLUMN public.devices.os IS 'Name of operating system and version number such as "iOS 11.3"';
COMMENT ON COLUMN public.devices.device_id IS 'The device ID such as the UUID of an Apple iOS device or the serial number of an Android device';
COMMENT ON COLUMN public.devices.passed_executions_last24h IS 'The number of times a test passed with the device in the last 24 hours';
COMMENT ON COLUMN public.devices.failed_executions_last24h IS 'The number of times a test failed with the device in the last 24 hours';
COMMENT ON COLUMN public.devices.errors_last24h IS 'The number of times the device has gone into error over the last 24 hours';

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
CREATE OR REPLACE FUNCTION cloud_upsert(cloud_fqdn character varying(255), OUT cloud_id uuid) AS $$
BEGIN
    INSERT INTO clouds(fqdn) VALUES (cloud_fqdn)
        ON CONFLICT (fqdn) DO NOTHING
        RETURNING id INTO cloud_id;
END;
$$ LANGUAGE plpgsql;

-- Create snapshot or update if one exists
CREATE OR REPLACE FUNCTION snapshot_add(uuid, date, integer, integer, integer, integer, integer, OUT snapshot_id uuid) AS $$
BEGIN
    INSERT INTO snapshots(cloud_id, snapshot_date, success_rate, lab_issues, orchestration_issues, scripting_issues,unknowns)
        VALUES ($1, $2, $3, $4, $5, $6 ,$7)
            ON CONFLICT (cloud_id, snapshot_date)
                DO UPDATE SET success_rate = $3, lab_issues = $4, orchestration_issues = $5, scripting_issues = $6,unknowns=$7
            RETURNING id INTO snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Add a device to the snapshot
CREATE OR REPLACE FUNCTION device_add(uuid, integer, character varying(255), character varying(255), character varying(255), integer, integer, integer, OUT devices_id uuid) AS $$
BEGIN
    INSERT INTO devices(snapshot_id, rank, model, os, device_id, passed_executions_last24h, failed_executions_last24h, errors_last24h) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
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
    cloud_id uuid := cloud_upsert('acme.perfectomobile.com');
    snapshot_id uuid := snapshot_add(cloud_id, '2018-06-12'::DATE, 37, 10, 20, 30,12);
BEGIN
    PERFORM device_add(snapshot_id, 1, 'iPhone-5S', 'iOS 9.2.1', '544cc6c6026af23c11f5ed6387df5d5f724f60fb', 0, 25, 10);
    PERFORM device_add(snapshot_id, 2, 'Galaxy S5', 'Android 5.0', 'B5DED881', 0, 23, 23);
    PERFORM device_add(snapshot_id, 3, 'Galaxy Note III', 'Android 4.4', '61F1BF00', 1, 15, 10);
    PERFORM device_add(snapshot_id, 4, 'Nexus 5', 'Android 5.0', '06B25936007418BB', 2, 13, 9);
    PERFORM device_add(snapshot_id, 5, 'iPhone-6', 'iOS 9.1', '8E1CBC7E90168A3A7CFDA2712A8C20DD15517F89', 2, 12, 8);
    PERFORM test_add(snapshot_id, 1, 'TransferMoney', 230, 75, 0);
    PERFORM test_add(snapshot_id, 2, 'FindBranch', 200, 71, 3);
    PERFORM test_add(snapshot_id, 3, 'HonkHorn', 4, 68, 13);
    PERFORM test_add(snapshot_id, 4, 'InsuranceSearch', 47, 7, 0);
    PERFORM test_add(snapshot_id, 5, 'RemoteStart', 132, 41, 25);
    PERFORM recommendation_add(snapshot_id, 1, 'Replace iPhone-5S (544cc6c6026af23c11f5ed6387df5d5f724f60fb) due to errors', 30, NULL);
    PERFORM recommendation_add(snapshot_id, 2, 'Use smart check for busy devices', 15, NULL);
    PERFORM recommendation_add(snapshot_id, 3, 'Remediate TransferMoney test', 12, NULL);
    PERFORM recommendation_add(snapshot_id, 4, 'XPath /bookstore/book[1]/title is broken (affects 30 tests)', 6, NULL);
    PERFORM recommendation_add(snapshot_id, 5, 'Ensure tests use Digitalzoom API', 0, 'Eliminate 720 Unknowns');
    done := true;
END;
$$ LANGUAGE plpgsql;

-- Nice view to simplify main inner join
CREATE VIEW clouds_snapshots AS
    SELECT
        fqdn,
        snapshots.id AS snapshot_id,
        snapshot_date,
        success_rate,
        (SELECT AVG(success_rate) FROM snapshots WHERE snapshot_date > CURRENT_DATE - INTERVAL '7 days')::bigint AS success_last7d,
        (SELECT AVG(success_rate) FROM snapshots WHERE snapshot_date > CURRENT_DATE - INTERVAL '14 days')::bigint AS success_last14d,
        lab_issues,
        orchestration_issues,
        scripting_issues,
        unknowns
    FROM clouds
    INNER JOIN
        snapshots ON clouds.id = snapshots.cloud_id;

-- Return a complete snapshot for a cloud on a particular date in JSON format
CREATE OR REPLACE FUNCTION cloudSnapshots(character varying(255), date) RETURNS json AS $$
    SELECT row_to_json(s) FROM (
        SELECT
            fqdn, snapshot_date AS "snapshotDate", success_rate AS last24h,
            success_last7d AS last7d, success_last14d AS last14d, lab_issues AS lab, orchestration_issues AS orchestration,
            scripting_issues AS scripting, unknowns,
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
                    SELECT rank, model, os, device_id AS id, passed_executions_last24h AS passed, failed_executions_last24h AS failed, errors_last24h AS errors
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
        WHERE fqdn = $1 AND snapshot_date = $2::DATE) s;
$$ LANGUAGE sql;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres; 

-- Run the function to populate the date
SELECT populate_test_data();

-- Show what the JSON looks like
SELECT cloudSnapshots('acme.perfectomobile.com', '2018-06-12'::DATE);
