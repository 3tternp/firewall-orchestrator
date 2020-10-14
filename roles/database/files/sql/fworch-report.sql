-- $Id: iso-report.sql,v 1.1.2.7 2012-05-28 10:32:56 tim Exp $
-- $Source: /home/cvs/iso/package/install/database/Attic/iso-report.sql,v $

----------------------------------------------------
-- Filterfunktionen zum Generieren von Reports
----------------------------------------------------
-- get_tenant_ip_filter(tenant_id) RETURNS VARCHAR
-- get_negated_tenant_ip_filter(tenant_id) RETURNS VARCHAR

-- get_obj_ids_of_filtered_ruleset(INTEGER[]) RETURNS SETOF INTEGER

-- get_rule_ids(device_id, zeitpunkt, tenant_id) RETURNS SETOF INTEGER
-- get_rule_ids(device_id, zeitpunkt, tenant_id, src_ip, dst_ip, any_ip, proto, port) RETURNS SETOF INTEGER --> for rulesearch

-- rule_src_contains_tenant_obj (rule_id, tenant_id) RETURNS BOOLEAN
-- rule_dst_contains_tenant_obj (rule_id, tenant_id) RETURNS BOOLEAN
-- obj_belongs_to_tenant (obj_id, tenant_id) RETURNS BOOLEAN
-- obj_neg_belongs_to_tenant (obj_id, tenant_id) RETURNS BOOLEAN

-- get_rule_src (rule_id, tenant_id) RETURNS SETOF INTEGER
-- get_rule_dst (rule_id, tenant_id) RETURNS SETOF INTEGER

-- get_tenant_relevant_changes(tenant-ID, management-id, device-id, startzeit, stopzeit)
-- unterfunktionen von get_tenant_relevant_changes:
	-- get_svc_ids_of_tenant(tenant, array_of_rule_ids) RETURNS SETOF INTEGER
	-- get_user_ids_of_tenant(tenant, array_of_rule_ids) RETURNS SETOF INTEGER
	-- get_obj_ids_of_tenant(tenant, array_of_rule_ids) RETURNS SETOF INTEGER

----------------------------------------------------
-- FUNCTION:	get_tenant_relevant_changes
-- Zweck:		liefert zu einem tenant alle Changes zurueck, die in fuer ihn relevanten sind
-- Parameter1:	tenant-ID des zu betrachtenden tenants
-- Parameter2:	managment-id
-- Parameter3:	device-id
-- Parameter4:	startzeit
-- Parameter5:	stopzeit

-- RETURNS:		Menge der relevanten Changes (abs_change_id : set of integer)
--
CREATE OR REPLACE FUNCTION get_tenant_relevant_changes(INTEGER, INTEGER, INTEGER, TIMESTAMP, TIMESTAMP) RETURNS SETOF INTEGER AS $$
DECLARE
	i_tenant_id	ALIAS FOR $1;
	i_mgm_id	ALIAS FOR $2;
	i_dev_id	ALIAS FOR $3;
	t_start		ALIAS FOR $4;
	t_end		ALIAS FOR $5;
	r_change	RECORD;
	v_sql		VARCHAR;
BEGIN
	-- delete content of temp table anf fill it again with all rule_ids of the requested tenant
	DELETE FROM temp_table_for_tenant_filtered_rule_ids;
	INSERT INTO temp_table_for_tenant_filtered_rule_ids SELECT rule_id FROM view_tenant_rules WHERE tenant_id=i_tenant_id;
	v_sql := 'SELECT abs_change_id FROM view_changes_by_changed_element_id WHERE TRUE';
	-- apply filter criteria if set
	IF NOT i_mgm_id=NULL THEN v_sql := v_sql || ' AND mgm_id=' || i_mgm_id; END IF;
	IF NOT i_dev_id=NULL THEN v_sql := v_sql || ' AND dev_id=' || i_dev_id; END IF;
	IF NOT t_start=NULL THEN v_sql := v_sql || ' AND change_time>=' || t_start; END IF;
	IF NOT t_end=NULL THEN v_sql := v_sql || ' AND change_time<=' || t_end; END IF;
	-- now the various individual change elements
	v_sql := v_sql || '	AND	((change_element=''service'' and element_id in (select * from get_svc_ids_for_tenant())) ' ||
		'OR (change_element=''user'' and element_id in (select * from get_user_ids_for_tenant())) ' ||
		'OR (change_element=''object'' and element_id in (select * from get_obj_ids_for_tenant())) ' ||
		'OR (change_element=''rule'' and element_id in (select * from temp_table_for_tenant_filtered_rule_ids))' ||
		') GROUP BY abs_change_id';
	FOR r_change IN EXECUTE v_sql
	LOOP
		RETURN NEXT r_change.abs_change_id;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_svc_ids_of_tenant
-- Zweck:		liefert zu einem tenant alle dienste zurueck, die in fuer ihn relevanten regeln vorkommen
-- Annahme:		die Menge der Regeln steht in temp_table_for_tenant_filtered_rule_ids
-- RETURNS:		Menge der Dienst-IDs (svc_id)
--
CREATE OR REPLACE FUNCTION get_svc_ids_for_tenant() RETURNS SETOF INTEGER AS $$
DECLARE
	r_svc				RECORD;
BEGIN		
	FOR r_svc IN
		SELECT service.svc_id FROM rule
			LEFT JOIN rule_service USING (rule_id) 
			LEFT JOIN svcgrp_flat ON (rule_service.svc_id=svcgrp_flat_id)
			LEFT JOIN service ON (svcgrp_flat_member_id=service.svc_id)
		WHERE rule.rule_id IN (SELECT rule_id FROM temp_table_for_tenant_filtered_rule_ids)
		GROUP BY service.svc_id		
	LOOP
		RETURN NEXT r_svc.svc_id;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_user_ids_of_tenant
-- Zweck:		liefert zu einem tenant alle User zurueck, die in fuer ihn relevanten regeln vorkommen
-- Annahme:		die Menge der Regeln steht in temp_table_for_tenant_filtered_rule_ids
-- RETURNS:		Menge der User-IDs (user_id)
--
CREATE OR REPLACE FUNCTION get_user_ids_for_tenant() RETURNS SETOF INTEGER AS $$
DECLARE
	r_user			RECORD;
BEGIN			 
	FOR r_user IN
		SELECT usr.user_id FROM rule
			LEFT JOIN rule_from USING (rule_id) 
			LEFT JOIN usergrp_flat ON (rule_user.user_id=usergrp_flat_id)
			LEFT JOIN usr ON (usergrp_flat_member_id=usr.user_id)
		WHERE rule.rule_id IN (SELECT rule_id FROM temp_table_for_tenant_filtered_rule_ids)
		GROUP BY usr.user_id
	LOOP
		RETURN NEXT r_user.user_id;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_obj_ids_of_tenant
-- Zweck:		liefert zu einem tenant alle NW-Objekte zurueck, die in fuer ihn relevanten regeln vorkommen
-- Annahme:		die Menge der Regeln steht in temp_table_for_tenant_filtered_rule_ids
-- RETURNS:		Menge der object-IDs (obj_id)
--
CREATE OR REPLACE FUNCTION get_obj_ids_for_tenant() RETURNS SETOF INTEGER AS $$
DECLARE
	r_obj				RECORD;
BEGIN		
	FOR r_obj IN
		SELECT object.obj_id FROM rule
			LEFT JOIN rule_from USING (rule_id) 
			LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat_id)
			LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id)
		WHERE rule.rule_id IN (SELECT rule_id FROM temp_table_for_tenant_filtered_rule_ids)
		UNION 
		SELECT object.obj_id FROM rule
			LEFT JOIN rule_to USING (rule_id) 
			LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat_id)
			LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id)		
		WHERE rule.rule_id IN (SELECT rule_id FROM temp_table_for_tenant_filtered_rule_ids)
		GROUP BY object.obj_id		
	LOOP
		RETURN NEXT r_obj.obj_id;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_tenant_ip_filter
-- Zweck:		liefert zu einem tenant einen Filter-String
-- Parameter1:	tenant-ID des zu betrachtenden tenants
-- RETURNS:		String mit booleschem Ausdruck fuer SQL-Where-Clause
--
CREATE OR REPLACE FUNCTION get_tenant_ip_filter(INTEGER) RETURNS VARCHAR AS $$
DECLARE
	i_tenant_id ALIAS FOR $1;
	v_filter VARCHAR;
	r_tenant_net RECORD;
