We want to benchmark tasks in 3 systems:
- NATIVE - Nim compiled to native
- WASM   - Nim compiled to wasm (run in node)
- JS     - JavaScript

Other than platform-specific imports, the same Nim code should be used for both the NATIVE and WASM systems.

Random inputs should be avoided. Create datasets as separate files with pre-randomized data instead.

Each task should have a key/identifier.
Each task may be run multiple times per system.
We are only focused on benchmarking time to complete the task on a single core.
Throughput and latency are not in scope.
Aggregations will be collected across the runs.
The aggregations for each task should be output to csv.
The aggregations should include:
- total runs
- min time
- max time
- mean time
- median time

So the output csv rows should look like:
```
<task key>,<total runs>,<min time>,<max time>,<mean time>,<median time>
```

Each system should have its own csv file as output which contains the row for each task.

A script will run each of the systems, collect the respective outputs, compare them, and formulate some concise shared report as output.