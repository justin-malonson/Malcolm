FROM debian:12-slim

# Copyright (c) 2024 Battelle Energy Alliance, LLC.  All rights reserved.
LABEL maintainer="malcolm@inl.gov"
LABEL org.opencontainers.image.authors='malcolm@inl.gov'
LABEL org.opencontainers.image.url='https://github.com/cisagov/Malcolm'
LABEL org.opencontainers.image.documentation='https://github.com/cisagov/Malcolm/blob/main/README.md'
LABEL org.opencontainers.image.source='https://github.com/cisagov/Malcolm'
LABEL org.opencontainers.image.vendor='Idaho National Laboratory'
LABEL org.opencontainers.image.title='ghcr.io/cisagov/malcolm/pcap-monitor'
LABEL org.opencontainers.image.description='Malcolm container watching for captured or uploaded artifacts to be processed'

ARG DEFAULT_UID=1000
ARG DEFAULT_GID=1000
ENV DEFAULT_UID $DEFAULT_UID
ENV DEFAULT_GID $DEFAULT_GID
ENV PUSER "watcher"
ENV PGROUP "watcher"
# not dropping privileges globally: supervisord will take care of it
# on a case-by-case basis so that one script (watch-pcap-uploads-folder.sh)
# can chown uploaded files
ENV PUSER_PRIV_DROP false

ENV DEBIAN_FRONTEND noninteractive
ENV TERM xterm
ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1

ARG PCAP_PATH=/pcap
ARG PCAP_PIPELINE_VERBOSITY=""
ARG PCAP_PIPELINE_IGNORE_PREEXISTING=false
ARG PCAP_PIPELINE_POLLING=false
ARG PCAP_PIPELINE_POLLING_ASSUME_CLOSED_SEC=10
ARG PCAP_NODE_NAME=malcolm
ARG ZEEK_PATH=/zeek

ENV PCAP_PATH $PCAP_PATH
ENV PCAP_PIPELINE_VERBOSITY $PCAP_PIPELINE_VERBOSITY
ENV PCAP_PIPELINE_IGNORE_PREEXISTING $PCAP_PIPELINE_IGNORE_PREEXISTING
ENV PCAP_PIPELINE_POLLING $PCAP_PIPELINE_POLLING
ENV PCAP_PIPELINE_POLLING_ASSUME_CLOSED_SEC $PCAP_PIPELINE_POLLING_ASSUME_CLOSED_SEC
ENV PCAP_NODE_NAME $PCAP_NODE_NAME
ENV ZEEK_PATH $ZEEK_PATH

RUN apt-get -q update && \
    apt-get -y -q --no-install-recommends upgrade && \
    apt-get install --no-install-recommends -y -q \
      file \
      inotify-tools \
      libzmq5 \
      procps \
      psmisc \
      python3-pip \
      python3-setuptools \
      python3-wheel \
      rsync \
      supervisor \
      tini \
      vim-tiny && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    python3 -m pip install --break-system-packages --no-compile --no-cache-dir \
      elasticsearch \
      elasticsearch-dsl \
      opensearch-py \
      python-magic \
      pyzmq \
      requests \
      watchdog && \
    groupadd --gid ${DEFAULT_GID} ${PGROUP} && \
      useradd -M --uid ${DEFAULT_UID} --gid ${DEFAULT_GID} ${PUSER}

COPY --chmod=644 pcap-monitor/supervisord.conf /etc/supervisord.conf
COPY --chmod=644 scripts/malcolm_utils.py /usr/local/bin/
COPY --chmod=644 shared/bin/pcap_utils.py /usr/local/bin/
COPY --chmod=644 shared/bin/watch_common.py /usr/local/bin/
COPY --chmod=755 pcap-monitor/scripts/watch-pcap-uploads-folder.py /usr/local/bin/
COPY --chmod=755 shared/bin/docker-uid-gid-setup.sh /usr/local/bin/
COPY --chmod=755 shared/bin/pcap_watcher.py /usr/local/bin/
COPY --chmod=755 shared/bin/service_check_passthrough.sh /usr/local/bin/
COPY --from=ghcr.io/mmguero-dev/gostatic --chmod=755 /goStatic /usr/bin/goStatic

EXPOSE 30441

ENTRYPOINT ["/usr/bin/tini", \
            "--", \
            "/usr/local/bin/docker-uid-gid-setup.sh", \
            "/usr/local/bin/service_check_passthrough.sh", \
            "-s", "pcap-monitor"]

CMD ["/usr/bin/supervisord", "-c", "/etc/supervisord.conf", "-u", "root", "-n"]


# to be populated at build-time:
ARG BUILD_DATE
ARG MALCOLM_VERSION
ARG VCS_REVISION
ENV BUILD_DATE $BUILD_DATE
ENV MALCOLM_VERSION $MALCOLM_VERSION
ENV VCS_REVISION $VCS_REVISION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.version=$MALCOLM_VERSION
LABEL org.opencontainers.image.revision=$VCS_REVISION