BEGIN
	IF i_tenant_id IS NULL THEN
		RETURN 'TRUE';
	ELSE 
		v_filter := '(';
		FOR r_tenant_net IN
			SELECT tenant_net_ip FROM tenant_network WHERE tenant_id=i_tenant_id
		LOOP
			v_filter := v_filter || ' obj_ip<<=' || E'\'' ||
				CAST (r_tenant_net.tenant_net_ip AS VARCHAR) || E'\'' || ' OR ' || E'\'' ||
				CAST (r_tenant_net.tenant_net_ip AS VARCHAR) || E'\'' || '<<=obj_ip OR';
		END LOOP;
		v_filter := v_filter || ' FALSE)';
--		RAISE INFO 'tenant-filter: %', v_filter;
	    RETURN v_filter;
	END IF;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------
-- FUNCTION:	get_ip_filter
-- Zweck:		liefert zu einer IP-Adresse einen Filter-String
-- Parameter1:	IP-Adresse (auch Netzbereich)
-- RETURNS:		String mit booleschem Ausdruck fuer SQL-Where-Clause
--
CREATE OR REPLACE FUNCTION get_ip_filter(CIDR) RETURNS VARCHAR AS $$
DECLARE
	c_ip_filter ALIAS FOR $1;
	v_filter VARCHAR;
BEGIN
	IF c_ip_filter IS NULL THEN
		RETURN ' TRUE ';
	ELSE 
		v_filter := ' ( obj_ip<<=' || E'\'' ||
				CAST (c_ip_filter AS VARCHAR) || E'\'' || ' OR  ' || E'\'' ||
				CAST (c_ip_filter AS VARCHAR) || E'\'' || '<<=obj_ip ) ';
--		RAISE INFO 'ip-filter: %', v_filter;
	    RETURN v_filter;
	END IF;
END;
$$ LANGUAGE plpgsql;
----------------------------------------------------
-- FUNCTION:	get_negated_tenant_ip_filter
-- Zweck:		liefert zu einem tenant einen Filter-String
-- Zweck:		fuer ngegierte Regelteile (Quelle oder Ziel)
-- Parameter1:	tenant-ID des zu betrachtenden tenants
-- RETURNS:		String mit booleschem Ausdruck fuer SQL-Where-Clause
--
CREATE OR REPLACE FUNCTION get_negated_tenant_ip_filter(INTEGER) RETURNS VARCHAR AS $$
DECLARE
	i_tenant_id ALIAS FOR $1;
	v_filter VARCHAR;
	r_tenant_net RECORD;
BEGIN
	IF i_tenant_id IS NULL THEN
		RETURN 'TRUE';
	ELSE 
		v_filter := '(';
		FOR r_tenant_net IN
			SELECT tenant_net_ip FROM tenant_network WHERE tenant_id=i_tenant_id
		LOOP
			v_filter := v_filter || 'NOT(obj_ip<<=' || E'\'' ||
				CAST (r_tenant_net.tenant_net_ip AS VARCHAR) || E'\'' || ') AND NOT(' || E'\'' ||
				CAST (r_tenant_net.tenant_net_ip AS VARCHAR) || E'\'' || '<<=obj_ip) AND ';
		END LOOP;
		v_filter := v_filter || ' TRUE)';
--		RAISE INFO 'tenant-filter: %', v_filter;
	    RETURN v_filter;
	END IF;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------
-- FUNCTION:	get_obj_ids_of_filtered_ruleset
-- Zweck:		liefert Tabelle mit allen Object-IDs zurueck,
-- Zweck:		die in den Zielen oder Quellen der Regeln vorkommen
-- Parameter1:	Array mit allen Rule_IDs
-- Parameter2:	import_id
-- Parameter3:	tenant-ID des Kunden, fuer den der Report generiert werden soll
-- Parameter3:	wenn NULL: keine Kunden-Filterung: liefere alle Regeln
-- RETURNS:		Tabelle mit einer Spalte (obj_id)
--
CREATE OR REPLACE FUNCTION get_obj_ids_of_filtered_ruleset(INTEGER[], INTEGER, TIMESTAMP) RETURNS SETOF INTEGER AS $$
DECLARE
    ar_rule_ids ALIAS FOR $1;
    i_tenant ALIAS FOR $2;
    t_time ALIAS FOR $3;
    r_rule RECORD;
    r_obj RECORD;
BEGIN
	FOR r_rule IN
		SELECT rule_id FROM rule WHERE rule_id = ANY (ar_rule_ids)
	LOOP
		FOR r_obj IN
			(
				(
--					SELECT get_rule_src AS obj_id FROM get_rule_src(r_rule.rule_id,i_import_id,i_tenant)
					SELECT get_rule_src AS obj_id FROM get_rule_src(r_rule.rule_id,i_tenant,t_time)
				)
				UNION
				(
--					SELECT get_rule_dst AS obj_id FROM get_rule_dst(r_rule.rule_id,i_import_id,i_tenant)
					SELECT get_rule_dst AS obj_id FROM get_rule_dst(r_rule.rule_id,i_tenant,t_time)
				)
			) -- GROUP BY obj_id ORDER BY obj_id
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_obj_ids_of_filtered_ruleset_flat
-- Zweck:		liefert Tabelle mit allen Object-IDs zurueck,
-- Zweck:		die in den Zielen oder Quellen der Regeln vorkommen
-- Zweck:		plus alle Objekte, die in den Gruppen dort stecken
-- Parameter1:	Array mit allen Rule_IDs
-- Parameter2:	import_id
-- Parameter3:	tenant-ID des Kunden, fuer den der Report generiert werden soll
-- Parameter3:	wenn NULL: keine Kunden-Filterung: liefere alle Regeln
-- RETURNS:		Tabelle mit einer Spalte (obj_id)
--
CREATE OR REPLACE FUNCTION get_obj_ids_of_filtered_ruleset_flat(INTEGER[], INTEGER, TIMESTAMP) RETURNS SETOF INTEGER AS $$
DECLARE
    ar_rule_ids ALIAS FOR $1;
    i_tenant ALIAS FOR $2;
    t_time ALIAS FOR $3;
    r_rule RECORD;
    r_obj RECORD;
BEGIN
	FOR r_rule IN
		SELECT rule_id FROM rule WHERE rule_id = ANY (ar_rule_ids)
	LOOP
		FOR r_obj IN
			(
				SELECT get_rule_src_flat AS obj_id FROM get_rule_src_flat(r_rule.rule_id,i_tenant,t_time)
				UNION
				SELECT get_rule_dst_flat AS obj_id FROM get_rule_dst_flat(r_rule.rule_id,i_tenant,t_time)
			)
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_obj_ids_of_filtered_management
-- Zweck:		liefert Tabelle mit allen Object-IDs des Managements zurueck,
-- Zweck:		die in den Filterkriterien (tenant und Zeitpunkt) gen�gen
-- Parameter1:	ID des Managements
-- Parameter2:	import_id
-- Parameter3:	tenant-ID des Kunden, fuer den der Report generiert werden soll
-- Parameter3:	wenn NULL: keine Kunden-Filterung: liefere alle Regeln
-- RETURNS:		Tabelle mit einer Spalte (obj_id)
--
CREATE OR REPLACE FUNCTION get_obj_ids_of_filtered_management(INTEGER, INTEGER, INTEGER) RETURNS SETOF INTEGER AS $$
DECLARE
    i_mgm_id ALIAS FOR $1;
    i_import_id ALIAS FOR $2;
    i_tenant ALIAS FOR $3;
    r_obj RECORD;
    v_sql_code VARCHAR;
    v_filter VARCHAR;
BEGIN
	IF NOT i_tenant IS NULL THEN
		v_filter := get_tenant_ip_filter(i_tenant);
		v_sql_code := 'SELECT obj_id FROM object WHERE mgm_id=' || i_mgm_id || ' AND obj_create<=' || i_import_id ||
			' AND obj_last_seen>=' || i_import_id || ' AND ' || v_filter;
