FROM debian:buster-slim as builder

ARG MB_VERSION=e968d39e427a6f2180fc91e7531be59331f5a27e

RUN apt-get update && \
    apt-get install -y git make gcc autogen curl autoconf libtool && \
    git clone --depth 1 https://github.com/jmencak/mb.git && \
    cd mb && \
    git checkout $MB_VERSION && \
    make && \
    rm -rf /var/lib/apt/lists/*

FROM python:3.8.1-slim-buster

ARG AWS_CLI_VERSION=1.17.9

RUN pip install --no-cache-dir awscli==$AWS_CLI_VERSION && \
    apt-get update && \
    apt-get install xz-utils && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /mb/mb /usr/local/bin

ADD attack.sh /usr/local/bin

CMD attack.sh
