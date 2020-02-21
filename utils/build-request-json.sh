#!/bin/bash

function usage() {
    echo "Usage: $0 -f targets-list-file [options]"
    exit 1
}

OPTIONS=$(getopt -o f:tm:b:k:c:p:d:h -- "$@")
[[ $? == 0 ]] || { echo "Incorrect options provided"; exit 1; }
eval set -- "${OPTIONS}"

while true; do
    case "$1" in
        -f ) TARGETS_LIST="${2}"; shift 2;;
        -t ) TLS_SESSION_REUSE="true"; shift;;
        -m ) METHOD="${2}"; shift 2;;
        -b ) REQUEST_BODY_SIZE="${2}"; shift 2;;
        -k ) KA_REQUESTS="${2}"; shift 2;;
        -c ) CONNS_PER_TARGET="${2}"; shift 2;;
        -p ) URL_PATH="${2}"; shift 2;;
        -d ) DELAY="${2}"; shift 2;;
        -h ) usage;;
        -- ) shift; break;
    esac
done

[[ -n ${TARGETS_LIST} ]] || usage
[[ -f ${TARGETS_LIST} ]] || { echo "${TARGETS_LIST} does not exist"; exit 1; }

## adapted from https://github.com/openshift-scale/images/blob/master/http-stress/root/requests-mb.awk
## GNU AWK required
awk -vtls_session_reuse=${TLS_SESSION_REUSE:-false} \
    -vmethod=${METHOD:-GET} \
    -vbody_length=${REQUEST_BODY_SIZE:-128} \
    -vka_requests=${KA_REQUESTS:-100} \
    -vclients=${CONNS_PER_TARGET:-10} \
    -vpath=${URL_PATH:-/} \
    -vdelay_min=0 \
    -vdelay_max=${DELAY:-1000} \
'
match($1, "^http://(.+)$", arr) { # insecure routes
  if (i) {printf "\n  },\n" }
  printf "  {\n"
#  printf "    \"host_from": \"192.168.0.102\",
  printf "    \"scheme\": \"http\",\n"
#  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", arr[1]
  printf "    \"port\": 80,\n"
  printf "    \"method\": \"%s\",\n", method
  printf "    \"path\": \"%s\",\n", path
  if (method == "POST") {
    printf "    \"headers\": {\n"
    printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
    printf "    },\n"
    printf "    \"body\": \""
    printf("%0*d\",\n", body_length, 0);
  }
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
match($1, "^https://(.+)$", arr) { # insecure routes
  if (i) {printf "\n  },\n" }
  printf "  {\n"
  printf "    \"scheme\": \"https\",\n"
  printf "    \"tls-session-reuse\": %s,\n", tls_session_reuse
  printf "    \"host\": \"%s\",\n", arr[1]
  printf "    \"port\": 443,\n"
  printf "    \"method\": \"%s\",\n", method
  printf "    \"path\": \"%s\",\n", path
  if (method == "POST") {
    printf "    \"headers\": {\n"
    printf "      \"Content-Type\": \"application/x-www-form-urlencoded\"\n"
    printf "    },\n"
    printf "    \"body\": \""
    printf("%0*d\",\n", body_length, 0);
  }
  printf "    \"keep-alive-requests\": %s,\n", ka_requests
  printf "    \"clients\": %s,\n", clients
  printf "    \"delay\": {\n"
  printf "      \"min\": %s,\n", delay_min
  printf "      \"max\": %s\n", delay_max
  printf "    }"
  i++
}
BEGIN { i=0; printf "[\n" }
END {
  if (i) { printf "\n  }" }
  printf "\n]\n"
}
' ${TARGETS_LIST}
