# Index access
Consider the efficiency and metrics of index access

## au_wg_bestand.sql
This test script checks the runtime and the number of consistent gets for an index access.

Each block of the index is accessed only once.
This is ensured by selecting with a filter where each index partition only has one row hit.

Several compression strategies are evaluated and compared this way.