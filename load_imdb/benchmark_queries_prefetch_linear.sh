#!/bin/bash

# PostgreSQL connection parameters
DB_NAME="imdbload"
# You may use your own username here
DB_USER="qihan"
DB_HOST="localhost"
DB_PORT="5432"

# Output files
OUTPUT_FILE="query_benchmark_results.txt"
TIMING_FILE="query_timing.csv"
COMPARISON_FILE="performance_comparison.csv"

# Create output directory
RESULTS_DIR="benchmark_results_prefetch_linear"
# if this directory exists, delete it, to avoid appending to the existing file
if [ -d "$RESULTS_DIR" ]; then
    rm -rf "$RESULTS_DIR"
fi
mkdir -p "$RESULTS_DIR"

# Clear output files
> "$RESULTS_DIR/$OUTPUT_FILE"
> "$RESULTS_DIR/$TIMING_FILE"
> "$RESULTS_DIR/$COMPARISON_FILE"

# Write CSV headers
echo "query_file,test_round,btree_setting,start_time,end_time,duration_ms,status" > "$RESULTS_DIR/$TIMING_FILE"
echo "query_file,off_off_duration_ms,on_on_duration_ms,performance_improvement_ms,improvement_percent,off_off_order,on_on_order" > "$RESULTS_DIR/$COMPARISON_FILE"

echo "Starting SQL query performance A/B test..." | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "================================================" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Test time: $(date)" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Database: $DB_NAME@$DB_HOST:$DB_PORT" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Testing: btree_leaf_prefetch = off + btree_binsrch_linear = off vs btree_leaf_prefetch = on + btree_binsrch_linear = on" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "================================================" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

# Get all SQL files and sort them
SQL_FILES=$(find "job_queries" -name "*.sql" | sort -V)

# Counters
TOTAL_FILES=$(echo "$SQL_FILES" | wc -l)
CURRENT=0

# Arrays to store timing results for each query
declare -A ON_ON_DURATIONS_ROUND1
declare -A OFF_OFF_DURATIONS_ROUND1
declare -A ON_ON_DURATIONS_ROUND2
declare -A OFF_OFF_DURATIONS_ROUND2

# Big Loop 1: ON_ON first, then OFF_OFF
echo "=== BIG LOOP 1: btree_leaf_prefetch = ON + btree_binsrch_linear = ON first, then both OFF ===" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

