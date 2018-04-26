#!/bin/bash 

while getopts 'm:f:' flag; do
  case "${flag}" in
    m) OP_MODE="${OPTARG}" ;;
    f) REPORT_FILENAME="${OPTARG}" ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

if [ -z $OP_MODE ]; then
  echo "Please specify Mode of Operation via Parameter -m (start: Start Snapshot, end: End Snapshot, report: Generate Report)!"; exit 1;
fi

cleanSnapIDTable() {
  echo "$(date) - cleaning snapshot-ID table";
  sqlplus -silent /nolog <<EOF
  connect / as sysdba

  DECLARE
    v_SNAPID_TABLE_EXISTS INTEGER := 0;
  BEGIN

  -- check if our snapshot-ID table already exists
  -- if it does not exist we create it...
    SELECT COUNT(*) INTO v_SNAPID_TABLE_EXISTS
      FROM ALL_OBJECTS
     WHERE OBJECT_TYPE = 'TABLE'
       AND OWNER = 'SYS'
       AND OBJECT_NAME = 'T_AWRSNAP'
    ;
    
    IF v_SNAPID_TABLE_EXISTS <= 0 THEN
      EXECUTE IMMEDIATE 'CREATE TABLE SYS.T_AWRSNAP(SNAPID NUMBER)';
    ELSE
      EXECUTE IMMEDIATE 'TRUNCATE TABLE SYS.T_AWRSNAP';  
    END IF;
  END;
  /

  EXIT;
EOF
}

createAWRSnapshot() {
  echo "$(date) - creating AWR snapshot";
  sqlplus -silent /nolog <<EOF
  connect / as sysdba
  
  -- create AWR snapshot and insert ID into our snapshot-ID table  
  INSERT INTO SYS.T_AWRSNAP (SNAPID) VALUES (DBMS_WORKLOAD_REPOSITORY.CREATE_SNAPSHOT);
  COMMIT;

  EXIT;
EOF
}

createAWRReport() {
  if [ -z $REPORT_FILENAME ]; then
    echo "Please specify filename of the report parameter -f (e.g. -f /tmp/swrf_report_10_11.html)!"; exit 1;
  fi

  echo "$(date) - creating AWR report";
  sqlplus -silent /nolog <<EOF
  connect / as sysdba
  set echo off heading on
  column inst_num heading "Inst Num" new_value inst_num format 99999;
  column inst_name heading "Instance" new_value inst_name format a12;
  column db_name heading "DB Name" new_value db_name format a12;
  column dbid heading "DB Id" new_value dbid format 9999999999 just c;
  column begin_snap heading "begin_snap" new_value begin_snap format 99999;
  column end_snap heading "end_snap" new_value end_snap format 99999;
  
  SELECT D.DBID DBID, D.NAME DB_NAME, I.INSTANCE_NUMBER INST_NUM, I.INSTANCE_NAME INST_NAME FROM V\$DATABASE D, V\$INSTANCE I;
  SELECT DISTINCT FIRST_VALUE(SNAPID) OVER (ORDER BY SNAPID ASC) begin_snap, FIRST_VALUE(SNAPID) OVER (ORDER BY SNAPID DESC) end_snap FROM SYS.T_AWRSNAP;  
   
  define  num_days     = 1;  
  define  report_type  = 'html';
  define  report_name  = ${REPORT_FILENAME}
 
  @@?/rdbms/admin/awrrpti
  EXIT;
EOF
}

case "${OP_MODE}" in
    start) cleanSnapIDTable
           createAWRSnapshot
           ;;
      end) createAWRSnapshot
           ;;
   report) createAWRReport
           ;;
        *) error " - unkown OP_MODE: ${OP_MODE}" 
           ;;
esac

exit 0;