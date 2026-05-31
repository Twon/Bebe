{% include 'tools/versions.Dockerfile' %}

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

FROM {{ params.os }} AS build_base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Install central build dependencies once
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git build-essential cmake ninja-build python3 python3-dev file flex bison lsb-release gnupg ca-certificates \
    libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev libreadline-dev texinfo libgmp-dev libzstd-dev liblzma-dev \
    libexpat1-dev libmpfr-dev libmpc-dev libisl-dev libncurses-dev uuid-dev libgdbm-dev libgdbm-compat-dev \
    && rm -rf /var/lib/apt/lists/*



# --- TOOLS BUILD STAGE ---
# This stage is now independent from compiler_stage to allow caching across all compiler images
FROM build_base AS build_stage

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Build other tools from source
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.build(tool_version) }}
{% endfor %}

# --- COMPILER BUILD STAGE ---
# Only builds the compiler from source. This is the heaviest and most cached layer.
FROM build_base AS compiler_stage

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

{% if params.compiler and compiler %}
{{ compiler.build(params) }}
{% endif %}

FROM {{ params.os }} AS runtime_base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV DEBIAN_FRONTEND=noninteractive

# Install minimal runtime dependencies and standard C++ build dependencies
# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    wget curl git ca-certificates gnupg build-essential libc6-dev xz-utils \
    libicu-dev binutils-dev libdw-dev \
    && rm -rf /var/lib/apt/lists/*

# libbacktrace-dev is not packaged in Ubuntu 24.04 Noble — build from source
RUN git clone --depth 1 https://github.com/ianlancetaylor/libbacktrace.git /tmp/libbacktrace
WORKDIR /tmp/libbacktrace
RUN ./configure --prefix=/usr --libdir=/usr/lib/x86_64-linux-gnu --enable-shared && \
    make -j"$(nproc)" && \
    make install
WORKDIR /
RUN rm -rf /tmp/libbacktrace

# Initialize current_stage state for chained builds
{% set state = namespace(current_stage='runtime_base') %}

# --- FINAL GENERATED IMAGE ---
FROM {{ state.current_stage }} AS bebe_final

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Initialize LD_LIBRARY_PATH to avoid "UndefinedVar" warnings in tool macros
ENV LD_LIBRARY_PATH=

# In the final stage, we call the compiler's copy macro to install the binaries
{% if params.compiler and compiler %}
{{ compiler.copy(params) }}
{% endif %}

# Copy and configure other tools
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.copy(tool_version) }}
{% endfor %}

# --- VERIFICATION ---
# Verify that the configured compilers can actually build code
RUN echo 'int main() { return 0; }' > /tmp/test.c && \
    echo -e '#include <iostream>\nint main() { std::cout << "Hello" << std::endl; return 0; }' > /tmp/test.cpp && \
    if command -v gcc >/dev/null 2>&1; then \
        echo "Testing GCC..." && \
        gcc -o /tmp/test_c /tmp/test.c && \
        g++ -o /tmp/test_cpp /tmp/test.cpp || exit 1; \
    fi && \
    if command -v clang >/dev/null 2>&1; then \
        echo "Testing Clang..." && \
        clang -o /tmp/test_clang_c /tmp/test.c && \
        clang++ -stdlib=libc++ -o /tmp/test_clang_cpp /tmp/test.cpp || exit 1; \
    fi && \
    rm -f /tmp/test*
