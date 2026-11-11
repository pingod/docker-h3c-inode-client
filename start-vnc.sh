#!/bin/bash
set -euo pipefail

VNC_USER="${USER:-vncuser}"
PASSWORD="${PASSWORD:-password}"
PROTOCOL="${PROTOCOL:-http}"
DISPLAY_NUM="${DISPLAY_NUM:-1}"
GEOMETRY="${GEOMETRY:-1280x720}"

if [ "${#PASSWORD}" -lt 6 ]; then
  echo "PASSWORD must be at least 6 characters (KasmVNC requirement)" >&2
  exit 1
fi

# NAT the iNode VPN tunnel so the SOCKS proxy can reach the remote network
iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null \
  || iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE \
  || echo "warning: cannot add NAT rule (missing --cap-add=NET_ADMIN?)" >&2

# danted binds externals; start it once iNode brought tun0 up
(
  until ip -4 addr show tun0 2>/dev/null | grep -q 'inet '; do
    sleep 1
  done
  echo "tun0 up, starting danted"
  exec danted -f /etc/danted.conf
) &

# stale lock files from a previous run in the same container
rm -f "/tmp/.X${DISPLAY_NUM}-lock" "/tmp/.X11-unix/X${DISPLAY_NUM}"

mkdir -p "$HOME/.vnc"
echo -e "${PASSWORD}\n${PASSWORD}" | kasmvncpasswd -u "$VNC_USER" -w -r

cat > "$HOME/.vnc/kasmvnc.yaml" <<EOF
network:
  protocol: ${PROTOCOL}
  websocket_port: 5901
  ssl:
    require_ssl: false
command_line:
  prompt: false
EOF

export DISPLAY=":${DISPLAY_NUM}"
kasmvncserver ":${DISPLAY_NUM}" -geometry "$GEOMETRY" -depth 24

# xstartup brings up fluxbox; give X a moment to accept clients
for _ in $(seq 30); do
  xset q >/dev/null 2>&1 && break
  sleep 1
done

/etc/init.d/iNodeAuthService restart

if [ "$(uname -m)" = "aarch64" ]; then
  INODE_DIR=/opt/apps/com.client.inode.arm/files
else
  INODE_DIR=/opt/apps/com.client.inode.amd/files
fi

exec "${INODE_DIR}/.iNode/iNodeClient"
