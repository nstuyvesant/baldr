-- Invoke this script via
-- $ psql -d postgres -f db_create.sql

-- Create user if doesn't exist
DO
$do$
BEGIN
   IF NOT EXISTS (
      SELECT                       -- SELECT list can stay empty for this
      FROM   pg_catalog.pg_roles
      WHERE  rolname = 'baldr') THEN

      CREATE ROLE baldr;
   END IF;
END
$do$;

-- Forcefully disconnect anyone
SELECT pid, pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE datname = 'vr' AND pid <> pg_backend_pid();

DROP DATABASE IF EXISTS vr;

-- Create database
CREATE DATABASE vr
    WITH 
    OWNER = baldr
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
    fqdn character varying(255) UNIQUE NOT NULL,
    last_update date DEFAULT CURRENT_DATE,
    token character varying(2000),
    token_issue boolean DEFAULT false
);

COMMENT ON COLUMN public.clouds.fqdn IS 'Fully-qualified domain name of the Perfecto cloud';
COMMENT ON COLUMN public.clouds.last_update IS 'Last time Uzi updated the data';

CREATE TABLE public.test_age (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    cloud_id uuid NOT NULL REFERENCES clouds(id) ON DELETE CASCADE,
    test_name character varying(4000) NOT NULL,
    first_seen date DEFAULT CURRENT_DATE NOT NULL,
    UNIQUE (cloud_id, test_name)
);

COMMENT ON COLUMN public.test_age.cloud_id IS 'Foreign key to cloud';
COMMENT ON COLUMN public.test_age.first_seen IS 'First date we saw that test';

CREATE TABLE public.snapshots (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  cloud_id uuid NOT NULL REFERENCES clouds(id) ON DELETE CASCADE,
  snapshot_date date DEFAULT CURRENT_DATE NOT NULL,
  success_rate smallint DEFAULT 0,
  lab_issues bigint DEFAULT 0,
  orchestration_issues bigint DEFAULT 0,
  scripting_issues bigint DEFAULT 0,
  unknowns bigint DEFAULT 0,
  executions bigint DEFAULT 0,
  score_automation smallint DEFAULT 0,
  score_experience smallint DEFAULT 0,
  score_usage smallint DEFAULT 0,
  score_formula json DEFAULT '{}'::json,
  score_automation smallint DEFAULT 0,
  score_experience smallint DEFAULT 0,
  score_usage smallint DEFAULT 0,
  UNIQUE (cloud_id, snapshot_date)
);

COMMENT ON COLUMN public.snapshots.cloud_id IS 'Foreign key to cloud';
COMMENT ON COLUMN public.snapshots.success_rate IS 'Success rate for last 24 hours expressed as an integer between 0 and 100 (not as decimal < 1)';
COMMENT ON COLUMN public.snapshots.lab_issues IS 'The number of script failures due to device or browser issues in the lab over the last 24 hours';
COMMENT ON COLUMN public.snapshots.orchestration_issues IS 'The number of script failures due to attempts to use the same device';
COMMENT ON COLUMN public.snapshots.scripting_issues IS 'The number of script failures due to a problem with the script or framework over the past 24 hours';
COMMENT ON COLUMN public.snapshots.unknowns IS 'The number of unknown scripts over the past 24 hours';
COMMENT ON COLUMN public.snapshots.executions IS 'The number of executions over the past 24 hours';
COMMENT ON COLUMN public.snapshots.score_automation IS '0 to 100 score for automation health';
COMMENT ON COLUMN public.snapshots.score_experience IS '0 to 100 score for how many defects, outages, etc. customer has experienced';
COMMENT ON COLUMN public.snapshots.score_usage IS '0 to 100 score for usage health';

CREATE TABLE public.devices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    snapshot_id uuid NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
    rank smallint DEFAULT 1 NOT NULL,
    model character varying(255) NOT NULL,
    os character varying(255) NOT NULL,
    device_id character varying(255) NOT NULL,
    passed_executions_last24h bigint DEFAULT 0 NOT NULL,
    failed_executions_last24h bigint DEFAULT 0 NOT NULL,
    errors_last24h bigint DEFAULT 0 NOT NULL,
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
    snapshot_id uuid NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
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
    snapshot_id uuid NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
    rank smallint DEFAULT 1 NOT NULL,
    test_name character varying(4000) NOT NULL,
    failures_last24h bigint DEFAULT 0 NOT NULL,
    passes_last24h bigint DEFAULT 0 NOT NULL,
    UNIQUE (snapshot_id, rank)
);

