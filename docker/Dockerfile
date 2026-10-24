FROM ubuntu:22.04
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential ca-certificates chrpath cpio debianutils diffstat file gawk \
    git iputils-ping libacl1 liblz4-tool locales python3 python3-git \
    python3-jinja2 python3-pexpect python3-pip python3-subunit socat texinfo \
    unzip wget xz-utils zstd bzip2 patch rsync curl less openssh-client tar util-linux \
    && locale-gen en_US.UTF-8 && rm -rf /var/lib/apt/lists/*
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
RUN groupadd --gid 1000 builder && useradd --uid 1000 --gid 1000 --create-home --shell /bin/bash builder \
    && mkdir -p /work && chown builder:builder /work
COPY --chmod=755 validate-foundation.sh /usr/local/bin/validate-foundation
USER builder
WORKDIR /work
CMD ["/bin/bash"]
