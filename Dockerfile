FROM registry.access.redhat.com/ubi8/ubi as builder

ARG MB_VERSION=e968d39e427a6f2180fc91e7531be59331f5a27e

RUN yum install -y git gcc libtool automake make && \
    git clone --depth 1 https://github.com/jmencak/mb.git && \
    cd mb && \
    git checkout $MB_VERSION && \
    make

FROM registry.access.redhat.com/ubi8/python-36

ARG AWS_CLI_VERSION=1.17.9

RUN pip install --no-cache-dir awscli==$AWS_CLI_VERSION

COPY --from=builder /mb/mb /opt/app-root/bin

ADD attack.sh /opt/app-root/bin

CMD attack.sh
