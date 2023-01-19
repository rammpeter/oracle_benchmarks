# Accessing compressed or uncompressed table data
Consider the efficiency and metrics of table access

## table_partitioned.sql
This test script checks the runtime and the number of consistent gets for an table access.

Each block of the index is accessed only once by calculating the block number from rowid.

Tests are executed with the lowest and the highest rowid of a block.

Several compression strategies are evaluated and compared this way.

To ensure comparability all DB blocks must be accessed in DB cache without disk reads.

### Results 2023-01
Test was run on a table with approx. 18 billion rows, partitioned by column ```Datum```.
Only cache hits without disk access are counted to ensure reproducable results.

Each block within a particular partition is accessed exactly once by rowid.

Legend  for columns of following table:
- Compression: The compression type of the considered partitioned index
- Access time by rowid: Avg. access time per row for table access by rowid over the first 10,000 blocks of one partition
- Gets/row by rowid: Avg. consistent gets per row for table access by rowid over the first 10,000 blocks of one partition
- Time/row full scan all columns: Avg. read time per row for full scan of all 134 rows/ 8 mio. records   
- Gets/row full scan all columns: Avg. consistent gets per row for full scan of all 134 rows/ 8 mio. records
- Time/row full scan 2 columns: Avg. read time per row for full scan of only 2 of 134 rows/ 8 mio. records
- Gets/row full scan 2 columns: Avg. consistent gets per row for full scan of only 2 of 134 rows/ 8 mio. records
- Time/row direct full scan all columns: Avg. read time per row for full scan with direct path read of all 134 rows/ 8 mio. records
- Gets/row direct full scan all columns: Avg. consistent gets per row for full scan with direct path read of all 134 rows/ 8 mio. records
- 
- 
- Size: Physiscal size of index after creation
- Creation time: Time effort for CREATE INDEX
- Access time range scan: Avg. time for accessing all partitions with filter ```Warengruppe_ID=:x AND Lgr_Bereich_ID=:y```
- Access time unique scan: Access time for one unique scan, average over one access for each of the 2266 partitions
- Gets/row unique scan: Avg. consistent gets per row for one unique scan, average over one access for each of the 2266 partitions

| Compression                            | Access time by rowid | Gets/row by rowid | Time/row full scan all columns | Gets/row full scan all columns | Time/row full scan 2 columns | Gets/row full scan 2 columns | Time/row direct full scan all columns | Gets/row direct full scan all columns |
|----------------------------------------|----------------------|-------------------|--------------------------------|--------------------------------|------------------------------|------------------------------|---------------------------------------|---------------------------------------|
| Uncompressed                           |                      |                   |                                |                                |                              |                              |                                       |                                       |
| ROW STORE COMPRESS ADVANCED            |                      |                   |                                |                                |                              |                              |                                       |                                       |
| COLUMN STORE COMPRESS FOR QUERY LOW    | 0.065 ms             | 1.91              | 0.017 ms                       | 0.0131                         | 0.0005 ms                    | 0.012                        | 0.015 ms                              | 0.0032                                |
| COLUMN STORE COMPRESS FOR QUERY HIGH   |                      |                   |                                |                                |                              |                              |                                       |                                       |
| COLUMN STORE COMPRESS FOR ARCHIVE LOW  |                      |                   |                                |                                |                              |                              |                                       |                                       |
| COLUMN STORE COMPRESS FOR ARCHIVE HIGH |                      |                   |                                | .                              |                              |                              |                                       |                                       |
