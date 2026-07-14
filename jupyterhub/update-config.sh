#!/bin/bash
# ---------------------------------------------------------------------------
# Render jupyterhub/config.yaml from the "jupyterhub:" section of inputs.yaml.
#
# inputs.yaml holds the whole JupyterHub Helm values tree under "jupyterhub:".
# This script copies that section out, dedented one level, into config.yaml.
# inputs.yaml is git-ignored, which lets config.yaml be git-ignored too.
#
# Usage:  ./update-config.sh      (jupyterhub/create.sh runs it automatically)
#
# Edit the "jupyterhub:" section of inputs.yaml and re-run this to apply.
# ---------------------------------------------------------------------------
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../utils/functions.sh"

OUTPUT="$SCRIPT_DIR/config.yaml"

# Stop before writing an empty config.yaml
if ! grep -q '^[[:space:]]*jupyterhub:[[:space:]]*$' "$CONFIG_FILE"; then
    echo >&2
    echo "ERROR: no 'jupyterhub:' section found in $CONFIG_FILE" >&2
    echo "       See inputs.example.yaml for the expected layout." >&2
    echo >&2
    exit 1
fi

# Copy the "jupyterhub:" section out, dedented one level. The section ends at
# the first non-blank line indented no deeper than "jupyterhub:" itself.
awk '
    function indent(s) { match(s, /^ */); return RLENGTH }
    BEGIN {
        print "# GENERATED FILE. Do not edit: it is overwritten on every run."
        print "# Rendered by jupyterhub/update-config.sh from the \"jupyterhub:\" section"
        print "# of inputs.yaml. Edit inputs.yaml instead, then re-run that script."
        print ""
    }
    !in_s && !done && /^[[:space:]]*jupyterhub:[[:space:]]*$/ { in_s=1; hind=indent($0); next }
    in_s && $0 ~ /^[[:space:]]*$/ { print ""; next }
    in_s && indent($0) <= hind { in_s=0; done=1 }
    in_s {
        if (!cind) cind = indent($0)   # depth of the first child sets the dedent
        print substr($0, cind + 1)
    }
' "$CONFIG_FILE" > "$OUTPUT"

echo "Rendered $(basename "$OUTPUT") from the 'jupyterhub:' section of $(basename "$CONFIG_FILE")"
