FROM quay.io/jupyter/pytorch-notebook:x86_64-cuda12-8890fc557a2c
ARG UV_VERSION=0.11.29
ARG PIXI_VERSION=v0.73.0

# System tools
USER root
RUN apt-get update --yes && \
    apt-get install --yes --no-install-recommends \
        build-essential \
        ca-certificates \
        curl \
        ffmpeg \
        file \
        git \
        git-lfs \
        gnupg \
        graphviz \
        htop \
        jq \
        less \
        libgl1 \
        libglib2.0-0 \
        man-db \
        nvitop \
        p7zip-full \
        pkg-config \
        rsync \
        tmux \
        screen \
        tree \
        unzip \
        vim \
        wget \
        zip && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# Pixi and uv
RUN curl -LsSf "https://astral.sh/uv/${UV_VERSION}/install.sh" | \
        env HOME=/root UV_INSTALL_DIR=/usr/local/bin UV_NO_MODIFY_PATH=1 sh && \
    curl -fsSL https://pixi.sh/install.sh | \
        env HOME=/root PIXI_VERSION="${PIXI_VERSION}" PIXI_BIN_DIR=/usr/local/bin PIXI_NO_PATH_UPDATE=1 bash && \
    uv --version && pixi --version
ENV UV_LINK_MODE=copy

# Common Python packages for a general-purpose lab base image
USER ${NB_UID}
RUN pip install --no-cache-dir \
        torchmetrics \
        opencv-python-headless \
        polars \
        pyarrow \
        plotly \
        requests \
        tqdm && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR "${HOME}"
