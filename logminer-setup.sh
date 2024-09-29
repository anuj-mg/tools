#!/bin/sh

# Set archive log mode and enable GG replication
ORACLE_SID=FREE
export ORACLE_SID
sqlplus /nolog <<- EOF
	CONNECT sys/password AS SYSDBA
	alter system set db_recovery_file_dest_size = 10G;
	alter system set db_recovery_file_dest = '/opt/oracle/oradata/recovery_area' scope=spfile;
	shutdown immediate
	startup mount
	alter database archivelog;
	alter database open;
        -- Should show "Database log mode: Archive Mode"
	archive log list
	exit;
EOF

# Enable LogMiner required database features/settings
sqlplus sys/password@//localhost:1521/FREE as sysdba <<- EOF
  ALTER DATABASE ADD SUPPLEMENTAL LOG DATA;
  ALTER PROFILE DEFAULT LIMIT FAILED_LOGIN_ATTEMPTS UNLIMITED;
  exit;
EOF

# Create Log Miner Tablespace and User
sqlplus sys/password@//localhost:1521/FREE as sysdba <<- EOF
  alter session set container=FREE;
  CREATE TABLESPACE LOGMINER_TBS DATAFILE '/opt/oracle/oradata/FREE/logminer_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
  exit;
EOF

sqlplus sys/password@//localhost:1521/FREEPDB1 as sysdba <<- EOF
  alter session set container=FREEPDB1;
  CREATE TABLESPACE LOGMINER_TBS DATAFILE '/opt/oracle/oradata/FREE/FREEPDB1/logminer_tbs.dbf' SIZE 25M REUSE AUTOEXTEND ON MAXSIZE UNLIMITED;
  exit;
EOF

sqlplus sys/password@//localhost:1521/FREE as sysdba <<- EOF
  alter session set container = CDB$ROOT;
  CREATE USER free##dbzuser IDENTIFIED BY dbz DEFAULT TABLESPACE LOGMINER_TBS QUOTA UNLIMITED ON LOGMINER_TBS CONTAINER=ALL;

  GRANT CREATE SESSION TO free##dbzuser CONTAINER=ALL;
  GRANT SET CONTAINER TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$DATABASE TO free##dbzuser CONTAINER=ALL;
  GRANT FLASHBACK ANY TABLE TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ANY TABLE TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT_CATALOG_ROLE TO free##dbzuser CONTAINER=ALL;
  GRANT EXECUTE_CATALOG_ROLE TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ANY TRANSACTION TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ANY DICTIONARY TO free##dbzuser CONTAINER=ALL;
  GRANT LOGMINING TO c##dbzuser CONTAINER=ALL;

  GRANT CREATE TABLE TO free##dbzuser CONTAINER=ALL;
  GRANT LOCK ANY TABLE TO free##dbzuser CONTAINER=ALL;
  GRANT CREATE SEQUENCE TO free##dbzuser CONTAINER=ALL;

  GRANT EXECUTE ON DBMS_LOGMNR TO free##dbzuser CONTAINER=ALL;
  GRANT EXECUTE ON DBMS_LOGMNR_D TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGMNR_LOGS TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGMNR_CONTENTS TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$LOGFILE TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$ARCHIVED_LOG TO free##dbzuser CONTAINER=ALL;
  GRANT SELECT ON V_\$ARCHIVE_DEST_STATUS TO free##dbzuser CONTAINER=ALL;

  exit;
EOF

sqlplus sys/password@//localhost:1521/FREEPDB1 as sysdba <<- EOF
  alter session set container = CDB$ROOT;
  CREATE USER debezium IDENTIFIED BY dbz;
  GRANT CONNECT TO debezium;
  GRANT CREATE SESSION TO debezium;
  GRANT CREATE TABLE TO debezium;
  GRANT CREATE SEQUENCE to debezium;
  ALTER USER debezium QUOTA 100M on users;
  exit;
EOF