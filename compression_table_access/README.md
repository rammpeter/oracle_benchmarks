# Table access
Consider the efficiency and metrics of table access

## index_partitioned.sql
This test script checks the runtime and the number of consistent gets for an table access.

Each block of the index is accessed only once by calculating the block number from rowid.

Tests are executed with the lowest and the highest rowid of a block.

Several compression strategies are evaluated and compared this way.

To ensure comparability all DB blocks must be accessed in DB cache without disk reads.
