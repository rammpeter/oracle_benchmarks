-- access a table without disk reads to compare the effort and times for different compression strategies
-- Peter Ramm, 2023-01-18


SET SERVEROUTPUT ON;
DECLARE
  trial_count             NUMBER := 10;
  MAX_LOOPS               CONSTANT NUMBER := 1000;
  MAX_ROWS                CONSTANT NUMBER := 10000;
  v_Consistent_Gets_Start NUMBER;
  v_Consistent_Gets_End   NUMBER;
  v_Consistent_Gets       NUMBER := 0;    /* total number of consistent gets */
  v_Physical_Reads_Start  NUMBER;
  v_Physical_Reads_End    NUMBER;
  v_Physical_Reads        NUMBER;         /* counted number of physical reads */
  v_Start_Time            TIMESTAMP;
  v_End_Time              TIMESTAMP;
  v_Row_Count             NUMBER;
  v_Loop_Count            NUMBER := 0;    /* max. number of loops to avoid infinite loops if access without phys. reads is never reached */
  v_Counted_Loop_Count    NUMBER := 0;    /* Number of accesses without physical reads to calculate averages */
  v_Spent_Time            INTERVAL DAY TO SECOND := NULL;
  TYPE Rowid_Table_Type IS TABLE OF RowID INDEX BY BINARY_INTEGER;
  Rowid_Table             RowID_Table_Type;
  v_Full_Row              auftrag.AU_WG_BESTAND%ROWTYPE;
  TYPE Number_Array_Type IS VARRAY(150) OF NUMBER;
  v_Number_Array          Number_Array_Type := Number_Array_Type(0, 0, 0, 0, 0, 0, 0, 0, 0, 0); 
