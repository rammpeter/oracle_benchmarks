-- access a table without disk reads to compare the effort and times for different compression strategies
-- Peter Ramm, 2023-01-18


SET SERVEROUTPUT ON;
DECLARE
  trial_count             NUMBER := 3;
  MAX_LOOPS               CONSTANT NUMBER := 1000;
  MAX_ROWS                CONSTANT NUMBER := 10000;
  v_Consistent_Gets_Start NUMBER;
  v_Consistent_Gets_End   NUMBER;
  v_Consistent_Gets       NUMBER := 0;    /* total number of consistent gets */
  v_Physical_Reads_Start  NUMBER;
  v_Physical_Reads_End    NUMBER;
  v_Physical_Reads        NUMBER;         /* counted number of physical reads */
  v_CPU_Start             NUMBER;         /* 1/100 CPU seconds */
  v_CPU_End               NUMBER;
  v_CPU                   NUMBER;         /* cumulated CPU time over trials */
  v_Start_Time            TIMESTAMP;
  v_End_Time              TIMESTAMP;
  v_Row_Count             NUMBER;
  v_Loop_Count            NUMBER;         /* max. number of loops to avoid infinite loops if access without phys. reads is never reached */
  v_Counted_Loop_Count    NUMBER;         /* Number of accesses without physical reads to calculate averages */
  v_Spent_Time            INTERVAL DAY TO SECOND;
  TYPE Rowid_Table_Type IS TABLE OF RowID INDEX BY BINARY_INTEGER;
  Rowid_Table             RowID_Table_Type;
  v_Full_Row              auftrag.AU_WG_BESTAND%ROWTYPE;
  TYPE Number_Array_Type IS VARRAY(150) OF NUMBER;
  v_Number_Array          Number_Array_Type := Number_Array_Type(0, 0, 0, 0, 0, 0, 0, 0, 0, 0); 
  
  -- Ensure that the table/partition is considered as small table, so that buffer cache scans are used
  PROCEDURE Consider_as_small_table IS
  BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION SET "_small_table_threshold" = 1000000';
  END Consider_as_small_table;

    -- Ensure that the table/partition is considered as large table, so that direct path reads are used
  PROCEDURE Consider_as_large_table IS
  BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION SET "_small_table_threshold" = 5000';
  END Consider_as_large_table;

  PROCEDURE Reset_Counter(Small_Table BOOLEAN) IS
  BEGIN
    v_Consistent_Gets     := 0;
    v_Loop_Count          := 0;
    v_Counted_Loop_Count  := 0;
    v_Row_Count           := 0;
    v_CPU                 := 0;
    v_Spent_Time          := NULL;
    IF Small_Table THEN
      Consider_as_small_table;
    ELSE
      Consider_as_large_table;
    END IF;
  END Reset_Counter;

  PROCEDURE Log_Results(p_Row_Count NUMBER, p_Name VARCHAR2) IS
  BEGIN
    DBMS_OUTPUT.PUT_LINE('');
    DBMS_OUTPUT.PUT_LINE('### '||p_Name);
    DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
    DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
    IF v_Counted_Loop_Count = 0 THEN
      DBMS_OUTPUT.PUT_LINE('No trial without disk access, no results available');
    ELSE
      IF p_Row_Count IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Records per trial:              '||p_Row_Count);
      END IF;
      DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
      DBMS_OUTPUT.PUT_LINE('CPU seconds per trial:          '||ROUND((v_CPU / 100.0 / v_Counted_Loop_Count), 4));
      IF p_Row_Count IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Avg. runtime per row:           '||(v_Spent_Time / (v_Counted_Loop_Count*p_Row_Count)));
      END IF;
      DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
      IF p_Row_Count IS NOT NULL THEN
        DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / p_Row_Count), 4));
      END IF;
    END IF;
  END Log_Results;
  
  PROCEDURE Snap_Start IS
  BEGIN
    v_Row_Count           := 0;
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT Value INTO v_CPU_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'CPU used by this session');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;
  END Snap_Start;

  PROCEDURE Snap_End(p_Wait_For_No_Phys_Read BOOLEAN DEFAULT TRUE) IS
  BEGIN
    SELECT SYSTIMESTAMP INTO v_End_Time FROM DUAL;
    SELECT Value INTO v_CPU_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'CPU used by this session');
    SELECT Value INTO v_Consistent_Gets_End FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    v_Physical_Reads := v_Physical_Reads_End - v_Physical_Reads_Start;
    IF v_Physical_Reads = 0 OR NOT p_Wait_For_No_Phys_Read THEN
      v_Consistent_Gets    := v_Consistent_Gets + v_Consistent_Gets_End - v_Consistent_Gets_Start;
      v_CPU                := v_CPU + v_CPU_End - v_CPU_Start;
      v_Counted_Loop_Count := v_Counted_Loop_Count + 1;
      IF v_Spent_Time IS NULL THEN
        v_Spent_Time := v_End_Time-v_Start_Time;
      ELSE
        v_Spent_Time := v_Spent_Time + (v_End_Time-v_Start_Time);
      END IF;
      -- TODO: Log ASH wait events for the session between start and end
    END IF;
  END Snap_End;