COMMENT ON COLUMN public.tests.snapshot_id IS 'Foreign key to snapshot record';
COMMENT ON COLUMN public.tests.rank IS 'Report ranking of the importance of the problematic test';
COMMENT ON COLUMN public.tests.test_name IS 'Name of the test having issues';
COMMENT ON COLUMN public.tests.failures_last24h IS 'Number of failures of the test for the last 7 days';
COMMENT ON COLUMN public.tests.passes_last24h IS 'The number of times the test has passed over the last 7 days';

-- Add indices
CREATE INDEX fki_clouds_fkey ON public.snapshots USING btree (cloud_id);
CREATE INDEX fki_devices_snapshots_fkey ON public.devices USING btree (snapshot_id);
CREATE INDEX fki_recommendations_snapshots_fkey ON public.recommendations USING btree (snapshot_id);
CREATE INDEX fki_tests_snapshots_fkey ON public.tests USING btree (snapshot_id);

-- Use stored procedures to interact with DB (never direct queries) - allows us to change schema without breaking things

-- Insert cloud record or update email recipients if one exists
CREATE OR REPLACE FUNCTION cloud_upsert(character varying(255), OUT cloud_id uuid) AS $$
BEGIN
    INSERT INTO clouds(fqdn) VALUES ($1)
        ON CONFLICT (fqdn) DO UPDATE SET fqdn = $1 -- re-update in order to get id
        RETURNING id INTO cloud_id;
END;
$$ LANGUAGE plpgsql;

-- Return cloud_id parent from snapshot_id
CREATE OR REPLACE FUNCTION cloud_get_id(uuid) RETURNS uuid AS $$
    SELECT cloud_id FROM snapshots WHERE id = $1;
$$ LANGUAGE sql;

-- Insert test_age record if one doesn't already exist (first param is snaphot_id, second is test name)
CREATE OR REPLACE FUNCTION age_test(uuid, character varying(4000), OUT test_age_id uuid) AS $$
BEGIN
    INSERT INTO test_age(cloud_id, test_name) VALUES (cloud_get_id($1), $2)
        ON CONFLICT (cloud_id, test_name) DO UPDATE SET test_name = $2 -- re-update in order to get id
        RETURNING id INTO test_age_id;
END;
$$ LANGUAGE plpgsql;

-- Create snapshot or update if one exists
CREATE OR REPLACE FUNCTION snapshot_add(uuid, date, integer, integer, integer, integer, integer, integer, integer, OUT snapshot_id uuid) AS $$
BEGIN
    INSERT INTO snapshots(cloud_id, snapshot_date, success_rate, lab_issues, orchestration_issues, scripting_issues, unknowns, executions ,score_experience)
        VALUES ($1, $2, $3, $4, $5, $6 ,$7, $8 , $9)
            ON CONFLICT (cloud_id, snapshot_date)
                DO UPDATE SET success_rate = $3, lab_issues = $4, orchestration_issues = $5, scripting_issues = $6, unknowns= $7, executions = $8 , score_experience = $9
            RETURNING id INTO snapshot_id;
END;
$$ LANGUAGE plpgsql;

-- Delete snapshot
CREATE OR REPLACE FUNCTION snapshot_delete(uuid, OUT done boolean) AS $$
BEGIN
  DELETE FROM snapshots WHERE snapshot_id = $1;
    DELETE FROM recommendations WHERE snapshot_id = $1;
    DELETE FROM devices WHERE snapshot_id = $1;
    DELETE FROM tests WHERE snapshot_id = $1;
  done := true;
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
CREATE OR REPLACE FUNCTION test_add(uuid, integer, character varying(4000), integer, integer, OUT test_id uuid) AS $$
BEGIN
    PERFORM age_test($1, $3);
    INSERT INTO tests(snapshot_id, rank, test_name, failures_last24h, passes_last24h) VALUES ($1, $2, $3, $4, $5)
        RETURNING id INTO test_id;
END;
$$ LANGUAGE plpgsql;

-- Add a recommendation to the snapshot
CREATE OR REPLACE FUNCTION recommendation_add(uuid, integer, character varying(2000), integer, character varying(2000), OUT recommendation_id uuid) AS $$
BEGIN
    INSERT INTO recommendations(snapshot_id, rank, recommendation, impact_percentage, impact_message) VALUES ($1, $2, $3, $4, $5);
END;
$$ LANGUAGE plpgsql;

-- Read a snapshot in JSON format
CREATE OR REPLACE FUNCTION json_snapshot_upsert(input json, OUT done boolean) AS $$
DECLARE
    v_cloud_id uuid := cloud_upsert((input->>'fqdn')::varchar);
    v_snapshot_id uuid;
