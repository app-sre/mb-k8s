#!/bin/bash

set -e

function log() {
    echo "$(date +%Y%m%d%H%M%S) - $1"
}

function copy_response_file() {
    log "Compressing $RESPONSE_FILE"
    xz $RESPONSE_FILE
    log "Copying ${RESPONSE_FILE}.xz to $S3_BUCKET_NAME bucket"
    aws s3 cp "${RESPONSE_FILE}.xz" "s3://$S3_BUCKET_NAME"
    local rc=$?
    rm $RESPONSE_FILE.xz
    exit $rc
}

## env check
COUNT=0
for VAR in DURATION \
           REQUEST_FILE
do
    if [[ ! "${!VAR}" ]]; then
        echo "$VAR not defined"
        COUNT=$((COUNT + 1))
    fi
done

if [[ "$STORE_OUTPUT" != "" ]]; then
    for VAR in AWS_ACCESS_KEY_ID \
               AWS_SECRET_ACCESS_KEY \
               AWS_DEFAULT_REGION \
               S3_BUCKET_NAME \
               POD_NAME \
               TEMP_DIR
    do
        if [[ ! "${!VAR}" ]]; then
            echo "$VAR not defined while STORE_OUTPUT is"
            COUNT=$((COUNT + 1))
        fi
    done
fi

[[ $COUNT -gt 0 ]] && exit 1

# Here we go!
ULIMIT=${ULIMIT:-1048576}
ulimit -n $ULIMIT

CMD="mb --duration $DURATION --request-file $REQUEST_FILE"
[[ -n "$RAMP_UP" ]] && CMD="$CMD --ramp-up $RAMP_UP"
[[ -n "$THREADS" ]] && CMD="$CMD --threads $THREADS"
if [[ -n "$STORE_OUTPUT" ]]; then
    RESPONSE_FILE="$TEMP_DIR/mb-results-$POD_NAME-$(date +%Y%m%d_%H%M%S).csv"
    CMD="$CMD --response-file $RESPONSE_FILE"
    trap copy_response_file INT TERM
fi

log "Running $CMD"
$CMD

[[ -n "$STORE_OUTPUT" ]] && copy_response_file
