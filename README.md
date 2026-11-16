# PostgreSQL 17.4 B-Tree Optimization

**CSCI 543 Project — University of Southern California**

An experimental study of two B-Tree access-path optimizations in PostgreSQL 17.4,
benchmarked against the IMDB / Join Order Benchmark (JOB) workload.

The project adds two runtime-toggleable B-Tree tuning knobs to a patched build of
PostgreSQL 17.4 and measures their effect on query latency with a reproducible,
cache-aware A/B harness.

---

## Optimizations under test

Both optimizations are exposed as session-level GUC parameters (set with
`SET <name> = on | off;`) so they can be turned on and off without recompiling or
restarting the server. They are implemented as modifications to the PostgreSQL 17.4
B-Tree access method (`nbtree`).

| GUC parameter | Idea | What it changes |
| --- | --- | --- |
| `btree_binsrch_linear` | **Linear in-page search** | Replaces the binary search used to locate a key within a B-Tree page with a linear scan, which can be cheaper on small/cache-resident pages and more branch-predictor friendly. |
| `btree_leaf_prefetch` | **Leaf-page prefetch** | Issues prefetch hints for upcoming B-Tree leaf pages so index scans overlap I/O with computation instead of stalling on each page fetch. |

> **Note:** The C source changes that implement these two GUCs live in the
> PostgreSQL 17.4 source tree (the `nbtree` access method), **not** in this
> repository. This repo contains the environment, the dataset loader, and the
> benchmark harness used to evaluate those changes. Build PostgreSQL 17.4 from a
> source tree that already has the patches applied; on an unpatched build the
> `SET btree_binsrch_linear` / `SET btree_leaf_prefetch` statements will error.

---

## Repository layout

```
.
├── Dockerfile                         # Ubuntu 22.04 build/debug environment for PostgreSQL
├── load_imdb/
│   ├── load-postgres/                 # IMDB/JOB schema + loader
│   │   ├── schema.sql                 # table definitions
│   │   ├── add_fks.sql                # foreign keys
│   │   ├── fkindexes.sql              # indexes on FK columns
│   │   └── load_job_postgres.sh       # loads the IMDB data into PostgreSQL
│   ├── job_queries/                   # 113 Join Order Benchmark queries (1a.sql … 33c.sql)
│   ├── prepend_imdb_headers.sh        # adds CSV headers the loader expects
│   ├── benchmark_queries_linear.sh    # A/B test: btree_binsrch_linear off vs on
│   ├── benchmark_queries_prefetch.sh  # A/B test: btree_leaf_prefetch off vs on
│   └── benchmark_queries_prefetch_linear.sh  # A/B test: both off vs both on
```

---

## Prerequisites

- **Docker** on the host (the Dockerfile targets Ubuntu 22.04). Other platforms
  — a native Linux server or WSL — also work; adjust paths accordingly.
- A **PostgreSQL 17.4 source tree with the B-Tree patches applied**, built in
  debug mode.
- Enough disk and memory for the PostgreSQL build and the IMDB/JOB dataset
  (~several GB).
- *(Optional)* VS Code with the C/C++ extension for GDB-attach debugging.

---

## 1. Build and run the container

```bash
# From the folder containing the Dockerfile:
docker build -t csci543_image:latest .

# Large /dev/shm, privileged mode, and ptrace caps for debugging:
docker run --name csci543_container --privileged -it \
    --shm-size=32g \
    --cap-add=SYS_PTRACE --cap-add=CAP_SYS_ADMIN \
    csci543_image:latest
```

The image ships with the build toolchain (bison, flex, build-essential, cmake),
debugging tools (gdb, valgrind, libc6-dbg), and a non-root `imrkale1` user with
sudo access.

## 2. Build PostgreSQL 17.4 (patched, debug)

Inside the container, build the patched PostgreSQL 17.4 source in debug mode
(`-O0`, `--enable-debug`). Point `--prefix` at your home directory and put the
resulting `bin/` first on your `PATH`.