BEGIN
    v_snapshot_id := snapshot_add(
        v_cloud_id,
        (input->>'snapshotDate')::date,
        (input->>'last24h')::integer, 
        (input->>'lab')::integer,
        (input->>'orchestration')::integer,
        (input->>'scripting')::integer,
        (input->>'unknowns')::integer,
    (input->>'executions')::integer,
    (input->>'score_experience')::integer
    );
    -- Delete records related to existing snapshot (as this will overwrite)
    DELETE FROM recommendations WHERE snapshot_id = v_snapshot_id;
    DELETE FROM devices WHERE snapshot_id = v_snapshot_id;
    DELETE FROM tests WHERE snapshot_id = v_snapshot_id;

    -- Add recommendations
    WITH r AS (
        SELECT
            v_snapshot_id AS snapshot_id,
            (value->>'rank')::smallint AS rank,
            (value->>'recommendation')::varchar AS recommendation,
            (value->>'impact')::integer AS impact_percentage,
            (value->>'impactMessage')::varchar AS impact_message
        FROM json_array_elements(input->'recommendations')
    )
    INSERT INTO recommendations(snapshot_id, rank, recommendation, impact_percentage, impact_message) SELECT snapshot_id, rank, recommendation, impact_percentage, impact_message FROM r;
    -- Add devices
    WITH d AS (
        SELECT
            v_snapshot_id AS snapshot_id,
            (value->>'rank')::smallint AS rank,
            (value->>'model')::varchar AS model,
            (value->>'os')::varchar AS os,
            (value->>'id')::varchar AS device_id,
            (value->>'passed')::integer AS passed_executions_last24h,
            (value->>'failed')::integer AS failed_executions_last24h,
            (value->>'errors')::integer AS errors_last24h
        FROM json_array_elements(input->'topProblematicDevices')
    )
    INSERT INTO
        devices(snapshot_id, rank, model, os, device_id, passed_executions_last24h, failed_executions_last24h, errors_last24h)
        SELECT snapshot_id, rank, model, os, device_id, passed_executions_last24h, failed_executions_last24h, errors_last24h FROM d;
    -- Add tests
    WITH t AS (
        SELECT
            v_snapshot_id AS snapshot_id,
            (value->>'rank')::smallint AS rank,
            (value->>'test')::varchar AS test_name,
            (value->>'failures')::integer AS failures_last24h,
            (value->>'passes')::integer AS passes_last24h
        FROM json_array_elements(input->'topFailingTests')
    )
    INSERT INTO
        tests(snapshot_id, rank, test_name, failures_last24h, passes_last24h)
        SELECT snapshot_id, rank, test_name, failures_last24h, passes_last24h FROM t;
    INSERT INTO
        test_age(cloud_id, test_name)
        SELECT v_cloud_id, test_name FROM tests WHERE snapshot_id = v_snapshot_id
            ON CONFLICT DO NOTHING;
    done := TRUE;
END;
$$ LANGUAGE plpgsql;

-- Load test data dependencies
CREATE OR REPLACE FUNCTION populate_test_data(OUT done boolean) AS $$
DECLARE
    cloud_id uuid := cloud_upsert('demo.perfectomobile.com');
    snapshot_id uuid := snapshot_add(cloud_id, '2018-06-20'::DATE, 37, 10, 20, 30, 12, 1230,98);
BEGIN
    PERFORM device_add(snapshot_id, 1, 'iPhone-5S', 'iOS 9.2.1', '544cc6c6026af23c11f5ed6387df5d5f724f60fb', 0, 25, 10);
    PERFORM device_add(snapshot_id, 2, 'Galaxy S5', 'Android 5.0', 'B5DED881', 0, 23, 23);
    PERFORM device_add(snapshot_id, 3, 'Galaxy Note III', 'Android 4.4', '61F1BF00', 1, 15, 10);
    PERFORM device_add(snapshot_id, 4, 'Nexus 5', 'Android 5.0', '06B25936007418BB', 2, 13, 9);
    PERFORM device_add(snapshot_id, 5, 'iPhone-6', 'iOS 9.1', '8E1CBC7E90168A3A7CFDA2712A8C20DD15517F89', 2, 12, 8);
    PERFORM test_add(snapshot_id, 1, 'TransferMoney', 75, 0);
    PERFORM test_add(snapshot_id, 2, 'FindBranch', 71, 3);
    PERFORM test_add(snapshot_id, 3, 'HonkHorn', 68, 13);
    PERFORM test_add(snapshot_id, 4, 'InsuranceSearch', 7, 0);
    PERFORM test_add(snapshot_id, 5, 'RemoteStart', 41, 25);
    PERFORM recommendation_add(snapshot_id, 1, 'Replace iPhone-5S (544cc6c6026af23c11f5ed6387df5d5f724f60fb) due to errors', 30, NULL);
    PERFORM recommendation_add(snapshot_id, 2, 'Use smart check for busy devices', 15, NULL);
    PERFORM recommendation_add(snapshot_id, 3, 'Remediate TransferMoney test', 12, NULL);
    PERFORM recommendation_add(snapshot_id, 4, 'XPath /bookstore/book[1]/title is broken (affects 30 tests)', 6, NULL);
    PERFORM recommendation_add(snapshot_id, 5, 'Ensure tests use Digitalzoom API', 0, 'Eliminate 720 Unknowns');
    done := true;
