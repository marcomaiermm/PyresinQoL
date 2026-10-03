FROM rust:1.92-bookworm AS builder
RUN apt-get update && apt-get install -y --no-install-recommends clang mold cmake pkg-config \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /build
# Keep the simulator and its Lua VM reproducible; Cargo.lock pins dependencies.
ARG SIM_REVISION=6a1d81b1c5a1f9771a1b1a7aec6c1361753b3d3f
RUN git init . && git remote add origin https://github.com/Osso/wow-ui-sim.git \
    && git fetch --depth 1 origin "$SIM_REVISION" && git checkout --detach FETCH_HEAD
# The upstream binary targets the builder's CPU; the CI runner may differ.
ENV RUSTFLAGS="-C link-arg=-fuse-ld=mold"
COPY simulator.patch /tmp/simulator.patch
# Normalize the pinned Forever loader's relative overlay and absolute addon paths.
RUN git apply --check /tmp/simulator.patch && git apply /tmp/simulator.patch
# Set the simulation size before addon loading, independently of desktop chrome.
COPY viewport.patch /tmp/viewport.patch
RUN git apply --check /tmp/viewport.patch && git apply /tmp/viewport.patch
RUN cargo build --release --locked --bin wow-sim --no-default-features --features client-wowforever \
    && strip target/release/wow-sim

FROM debian:bookworm-slim AS blizzard-ui
RUN apt-get update && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
WORKDIR /source
# Forever 1.60.1.69913, matching the addon and the simulator's Forever profile.
ARG UI_REVISION=70ef1b2fd78061a73f886c4a1e79dc5b5cff6d5e
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
ENV WOW_SIM_NO_SAVED_VARS=1
ENTRYPOINT ["/app/wow-sim"]

FROM builder AS gui-builder
RUN cargo build --release --locked --bin wow-sim --bin wow-cli \
    --no-default-features --features gui,client-wowforever \
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

# Keep the default build small for tests/run-ui.sh and CI.
FROM runtime AS headless
COPY --from=builder /build/target/release/wow-sim /app/wow-sim
