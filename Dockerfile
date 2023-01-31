# Based on https://github.com/ipfs/kubo/tree/v0.18.1
FROM golang:1.19.1-buster as clone

WORKDIR /clone

RUN git clone --depth 1 --branch v0.18.1 https://github.com/ipfs/kubo kubo

# Note: when updating the go minor version here, also update the go-channel in snap/snapcraft.yml
FROM golang:1.19.1-buster

# Install deps
RUN apt-get update && apt-get install -y \
  libssl-dev \
  ca-certificates \
  fuse

ENV SRC_DIR /kubo

# Download packages first so they can be cached.
COPY --from=clone /clone/kubo/go.mod /clone/kubo/go.sum $SRC_DIR/
COPY --from=clone /clone/kubo $SRC_DIR

RUN cd $SRC_DIR \
  && go get github.com/ceramicnetwork/go-ipfs-healthcheck/plugin@v0.14.0 \
  && go get github.com/3box/go-ds-s3/plugin@v0.14.0

RUN cd $SRC_DIR \
  && echo "\nhealthcheck github.com/ceramicnetwork/go-ipfs-healthcheck/plugin 0" >> plugin/loader/preload_list \
  && echo "\ns3ds github.com/3box/go-ds-s3/plugin 0" >> plugin/loader/preload_list

RUN cd $SRC_DIR \
  && go mod download

# Preload an in-tree but disabled-by-default plugin by adding it to the IPFS_PLUGINS variable
# e.g. docker build --build-arg IPFS_PLUGINS="foo bar baz"
ARG IPFS_PLUGINS

# Build the thing.
# Also: fix getting HEAD commit hash via git rev-parse.
RUN cd $SRC_DIR \
  && mkdir -p .git/objects \
  && make build GOTAGS=openssl IPFS_PLUGINS=$IPFS_PLUGINS

COPY config_scripts/ /config_scripts

ENV CURL_VERSION v7.82.0
ENV JQ_VERISON jq-1.6
# Get su-exec, a very minimal tool for dropping privileges,
# and tini, a very minimal init daemon for containers
ENV SUEXEC_VERSION v0.2
ENV TINI_VERSION v0.19.0
RUN set -eux; \
    dpkgArch="$(dpkg --print-architecture)"; \
    case "${dpkgArch##*-}" in \
        "amd64" | "armhf" | "arm64") tiniArch="tini-static-$dpkgArch" ;;\
        *) echo >&2 "unsupported architecture: ${dpkgArch}"; exit 1 ;; \
    esac; \
  cd /tmp \
  && git clone https://github.com/ncopa/su-exec.git \
  && cd su-exec \
  && git checkout -q $SUEXEC_VERSION \
  && make su-exec-static \
  && cd /tmp \
  && wget -q -O tini https://github.com/krallin/tini/releases/download/$TINI_VERSION/$tiniArch \
  && chmod +x tini \
  && cd /tmp \
  && wget -q -O jq https://github.com/stedolan/jq/releases/download/$JQ_VERISON/jq-linux64 \
  && chmod +x jq \
  && cd /tmp \
  && wget -q -O curl https://github.com/moparisthebest/static-curl/releases/download/$CURL_VERSION/curl-amd64 \
  && chmod +x curl \
  && cd /config_scripts \
  && ./install_scripts.sh \
  && chmod -R +x /config_scripts

# Now comes the actual target image, which aims to be as small as possible.
FROM busybox:1.31.1-glibc

# Get the ipfs binary, entrypoint script, and TLS CAs from the build container.
ENV SRC_DIR /kubo
COPY --from=1 $SRC_DIR/cmd/ipfs/ipfs /usr/local/bin/ipfs
COPY container_daemon /usr/local/bin/start_ipfs
COPY --from=1 /tmp/su-exec/su-exec-static /sbin/su-exec
COPY --from=1 /tmp/tini /sbin/tini
COPY --from=1 /bin/fusermount /usr/local/bin/fusermount
COPY --from=1 /etc/ssl/certs /etc/ssl/certs
COPY --from=1 /tmp/curl /sbin/curl
COPY --from=1 /tmp/jq /sbin/jq
COPY --from=1 /config_scripts /config_scripts

# Add suid bit on fusermount so it will run properly
RUN chmod 4755 /usr/local/bin/fusermount

# Fix permissions on start_ipfs (ignore the build machine's permissions)
RUN chmod 0755 /usr/local/bin/start_ipfs

# This shared lib (part of glibc) doesn't seem to be included with busybox.
COPY --from=1 /lib/*-linux-gnu*/libdl.so.2 /lib/

# Copy over SSL libraries.
COPY --from=1 /usr/lib/*-linux-gnu*/libssl.so* /usr/lib/
COPY --from=1 /usr/lib/*-linux-gnu*/libcrypto.so* /usr/lib/

# Swarm TCP; should be exposed to the public
ENV IPFS_SWARM_TCP_PORT 4001
EXPOSE $IPFS_SWARM_TCP_PORT
# Swarm UDP; should be exposed to the public
# Can be the same as TCP port
EXPOSE $IPFS_SWARM_TCP_PORT/udp
# Daemon API; must not be exposed publicly but to client services under you control
ENV IPFS_API_PORT 5001
EXPOSE $IPFS_API_PORT
# Web Gateway; can be exposed publicly with a proxy, e.g. as https://ipfs.example.org
ENV IPFS_GATEWAY_PORT 8080
EXPOSE $IPFS_GATEWAY_PORT
# Swarm Websockets; must be exposed publicly when the node is listening using the websocket transport (/ipX/.../tcp/8081/ws).
ENV IPFS_SWARM_WS_PORT 8081
EXPOSE $IPFS_SWARM_WS_PORT
# Healthcheck Server; can be exposed to services under your control
ENV IPFS_HEALTHCHECK_PORT 8011
EXPOSE $IPFS_HEALTHCHECK_PORT

# Create the fs-repo directory and switch to a non-privileged user.
ENV IPFS_PATH /data/ipfs
RUN mkdir -p $IPFS_PATH \
  && adduser -D -h $IPFS_PATH -u 1000 -G users ipfs \
  && chown ipfs:users $IPFS_PATH

# Create mount points for `ipfs mount` command
RUN mkdir /ipfs /ipns \
  && chown ipfs:users /ipfs /ipns

# Expose the fs-repo as a volume.
# start_ipfs initializes an fs-repo if none is mounted.
# Important this happens after the USER directive so permissions are correct.
VOLUME $IPFS_PATH

# The default logging level
ENV IPFS_LOGGING ""

# The daemon will announce inferred swarm addresses by default
# ENV IPFS_ANNOUNCE_ADDRESS_LIST ""

# This just makes sure that:
# 1. There's an fs-repo, and initializes one if there isn't.
# 2. The API and Gateway are accessible from outside the container.
# Use -s for subreaping zombie processes
ENTRYPOINT ["/sbin/tini", "-s", "--", "/usr/local/bin/start_ipfs"]

# Heathcheck for the container
# QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn is the CID of empty folder
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD ipfs dag stat /ipfs/QmUNLLsPACCz1vLxQVkXqqLX5R1X345qqfHbsf67hvA3Nn || exit 1

# Execute the daemon subcommand by default
CMD ["daemon", "--migrate=false", "--agent-version-suffix=docker"]
