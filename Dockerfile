# syntax=docker/dockerfile:1
FROM ubuntu:26.04

ARG TARGETARCH
# iNode Linux client build shipped in assets/. Keep in sync with the deb file name.
ARG INODE_VERSION=E0626
ARG KASMVNC_VERSION=1.5.2
# Optional apt mirror for local builds, e.g. mirrors.ustc.edu.cn
ARG APT_MIRROR=""

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    DISPLAY=:1

RUN if [ -n "$APT_MIRROR" ]; then \
      sed -i "s|http://archive.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g; \
              s|http://security.ubuntu.com/ubuntu|http://${APT_MIRROR}/ubuntu|g; \
              s|http://ports.ubuntu.com/ubuntu-ports|http://${APT_MIRROR}/ubuntu-ports|g" \
        /etc/apt/sources.list.d/ubuntu.sources; \
    fi

# iNode is a GTK2/wxGTK application (libgtk-x11-2.0, libjpeg.so.62, libSM, libxxf86vm);
# KasmVNC ships its own X server and is packaged as a Perl script, so apt pulls
# the perl modules it needs automatically.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        fonts-dejavu-core \
        fluxbox \
        xterm \
        x11-xserver-utils \
        libgtk2.0-0t64 \
        libglib2.0-0t64 \
        libjpeg62 \
        libsm6 \
        libxxf86vm1 \
        libncurses6 \
        network-manager \
        net-tools \
        iproute2 \
        iptables \
        procps \
        dante-server \
    && rm -rf /var/lib/apt/lists/*

# H3C iNode client (amd64/arm64 builds are published as separate debs)
COPY assets/inode.${TARGETARCH}_${INODE_VERSION}.deb /tmp/iNode.deb
RUN apt-get update \
    && apt-get install -y --no-install-recommends /tmp/iNode.deb \
    && rm -f /tmp/iNode.deb \
    && rm -rf /var/lib/apt/lists/*

# KasmVNC web console (ubuntu_resolute packages are built for 26.04)
RUN curl -fsSL -o /tmp/kasmvnc.deb \
        "https://github.com/kasmtech/KasmVNC/releases/download/v${KASMVNC_VERSION}/kasmvncserver_ubuntu_resolute_${KASMVNC_VERSION}_${TARGETARCH}.deb" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/kasmvnc.deb \
    && rm -f /tmp/kasmvnc.deb \
    && rm -rf /var/lib/apt/lists/*

COPY danted.conf /etc/danted.conf
COPY start-vnc.sh /usr/local/bin/start-vnc.sh
COPY xstartup /root/.vnc/xstartup
RUN chmod 0755 /usr/local/bin/start-vnc.sh /root/.vnc/xstartup

LABEL com.h3c.inode.version="${INODE_VERSION}" \
      com.kasmvnc.version="${KASMVNC_VERSION}"

EXPOSE 5901 1080

CMD ["/usr/local/bin/start-vnc.sh"]
