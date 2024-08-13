# Stage 1: Base with runtime essentials
FROM ubuntu:20.04 AS base
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-pip \
    libc6 libdbus-1-3 libexpat1 libfontconfig1 libgl1 libglx0 \
    libice6 libnspr4 libnss3 libopengl0 libpci3 libsm6 libx11-6 libx11-xcb1 \
    libxcb1 libxcomposite1 libxcursor1 libxdamage1 libxext6 libxfixes3 \
    libxi6 libxkbcommon-x11-0 libxkbcommon0 libxrandr2 libxrender1 libxss1 \
    libxt6 libxtst6 libzstd1 zlib1g \
    inotify-tools micro pigz rclone ca-certificates openssl \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates \

# Stage 2: Houdini installation
FROM base AS houdini-installer
COPY ./houdini_installer /houdini_installer

RUN bash /houdini_installer/houdini.install --accept-EULA 2021-10-13 \
    --install-houdini --install-license \
    --no-install-engine-maya \
    --no-install-engine-unity \
    --no-install-engine-unreal \
    --no-install-menus \
    --no-install-avahi \
    --no-install-hqueue-server \
    --mount-hqueue-shared-dir yes \
    --hqueue-shared-dir /houdini_projects \
    --hqueue-shared-dir-mount /tmp \
    --install-hqueue-client \
    --hqueue-client-dir /houdini/hqueue_client \
    --hqueue-client-user root \
    --auto-install \
    --make-dir /houdini/houdini20.0

FROM base
COPY --from=houdini-installer /houdini /houdini
COPY --from=houdini-installer /usr/lib/sesi /usr/lib/sesi

ENV PATH="${PATH}:/houdini/houdini20.0/bin:/houdini/hqueue_client/bin"

COPY ./license_installer.sh /scripts/license_installer.sh
RUN bash /scripts/license_installer.sh

RUN pip3 install vastai

# Copy and set permissions for all scripts at once
COPY cloud_write_monitor.sh log_monitor.sh compress_files.sh entrypoint.sh /scripts/
RUN chmod +x /scripts/*.sh

# Download and install Tini, setting it as an entrypoint
ADD https://github.com/krallin/tini/releases/download/v0.19.0/tini /tini
RUN chmod +x /tini
ENTRYPOINT ["/tini", "-s", "--"]

CMD ["/scripts/entrypoint.sh", "bash"]