END;
$$ LANGUAGE plpgsql;

-- Nice view to simplify main inner join
CREATE OR REPLACE VIEW clouds_snapshots AS
    SELECT
        clouds.id AS cloud_id,
        fqdn,
        snapshots.id AS snapshot_id,
        snapshot_date,
        success_rate,
        (SELECT SUM(success_rate*executions/100)/SUM(executions)*100 FROM snapshots
          WHERE cloud_id = clouds.id AND snapshot_date > snapshot_date - INTERVAL '7 days')::bigint AS success_last7d,
        (SELECT SUM(success_rate*executions/100)/SUM(executions)*100 FROM snapshots
          WHERE cloud_id = clouds.id AND snapshot_date > snapshot_date - INTERVAL '14 days')::bigint AS success_last14d,
        lab_issues,
        score_experience,
        orchestration_issues,
        scripting_issues,
        unknowns,
        executions,
        score_automation,
        score_experience,
        score_usage
    FROM clouds
    INNER JOIN
        snapshots ON clouds.id = snapshots.cloud_id;

-- Return a complete snapshot for a cloud on a particular date in JSON format
CREATE OR REPLACE FUNCTION cloudSnapshot(character varying(255), date) RETURNS json AS $$
    SELECT row_to_json(s) FROM (
        SELECT
            fqdn, snapshot_date AS "snapshotDate", success_rate AS last24h,
            success_last7d AS last7d, success_last14d AS last14d, lab_issues AS lab,score_experience, orchestration_issues AS orchestration,
            scripting_issues AS scripting, unknowns, executions,
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
                    SELECT rank, tests.test_name AS test, CURRENT_DATE - first_seen AS age, failures_last24h AS failures, passes_last24h as passes
                    FROM tests INNER JOIN test_age ON tests.test_name = test_age.test_name
                    WHERE tests.snapshot_id = clouds_snapshots.snapshot_id AND test_age.cloud_id = clouds_snapshots.cloud_id
                    ORDER BY rank ASC
                ) t
            ) AS "topFailingTests"
        FROM clouds_snapshots
        WHERE fqdn = $1 AND snapshot_date = $2::DATE) s;
$$ LANGUAGE sql;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO postgres;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO baldr;

-- Run the function to populate the date inside a transaction
-- BEGIN;
--   SELECT populate_test_data();
-- COMMIT;

BEGIN; -- Start a transaction

