-- on first node: call replica('node1', 'node2', 'replication_user', 'iewefijkoierjfrsohD', true);
-- on second node: call replica('node1', 'node2', 'replication_user', 'iewefijkoierjfrsohD', false);

CREATE OR REPLACE PROCEDURE replica(in host1 text, in host2 text, in username text, in password text, in initialize bool)
LANGUAGE plpgsql
AS $proc$
DECLARE
	db text := current_database();
	host1_name text := replace(host1, '.', '_');
    host2_name text := replace(host2, '.', '_');
	server1 text := format('pgactive_server_%s', host1_name);
    server2 text := format('pgactive_server_%s', host2_name);
BEGIN
	CREATE EXTENSION IF NOT EXISTS pgactive;
	EXECUTE format('CREATE SERVER IF NOT EXISTS %s FOREIGN DATA WRAPPER pgactive_fdw OPTIONS (host ''%s'', dbname ''%s'');', server1, host1, db);
	EXECUTE format('CREATE USER MAPPING IF NOT EXISTS FOR %s SERVER %s OPTIONS (user ''%s'', password ''%s'');', username, server1, username, password);
	EXECUTE format('CREATE SERVER IF NOT EXISTS %s FOREIGN DATA WRAPPER pgactive_fdw OPTIONS (host ''%s'', dbname ''%s'');', server2, host2, db);
	EXECUTE format('CREATE USER MAPPING IF NOT EXISTS FOR %s SERVER %s OPTIONS (user ''%s'', password ''%s'');', username, server2, username, password);
	IF initialize THEN
		EXECUTE format('SELECT pgactive.pgactive_create_group(
			node_name := ''%s_%s'',
			node_dsn := ''user_mapping=%s pgactive_foreign_server=%s'');',
				host1_name,
				db,
				username,
				server1
		);
		EXECUTE 'SELECT pgactive.pgactive_wait_for_node_ready();';
  ELSE
		EXECUTE format('SELECT pgactive.pgactive_join_group(
			node_name := ''%s_%s'',
			node_dsn := ''user_mapping=%s pgactive_foreign_server=%s'',
			join_node_dsn := ''user_mapping=%s pgactive_foreign_server=%s'');',
				host2_name,
				db,
				username,
				server2,
				username,
				server1
		);
		EXECUTE 'SELECT pgactive.pgactive_wait_for_node_ready();';
  END IF;
END; $proc$;

CREATE OR REPLACE PROCEDURE replica_reset()
LANGUAGE plpgsql
AS $proc$
BEGIN
  DROP EXTENSION pgactive CASCADE;
END; $proc$;
