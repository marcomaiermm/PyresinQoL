FROM rust:1.92-bookworm AS builder
RUN apt-get update && apt-get install -y --no-install-recommends clang mold cmake pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Keep the simulator and its Lua VM reproducible; Cargo.lock pins dependencies.
# renovate: repo=https://github.com/Osso/wow-ui-sim branch=master
ARG SIM_REVISION=e6e0f6476890ca96095ff2eb5c03b31716e0891f
RUN git init . && git remote add origin https://github.com/Osso/wow-ui-sim.git \
    && git fetch --depth 1 origin "$SIM_REVISION" && git checkout --detach FETCH_HEAD
# The upstream binary targets the builder's CPU; the CI runner may differ.
ENV RUSTFLAGS="-C link-arg=-fuse-ld=mold"
COPY simulator.patch /tmp/simulator.patch
# Normalize Forever loader paths and reject errors in single-process CI commands.
RUN git apply --check /tmp/simulator.patch && git apply /tmp/simulator.patch
# Set the simulation size before addon loading, independently of desktop chrome.
COPY viewport.patch /tmp/viewport.patch
RUN git apply --check /tmp/viewport.patch && git apply /tmp/viewport.patch

# Forever runtime requires the simulator's pinned spell data, fetched from Blizzard's CDN.
FROM builder AS spells
RUN cargo build --release --locked --bin wow-cli --no-default-features --features casc,tools,client-wowforever \
    && mkdir -p /spells && target/release/wow-cli casc sync-forever-spells --source cdn --output /spells/spells.json

FROM debian:bookworm-slim AS blizzard-ui
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /source
# Head of Gethe's Forever branch, matching the addon and the simulator's Forever profile.
# renovate: repo=https://github.com/Gethe/wow-ui-source branch=forever
ARG UI_REVISION=3d8abb1da73acd38e412e24fb3f99454a6392346
RUN git init . && git remote add origin https://github.com/Gethe/wow-ui-source.git \
    && git config core.sparseCheckout true \
    && printf 'Interface/AddOns/\n' > .git/info/sparse-checkout \
    && git fetch --depth 1 origin "$UI_REVISION" && git checkout --detach FETCH_HEAD \
    && touch Interface/AddOns/.wow-ui-sim-blizzard-ui-complete \
    && printf 'profile=wowforever\nsource=gethe\nrevision=%s\n' "$UI_REVISION" \
        > Interface/AddOns/.wow-ui-sim-blizzard-ui-provenance

FROM debian:bookworm-slim AS runtime
# Forever's native duration formatting links ICU; text layout also needs fonts.
RUN apt-get update && apt-get install -y --no-install-recommends libicu72 fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY --from=builder /build/Interface/AddOns/TestFramework/ /app/Interface/AddOns/TestFramework/
COPY --from=blizzard-ui /source/Interface/AddOns/ /root/.cache/wow-ui-sim/blizzard-ui/wowforever/AddOns/
COPY --from=spells /spells/ /app/spells/wowforever/
ENV WOW_SIM_NO_SAVED_VARS=1
ENTRYPOINT ["/app/wow-sim"]

FROM builder AS gui-builder
RUN cargo build --release --locked --bin wow-sim --bin wow-cli \
    --no-default-features --features gui,tools,client-wowforever \
    && strip target/release/wow-sim target/release/wow-cli

FROM runtime AS dev
# Software Vulkan also permits screenshots without a display or host GPU.
RUN apt-get update && apt-get install -y --no-install-recommends \
    libvulkan1 mesa-vulkan-drivers libegl1 libxkbcommon0 libwayland-client0 \
    libx11-6 libxcursor1 libxi6 libxrandr2 \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /run/user/0 && chmod 700 /run/user/0
ENV XDG_RUNTIME_DIR=/run/user/0
COPY --from=gui-builder /build/target/release/wow-sim /build/target/release/wow-cli /app/
COPY --from=builder /build/data/ /app/data/

FROM builder AS headless-builder
RUN cargo build --release --locked --bin wow-sim --no-default-features --features client-wowforever \
    && strip target/release/wow-sim

# Each target compiles once; the GUI does not need a headless binary first.
FROM runtime AS headless
COPY --from=headless-builder /build/target/release/wow-sim /app/wow-sim
