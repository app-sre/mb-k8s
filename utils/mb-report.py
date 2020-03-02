#!/usr/bin/env python

# needs at least python 3.8.0

import sys
import lzma
import statistics

ROUND_PRECISION = 2

def format_microseconds(ms):
    if ms >= 1e6:
        return "%ss" % round(ms/1e6, ROUND_PRECISION)
    elif 1e3 <= ms < 1e6:
        return "%sms" % round(ms/1e3, ROUND_PRECISION)
    elif 1 <= ms < 1e3:
        return "%sμs" % ms
    elif ms < 1:
        return "%sns" % round(ms * 1e3, ROUND_PRECISION)

if not len(sys.argv) == 2:
    print("Usage: %s request-file.xz" % sys.argv[0])
    sys.exit(1)

results_file = sys.argv[1]

# start_request(0),delay(1),status(2),written(3),read(4),method_and_url(5),thread_id(6),conn_id(7),conns(8),reqs(9),start(10),socket_writable(11),conn_est(12),tls_reuse(13),err(14)

with lzma.open(results_file) as f:
    lines = f.read().decode().strip('\n').split('\n')

    first_request = lines[0].split(",")
    last_request = lines[-1].split(",")
    latencies = []
    end_times = []
    status = {}
    bytes_in = []
    bytes_out = []
    errors = []
    for line in lines:
        fields = line.split(",")
        if len(fields) != 15:
            raise Exception("Unknown line format [%s])" % line)

        latencies.append(int(fields[1]))
        end_times.append(int(fields[0]) + int(fields[1]))
        bytes_in.append(int(fields[4]))
        bytes_out.append(int(fields[3]))
        if fields[2] in status:
            status[fields[2]] += 1
        else:
            status[fields[2]] = 1

        if fields[14]:
            errors.append(fields[14])


TEMPLATE = '''
Requests      [total, rate, throughput]  %(total_requests)s, %(request_rate)s, %(request_throughput)s
Duration      [total, attack, wait]      %(total_duration)s, %(attack_duration)s
Latencies     [mean, 50, 95, 99, max]    %(mean_latency)s, %(p50_latency)s, %(p95_latency)s, %(p99_latency)s, %(max_latency)s
Bytes In      [total, mean]              %(bytes_in_total)s, %(bytes_in_mean)s
Bytes Out     [total, mean]              %(bytes_out_total)s, %(bytes_out_mean)s
Success       [ratio]                    %(success_ratio)s
Status Codes  [code:count]               %(status_codes_count)s
Error Set:
%(error_set)s'''

total_requests = len(latencies)
attack_duration = int(last_request[0]) - int(first_request[0])
latencies_pctls = statistics.quantiles(latencies, n=100)
total_duration = max(end_times) - int(first_request[0])
status_codes_count = ",".join([ "%s:%s" % (k,v) for k,v in status.items() ])

success_ratio = 0
request_throughput = 0
if "200" in status:
    success_ratio = round(100 * status["200"] / total_requests,
                          ROUND_PRECISION)
    request_throughput = round(status["200"] / (attack_duration/1e6),
                               ROUND_PRECISION)


error_set = {}
for error in errors:
    if error in error_set:
        error_set[error] += 1
    else:
        error_set[error] = 1

values = {
    'total_requests': total_requests,
    'request_rate': round(total_requests / (attack_duration/1e6), ROUND_PRECISION),
    'request_throughput': request_throughput,
    'attack_duration': format_microseconds(attack_duration),
    'total_duration': format_microseconds(total_duration),
    'mean_latency': format_microseconds(statistics.mean(latencies)),
    'p50_latency': format_microseconds(latencies_pctls[49]),
    'p95_latency': format_microseconds(latencies_pctls[94]),
    'p99_latency': format_microseconds(latencies_pctls[98]),
    'max_latency': format_microseconds(max(latencies)),
    'bytes_in_total': sum(bytes_in),
    'bytes_in_mean': round(sum(bytes_in) / total_requests, ROUND_PRECISION),
    'bytes_out_total': sum(bytes_out),
    'bytes_out_mean': round(sum(bytes_out) / total_requests, ROUND_PRECISION),
    'success_ratio': success_ratio,
    'status_codes_count': status_codes_count,
    'error_set': "\n".join(["%s:%s" % (k,v) for k,v in error_set.items()])
}

print(TEMPLATE % values)
