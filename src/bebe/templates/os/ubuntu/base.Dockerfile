{% include 'tools/versions.Dockerfile' %}

{% if params.compiler %}
{% import 'compiler/' ~ params.compiler.family ~ '.Dockerfile' as compiler %}
{% endif %}

# --- BUILD BASE STAGE ---
# This stage installs heavy dependencies and provides a foundation for all builds
FROM {{ params.os }} AS build_base

ENV DEBIAN_FRONTEND=noninteractive

# Install central build dependencies once
RUN apt-get update && apt-get install -y \
    wget curl git build-essential cmake ninja-build python3 python3-dev file flex bison lsb-release gnupg ca-certificates \
    libssl-dev zlib1g-dev libffi-dev libsqlite3-dev libbz2-dev libreadline-dev texinfo libgmp-dev libzstd-dev \
    libexpat1-dev libmpfr-dev libmpc-dev libisl-dev libncurses-dev \
    && rm -rf /var/lib/apt/lists/*

# --- COMPILER BUILD STAGE ---
# Only builds the compiler from source. This is the heaviest and most cached layer.
FROM build_base AS compiler_stage
{% if params.compiler and compiler %}
{{ compiler.build(params) }}
{% endif %}

# --- TOOLS BUILD STAGE ---
# Builds additional tools from source. Inherits base instead of compiler to avoid cache-busts.
# We name this 'build_stage' to maintain compatibility with all tool macros.
FROM build_base AS build_stage
{% if params.compiler and compiler %}
# Copy compiler binaries so subsequent tools can use them if needed for building
COPY --from=compiler_stage /opt /opt
{% endif %}

# Import and build other tools from source
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.build(tool_version) }}
{% endfor %}

# --- RUNTIME BASE STAGE ---
# This stage is minimal and provides the runtime components
FROM {{ params.os }} AS runtime_base

ENV DEBIAN_FRONTEND=noninteractive

# Install only minimal runtime dependencies
RUN apt-get update && apt-get install -y \
    wget curl git ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Initialize current_stage state for chained builds
{% set state = namespace(current_stage='runtime_base') %}

# --- FINAL GENERATED IMAGE ---
FROM {{ state.current_stage }} AS bebe_final

# Initialize LD_LIBRARY_PATH to avoid "UndefinedVar" warnings in tool macros
ENV LD_LIBRARY_PATH=

# In the final stage, we call the compiler's copy macro to install the binaries
{% if params.compiler and compiler %}
{# The compiler copy macro usually uses --from=build_stage, so we override it to tools_stage #}
{{ compiler.copy(params) | replace('build_stage', 'tools_stage') }}
{% endif %}

# Copy and configure other tools
{% for tool_name, tool_version in params.versions.items() %}
{% import 'tools/' ~ tool_name ~ '.Dockerfile' as tool_module with context %}
{{ tool_module.copy(tool_version) | replace('build_stage', 'tools_stage') }}
{% endfor %}
