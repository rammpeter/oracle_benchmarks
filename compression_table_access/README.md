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

Machine: EXADATA X6-2L High Capacity with 3 storage cell server

Only 100% cache hits without disk access are counted for non-direct access to ensure reproducable results.

Each block within a particular partition is accessed exactly once by rowid.

Legend  for columns of following table:
- Compression: The compression type of the considered partitioned index
- Cpr. time: Time for compression by ALTER TABLE MOVE PARTITION &lt;compression rule&gt;
- Size: Physiscal size of one partition with approx . 8 mio. records
- Access by rowid: table access by rowid of all columns over the first 10,000 blocks of one partition (100% cache hits)
  - Time: Avg. Average access time per row
  - Gets / row: Avg. consistent gets per row
- Full scan all columns: Full scan of all 134 rows for first 1,000,000 records of a partition (100% cache hits)  
    - Time: Total runtime for SQL execution and fetch in PL/SQL 
    - Gets / row: Avg. consistent gets per row
- Full scan 2 columns: Full scan of only 2 of 134 rows for first 1,000,000 records of a partition (100% cache hits)
    - Time: Total runtime for SQL execution and fetch in PL/SQL
    - Gets / row: Avg. consistent gets per row
- Direct full scan all columns: Full scan with direct path read of all 134 rows for first 1,000,000 records of a partition
    - Time: Total runtime for SQL execution and fetch in PL/SQL
    - CPU: Used CPU time during SQL execution and fetch
    - Gets / row: Avg. consistent gets per row
- Search scan 2 columns: Nondirect full table scan without fetch of a whole partition with 8 mio. records and 2 filter columns (100% cache hits)
  - Time: Total SQL runtime without fetch
  - Gets: Consistent gets for the whole SQL execution
- Search scan direct 2 columns: direct path full table scan without fetch of a whole partition with 8 mio. records and 2 filter columns
    - Time: Total SQL runtime without fetch
    - CPU: Used CPU time during SQL execution
    - Gets: Consistent gets for the whole SQL execution

<table>
    <tr>
        <th rowspan="2">Compression</th>
        <th rowspan="2">Size</th>
        <th rowspan="2">Cpr. time</th>
        <th colspan="2">Access by RowID</th>
        <th colspan="2">Full scan all columns</th>
        <th colspan="2">Full scan 2 columns</th>
        <th colspan="3">Direct full scan all columns</th>
        <th colspan="2">Search scan 2 columns</th>
        <th colspan="3">Search scan direct 2 columns</th>
    </tr>
    <tr>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>CPU</th>
        <th>Gets / row</th>
        <th>Time</th>
        <th>Gets</th>
        <th>Time</th>
        <th>CPU</th>
        <th>Gets</th>
    </tr>
    <tr>
        <td>Uncompressed</td>
        <td>2638 MB</td>
        <td></td>
        <td>0.048 ms</td>
        <td>1</td>
        <td>17033 ms</td>
        <td>0.048</td>
        <td>764 ms</td>
        <td>0.0497</td>
        <td>14832</td>
        <td>20683 ms</td>
        <td>0.0407</td>
        <td>1218 ms</td>
        <td>336262</td>
        <td>907 ms</td>
        <td>187 ms</td>
        <td>336377</td>
    </tr>
    <tr>
        <td>ROW STORE COMPRESS ADVANCED</td>
        <td>178 MB</td>
        <td>83 s</td>
        <td>0.051 ms</td>
        <td>1</td>
        <td>18000 ms</td>
        <td>0.0122</td>
        <td>1192 ms</td>
        <td>0.0122</td>
        <td>14479 ms</td>
        <td>19963 ms</td>
        <td>0.0026</td>
        <td>660 ms</td>
        <td>22241</td>
        <td>388 ms</td>
        <td>756 ms</td>
        <td>22358</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR QUERY LOW</td>
        <td>106 MB</td>
        <td>150 s</td>
        <td>0,19 ms</td>
        <td>5.37</td>
        <td>15792 ms</td>
        <td>0.0123</td>
        <td>554 ms</td>
        <td>0.0116</td>
        <td>14758 ms</td>
        <td>18476 ms</td>
        <td>0.002</td>
        <td>89.3 ms</td>
        <td>21064</td>
        <td>56,6 ms</td>
        <td>110 ms</td>
        <td>21200</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR QUERY HIGH</td>
        <td>54 MB</td>
        <td>216 s</td>
        <td>0.51 ms</td>
        <td>4.68</td>
        <td>16426 ms</td>
        <td>0.011</td>
        <td>573 ms</td>
        <td>0.0107</td>
        <td>14809 ms</td>
        <td>18560 ms</td>
        <td>0.0013</td>
        <td>162 ms</td>
        <td>10885</td>
        <td>92.4 ms</td>
        <td>166 ms</td>
        <td>10942</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR ARCHIVE LOW</td>
        <td>46 MB</td>
        <td>204 s</td>
        <td>0,9 ms</td>
        <td>8.01</td>
        <td>16716 ms</td>
        <td>0.0107</td>
        <td>585 ms</td>
        <td>0.0105</td>
        <td>14821 ms</td>
        <td>18610 ms</td>
        <td>0.002</td>
        <td>128 ms</td>
        <td>7915</td>
        <td>76.5 ms</td>
        <td>143 ms</td>
        <td>8046</td>
    </tr>
    <tr>
        <td>COLUMN STORE COMPRESS FOR ARCHIVE HIGH</td>
        <td>46 MB</td>
        <td>410 s</td>
        <td>16.2 ms</td>
        <td>11.34</td>
        <td>16265 ms</td>
        <td>0.0106</td>
        <td>14146 ms</td>
        <td>0.0104</td>
        <td>14146 ms</td>
        <td>18800 ms</td>
        <td>0.0015</td>
        <td>633 ms</td>
        <td>6668</td>
        <td>331 ms</td>
        <td>647 ms</td>
        <td>6749</td>
    </tr>
</table>
