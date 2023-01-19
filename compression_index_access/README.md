# Accessing compressed or uncompressed indexes
Consider the efficiency and metrics of index access combined with several compression strategies

## index_partitioned.sql
This test script checks the runtime and the number of consistent gets for an index access.

Each block of the index is accessed only once.
This is ensured by selecting with a filter where each index partition only has one row hit.

Several compression strategies are evaluated and compared this way.

To ensure comparability all DB blocks must be accessed in DB cache without disk reads.

### Results 2023-01
Legend  for columns of following table:
- Compression: The compression type of the considered partitioned index
- Column order: the order of the three columns: DATUM (8 Byte), WARENGRUPPE_ID (7 Byte), LGR_BEREICH_ID (4 Byte)
- Size: Physiscal size of index after creation
- Creation time: Time effort for CREATE INDEX
- Access time range scan: Avg. time for accessing all partitions with filter ```Warengruppe_ID=:x AND Lgr_Bereich_ID=:y``` 
- Gets/row range scan: Avg. consistent gets per row accessing all partitions with filter ```Warengruppe_ID=:x AND Lgr_Bereich_ID=:y```
- Access time unique scan: Access time for one unique scan, average over one access for each of the 2266 partitions
- Gets/row unique scan: Avg. consistent gets per row for one unique scan, average over one access for each of the 2266 partitions

|Compression|Column order  | Size     | Creation time | Access time range scan |Gets/row range scan| Access time unique scan | Gets/row unique scan |
|---|---|----------|---------------|---|---|-------------------------|----------------------|
| Uncompressed           | Datum, Warengruppe_ID, Lgr_Bereich_ID | 535.7 GB | 35 min.       |0.078 sec.|9.07| 0.03 ms| 3                    |
| Key compression (1)    | Datum, Warengruppe_ID, Lgr_Bereich_ID | 397.4 GB |               |0.11 sec.|9.06| 0.08 ms| 3                    |
| COMPRESS ADVANCED LOW  | Datum, Warengruppe_ID, Lgr_Bereich_ID | 381.6 GB | 27 min.       |0.08 sec.|13.59||
| COMPRESS ADVANCED LOW  | Warengruppe_ID, Lgr_Bereich_ID, Datum | 531.6 GB | 34 min.       |0.064 sec.|9.06| 0.06 ms| 3                    |
| COMPRESS ADVANCED HIGH | Warengruppe_ID, Lgr_Bereich_ID, Datum | 160.3 GB | 23 min.       |0.063 sec.|8.95|0.07 ms| 2.917