--		RAISE NOTICE 'sql_code: %', v_sql_code;
		FOR r_obj IN EXECUTE v_sql_code
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	ELSE 
		FOR r_obj IN 
			SELECT obj_id FROM object WHERE mgm_id=i_mgm_id AND obj_create<=i_import_id AND obj_last_seen>=i_import_id
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	END IF;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_rule_ids
-- Zweck:		liefert Tabelle mit Regel-IDs zurueck, die den Filterkriterien entsprechen
-- Parameter1:	Device-ID dessen Regelsatz untersucht wird (erforderlich)
-- Parameter2:	Zeitpunkt zu dem das Regelwerk angezeigt werden soll
-- Parameter2:	wenn NULL: Zeitpunkt = jetzt (also hoechste vorhandene Import-ID, des Devices)
-- Parameter3:	cidr quell- oder ziel-ip-adresse
-- Parameter4:	cidr quell-ip-adresse
-- Parameter5:	cidr ziel-ip-adresse
-- Parameter6:	int4 protocol type (0-128)
-- Parameter7:	int4 port (tcp/udp)
-- Parameter8:	varchar filter fuer mgm/dev des angemeldeten users
-- RETURNS:		Tabelle mit einer Spalte (rule_id)
--

-- SELECT * FROM get_rule_ids(4,'2007-07-26 18:07', '10.0.0.0/8', NULL, NULL,NULL,NULL) 

/* -- alte Funktion mit tenant-Filter
CREATE OR REPLACE FUNCTION get_rule_ids(int4, "timestamp", int4, cidr, cidr, cidr, int4, int4, VARCHAR)
  RETURNS SETOF int4 AS
$BODY$
DECLARE
    i_device_id ALIAS FOR $1;
    t_in_report_time ALIAS FOR $2;
    i_tenant_id ALIAS FOR $3;
    c_ip_src ALIAS FOR $4;
    c_ip_dst ALIAS FOR $5;
    c_ip_anywhere ALIAS FOR $6;
    i_proto ALIAS FOR $7;
    i_port ALIAS FOR $8;
    v_admin_view_filter ALIAS FOR $9;
    i_relevant_import_id INTEGER;					-- ID des Imports, direkt vor dem Report-Zeitpunkt
    v_tenant_filter_ip_list VARCHAR;				-- Filter-Liste mit allen IP-Bereichen des tenants
    v_tenant_filter_ip_list_negated VARCHAR;		-- Filter-Liste mit allen IP-Bereichen des tenants fuer negierte Faelle
    r_rule RECORD;									-- temp. Variable fuer Rule-ID
    t_report_time TIMESTAMP;						-- Zeitpunkt des Reports (jetzt, wenn t_in_report_time IS NULL)
    v_sql_get_rules_with_tenant_src_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Quellen im tenant-Bereich
    v_sql_get_rules_with_tenant_dst_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Zielen im tenant-Bereich
	v_error_str VARCHAR;
	v_dev_filter VARCHAR; 							-- filter for devices (true for all devices)
	v_import_filter VARCHAR;						-- filter for imports
	v_select_statement VARCHAR;
	v_order_statement VARCHAR;
    v_src_ip_filter VARCHAR;						-- Filter fuer source ip match
    v_dst_ip_filter VARCHAR;						-- Filter fuer destination ip match
BEGIN
--	RAISE NOTICE 'get_rule_ids parameter device_id: %', i_device_id;
--	RAISE NOTICE 'get_rule_ids parameter in_report_time: %', t_in_report_time;
--	v_order_statement := ' ORDER BY dev_id';
	v_order_statement := '';
	IF t_in_report_time IS NULL THEN t_report_time := now(); --	no report time given, assuming now()
	ELSE t_report_time := t_in_report_time; END IF;
	-- set filter: a) import filter, b) device filter
	IF i_device_id IS NULL THEN   -- ueber alle Devices
		v_import_filter := get_previous_import_ids(t_report_time);
		IF v_import_filter = ' () ' THEN v_import_filter := ' FALSE ';
		ELSE v_import_filter := 'rule_order.control_id IN ' || get_previous_import_ids(t_report_time); END IF;
		v_dev_filter := ' TRUE ';
	ELSE 
		i_relevant_import_id := get_previous_import_id(i_device_id, t_report_time);
	    IF i_relevant_import_id IS NULL THEN
			v_error_str := 'device_id: ' || CAST(i_device_id AS VARCHAR) || ', time: ' || CAST(t_report_time AS VARCHAR);
    	    PERFORM error_handling('WARN_NO_IMP_ID_FOUND', v_error_str);
			v_import_filter := ' FALSE ';
		ELSE    	    
			v_import_filter := 'rule_order.control_id = ' || CAST(i_relevant_import_id AS VARCHAR);
		END IF;
		v_dev_filter := 'rule_order.dev_id = ' || CAST(i_device_id AS VARCHAR);
	END IF;
	IF c_ip_src IS NULL THEN v_src_ip_filter := ' TRUE ';
	ELSE v_src_ip_filter := ' (object.obj_ip <<= ' || E'\'' || CAST(c_ip_src AS VARCHAR) || E'\'' || ' OR object.obj_ip >>= ' || E'\'' || CAST(c_ip_src AS VARCHAR) || E'\'' || ') '; END IF;
	IF c_ip_dst IS NULL THEN v_dst_ip_filter := ' TRUE ';
	ELSE v_dst_ip_filter := ' (object.obj_ip <<= ' || E'\'' || CAST(c_ip_dst AS VARCHAR) || E'\'' || ' OR object.obj_ip >>= ' || E'\'' || CAST(c_ip_dst AS VARCHAR) || E'\'' || ') '; END IF;
	IF i_tenant_id IS NULL THEN -- einfacher Fall ohne tenant-Filter
		v_select_statement :=
			' (SELECT rule_id FROM rule_order LEFT JOIN rule USING (rule_id) LEFT JOIN rule_from USING (rule_id) LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat_member_id) ' ||
			' LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id) WHERE ' || v_import_filter || ' AND ' || v_dev_filter ||
			' AND ' || v_src_ip_filter || ' AND ' || v_admin_view_filter || ' AND rule.rule_head_text IS NULL AND NOT rule_disabled AND rule_action<>' ||
			E'\'' || 'drop' || E'\'' || ' AND rule_action<>' ||
			E'\'' || 'reject' || E'\'' || ' AND rule_action<>' || E'\'' || 'deny' || E'\'' || ')' ||
			' INTERSECT ' ||
			' (SELECT rule_id FROM rule_order LEFT JOIN rule USING (rule_id) LEFT JOIN rule_to USING (rule_id) LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat_member_id) ' ||
			' LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id) WHERE ' || v_import_filter || ' AND ' || v_dev_filter ||
			' AND ' || v_dst_ip_filter || ' AND ' || v_admin_view_filter  || ' AND rule.rule_head_text IS NULL AND NOT rule_disabled AND rule_action<>' ||
			E'\'' || 'drop' || E'\'' || ' AND rule_action<>' ||
			E'\'' || 'reject' || E'\'' || ' AND rule_action<>' || E'\'' || 'deny' || E'\'' 
			-- || ' GROUP BY rule_id' 
			|| ')';
	ELSE -- tenant-Filter
		v_tenant_filter_ip_list := get_tenant_ip_filter(i_tenant_id);
		v_tenant_filter_ip_list_negated := get_negated_tenant_ip_filter(i_tenant_id);	
		v_sql_get_rules_with_tenant_src_ips :=
			'(SELECT rule.rule_id FROM rule,rule_order,object,rule_from
			WHERE rule_head_text IS NULL AND rule.rule_id = rule_from.rule_id
				AND ' || v_import_filter || ' AND ' || v_dev_filter || ' AND ' || v_admin_view_filter  ||
				 ' AND rule_order.rule_id=rule.rule_id
				AND (((' || v_tenant_filter_ip_list || ') AND NOT rule.rule_src_neg) OR ((' ||
				v_tenant_filter_ip_list_negated || ') AND rule.rule_src_neg))' ||
				' AND (rule.rule_id,object.obj_id) IN
				(
					SELECT rule.rule_id,object.obj_id FROM rule_order,rule,rule_from,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule_head_text IS NULL AND rule.rule_id = rule_from.rule_id
					AND ' || v_src_ip_filter || '
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND ' || v_admin_view_filter  || ' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_from.obj_id
				UNION
					SELECT rule.rule_id,objgrp_flat.objgrp_flat_member_id FROM rule_order,rule,rule_from,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule_head_text IS NULL AND rule.rule_id = rule_from.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND ' || v_admin_view_filter  || ' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_from.obj_id
				)
			)';
		v_sql_get_rules_with_tenant_dst_ips :=
			'(SELECT rule.rule_id FROM rule,rule_order,object,rule_to WHERE rule.rule_id = rule_to.rule_id
				AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND ' || v_admin_view_filter  || ' AND rule_order.rule_id=rule.rule_id
	            AND (((' || v_tenant_filter_ip_list || ') AND NOT rule.rule_dst_neg) OR ((' ||
    	        v_tenant_filter_ip_list_negated || ') AND rule.rule_dst_neg))' ||
				' AND (rule.rule_id,object.obj_id) in
				(
					SELECT rule.rule_id,object.obj_id FROM rule_order,rule,rule_to,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule_head_text IS NULL AND rule.rule_id = rule_to.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND ' || v_admin_view_filter  || ' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_to.obj_id
					UNION
					SELECT rule.rule_id,objgrp_flat.objgrp_flat_member_id FROM rule_order,rule,rule_to,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule_head_text IS NULL AND rule.rule_id = rule_to.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND ' || v_admin_view_filter  || ' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_to.obj_id
				)
			)';
		v_select_statement := 'SELECT rule_id FROM rule_order WHERE rule_id IN (' || v_sql_get_rules_with_tenant_src_ips 
			|| ' UNION ' ||	v_sql_get_rules_with_tenant_dst_ips || ') ' || ' GROUP BY rule_order.rule_id ';
	END IF; -- tenant_filter set

--	RAISE warning 'get_rule_ids select: %', v_select_statement;
	FOR r_rule IN EXECUTE v_select_statement	
	LOOP
		RETURN NEXT r_rule.rule_id;
	END LOOP;
	RETURN;
END;
$BODY$ LANGUAGE plpgsql;

*/

