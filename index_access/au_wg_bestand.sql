-- access an index without disk reads to compare the effort and times for different compression strategies
-- Unique index is on columns DATUM, WARENGRUPPE_ID, LGR_BEREICH_ID intervall partitioned by DATUM
-- Peter Ramm, 2023-01-18


-- find values existing in most of the partitions
SELECT first.warengruppe_id, first.lgr_bereich_ID
FROM (SELECT DISTINCT warengruppe_id, lgr_bereich_ID FROM auftrag.AU_WG_Bestand WHERE Datum = (SELECT MIN(Datum) FROM AU_WG_Bestand)) first
JOIN (SELECT DISTINCT warengruppe_id, lgr_bereich_ID FROM auftrag.AU_WG_Bestand WHERE Datum = (SELECT Max(Datum) FROM AU_WG_Bestand)) ende ON ende.Warengruppe_id = first.warengruppe_id and ende.lgr_bereich_ID = first.lgr_bereich_ID
;


SET SERVEROUTPUT ON;
DECLARE
  TRIAL_COUNT             CONSTANT NUMBER := 100;
  MAX_LOOPS               CONSTANT NUMBER := 10000;
  v_Consistent_Gets_Start NUMBER;
  v_Consistent_Gets_End   NUMBER;
  v_Consistent_Gets       NUMBER := 0;    /* total number of consistent gets */
  v_Physical_Reads_Start  NUMBER;
  v_Physical_Reads_End    NUMBER;
  v_Physical_Reads        NUMBER;         /* counted number of physical reads */
  v_Start_Time            TIMESTAMP;
  v_End_Time              TIMESTAMP;
  v_Loop_Count            NUMBER := 0;    /* max. number of loops to avoid infinite loops if access without phys. reads is never reached */
  v_Counted_Loop_Count    NUMBER := 0;    /* Number of accesses without physical reads to calculate averages */
  v_RowID_Count           NUMBER;
  v_Row_Count             NUMBER;
  v_Spent_Time            INTERVAL DAY TO SECOND := NULL;
BEGIN
  LOOP
    v_Loop_Count := v_Loop_Count + 1;
    SELECT Value INTO v_Consistent_Gets_Start FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'consistent gets');
    SELECT Value INTO v_Physical_Reads_Start  FROM v$MyStat s WHERE s.Statistic# = (SELECT Statistic# FROM v$StatName WHERE Name = 'physical reads');
    SELECT SYSTIMESTAMP INTO v_Start_Time FROM DUAL;

    SELECT COUNT(DISTINCT RowID), COUNT(*) INTO v_RowID_Count, v_Row_Count FROM auftrag.AU_WG_Bestand where Warengruppe_ID=10396748 and lgr_bereich_ID=1;

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
  
    EXIT WHEN v_Loop_Count > MAX_LOOPS OR v_Counted_Loop_Count >= TRIAL_COUNT; /* End if test had no disk reads */
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('');
  DBMS_OUTPUT.PUT_LINE('Total trial count:              '||v_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Trials without disk:            '||v_Counted_Loop_Count);
  DBMS_OUTPUT.PUT_LINE('Records per trial:              '||v_Row_Count);
  DBMS_OUTPUT.PUT_LINE('Runtime total:                  '||v_Spent_Time);
  DBMS_OUTPUT.PUT_LINE('Avg. runtime per trial:         '||(v_Spent_Time / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per trial:  '||(v_Consistent_Gets / v_Counted_Loop_Count));
  DBMS_OUTPUT.PUT_LINE('Avg consistent gets per row:    '||ROUND((v_Consistent_Gets / v_Counted_Loop_Count / v_Row_Count), 4));
END;