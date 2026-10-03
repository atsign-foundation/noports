# =============================================================================
# NoPorts CYD – Firmware builder + web flasher
#
# Build context must be the repo root (at_Arduino_NoPorts/) so both lib/ and
# packages/NoPorts_CYD/ are accessible:
#
#   docker build -f packages/NoPorts_CYD/Dockerfile -t noports-cyd-flasher .
#
# Or use docker-compose (recommended):
#   docker compose -f packages/NoPorts_CYD/docker-compose.yml up --build
# =============================================================================

# ---------------------------------------------------------------------------
# Stage 1: build firmware
# ---------------------------------------------------------------------------
FROM --platform=linux/amd64 python:3.11-slim AS builder

# System dependencies needed by PlatformIO / esptool
RUN apt-get update && apt-get install -y --no-install-recommends \
        git \
        curl \
    && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir platformio esptool

# ---------------------------------------------------------------------------
# Vendor ESP Web Tools (the browser-side flasher) at a pinned, checksum-verified
# version so the install page loads it from this same origin instead of a live
# CDN. This removes the supply-chain risk of fetching unpinned JS from unpkg at
# flash time — the exact bytes are fixed at build time and the download aborts
# on any hash mismatch. To upgrade: bump the version, update the SHA-256 (from
# `shasum -a 256` of the npm tarball), and re-test the flow.
# ---------------------------------------------------------------------------
ARG ESP_WEB_TOOLS_VERSION=10.4.0
ARG ESP_WEB_TOOLS_SHA256=f18da75335d2f0dca044c4bb052848c0696e7b03cc23d61d8530dd6eba0a9008
RUN curl -fsSL -o /tmp/ewt.tgz \
        "https://registry.npmjs.org/esp-web-tools/-/esp-web-tools-${ESP_WEB_TOOLS_VERSION}.tgz" && \
    echo "${ESP_WEB_TOOLS_SHA256}  /tmp/ewt.tgz" | sha256sum -c - && \
    mkdir -p /esp-web-tools && \
    tar -xzf /tmp/ewt.tgz -C /esp-web-tools --strip-components=3 package/dist/web && \
    rm /tmp/ewt.tgz

WORKDIR /build

# ---------------------------------------------------------------------------
# Layer cache optimisation:
#   Copy only what's needed to fetch registry packages first, so rebuilds
#   that change only source code skip the slow framework download.
# ---------------------------------------------------------------------------
COPY packages/NoPorts_CYD/platformio.ini   packages/NoPorts_CYD/platformio.ini
COPY packages/NoPorts_CYD/boards/          packages/NoPorts_CYD/boards/
COPY packages/NoPorts_CYD/partitions.csv   packages/NoPorts_CYD/partitions.csv

# Create a minimal stub so lib_extra_dirs path (../../lib) resolves during
# package scan, but no source code is included yet (keeps this layer cached).
RUN mkdir -p lib/NoPorts

WORKDIR /build/packages/NoPorts_CYD

# Fetch all registry packages + ESP32 toolchain (cached unless platformio.ini changes)
RUN platformio pkg install -e cyd2usb -e cyd2usb_s3 -e crowpanel_adv7

# ---------------------------------------------------------------------------
# Now copy the full source and build
# ---------------------------------------------------------------------------
WORKDIR /build

COPY lib/               lib/
COPY packages/NoPorts_CYD/  packages/NoPorts_CYD/

WORKDIR /build/packages/NoPorts_CYD

RUN platformio run -e cyd2usb -e cyd2usb_s3 -e crowpanel_adv7

# ---------------------------------------------------------------------------
# Merge each environment into a single self-contained binary.
#   ESP32  – bootloader at 0x1000
#   ESP32-S3 – bootloader at 0x0
# The merged binary can be written at offset 0x0 in one shot by ESPTool.js.
# ---------------------------------------------------------------------------
RUN BOOT=$(find /root/.platformio/packages -name "boot_app0.bin" | head -1) && \
    echo "Using boot_app0: $BOOT" && \
    \
    esptool.py --chip esp32 merge_bin \
        -o merged-cyd2usb.bin \
        0x1000  .pio/build/cyd2usb/bootloader.bin \
        0x8000  .pio/build/cyd2usb/partitions.bin \
        0xe000  "$BOOT" \
        0x10000 .pio/build/cyd2usb/firmware.bin && \
    \
    esptool.py --chip esp32s3 merge_bin \
        -o merged-cyd2usb_s3.bin \
        0x0     .pio/build/cyd2usb_s3/bootloader.bin \
        0x8000  .pio/build/cyd2usb_s3/partitions.bin \
        0xe000  "$BOOT" \
        0x10000 .pio/build/cyd2usb_s3/firmware.bin && \
    \
    esptool.py --chip esp32s3 merge_bin \
        -o merged-crowpanel_adv7.bin \
        0x0     .pio/build/crowpanel_adv7/bootloader.bin \
        0x8000  .pio/build/crowpanel_adv7/partitions.bin \
        0xe000  "$BOOT" \
        0x10000 .pio/build/crowpanel_adv7/firmware.bin