CREATE OR REPLACE FUNCTION get_rule_ids_no_tenant_filter(int4, "timestamp", cidr, cidr, cidr, int4, int4, VARCHAR)
  RETURNS SETOF int4 AS
$BODY$
DECLARE
    i_device_id ALIAS FOR $1;
    t_in_report_time ALIAS FOR $2;
--    i_tenant_id ALIAS FOR $3;
    c_ip_src ALIAS FOR $3;
    c_ip_dst ALIAS FOR $4;
    c_ip_anywhere ALIAS FOR $5;
    i_proto ALIAS FOR $6;
    i_port ALIAS FOR $7;
    v_admin_view_filter ALIAS FOR $8;
    i_relevant_import_id INTEGER;					-- ID des Imports, direkt vor dem Report-Zeitpunkt
    v_tenant_filter_ip_list VARCHAR;				-- Filter-Liste mit allen IP-Bereichen des tenants
    v_tenant_filter_ip_list_negated VARCHAR;		-- Filter-Liste mit allen IP-Bereichen des tenants fuer negierte Faelle
    r_rule RECORD;									-- temp. Variable fuer Rule-ID
    t_report_time TIMESTAMP;						-- Zeitpunkt des Reports (jetzt, wenn t_in_report_time IS NULL)
    v_sql_get_rules_with_tenant_src_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Quellen im tenant-Bereich
    v_sql_get_rules_with_tenant_dst_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Zielen im tenant-Bereich
	v_error_str VARCHAR;
	v_dev_filter VARCHAR; 							-- filter for devices (true for all devices)
	v_import_filter VARCHAR;						-- filter for imports
	v_select_statement VARCHAR;
	v_order_statement VARCHAR;
    v_src_ip_filter VARCHAR;						-- Filter fuer source ip match
    v_dst_ip_filter VARCHAR;						-- Filter fuer destination ip match
BEGIN
	v_order_statement := '';
	IF t_in_report_time IS NULL THEN t_report_time := now(); --	no report time given, assuming now()
	ELSE t_report_time := t_in_report_time; END IF;
	-- set filter: a) import filter, b) device filter
	IF i_device_id IS NULL THEN   -- ueber alle Devices
		v_import_filter := get_previous_import_ids(t_report_time);
		IF v_import_filter = ' () ' THEN v_import_filter := ' FALSE ';
		ELSE v_import_filter := 'rule_order.control_id IN ' || get_previous_import_ids(t_report_time); END IF;
		v_dev_filter := ' TRUE ';
	ELSE 
		i_relevant_import_id := get_previous_import_id(i_device_id, t_report_time);
	    IF i_relevant_import_id IS NULL THEN
			v_error_str := 'device_id: ' || CAST(i_device_id AS VARCHAR) || ', time: ' || CAST(t_report_time AS VARCHAR);
    	    PERFORM error_handling('WARN_NO_IMP_ID_FOUND', v_error_str);
			v_import_filter := ' FALSE ';
		ELSE    	    
			v_import_filter := 'rule_order.control_id = ' || CAST(i_relevant_import_id AS VARCHAR);
		END IF;
		v_dev_filter := 'rule_order.dev_id = ' || CAST(i_device_id AS VARCHAR);
	END IF;
	IF c_ip_src IS NULL THEN v_src_ip_filter := ' TRUE ';
	ELSE v_src_ip_filter := ' (object.obj_ip <<= ' || E'\'' || CAST(c_ip_src AS VARCHAR) || E'\'' || ' OR object.obj_ip >>= ' || E'\'' || CAST(c_ip_src AS VARCHAR) || E'\'' || ') '; END IF;
	IF c_ip_dst IS NULL THEN v_dst_ip_filter := ' TRUE ';
	ELSE v_dst_ip_filter := ' (object.obj_ip <<= ' || E'\'' || CAST(c_ip_dst AS VARCHAR) || E'\'' || ' OR object.obj_ip >>= ' || E'\'' || CAST(c_ip_dst AS VARCHAR) || E'\'' || ') '; END IF;
	v_select_statement :=
		' (SELECT rule_id FROM rule_order LEFT JOIN rule USING (rule_id) LEFT JOIN rule_from USING (rule_id) LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat_member_id) ' ||
		' LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id) WHERE ' || v_import_filter || ' AND ' || v_dev_filter ||
		' AND ' || v_src_ip_filter || ' AND ' || v_admin_view_filter || ' AND rule.rule_head_text IS NULL AND NOT rule_disabled AND rule_action<>' ||
		E'\'' || 'drop' || E'\'' || ' AND rule_action<>' ||
		E'\'' || 'reject' || E'\'' || ' AND rule_action<>' || E'\'' || 'deny' || E'\'' || ')' ||
		' INTERSECT ' ||
		' (SELECT rule_id FROM rule_order LEFT JOIN rule USING (rule_id) LEFT JOIN rule_to USING (rule_id) LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat_member_id) ' ||
		' LEFT JOIN object ON (objgrp_flat_member_id=object.obj_id) WHERE ' || v_import_filter || ' AND ' || v_dev_filter ||
		' AND ' || v_dst_ip_filter || ' AND ' || v_admin_view_filter  || ' AND rule.rule_head_text IS NULL AND NOT rule_disabled AND rule_action<>' ||
		E'\'' || 'drop' || E'\'' || ' AND rule_action<>' ||
		E'\'' || 'reject' || E'\'' || ' AND rule_action<>' || E'\'' || 'deny' || E'\'' 
		-- || ' GROUP BY rule_id' 
		|| ')';
	FOR r_rule IN EXECUTE v_select_statement	
	LOOP
		RETURN NEXT r_rule.rule_id;
	END LOOP;
	RETURN;
END;
$BODY$ LANGUAGE plpgsql;
----------------------------------------------------
-- FUNCTION:	get_rule_ids
-- Zweck:		liefert Tabelle mit Regel-IDs zurueck, die den Filterkriterien entsprechen
-- Used for:	Account (Usage) Report
-- Parameter1:	Device-ID dessen Regelsatz untersucht wird (erforderlich)
-- Parameter2:	Zeitpunkt zu dem das Regelwerk angezeigt werden soll
-- Parameter2:	wenn NULL: Zeitpunkt = jetzt (also hoechste vorhandene Import-ID, des Devices)
-- Parameter3:	tenant-ID des Kunden, fuer den der Report generiert werden soll
-- Parameter3:	wenn NULL: keine Kunden-Filterung: liefere alle Regeln
-- Parameter4:	Filter resultierend aus Einschraenkungen des angemeldeten Benutzers (SQL as Text)
-- RETURNS:		Tabelle mit einer Spalte (rule_id)

