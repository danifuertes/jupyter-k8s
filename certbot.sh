#!/bin/bash
# ---------------------------------------------------------------------------
# Obtain (or renew) a Let's Encrypt certificate for the JupyterHub host defined
# in inputs.yaml and drop it into the jupyterhub/ folder under the file names
# that jupyterhub/create.sh expects (jupyter-crt.pem / jupyter-key.pem).
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils/functions.sh"
trap 'handle_failure $LINENO' ERR
JUPYTERHUB_DIR="$SCRIPT_DIR/jupyterhub"

# Read the primary host from inputs.yaml (first entry under proxy.https.hosts)
mapfile -t HOSTS < <(cfg_scalar_list hosts)
HOST="${HOSTS[0]:-}"
if [ -z "$HOST" ]; then
    echo "ERROR: no host found under jupyterhub.proxy.https.hosts in $CONFIG_FILE" >&2
    exit 1
fi

# Own the copied files
OWNER="${SUDO_USER:-$USER}"
echo
echo "Requesting/renewing a Let's Encrypt certificate for: $HOST"
echo "(certbot --standalone needs port 80 free and $HOST resolving to this host)"
echo

# Obtain the certificate
sudo certbot certonly --standalone --keep-until-expiring -d "$HOST"
LIVE_DIR="/etc/letsencrypt/live/$HOST"
if [ ! -d "$LIVE_DIR" ]; then
    echo "ERROR: expected certbot output not found: $LIVE_DIR" >&2
    exit 1
fi

# Copy certificates with correct permissions
echo
echo "Copying certificate into $JUPYTERHUB_DIR ..."
sudo cp "$LIVE_DIR/fullchain.pem" "$JUPYTERHUB_DIR/jupyter-crt.pem"
sudo cp "$LIVE_DIR/privkey.pem"   "$JUPYTERHUB_DIR/jupyter-key.pem"
sudo chown "$OWNER":"$OWNER" "$JUPYTERHUB_DIR/jupyter-crt.pem" "$JUPYTERHUB_DIR/jupyter-key.pem"
chmod 644 "$JUPYTERHUB_DIR/jupyter-crt.pem"
chmod 600 "$JUPYTERHUB_DIR/jupyter-key.pem"

# Print result
echo
echo "############################################################"
echo "# Certificate ready for $HOST"
echo "#   $JUPYTERHUB_DIR/jupyter-crt.pem"
echo "#   $JUPYTERHUB_DIR/jupyter-key.pem"
echo "############################################################"
echo