CURRENT=0
for sql_file in $SQL_FILES; do
    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TOTAL_FILES] Loop 1 - Testing: $sql_file" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    
    # Test with btree_leaf_prefetch = ON + btree_binsrch_linear = ON
    echo "  Testing with btree_leaf_prefetch = ON + btree_binsrch_linear = ON..." | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    START_TIME=$(date +%s%3N)
    START_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    timeout 300 psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" \
        -c "\timing on" \
        -c "SET btree_leaf_prefetch = on;" \
        -c "SET btree_binsrch_linear = on;" \
        -f "$sql_file" \
        -o "$RESULTS_DIR/${sql_file##*/}_on_on_loop1.result" \
        2> "$RESULTS_DIR/${sql_file##*/}_on_on_loop1.error"
    
    EXIT_CODE=$?
    END_TIME=$(date +%s%3N)
    END_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    DURATION=$((END_TIME - START_TIME))
    ON_ON_DURATIONS_ROUND1["$sql_file"]=$DURATION
    
    echo "    Duration: ${DURATION}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "$sql_file,1,on_on,$START_READABLE,$END_READABLE,$DURATION,$(if [ $EXIT_CODE -eq 0 ]; then echo "SUCCESS"; else echo "FAILED"; fi)" >> "$RESULTS_DIR/$TIMING_FILE"
    
    # Short pause to reduce immediate interference; note this does NOT clear DB/OS caches
    sleep 1
    
    # Test with btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF
    echo "  Testing with btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF..." | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    START_TIME=$(date +%s%3N)
    START_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    timeout 300 psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" \
        -c "\timing on" \
        -c "SET btree_leaf_prefetch = off;" \
        -c "SET btree_binsrch_linear = off;" \
        -f "$sql_file" \
        -o "$RESULTS_DIR/${sql_file##*/}_off_off_loop1.result" \
        2> "$RESULTS_DIR/${sql_file##*/}_off_off_loop1.error"
    
    EXIT_CODE=$?
    END_TIME=$(date +%s%3N)
    END_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    DURATION=$((END_TIME - START_TIME))
    OFF_OFF_DURATIONS_ROUND1["$sql_file"]=$DURATION
    
    echo "    Duration: ${DURATION}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "$sql_file,1,off_off,$START_READABLE,$END_READABLE,$DURATION,$(if [ $EXIT_CODE -eq 0 ]; then echo "SUCCESS"; else echo "FAILED"; fi)" >> "$RESULTS_DIR/$TIMING_FILE"
    
    echo "  Loop 1 - ON+ON: ${ON_ON_DURATIONS_ROUND1["$sql_file"]}ms, OFF+OFF: ${OFF_OFF_DURATIONS_ROUND1["$sql_file"]}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    
    # Wait before next query
    sleep 3
done

echo "=== BIG LOOP 2: btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF first, then both ON ===" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

CURRENT=0
for sql_file in $SQL_FILES; do
    CURRENT=$((CURRENT + 1))
    echo "[$CURRENT/$TOTAL_FILES] Loop 2 - Testing: $sql_file" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    
    # Test with btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF
    echo "  Testing with btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF..." | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    START_TIME=$(date +%s%3N)
    START_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    timeout 300 psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" \
        -c "\timing on" \
        -c "SET btree_leaf_prefetch = off;" \
        -c "SET btree_binsrch_linear = off;" \
        -f "$sql_file" \
        -o "$RESULTS_DIR/${sql_file##*/}_off_off_loop2.result" \
        2> "$RESULTS_DIR/${sql_file##*/}_off_off_loop2.error"
    
    EXIT_CODE=$?
    END_TIME=$(date +%s%3N)
    END_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    DURATION=$((END_TIME - START_TIME))
    OFF_OFF_DURATIONS_ROUND2["$sql_file"]=$DURATION
    
    echo "    Duration: ${DURATION}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "$sql_file,2,off_off,$START_READABLE,$END_READABLE,$DURATION,$(if [ $EXIT_CODE -eq 0 ]; then echo "SUCCESS"; else echo "FAILED"; fi)" >> "$RESULTS_DIR/$TIMING_FILE"
    
    # Short pause to reduce immediate interference; note this does NOT clear DB/OS caches
    sleep 1
    
    # Test with btree_leaf_prefetch = ON + btree_binsrch_linear = ON
    echo "  Testing with btree_leaf_prefetch = ON + btree_binsrch_linear = ON..." | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    START_TIME=$(date +%s%3N)
    START_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    
    timeout 300 psql -U "$DB_USER" -d "$DB_NAME" -h "$DB_HOST" -p "$DB_PORT" \
        -c "\timing on" \
        -c "SET btree_leaf_prefetch = on;" \
        -c "SET btree_binsrch_linear = on;" \
        -f "$sql_file" \
        -o "$RESULTS_DIR/${sql_file##*/}_on_on_loop2.result" \
        2> "$RESULTS_DIR/${sql_file##*/}_on_on_loop2.error"
    
    EXIT_CODE=$?
    END_TIME=$(date +%s%3N)
    END_READABLE=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    DURATION=$((END_TIME - START_TIME))
    ON_ON_DURATIONS_ROUND2["$sql_file"]=$DURATION
    
    echo "    Duration: ${DURATION}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "$sql_file,2,on_on,$START_READABLE,$END_READABLE,$DURATION,$(if [ $EXIT_CODE -eq 0 ]; then echo "SUCCESS"; else echo "FAILED"; fi)" >> "$RESULTS_DIR/$TIMING_FILE"
    
    echo "  Loop 2 - OFF+OFF: ${OFF_OFF_DURATIONS_ROUND2["$sql_file"]}ms, ON+ON: ${ON_ON_DURATIONS_ROUND2["$sql_file"]}ms" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    
    # Wait before next query
    sleep 3
done

echo "=== CALCULATING FINAL RESULTS ===" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

# Calculate final averages and generate comparison results
for sql_file in $SQL_FILES; do
    # Calculate averages
    AVG_OFF_OFF=$(( (OFF_OFF_DURATIONS_ROUND1["$sql_file"] + OFF_OFF_DURATIONS_ROUND2["$sql_file"]) / 2 ))
    AVG_ON_ON=$(( (ON_ON_DURATIONS_ROUND1["$sql_file"] + ON_ON_DURATIONS_ROUND2["$sql_file"]) / 2 ))
    
    # Calculate performance improvement (always relative to OFF_OFF setting)
    IMPROVEMENT=$((AVG_OFF_OFF - AVG_ON_ON))  # Positive if ON_ON is faster, negative if ON_ON is slower
    if [ "$AVG_OFF_OFF" -gt 0 ]; then
        IMPROVEMENT_PERCENT=$(echo "scale=2; $IMPROVEMENT * 100 / $AVG_OFF_OFF" | bc -l)
    else
        IMPROVEMENT_PERCENT=0
    fi
    
    # Generate descriptive text
    if [ $IMPROVEMENT -gt 0 ]; then
        IMPROVEMENT_TEXT="ON+ON faster by ${IMPROVEMENT}ms (${IMPROVEMENT_PERCENT}%)"
    elif [ $IMPROVEMENT -lt 0 ]; then
        # Convert negative improvement to positive for display
        ABS_IMPROVEMENT=$((-IMPROVEMENT))
        # Handle negative percentage (remove minus sign and convert to positive)
        ABS_PERCENT=$(echo "$IMPROVEMENT_PERCENT" | sed 's/^-//')
        IMPROVEMENT_TEXT="ON+ON slower by ${ABS_IMPROVEMENT}ms (${ABS_PERCENT}%)"
    else
        IMPROVEMENT_TEXT="ON+ON and OFF+OFF have same performance (0ms, 0.00%)"
    fi
    
    echo "Final Results for $sql_file:" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "  btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF: ${AVG_OFF_OFF}ms (avg: ${OFF_OFF_DURATIONS_ROUND1["$sql_file"]}ms, ${OFF_OFF_DURATIONS_ROUND2["$sql_file"]}ms)" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "  btree_leaf_prefetch = ON + btree_binsrch_linear = ON:  ${AVG_ON_ON}ms (avg: ${ON_ON_DURATIONS_ROUND1["$sql_file"]}ms, ${ON_ON_DURATIONS_ROUND2["$sql_file"]}ms)" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "  Result: $IMPROVEMENT_TEXT" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    echo "================================================" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
    
    # Write to comparison CSV
    echo "$sql_file,$AVG_OFF_OFF,$AVG_ON_ON,$IMPROVEMENT,$IMPROVEMENT_PERCENT,loop1,loop2" >> "$RESULTS_DIR/$COMPARISON_FILE"
done

echo "================================================" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Test finished at: $(date)" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Total files: $TOTAL_FILES" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Results saved to: $RESULTS_DIR/" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Detailed log: $RESULTS_DIR/$OUTPUT_FILE" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Timing details: $RESULTS_DIR/$TIMING_FILE" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Performance comparison: $RESULTS_DIR/$COMPARISON_FILE" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

# Generate summary
echo "" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "Performance comparison summary:" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
echo "----------------------------------------" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

# Compute stats from comparison file (exclude CSV header)
tail -n +2 "$RESULTS_DIR/$COMPARISON_FILE" | awk -F',' '
    BEGIN {
        count=0;
        off_off_faster=0;
        on_on_faster=0;
        on_on_faster_total_improvement=0;
        off_off_faster_total_improvement=0;
        max_improvement=0;
    }
    {
        count++
        off_off_duration=$2
        on_on_duration=$3

        if (off_off_duration > on_on_duration) {
            on_on_faster++
            improvement = off_off_duration - on_on_duration
            on_on_faster_total_improvement += improvement
            if (improvement > max_improvement) max_improvement = improvement
        } else if (on_on_duration > off_off_duration) {
            off_off_faster++
            improvement = on_on_duration - off_off_duration
            off_off_faster_total_improvement += improvement
            if (improvement > max_improvement) max_improvement = improvement
        }
    }
    END {
        if (count > 0) {
            printf "Total queries tested: %d\n", count
            printf "btree_leaf_prefetch = ON + btree_binsrch_linear = ON faster: %d (%.1f%%)\n", on_on_faster, (on_on_faster/count)*100
            printf "btree_leaf_prefetch = OFF + btree_binsrch_linear = OFF faster: %d (%.1f%%)\n", off_off_faster, (off_off_faster/count)*100
            printf "Average improvement when ON+ON is faster: %.2fms\n", (on_on_faster > 0) ? on_on_faster_total_improvement/on_on_faster : 0
            printf "Average improvement when OFF+OFF is faster: %.2fms\n", (off_off_faster > 0) ? off_off_faster_total_improvement/off_off_faster : 0
            printf "Maximum improvement observed: %.2fms\n", max_improvement
        }
    }' | tee -a "$RESULTS_DIR/$OUTPUT_FILE"

echo "================================================" | tee -a "$RESULTS_DIR/$OUTPUT_FILE"