CREATE OR REPLACE FUNCTION get_rule_ids(int4, "timestamp", int4, VARCHAR) RETURNS SETOF int4 AS
$BODY$
DECLARE
    i_device_id ALIAS FOR $1;
    t_in_report_time ALIAS FOR $2;
    i_tenant_id ALIAS FOR $3;
    v_admin_view_filter ALIAS FOR $4;
    i_relevant_import_id INTEGER;					-- ID des Imports, direkt vor dem Report-Zeitpunkt
    v_tenant_filter_ip_list VARCHAR;				-- Filter-Liste mit allen IP-Bereichen des tenants
    v_tenant_filter_ip_list_negated VARCHAR;		-- Filter-Liste mit allen IP-Bereichen des tenants fuer negierte Faelle
    r_rule RECORD;									-- temp. Variable fuer Rule-ID
    t_report_time TIMESTAMP;						-- Zeitpunkt des Reports (jetzt, wenn t_in_report_time IS NULL)
    v_sql_get_rules_with_tenant_src_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Quellen im tenant-Bereich
    v_sql_get_rules_with_tenant_dst_ips VARCHAR;	-- SQL-Code zum Holen der Rule-IDs mit Zielen im tenant-Bereich
	v_error_str VARCHAR;
	v_dev_filter VARCHAR; 							-- filter for devices (true for all devices)
	v_import_filter VARCHAR;						-- filter for imports
	v_select_statement VARCHAR;
	v_order_statement VARCHAR;