```bash
cd ~
# Use your patched 17.4 source tree, then:
CFLAGS=-O0 ./configure --prefix=$HOME/postgresql-17.4 --enable-debug
make -j8          # pick a -j value that suits your CPU
make install
echo "export PATH=$HOME/postgresql-17.4/bin:\$PATH" >> ~/.bashrc
source ~/.bashrc
```

After editing the source, rebuild with `make -j8 && make install` and restart the
server.

## 3. Initialize and start a database cluster

```bash
pg_ctl -D $HOME/databases initdb
pg_ctl -D $HOME/databases -l logfile start
# restart after a rebuild:
pg_ctl -D $HOME/databases -l logfile restart
# stop when done:
pg_ctl -D $HOME/databases stop
```

## 4. Load the IMDB / JOB dataset

```bash
cd ~/load_imdb

# Download the IMDB data used by the Join Order Benchmark
mkdir -p datasets/job && pushd datasets/job
wget -c https://event.cwi.nl/da/job/imdb.tgz
tar -xvzf imdb.tgz && popd

# Add the CSV headers the loader expects
bash ./prepend_imdb_headers.sh

# Load schema + data (tmux recommended so a disconnect doesn't kill the load)
bash load-postgres/load_job_postgres.sh $HOME/load_imdb/datasets/job
```

Verify the load with any JOB query:

```bash
psql -U imrkale1 -d imdbload -f job_queries/1a.sql
```

---

## 5. Run the benchmarks

Each script is a cache-aware A/B test over all 113 JOB queries. For every query it
runs the setting **on** and **off**, then repeats the whole set in the opposite
order, so ordering and warm-cache effects cancel out. Run them from the
`load_imdb/` directory (they look for `job_queries/` relative to the current
directory):

```bash
cd ~/load_imdb

bash benchmark_queries_linear.sh            # btree_binsrch_linear: off vs on
bash benchmark_queries_prefetch.sh          # btree_leaf_prefetch:  off vs on
bash benchmark_queries_prefetch_linear.sh   # both off vs both on (combined)
```

Before running, open the script and set the connection variables to match your
setup (`DB_USER`, `DB_NAME`, `DB_HOST`, `DB_PORT` — defaults are
`imrkale1` / `imdbload` / `localhost` / `5432`). Each query has a 300-second timeout.

### How the A/B test works

- **Loop 1:** for each query, run with the setting `ON`, then `OFF`.
- **Loop 2:** for each query, run with the setting `OFF`, then `ON`.
- The reported duration for each setting is the **average of its two runs**
  (one from each loop), which balances out the order in which the settings ran.
- Durations are wall-clock milliseconds measured around each `psql` invocation.

> The scripts deliberately do **not** flush the database or OS page cache between
> runs, so numbers reflect warm-cache behavior. Interpret absolute timings
> accordingly; the on-vs-off *delta* is the quantity of interest.

### Output

Each script writes to its own results directory (recreated on every run):

| Script | Results directory |
| --- | --- |
| `benchmark_queries_linear.sh` | `benchmark_results_linear/` |
| `benchmark_queries_prefetch.sh` | `benchmark_results_prefetch/` |
| `benchmark_queries_prefetch_linear.sh` | `benchmark_results_prefetch_linear/` |

Inside each directory:

- `query_benchmark_results.txt` — human-readable log and final per-query summary.
- `query_timing.csv` — every run: `query_file, test_round, btree_setting, start_time, end_time, duration_ms, status`.
- `performance_comparison.csv` — per-query comparison: off vs on averages, absolute improvement (ms), and percent improvement.
- `<query>_<setting>_loopN.result` / `.error` — raw query output and errors per run.

The run finishes with an aggregate summary: how many queries each setting won,
the average improvement in each direction, and the maximum improvement observed.
