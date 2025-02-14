#!/bin/bash
set -e

GEN_DATA_SCALE=$1
EXPLAIN_ANALYZE=$2
RANDOM_DISTRIBUTION=$3
MULTI_USER_COUNT=$4
SINGLE_USER_ITERATIONS=$5

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc
step="multi_user_reports"

init_log $step

if [ "$MULTI_USER_COUNT" -eq "0" ]; then
    echo "MULTI_USER_COUNT set at 0 so exiting..."
else
    get_version
    if [[ "$VERSION" == *"gpdb"* ]]; then
	filter="gpdb"
    elif [ "$VERSION" == "postgresql" ]; then
	filter="postgresql"
    else
	echo "ERROR: Unsupported VERSION!"
	exit 1
    fi

    for i in $(ls $PWD/*.$filter.*.sql); do
	echo "psql -v ON_ERROR_STOP=1 -a -f $i"
	psql -v ON_ERROR_STOP=1 -a -f $i
	echo ""
    done

    filename=$(ls $PWD/*.copy.*.sql)

    for i in $(ls $PWD/../log/rollout_testing_*); do
	logfile="'""$i""'"
        echo "psql -v ON_ERROR_STOP=1 -a -f $filename -v LOGFILE=\"$logfile\""
        psql -v ON_ERROR_STOP=1 -a -f $filename -v LOGFILE="$logfile"
    done

    psql -v ON_ERROR_STOP=1 -t -A -c "select 'analyze ' || n.nspname || '.' || c.relname || ';' from pg_class c join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'tpch_testing'" | psql -v ON_ERROR_STOP=1 -t -A -e

    psql -v ON_ERROR_STOP=1 -F $'\t' -A -P pager=off -f $PWD/detailed_report.sql
    echo ""
fi

end_step $step