# Binaries for upgrade manifests — exactly what PlatformIO flashes on every upload:
#   bootloader @ 0x1000 (ESP32) or 0x0 (ESP32-S3)
#   partitions @ 0x8000
#   boot_app0  @ 0xe000  (resets otadata -> boot app0)
#   firmware   @ 0x10000
# NVS at 0x9000 is a separate 4KB sector never touched by any of these offsets.
RUN cp .pio/build/cyd2usb/firmware.bin      firmware-cyd2usb.bin       && \
    cp .pio/build/cyd2usb_s3/firmware.bin   firmware-cyd2usb_s3.bin    && \
    cp .pio/build/crowpanel_adv7/firmware.bin   firmware-crowpanel_adv7.bin   && \
    cp .pio/build/cyd2usb/partitions.bin    partitions-cyd2usb.bin     && \
    cp .pio/build/cyd2usb_s3/partitions.bin partitions-cyd2usb_s3.bin  && \
    cp .pio/build/crowpanel_adv7/partitions.bin partitions-crowpanel_adv7.bin && \
    cp .pio/build/cyd2usb/bootloader.bin    bootloader-cyd2usb.bin     && \
    cp .pio/build/cyd2usb_s3/bootloader.bin bootloader-cyd2usb_s3.bin  && \
    cp .pio/build/crowpanel_adv7/bootloader.bin bootloader-crowpanel_adv7.bin && \
    BOOT=$(find /root/.platformio/packages -name "boot_app0.bin" | head -1) && \
    cp "$BOOT" boot_app0.bin && \
    wc -c firmware-cyd2usb.bin firmware-cyd2usb_s3.bin firmware-crowpanel_adv7.bin \
               partitions-cyd2usb.bin partitions-cyd2usb_s3.bin partitions-crowpanel_adv7.bin \
               bootloader-cyd2usb.bin bootloader-cyd2usb_s3.bin bootloader-crowpanel_adv7.bin \
               boot_app0.bin

# ---------------------------------------------------------------------------
# Stage 2: minimal nginx web server
# ---------------------------------------------------------------------------
FROM nginx:1.28-alpine

# Remove default nginx config; replace with our own
RUN rm /etc/nginx/conf.d/default.conf
COPY packages/NoPorts_CYD/web/nginx.conf /etc/nginx/conf.d/noports.conf

# Web assets (static HTML + manifests)
COPY packages/NoPorts_CYD/web/ /usr/share/nginx/html/

# Vendored ESP Web Tools (pinned + checksum-verified in the builder stage),
# served same-origin at /esp-web-tools/ — see index.html.
COPY --from=builder /esp-web-tools/ /usr/share/nginx/html/esp-web-tools/

# Merged firmware binaries (used by factory-reset manifests)
COPY --from=builder /build/packages/NoPorts_CYD/merged-cyd2usb.bin     /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/merged-cyd2usb_s3.bin  /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/merged-crowpanel_adv7.bin /usr/share/nginx/html/

# Upgrade binaries (mirrors exact PlatformIO upload sequence)
COPY --from=builder /build/packages/NoPorts_CYD/firmware-cyd2usb.bin       /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/firmware-cyd2usb_s3.bin    /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/partitions-cyd2usb.bin     /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/partitions-cyd2usb_s3.bin  /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/bootloader-cyd2usb.bin     /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/bootloader-cyd2usb_s3.bin  /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/firmware-crowpanel_adv7.bin   /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/partitions-crowpanel_adv7.bin /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/bootloader-crowpanel_adv7.bin /usr/share/nginx/html/
COPY --from=builder /build/packages/NoPorts_CYD/boot_app0.bin               /usr/share/nginx/html/

EXPOSE 80

LABEL org.opencontainers.image.title="NoPorts CYD Flasher" \
      org.opencontainers.image.description="Browser-based firmware installer for NoPorts CYD / ESP32-S3 / CrowPanel devices" \
      org.opencontainers.image.source="https://github.com/atsign-foundation/noports"