BEGIN
  SELECT Row_ID BULK COLLECT INTO RowID_Table
  FROM   (
          SELECT Block, MIN(RowID) Row_ID
          FROM   (SELECT DBMS_ROWID.ROWID_BLOCK_NUMBER(rowid) Block,rowid
                  FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P2262971)
                 )
          GROUP BY Block
         )
  WHERE  RowNum <= 10000       
  ;

  -- Table access by rowid
  LOOP
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;

    FOR i IN RowID_Table.FIRST .. RowID_Table.LAST LOOP
      SELECT * INTO v_Full_Row FROM auftrag.AU_WG_BESTAND WHERE RowID = RowID_Table(i);
    END LOOP;
  
    SELECT SYSTIMESTAMP INTO v_End_Time FROM DUAL;
    SELECT Value INTO v_Consistent_Gets_End FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    v_Physical_Reads := v_Physical_Reads_End - v_Physical_Reads_Start;
    IF v_Physical_Reads = 0 THEN
      v_Consistent_Gets    := v_Consistent_Gets + v_Consistent_Gets_End - v_Consistent_Gets_Start;
      v_Counted_Loop_Count := v_Counted_Loop_Count + 1;
      IF v_Spent_Time IS NULL THEN
        v_Spent_Time := v_End_Time-v_Start_Time;
      ELSE
        v_Spent_Time := v_Spent_Time + (v_End_Time-v_Start_Time);
      END IF;
    END IF;
  
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('### Table access by rowid');
  DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Records per trial:              '||MAX_ROWS);
  DBMS_OUTPUT.PUT_LINE('Runtime total:                  '||v_Spent_Time);
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per row:           '||(v_Spent_Time / (v_Counted_Loop_Count*MAX_ROWS)));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / MAX_ROWS), 4));

  -- Table access full for one partition with all columns
  v_Consistent_Gets     := 0;
  v_Loop_Count          := 0;
  v_Counted_Loop_Count  := 0;
  v_Row_Count           := 0;
  trial_count           := 1;
  v_Spent_Time          := NULL;
  LOOP
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;

    /* read all columns from table, otherwise HCC is not forced to atach all blocks */ 
    FOR Rec IN (SELECT /*+ FULL(x) */ * FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P2262971)) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Full_Row  := Rec;               /* force DB to really read all columns */
    END LOOP;
  
    SELECT SYSTIMESTAMP INTO v_End_Time FROM DUAL;
    SELECT Value INTO v_Consistent_Gets_End FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    v_Physical_Reads := v_Physical_Reads_End - v_Physical_Reads_Start;
    IF v_Physical_Reads = 0 THEN
      v_Consistent_Gets    := v_Consistent_Gets + v_Consistent_Gets_End - v_Consistent_Gets_Start;
      v_Counted_Loop_Count := v_Counted_Loop_Count + 1;
      IF v_Spent_Time IS NULL THEN
        v_Spent_Time := v_End_Time-v_Start_Time;
      ELSE
        v_Spent_Time := v_Spent_Time + (v_End_Time-v_Start_Time);
      END IF;
    END IF;
  
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('### Table access full for one partition with all columns');
  DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Records per trial:              '||v_Row_Count);
  DBMS_OUTPUT.PUT_LINE('Runtime total:                  '||v_Spent_Time);
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per row:           '||(v_Spent_Time / (v_Counted_Loop_Count*v_Row_Count)));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / v_Row_Count), 4));

  -- Table access full for one partition with less columns
  v_Consistent_Gets     := 0;
  v_Loop_Count          := 0;
  v_Counted_Loop_Count  := 0;
  v_Row_Count           := 0;
  trial_count           := 1;
  v_Spent_Time          := NULL;
  LOOP
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;

    /* read all columns from table, otherwise HCC is not forced to atach all blocks */ 
    FOR Rec IN (SELECT /*+ FULL(x) */ ARTIKEL_ORIG_ANZ, ARTPOS_ORIG_ANZ FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P2262971)) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Number_Array(1)  := Rec.ARTIKEL_ORIG_ANZ;               /* force DB to really read all columns */
      v_Number_Array(2)  := Rec.ARTPOS_ORIG_ANZ;
    END LOOP;
  
    SELECT SYSTIMESTAMP INTO v_End_Time FROM DUAL;
    SELECT Value INTO v_Consistent_Gets_End FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    v_Physical_Reads := v_Physical_Reads_End - v_Physical_Reads_Start;
    IF v_Physical_Reads = 0 THEN
      v_Consistent_Gets    := v_Consistent_Gets + v_Consistent_Gets_End - v_Consistent_Gets_Start;
      v_Counted_Loop_Count := v_Counted_Loop_Count + 1;
      IF v_Spent_Time IS NULL THEN
        v_Spent_Time := v_End_Time-v_Start_Time;
      ELSE
        v_Spent_Time := v_Spent_Time + (v_End_Time-v_Start_Time);
      END IF;
    END IF;
  
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('### Table access full for one partition with less (2) columns');
  DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Records per trial:              '||v_Row_Count);
  DBMS_OUTPUT.PUT_LINE('Runtime total:                  '||v_Spent_Time);
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per row:           '||(v_Spent_Time / (v_Counted_Loop_Count*v_Row_Count)));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / v_Row_Count), 4));

  -- Table access full for one partition with all columns and direct path read
  v_Consistent_Gets     := 0;
  v_Loop_Count          := 0;
  v_Counted_Loop_Count  := 0;
  v_Row_Count           := 0;
  trial_count           := 1;
  v_Spent_Time          := NULL;
  LOOP
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;

    /* read all columns from table, otherwise HCC is not forced to atach all blocks */ 
    FOR Rec IN (SELECT /*+ FULL(x) PARALLEL(2) */ * FROM auftrag.AU_WG_BESTAND PARTITION (SYS_P2262971)) LOOP
      v_Row_Count := v_Row_Count + 1;
      v_Full_Row  := Rec;               /* force DB to really read all columns */
    END LOOP;
  
    SELECT SYSTIMESTAMP INTO v_End_Time FROM DUAL;
    SELECT Value INTO v_Consistent_Gets_End FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_End  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    v_Physical_Reads := v_Physical_Reads_End - v_Physical_Reads_Start;
    IF v_Physical_Reads = 0 THEN
      v_Consistent_Gets    := v_Consistent_Gets + v_Consistent_Gets_End - v_Consistent_Gets_Start;
      v_Counted_Loop_Count := v_Counted_Loop_Count + 1;
      IF v_Spent_Time IS NULL THEN
        v_Spent_Time := v_End_Time-v_Start_Time;
      ELSE
        v_Spent_Time := v_Spent_Time + (v_End_Time-v_Start_Time);
      END IF;
    END IF;
  
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= trial_count; /* End if test had no disk reads */
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('### Table access full for one partition with all columns and direct path read');
  DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Records per trial:              '||v_Row_Count);
  DBMS_OUTPUT.PUT_LINE('Runtime total:                  '||v_Spent_Time);
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per row:           '||(v_Spent_Time / (v_Counted_Loop_Count*v_Row_Count)));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / v_Row_Count), 4));

END;