-- Show how to populate test data using JSON - alternative to the functions in populate_test_data()
SELECT json_snapshot_upsert('{
  "fqdn": "demo.perfectomobile.com",
  "snapshotDate": "2018-06-19",
  "last24h": 37,
  "lab": 10,
  "orchestration": 20,
  "scripting": 30,
  "unknowns": 12,
  "executions": 1230,
  "score_experience": 89,
  "recommendations": [{
    "rank": 1,
    "recommendation": "Replace iPhone-5S (544cc6c6026af23c11f5ed6387df5d5f724f60fb) due to errors",
    "impact": 30,
    "impactMessage": null
  }, {
    "rank": 2,
    "recommendation": "Use smart check for busy devices",
    "impact": 15,
    "impactMessage": null
  }, {
    "rank": 3,
    "recommendation": "Remediate TransferMoney test",
    "impact": 12,
    "impactMessage": null
  }, {
    "rank": 4,
    "recommendation": "XPath /bookstore/book[1]/title is broken (affects 30 tests)",
    "impact": 6,
    "impactMessage": null
  }, {
    "rank": 5,
    "recommendation": "Ensure tests use Digitalzoom API",
    "impact": 0,
    "impactMessage": "Eliminate 720 Unknowns"
  }],
  "topProblematicDevices": [{
    "rank": 1,
    "model": "iPhone-5S",
    "os": "iOS 9.2.1",
    "id": "544cc6c6026af23c11f5ed6387df5d5f724f60fb",
    "passed": 0,
    "failed": 25,
    "errors": 10
  }, {
    "rank": 2,
    "model": "Galaxy S5",
    "os": "Android 5.0",
    "id": "B5DED881",
    "passed": 0,
    "failed": 23,
    "errors": 23
  }, {
    "rank": 3,
    "model": "Galaxy Note III",
    "os": "Android 4.4",
    "id": "61F1BF00",
    "passed": 1,
    "failed": 15,
    "errors": 10
  }, {
    "rank": 4,
    "model": "Nexus 5",
    "os": "Android 5.0",
    "id": "06B25936007418BB",
    "passed": 2,
    "failed": 13,
    "errors": 9
  }, {
    "rank": 5,
    "model": "iPhone-6",
    "os": "iOS 9.1",
    "id": "8E1CBC7E90168A3A7CFDA2712A8C20DD15517F89",
    "passed": 2,
    "failed": 12,
    "errors": 8
  }],
  "topFailingTests": [{
    "rank": 1,
    "test": "TransferMoney",
    "failures": 75,
    "passes": 0
  }, {
    "rank": 2,
    "test": "FindBranch",
    "failures": 71,
    "passes": 3
  }, {
    "rank": 3,
    "test": "HonkHorn",
    "failures": 68,
    "passes": 13
  }, {
    "rank": 4,
    "test": "InsuranceSearch",
    "failures": 7,
    "passes": 0
  }, {
    "rank": 5,
    "test": "RemoteStart",
    "failures": 41,
    "passes": 25
  }]
}'::json);

SELECT json_snapshot_upsert('{
  "fqdn": "demo.perfectomobile.com",
  "snapshotDate": "2018-06-20",
  "last24h": 89,
  "lab": 11,
  "score_experience": 30,
  "orchestration": 21,
  "scripting": 31,
  "unknowns": 13,
  "executions": 1028,
  "recommendations": [{
    "rank": 1,
    "recommendation": "Replace iPhone-5S (544cc6c6026af23c11f5ed6387df5d5f724f60fb) due to errors",
    "impact": 30,
    "impactMessage": null
  }, {
    "rank": 2,
    "recommendation": "Use smart check for busy devices",
    "impact": 15,
    "impactMessage": null
  }, {
    "rank": 3,
    "recommendation": "Remediate TransferMoney test",
    "impact": 12,
    "impactMessage": null
  }, {
    "rank": 4,
    "recommendation": "XPath /bookstore/book[1]/title is broken (affects 30 tests)",
    "impact": 6,
    "impactMessage": null
  }, {
    "rank": 5,
    "recommendation": "Ensure tests use Digitalzoom API",
    "impact": 0,
    "impactMessage": "Eliminate 720 Unknowns"
  }],
  "topProblematicDevices": [{
    "rank": 1,
    "model": "iPhone-5S",
    "os": "iOS 9.2.1",
    "id": "544cc6c6026af23c11f5ed6387df5d5f724f60fb",
    "passed": 0,
    "failed": 25,
    "errors": 10
  }, {
    "rank": 2,
    "model": "Galaxy S5",
    "os": "Android 5.0",
    "id": "B5DED881",
    "passed": 0,
    "failed": 23,
    "errors": 23
  }, {
    "rank": 3,
    "model": "Galaxy Note III",
    "os": "Android 4.4",
    "id": "61F1BF00",
    "passed": 1,
    "failed": 15,
    "errors": 10
  }, {
    "rank": 4,
    "model": "Nexus 5",
    "os": "Android 5.0",
    "id": "06B25936007418BB",
    "passed": 2,
    "failed": 13,
    "errors": 9
  }, {
    "rank": 5,
    "model": "iPhone-6",
    "os": "iOS 9.1",
    "id": "8E1CBC7E90168A3A7CFDA2712A8C20DD15517F89",
    "passed": 2,
    "failed": 12,
    "errors": 8
  }],
  "topFailingTests": [{
    "rank": 1,
    "test": "TransferMoney",
    "failures": 75,
    "passes": 0
  }, {
    "rank": 2,
    "test": "FindBranch",
    "failures": 71,
    "passes": 3
  }, {
    "rank": 3,
    "test": "HonkHorn",
    "failures": 68,
    "passes": 13
  }, {
    "rank": 4,
    "test": "InsuranceSearch",
    "failures": 7,
    "passes": 0
  }, {
    "rank": 5,
    "test": "RemoteStart",
    "failures": 41,
    "passes": 25
  }]
}'::json);

COMMIT;

-- Show what the JSON looks like
SELECT cloudSnapshot('demo.perfectomobile.com', '2018-06-20'::date);