BEGIN
--	RAISE NOTICE 'get_rule_ids parameter device_id: %', i_device_id;
--	RAISE NOTICE 'get_rule_ids parameter in_report_time: %', t_in_report_time;
--	v_order_statement := ' ORDER BY dev_id, rule_number ';
	v_order_statement := '';
	IF t_in_report_time IS NULL THEN --	no report time given, assuming now()
		t_report_time := now();
	ELSE
		t_report_time := t_in_report_time;
	END IF;
	-- set filter: a) import filter, b) device filter
	IF i_device_id IS NULL THEN   -- ueber alle Devices
		v_import_filter := get_previous_import_ids(t_report_time);
		IF v_import_filter = ' () ' THEN
			v_import_filter := ' FALSE ';
		ELSE
			v_import_filter := 'rule_order.control_id IN ' ||  get_previous_import_ids(t_report_time);
		END IF;
		v_dev_filter := ' TRUE ';
	ELSE 
		i_relevant_import_id := get_previous_import_id(i_device_id, t_report_time);
	    IF i_relevant_import_id IS NULL THEN
			v_error_str := 'device_id: ' || CAST(i_device_id AS VARCHAR) || ', time: ' || CAST(t_report_time AS VARCHAR);
    	    PERFORM error_handling('WARN_NO_IMP_ID_FOUND', v_error_str);
			v_import_filter := ' FALSE ';
		ELSE    	    
			v_import_filter := 'rule_order.control_id = ' || CAST(i_relevant_import_id AS VARCHAR);
		END IF;
		v_dev_filter := 'rule_order.dev_id = ' || CAST(i_device_id AS VARCHAR);
	END IF;
	IF i_tenant_id IS NULL THEN -- einfacher Fall ohne tenant-Filter
		v_select_statement := 'SELECT rule_id FROM rule_order INNER JOIN device USING (dev_id) INNER JOIN management USING (mgm_id) WHERE ' || v_import_filter
			|| ' AND ' || v_dev_filter || ' AND ' || v_admin_view_filter || v_order_statement;
	ELSE -- tenant-Filter
		v_tenant_filter_ip_list := get_tenant_ip_filter(i_tenant_id);
		v_tenant_filter_ip_list_negated := get_negated_tenant_ip_filter(i_tenant_id);	
		v_sql_get_rules_with_tenant_src_ips :=
			'(SELECT rule.rule_id FROM rule, rule_order, object,rule_from
			WHERE rule.rule_id = rule_from.rule_id
				AND ' || v_import_filter || ' AND ' || v_dev_filter ||
				 ' AND rule_order.rule_id=rule.rule_id
				AND (((' || v_tenant_filter_ip_list || ') AND NOT rule.rule_src_neg) OR ((' ||
				v_tenant_filter_ip_list_negated || ') AND rule.rule_src_neg))' ||
				' AND (rule.rule_id,object.obj_id) IN
				(
					SELECT rule.rule_id,object.obj_id FROM rule_order,rule,rule_from,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule.rule_id = rule_from.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || 
					' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_from.obj_id
				UNION
					SELECT rule.rule_id,objgrp_flat.objgrp_flat_member_id FROM rule_order,rule,rule_from,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule.rule_id = rule_from.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || 
					' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_from.obj_id
				)
			)';
		v_sql_get_rules_with_tenant_dst_ips :=
			'(SELECT rule.rule_id FROM rule,rule_order,object,rule_to WHERE rule.rule_id = rule_to.rule_id
				AND ' || v_import_filter || ' AND  ' || v_dev_filter || ' AND rule_order.rule_id=rule.rule_id
	            AND (((' || v_tenant_filter_ip_list || ') AND NOT rule.rule_dst_neg) OR ((' ||
    	        v_tenant_filter_ip_list_negated || ') AND rule.rule_dst_neg))' ||
				' AND (rule.rule_id,object.obj_id) in
				(
					SELECT rule.rule_id,object.obj_id FROM rule_order,rule,rule_to,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule.rule_id = rule_to.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter || 
					' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_to.obj_id
					UNION
					SELECT rule.rule_id,objgrp_flat.objgrp_flat_member_id FROM rule_order,rule,rule_to,object
					LEFT JOIN objgrp_flat ON objgrp_flat_id=object.obj_id
					WHERE rule.rule_id = rule_to.rule_id
					AND ' || v_import_filter || ' AND  ' || v_dev_filter ||
					' AND rule_order.rule_id=rule.rule_id AND object.obj_id=rule_to.obj_id
				)	
			)';
		v_select_statement := 'SELECT rule_id FROM rule_order LEFT JOIN device USING (dev_id) LEFT JOIN management USING (mgm_id) WHERE rule_id IN (' || v_sql_get_rules_with_tenant_src_ips 
			|| ' UNION ' ||	v_sql_get_rules_with_tenant_dst_ips || ')' || ' AND ' || v_admin_view_filter || v_order_statement
			|| ' GROUP BY rule_order.rule_id ';
	END IF; -- tenant_filter set

--	RAISE NOTICE 'get_rule_ids select: %', v_select_statement;
	FOR r_rule IN EXECUTE v_select_statement	
	LOOP
		RETURN NEXT r_rule.rule_id;
	END LOOP;
	RETURN;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;

  
CREATE OR REPLACE FUNCTION get_rule_ids_no_tenant_filter(int4, "timestamp", VARCHAR) RETURNS SETOF int4 AS
$BODY$
DECLARE
    i_device_id ALIAS FOR $1;
    t_in_report_time ALIAS FOR $2;
    v_admin_view_filter ALIAS FOR $3;
    i_relevant_import_id INTEGER;					-- ID des Imports, direkt vor dem Report-Zeitpunkt
    r_rule RECORD;									-- temp. Variable fuer Rule-ID
    t_report_time TIMESTAMP;						-- Zeitpunkt des Reports (jetzt, wenn t_in_report_time IS NULL)
 	v_error_str VARCHAR;
	v_dev_filter VARCHAR; 							-- filter for devices (true for all devices)
	v_import_filter VARCHAR;						-- filter for imports
	v_select_statement VARCHAR;
	v_order_statement VARCHAR;
BEGIN
	v_order_statement := '';
	IF t_in_report_time IS NULL THEN --	no report time given, assuming now()
		t_report_time := now();
	ELSE
		t_report_time := t_in_report_time;
	END IF;
	-- set filter: a) import filter, b) device filter
	IF i_device_id IS NULL THEN   -- ueber alle Devices
		v_import_filter := get_previous_import_ids(t_report_time);
		IF v_import_filter = ' () ' THEN
			v_import_filter := ' FALSE ';
		ELSE
			v_import_filter := 'rule_order.control_id IN ' ||  get_previous_import_ids(t_report_time);
		END IF;
		v_dev_filter := ' TRUE ';
	ELSE 
		i_relevant_import_id := get_previous_import_id(i_device_id, t_report_time);
		IF i_relevant_import_id IS NULL THEN
			v_error_str := 'device_id: ' || CAST(i_device_id AS VARCHAR) || ', time: ' || CAST(t_report_time AS VARCHAR);
			PERFORM error_handling('WARN_NO_IMP_ID_FOUND', v_error_str);
			v_import_filter := ' FALSE ';
		ELSE    	    
			v_import_filter := 'rule_order.control_id = ' || CAST(i_relevant_import_id AS VARCHAR);
		END IF;
		v_dev_filter := 'rule_order.dev_id = ' || CAST(i_device_id AS VARCHAR);
	END IF;
	v_select_statement := 'SELECT rule_id FROM rule_order INNER JOIN device USING (dev_id) INNER JOIN management USING (mgm_id) WHERE ' || v_import_filter
		|| ' AND ' || v_dev_filter || ' AND ' || v_admin_view_filter || v_order_statement;
	FOR r_rule IN EXECUTE v_select_statement	
	LOOP
		RETURN NEXT r_rule.rule_id;
	END LOOP;
	RETURN;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;

CREATE OR REPLACE FUNCTION get_import_ids_for_time (TIMESTAMP) RETURNS SETOF INTEGER AS $$
DECLARE
    t_import_time	ALIAS FOR $1;
	r_mgm			RECORD;
	i_ctrl_id		INTEGER;
BEGIN
	FOR r_mgm IN
		SELECT mgm_id FROM management
	LOOP
		SELECT INTO i_ctrl_id MAX(control_id) FROM import_control WHERE mgm_id=r_mgm.mgm_id
			AND start_time<=t_import_time AND NOT stop_time IS NULL AND successful_import;
		IF FOUND AND NOT i_ctrl_id IS NULL THEN 
--			RAISE NOTICE 'ctrl_id found: %', i_ctrl_id;
			RETURN NEXT i_ctrl_id;
		END IF;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	rule_src_contains_tenant_obj
-- Zweck:		prueft, ob in den Quellen ein Objekt enthalten ist, das zum Kunden-Dunstkreis gehoert
-- Parameter1:	rule_id
-- Parameter2:	id des relevanten Imports
-- Parameter3:	tenant_id fuer Filterung innerhalb der Regel
-- RETURNS:		wahr, wenn in den Quellen der Regeln ein tenant-relevantes Objekt enthalten ist
--
CREATE OR REPLACE FUNCTION rule_src_contains_tenant_obj (BIGINT, INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    i_rule_id ALIAS FOR $1;
--    i_import_id ALIAS FOR $2;
    i_tenant_id ALIAS FOR $2;
    r_obj	RECORD; -- object
	v_tenant_ip_filter VARCHAR;
BEGIN
	IF is_rule_src_negated(i_rule_id) THEN
		v_tenant_ip_filter := get_negated_tenant_ip_filter(i_tenant_id);
	ELSE
		v_tenant_ip_filter := get_tenant_ip_filter(i_tenant_id);
	END IF;
--	CREATE TEMPORARY TABLE obj_id_table (id INTEGER);
--	INSERT INTO obj_id_table SELECT get_exploded_src_of_rule AS id FROM get_exploded_src_of_rule(i_rule_id);
	FOR r_obj IN EXECUTE
		'SELECT obj_id FROM object WHERE (obj_id IN (SELECT * FROM get_exploded_src_of_rule(' || 
		CAST(i_rule_id AS VARCHAR) || '))) AND (' || v_tenant_ip_filter || ')'
--		CAST(i_rule_id AS VARCHAR) || ',' || CAST(i_import_id AS VARCHAR) || '))) AND (' || v_tenant_ip_filter || ')'
	LOOP
--		RAISE INFO 'obj: %', r_obj.obj_id;
		RETURN TRUE;
	END LOOP;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- version ohne import_id
-- FUNCTION:	rule_dst_contains_tenant_obj
-- Zweck:		prueft, ob in den Zielen ein Objekt enthalten ist, das zum Kunden-Dunstkreis gehoert
-- Parameter1:	rule_id
-- Parameter2:	tenant_id fuer Filterung innerhalb der Regel
-- RETURNS:		wahr, wenn in den Zielen der Regeln ein tenant-relevantes Objekt enthalten ist
--
CREATE OR REPLACE FUNCTION rule_dst_contains_tenant_obj (BIGINT, INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    i_rule_id ALIAS FOR $1;
    i_tenant_id ALIAS FOR $2;
    r_rule	RECORD; -- rule to be returned
	v_tenant_ip_filter VARCHAR;
BEGIN
	IF is_rule_dst_negated(i_rule_id) THEN
		v_tenant_ip_filter := get_negated_tenant_ip_filter(i_tenant_id);
	ELSE
		v_tenant_ip_filter := get_tenant_ip_filter(i_tenant_id);
	END IF;
	FOR r_rule IN EXECUTE
		'SELECT obj_id FROM object WHERE (obj_id IN (SELECT * FROM get_exploded_dst_of_rule(' || 
		CAST(i_rule_id AS VARCHAR) || '))) AND (' || v_tenant_ip_filter || ')'
	LOOP
		RETURN TRUE;
	END LOOP;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	obj_belongs_to_tenant
-- Zweck:		prueft, ob das NW-Objekt zum tenant-Bereich gehoert
-- Parameter1:	obj_id
-- Parameter2:	tenant_id
-- RETURNS:		wahr, wenn object zum tenant mit tenant_id gehoert
--
CREATE OR REPLACE FUNCTION obj_belongs_to_tenant (BIGINT, INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    i_obj_id ALIAS FOR $1;
    i_tenant_id ALIAS FOR $2;
    r_obj	RECORD;				-- zu pruefendes Objekt
	v_tenant_filter_ip_list VARCHAR;
BEGIN
	v_tenant_filter_ip_list := get_tenant_ip_filter(i_tenant_id);
--	RAISE INFO 'tenant: %', i_tenant_id;
--	RAISE INFO 'tenant_filter: %', v_tenant_filter_ip_list;
	FOR r_obj IN EXECUTE
		'SELECT obj_id FROM object WHERE (obj_id IN (SELECT * FROM explode_objgrp(' || i_obj_id ||
		'))) AND ('|| v_tenant_filter_ip_list || ')'
	LOOP
--		RAISE INFO 'obj: %', r_obj.obj_id;
		RETURN TRUE;
	END LOOP;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	obj_neg_belongs_to_tenant
-- Zweck:		prueft, ob die Negation des NW-Objekts zum tenant-Bereich gehoert
-- Parameter1:	obj_id
-- Parameter2:	tenant_id
-- RETURNS:		wahr, wenn das Komplement von object zum tenant mit tenant_id gehoert
--
CREATE OR REPLACE FUNCTION obj_neg_belongs_to_tenant (BIGINT, INTEGER) RETURNS BOOLEAN AS $$
DECLARE
    i_obj_id ALIAS FOR $1;
    i_tenant_id ALIAS FOR $2;
    r_obj	RECORD;				-- zu pruefendes Objekt
	v_tenant_filter_ip_list_neg VARCHAR;
BEGIN
	v_tenant_filter_ip_list_neg := get_negated_tenant_ip_filter(i_tenant_id);
	FOR r_obj IN EXECUTE
		'SELECT obj_id FROM object WHERE (obj_id IN (SELECT * FROM explode_objgrp(' || i_obj_id ||
		'))) AND ('|| v_tenant_filter_ip_list_neg || ')'
	LOOP
		RETURN TRUE;
	END LOOP;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	flatten_obj_list
-- Zweck:		gibt zu einer Liste von Objek-IDs die aufgeloeste Liste zurueck
-- Zweck:       die auch alle Mitglieder enthaelt
-- Parameter1:	Array of Object-IDs
-- RETURNS:		Array of Object-IDs
--
CREATE OR REPLACE FUNCTION flatten_obj_list (BIGINT[]) RETURNS BIGINT[] AS $$
DECLARE
    ar_obj_ids ALIAS FOR $1;
    r_obj	RECORD;
    ar_obj_ids_result INTEGER[];
	i INTEGER;
	i_array_size INTEGER;
BEGIN
	ar_obj_ids_result := '{}';
	i_array_size := array_upper(ar_obj_ids,1);
	FOR i IN 0..i_array_size-1 LOOP
		ar_obj_ids_result := array_append(ar_obj_ids_result, ar_obj_ids[i]);
		FOR r_obj IN
	   		SELECT objgrp_flat_member_id FROM objgrp_flat WHERE objgrp_flat_id=ar_obj_ids[i]
		LOOP
			ar_obj_ids_result := array_append(ar_obj_ids_result, r_obj.objgrp_flat_member_id);
		END LOOP;
	END LOOP;
	RETURN ar_obj_ids_result;
END;
$$ LANGUAGE plpgsql;


----------------------------------------------------
-- FUNCTION:	get_rule_src
-- Zweck:		liefert alle Quellen der Regel als setof zurueck
-- Parameter1:	rule_id
-- Parameter2:	tenant_id fuer Filterung innerhalb der Regel
-- Parameter3:	Zeitpunkt
-- RETURNS:		Tabelle mit allen src-obj_ids der Regel fuer Report
--
CREATE OR REPLACE FUNCTION get_rule_src (BIGINT, INTEGER, TIMESTAMP) RETURNS SETOF BIGINT AS $$
DECLARE
    i_rule_id		ALIAS FOR $1;
    i_tenant_id		ALIAS FOR $2;
    t_time			ALIAS FOR $3;
    r_obj			RECORD; -- temp. object
    i_import_id		INTEGER;
    i_mgm_id		INTEGER;
BEGIN
	SELECT INTO i_mgm_id device.mgm_id FROM rule_order LEFT JOIN device USING (dev_id) WHERE rule_id=i_rule_id LIMIT 1;
	i_import_id := get_import_id_for_mgmt_at_time(i_mgm_id,t_time);
	IF i_tenant_id IS NULL THEN
--		RAISE NOTICE 'import: %', i_import_id;
		FOR r_obj IN
   			SELECT obj_id FROM rule,rule_from WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND
				rule.rule_id=rule_from.rule_id AND rule.rule_id=i_rule_id
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	ELSE
		-- do the filtering	
		IF rule_dst_contains_tenant_obj(i_rule_id, i_tenant_id) THEN -- alle Quellen anzeigen
			FOR r_obj IN
	   			SELECT obj_id FROM rule,rule_from WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND
					rule.rule_id=rule_from.rule_id AND rule.rule_id=i_rule_id
			LOOP
				RETURN NEXT r_obj.obj_id;
			END LOOP;
		ELSE -- filtern - nur tenant-Objekte anzeigen
			IF is_rule_src_negated(i_rule_id) THEN
				FOR r_obj IN
		   			SELECT obj_id FROM rule,rule_from WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND
						rule.rule_id=rule_from.rule_id AND rule.rule_id=i_rule_id
				LOOP
					IF obj_neg_belongs_to_tenant(r_obj.obj_id, i_tenant_id) THEN
						RETURN NEXT r_obj.obj_id;
					END IF;
				END LOOP;
			ELSE
				FOR r_obj IN
		   			SELECT obj_id FROM rule,rule_from WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND
						rule.rule_id=rule_from.rule_id AND rule.rule_id=i_rule_id
				LOOP
					IF obj_belongs_to_tenant(r_obj.obj_id, i_tenant_id) THEN
						RETURN NEXT r_obj.obj_id;
					END IF;
				END LOOP;
			END IF;
		END IF;
	END IF;
	RETURN;
END;
$$ LANGUAGE plpgsql;

----------------------------------------------------
-- FUNCTION:	get_rule_dst
-- Zweck:		liefert alle Ziele der Regel als setof zurueck
-- Parameter1:	rule_id
-- Parameter2:	relevante import id
-- Parameter3:	tenant_id fuer Filterung innerhalb der Regel
-- RETURNS:		Tabele mit allen dst-obj_ids der Regel fuer Report
--
-- CREATE OR REPLACE FUNCTION get_rule_dst (BIGINT, INTEGER, INTEGER) RETURNS SETOF INTEGER AS $$
CREATE OR REPLACE FUNCTION get_rule_dst (BIGINT, INTEGER, TIMESTAMP) RETURNS SETOF BIGINT AS $$
DECLARE
    i_rule_id	ALIAS FOR $1;
    i_tenant_id ALIAS FOR $2;
    t_time		ALIAS FOR $3;
    i_import_id INTEGER;
    r_obj	RECORD; -- rule to be returned
    i_mgm_id		INTEGER;
BEGIN
	SELECT INTO i_mgm_id device.mgm_id FROM rule_order LEFT JOIN device USING (dev_id) WHERE rule_id=i_rule_id LIMIT 1;
	i_import_id := get_import_id_for_mgmt_at_time(i_mgm_id,t_time);
	IF i_tenant_id IS NULL THEN
		FOR r_obj IN
   			SELECT obj_id FROM rule,rule_to WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND
				rule.rule_id=rule_to.rule_id AND rule.rule_id=i_rule_id
		LOOP
			RETURN NEXT r_obj.obj_id;
		END LOOP;
	ELSE -- do the filtering	
		IF rule_src_contains_tenant_obj(i_rule_id, i_tenant_id) THEN -- alle Quellen anzeigen
			FOR r_obj IN
	   			SELECT obj_id FROM rule,rule_to WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND
					rule.rule_id=rule_to.rule_id AND rule.rule_id=i_rule_id
			LOOP
				RETURN NEXT r_obj.obj_id;
			END LOOP;
		ELSE -- filtern - nur tenant-Objekte anzeigen
			IF is_rule_dst_negated(i_rule_id) THEN
				FOR r_obj IN
		   			SELECT obj_id FROM rule,rule_to WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND
						rule.rule_id=rule_to.rule_id AND rule.rule_id=i_rule_id
				LOOP
					IF obj_neg_belongs_to_tenant(r_obj.obj_id, i_tenant_id) THEN
						RETURN NEXT r_obj.obj_id;
					END IF;
				END LOOP;
			ELSE
				FOR r_obj IN
		   			SELECT obj_id FROM rule,rule_to WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND
						rule.rule_id=rule_to.rule_id AND rule.rule_id=i_rule_id
				LOOP
					IF obj_belongs_to_tenant(r_obj.obj_id, i_tenant_id) THEN
						RETURN NEXT r_obj.obj_id;
					END IF;
				END LOOP;
			END IF;
		END IF;
	END IF;
	RETURN;
END;
$$ LANGUAGE plpgsql;



----------------------------------------------------
-- FUNCTION:	get_rule_src_flat
-- Zweck:		liefert alle Quellen (und deren Gruppen-Mitglieder) der Regel als setof zurueck
-- Parameter1:	rule_id
-- Parameter2:	tenant_id fuer Filterung innerhalb der Regel
-- Parameter3:	Zeitpunkt
-- RETURNS:		Tabelle mit allen src-obj_ids der Regel fuer Report
--
-- Function: get_rule_src(integer, integer, timestamp without time zone)

-- DROP FUNCTION get_rule_src(integer, integer, timestamp without time zone);

CREATE OR REPLACE FUNCTION get_rule_src_flat (BIGINT, integer, timestamp without time zone)
  RETURNS SETOF integer AS
$BODY$
DECLARE
    i_rule_id		ALIAS FOR $1;
    i_tenant_id		ALIAS FOR $2;
    t_time			ALIAS FOR $3;
    r_obj			RECORD; -- temp. object
    i_import_id		INTEGER;
    i_mgm_id		INTEGER;
BEGIN
	SELECT INTO i_mgm_id device.mgm_id FROM rule_order LEFT JOIN device USING (dev_id) WHERE rule_id=i_rule_id LIMIT 1;
	i_import_id := get_import_id_for_mgmt_at_time(i_mgm_id,t_time);
	IF i_tenant_id IS NULL OR rule_dst_contains_tenant_obj(i_rule_id, i_tenant_id) THEN
--		RAISE NOTICE 'import: %', i_import_id;
		FOR r_obj IN
			SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_from USING (rule_id) 
			LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat.objgrp_flat_id) 
			WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND rule.rule_id=i_rule_id
		LOOP
			RETURN NEXT r_obj.objgrp_flat_member_id;
		END LOOP;
	ELSE -- filtern - nur tenant-Objekte anzeigen
		IF is_rule_src_negated(i_rule_id) THEN
			FOR r_obj IN
				SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_from USING (rule_id) 
				LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat.objgrp_flat_id) 
				WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND rule.rule_id=i_rule_id
			LOOP
				IF obj_neg_belongs_to_tenant(r_obj.objgrp_flat_member_id, i_tenant_id) THEN
					RETURN NEXT r_obj.objgrp_flat_member_id;
				END IF;
			END LOOP;
		ELSE
			FOR r_obj IN
				SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_from USING (rule_id) 
				LEFT JOIN objgrp_flat ON (rule_from.obj_id=objgrp_flat.objgrp_flat_id) 
				WHERE rf_last_seen>=i_import_id AND rf_create<=i_import_id AND rule.rule_id=i_rule_id
			LOOP
				IF obj_belongs_to_tenant(r_obj.objgrp_flat_member_id, i_tenant_id) THEN
					RETURN NEXT r_obj.objgrp_flat_member_id;
				END IF;
			END LOOP;
		END IF;
	END IF;
	RETURN;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100
  ROWS 1000;

----------------------------------------------------
-- FUNCTION:	get_rule_dst_flat
-- Zweck:		liefert alle Ziele der Regel (und alle Gruppenmitglieder davon) als setof zurueck
-- Parameter1:	rule_id
-- Parameter2:	relevante import id
-- Parameter3:	tenant_id fuer Filterung innerhalb der Regel
-- RETURNS:		Tabele mit allen dst-obj_ids der Regel fuer Report
--
-- CREATE OR REPLACE FUNCTION get_rule_dst_flat (INTEGER, INTEGER, INTEGER) RETURNS SETOF INTEGER AS $$
-- Function: get_rule_src(integer, integer, timestamp without time zone)

-- DROP FUNCTION get_rule_src(integer, integer, timestamp without time zone);

CREATE OR REPLACE FUNCTION get_rule_dst_flat (BIGINT, integer, timestamp without time zone)
  RETURNS SETOF integer AS
$BODY$
DECLARE
    i_rule_id		ALIAS FOR $1;
    i_tenant_id		ALIAS FOR $2;
    t_time			ALIAS FOR $3;
    r_obj			RECORD; -- temp. object
    i_import_id		INTEGER;
    i_mgm_id		INTEGER;
BEGIN
	SELECT INTO i_mgm_id device.mgm_id FROM rule_order LEFT JOIN device USING (dev_id) WHERE rule_id=i_rule_id LIMIT 1;
	i_import_id := get_import_id_for_mgmt_at_time(i_mgm_id,t_time);
	IF i_tenant_id IS NULL OR rule_src_contains_tenant_obj(i_rule_id, i_tenant_id) THEN
--		RAISE NOTICE 'import: %', i_import_id;
		FOR r_obj IN
			SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_to USING (rule_id) 
			LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat.objgrp_flat_id) 
			WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND rule.rule_id=i_rule_id
		LOOP
			RETURN NEXT r_obj.objgrp_flat_member_id;
		END LOOP;
	ELSE -- filtern - nur tenant-Objekte anzeigen
		IF is_rule_dst_negated(i_rule_id) THEN
			FOR r_obj IN
				SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_to USING (rule_id) 
				LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat.objgrp_flat_id) 
				WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND rule.rule_id=i_rule_id
			LOOP
				IF obj_neg_belongs_to_tenant(r_obj.objgrp_flat_member_id, i_tenant_id) THEN
					RETURN NEXT r_obj.objgrp_flat_member_id;
				END IF;
			END LOOP;
		ELSE
			FOR r_obj IN
				SELECT objgrp_flat_member_id FROM rule LEFT JOIN rule_to USING (rule_id) 
				LEFT JOIN objgrp_flat ON (rule_to.obj_id=objgrp_flat.objgrp_flat_id) 
				WHERE rt_last_seen>=i_import_id AND rt_create<=i_import_id AND rule.rule_id=i_rule_id
			LOOP
				IF obj_belongs_to_tenant(r_obj.objgrp_flat_member_id, i_tenant_id) THEN
					RETURN NEXT r_obj.objgrp_flat_member_id;
				END IF;
			END LOOP;
		END IF;
	END IF;
	RETURN;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE
  COST 100
  ROWS 1000;

-- Function: get_changed_newrules(refcursor, _int4)

-- DROP FUNCTION get_changed_newrules(refcursor, _int4);

CREATE OR REPLACE FUNCTION get_changed_newrules(refcursor, _int4)
  RETURNS refcursor AS
$BODY$
DECLARE
    cursor_result ALIAS FOR $1;
	log_rule_ids ALIAS FOR $2;
    BEGIN
	OPEN cursor_result FOR
		SELECT changelog_rule.*, rule.rule_num,rule.rule_id,action_name,track_name,from_zone.zone_name,to_zone.zone_name,rule.*
		FROM changelog_rule,stm_track,stm_action,rule
			LEFT JOIN zone as from_zone ON rule.rule_from_zone=from_zone.zone_id
			LEFT JOIN zone as to_zone ON rule.rule_to_zone=to_zone.zone_id
		WHERE rule.action_id=stm_action.action_id 
			AND rule.track_id=stm_track.track_id 
			AND rule.rule_id = changelog_rule.new_rule_id 
			AND changelog_rule.log_rule_id = ANY (log_rule_ids) 
		ORDER BY changelog_rule.log_rule_id;
	RETURN cursor_result;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;

-- Function: get_changed_oldrules(refcursor, _int4)

-- DROP FUNCTION get_changed_oldrules(refcursor, _int4);

CREATE OR REPLACE FUNCTION get_changed_oldrules(refcursor, _int4)
  RETURNS refcursor AS
$BODY$
DECLARE
    cursor_result ALIAS FOR $1;
	log_rule_ids ALIAS FOR $2;
    BEGIN
	OPEN cursor_result FOR
		SELECT changelog_rule.*, rule.rule_num,rule.rule_id,action_name,track_name,from_zone.zone_name,to_zone.zone_name,rule.*
		FROM changelog_rule,stm_track,stm_action,rule
			LEFT JOIN zone as from_zone ON rule.rule_from_zone=from_zone.zone_id
			LEFT JOIN zone as to_zone ON rule.rule_to_zone=to_zone.zone_id
		WHERE rule.action_id=stm_action.action_id 
			AND rule.track_id=stm_track.track_id 
			AND rule.rule_id = changelog_rule.old_rule_id 
			AND changelog_rule.log_rule_id = ANY (log_rule_ids) 
		ORDER BY changelog_rule.log_rule_id;
	RETURN cursor_result;
END;
$BODY$
  LANGUAGE 'plpgsql' VOLATILE;

----------------------------------------------------
-- FUNCTION:    get_undocumented_changelog_entries
-- Zweck:       liefert eine Tabelle mit allen Feldern von changelog_$1 zurueck, die 'undocumented' sind
-- Parameter1:  table_name (object,service,user,rule)
-- RETURNS:     Tabelle mit allen Feldern der Eintraege von changelog_$1 zurueck, die 'undocumented' sind
--
CREATE OR REPLACE FUNCTION get_undocumented_changelog_entries(VARCHAR) RETURNS SETOF RECORD AS $$
DECLARE
	v_table ALIAS FOR $1;
	r_chlog RECORD;
	v_sql VARCHAR;
BEGIN
--	RAISE NOTICE 'sql';
	v_sql := 'SELECT * FROM changelog_' || v_table || ' WHERE NOT documented ORDER BY change_action';
--	RAISE NOTICE 'sql: %', v_sql;
	FOR r_chlog IN EXECUTE
		v_sql
	LOOP
		RETURN NEXT r_chlog;
	END LOOP;
	RETURN;
END;
$$ LANGUAGE plpgsql;

