#! /bin/bash
# Function defintion to help analyze jtl failures.
# Creates two files count.failure and uniq.failure
# Requires one argument the jtl file to analyze.

jtl_failure(){
    if [[ ! -f $1 ]]; then
        echo "Requires one argument, the jtl results file."
        return 1
    fi
    
    grep false $1 > failures.jtl
    cut -f3 -d, failures.jtl | sort | uniq -c | sort -nr | tee  count.failure		
    sort -u -t, -k3,3 failures.jtl > uniq.failure
    rm failures.jtl
}