BEGIN
  SELECT Row_ID BULK COLLECT INTO RowID_Table
  FROM   (
          SELECT Block, MIN(RowID) Row_ID
          FROM   (SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) Block,rowid
                  FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098)
                 )
          GROUP BY Block
         )
  WHERE  RowNum <= 10000       
  ;


  Reset_Counter(Small_Table => TRUE);
  LOOP
    Snap_Start;
    FOR i IN RowID_Table.FIRST .. RowID_Table.LAST LOOP
      v_Row_Count := v_Row_Count + 1;
      SELECT * INTO v_Full_Row FROM auftrag.AU_WG_BESTAND WHERE RowID = RowID_Table(i);
    END LOOP;
    Snap_End;
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(v_Row_Count, 'Table access by rowid (100% cache hits)');

  Reset_Counter(Small_Table => TRUE);
  LOOP
    Snap_Start;
    /* read all columns from table, otherwise HCC is not forced to atach all blocks */ 
    /* ensure that nondirect path via DB-cache is used on Exadata by disable cell offloading*/
    FOR Rec IN (SELECT /*+ FULL(x) OPT_PARAM('cell_offload_processing' 'false')  */ * FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098) x WHERE RowNum <= 1000000) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Full_Row  := Rec;               /* force DB to really read all columns */
    END LOOP;  
    Snap_End;
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(v_Row_Count, 'Table access full for one partition with all columns (100% cache hits)');

  Reset_Counter(Small_Table => TRUE);
  LOOP
    Snap_Start;
    /* read all columns from table, otherwise HCC is not forced to attach all blocks */
    /* ensure that nondirect path via DB-cache is used on Exadata by disable cell offloading*/
    FOR Rec IN (SELECT /*+ FULL(x) OPT_PARAM('cell_offload_processing' 'false') */ ARTIKEL_ORIG_ANZ, ARTPOS_ORIG_ANZ FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098) x WHERE RowNum <= 1000000) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Number_Array(1)  := Rec.ARTIKEL_ORIG_ANZ;               /* force DB to really read all columns */
      v_Number_Array(2)  := Rec.ARTPOS_ORIG_ANZ;
    END LOOP;
    Snap_End;
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(v_Row_Count, 'Table access full for one partition with less (2) columns (100% cache hits)');

  Reset_Counter(Small_Table => FALSE);
  LOOP
    Snap_Start;
    /* read all columns from table, otherwise HCC is not forced to atach all blocks */ 
    FOR Rec IN (SELECT /*+ FULL(x) PARALLEL(2) */ * FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098) x WHERE RowNum <= 1000000) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Full_Row  := Rec;               /* force DB to really read all columns */
    END LOOP;
    Snap_End(FALSE);
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(v_Row_Count, 'Table access full for one partition with all columns and direct path read');

  Reset_Counter(Small_Table => TRUE);
  LOOP
    Snap_Start;
    /* ensure that nondirect path via DB-cache is used on Exadata by disable cell offloading*/
    SELECT /*+ FULL(x) OPT_PARAM('cell_offload_processing' 'false')  */ COUNT(*) INTO v_Row_Count FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098) x
    WHERE Prom_anz = 55 AND PromPos_Anz = 55; /* 2 subsequent columns */
    Snap_End;
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(NULL, 'Table access full nondirect with with 2 filter columns without fetch (100% cache hits)');

  Reset_Counter(Small_Table => FALSE);
  LOOP
    Snap_Start;
    SELECT /*+ FULL(x) PARALLEL(2) */ COUNT(*) INTO v_Row_Count FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P436098) x
    WHERE  Prom_anz = 55 AND PromPos_Anz = 55; /* 2 subsequent columns */ 
    Snap_End(FALSE);
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  Log_Results(NULL, 'Table access full direct path read with with 2 filter columns without fetch');

END;