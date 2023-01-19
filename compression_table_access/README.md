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
- Size: Physiscal size of one partition with approx . 8 mio. records
- Access by rowid: table access by rowid over the first 10,000 blocks of one partition
  - Time: Avg. Average access time per row
  - Gets / row: Avg. consistent gets per row
- Full scan all columns: Full scan of all 134 rows for first 1,000,000 records of a partition   
    - Time: Avg. Average time per row for scan and fetch
    - Gets / row: Avg. consistent gets per row
- Full scan 2 columns: Full scan of only 2 of 134 rows for first 1,000,000 records of a partition
    - Time: Avg. Average time per row for scan and fetch
    - Gets / row: Avg. consistent gets per row
- Direct full scan all columns: Full scan with direct path read of all 134 rows for first 1,000,000 records of a partition
    - Time: Avg. Average time per row for scan and fetch
    - Gets / row: Avg. consistent gets per row
- Search scan 2 columns: Nondirect full table scan without fetch of a whole partition with 8 mio. records and 2 filter columns
  - Time: Total SQL runtime without fetch
  - Gets: Consistent gets for the whole SQL execution
- Search scan direct 2 columns: direct path full table scan without fetch of a whole partition with 8 mio. records and 2 filter columns
    - Time: Total SQL runtime without fetch
    - Gets: Consistent gets for the whole SQL execution

<table>
    <tr>
        <th rowspan="2">Compression</th>
        <th rowspan="2">Size</th>
        <th colspan="2">Access by RowID</th>
        <th colspan="2">Full scan all columns</th>
        <th colspan="2">Full scan 2 columns</th>
        <th colspan="2">Direct full scan all columns</th>
        <th colspan="2">Search scan 2 columns</th>
        <th colspan="2">Search scan direct 2 columns</th>
    </tr>
    <tr>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets</th>
        <th>Time</th>
        <th>Gets</th>
    </tr>
    <tr>
        <td>Uncompressed</td>
        <td>2488 MB</td>
        <td>0.045 ms</td>
        <td>1</td>
        <td>0.0016 ms</td>
        <td>0.046</td>
        <td>0.00069 ms</td>
        <td>0.046</td>
        <td>0.014 ms</td>
        <td>0.036</td>
        <td>1008 ms</td>
        <td>317666</td>
        <td>207 ms</td>
        <td>317804</td>
    </tr>
    <tr>
        <td>ROW STORE COMPRESS ADVANCED</td>
        <td>156.4 MB</td>
        <td>0.049 ms</td>
        <td>1</td>
        <td>0.017 ms</td>
        <td>0.0122</td>
        <td>0.0008 ms</td>
        <td>0.0122</td>
        <td>0.014 ms</td>
        <td>0.0023</td>
        <td>433 ms</td>
        <td>19855</td>
        <td>227 ms</td>
        <td>20017</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR QUERY LOW</td>
        <td>-- MB</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR QUERY HIGH</td>
        <td>-- MB</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR ARCHIVE LOW</td>
        <td>-- MB</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR ARCHIVE HIGH</td>
        <td>-- MB</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
        <td>-- ms</td>
        <td>--</td>
    </tr>
</table>
