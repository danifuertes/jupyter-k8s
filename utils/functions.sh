#!/bin/bash
# ---------------------------------------------------------------------------
# Shared config helpers for the cluster scripts.
#
# Source this file from a script:   source "$(dirname "$0")/../utils/functions.sh"
# It exposes:
#   cfg_map <section> <key>   -> prints a scalar under the "<section>:" map
#   cfg_cluster <key>         -> shortcut for cfg_map cluster <key>
#   cfg_scalar_list <section> -> prints the items of a "- value" list
#   cfg_node_names <sec>      -> prints the node names of a section (masters/workers)
#   cfg_nodes <sec>           -> prints "name ip" pairs of a section
#
#   handle_success <name>     -> prints a green "installed successfully" banner
#   handle_failure <line>     -> prints a red error banner and exits (use with trap)
# ---------------------------------------------------------------------------

# Locate the config file at the workspace root, unless overridden
CONFIG_FILE="${CONFIG_FILE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/inputs.yaml}"
if [ ! -f "$CONFIG_FILE" ]; then
    echo >&2
    echo "ERROR: inputs file not found: $CONFIG_FILE" >&2
    echo "       Create it with:  cp inputs.example.yaml inputs.yaml" >&2
    echo "       then edit it with your node names, IPs and users." >&2
    echo >&2
    exit 1
fi

# Print a scalar value stored under a "<section>:" mapping (at any depth)
# Example:  cfg_map jupyterhub hostname
cfg_map() {
    awk -v section="$1" -v key="$2" '
        function indent(s) { match(s, /^ */); return RLENGTH }
        !in_s && !done && $0 ~ "^[[:space:]]*" section ":" { in_s=1; hind=indent($0); next }
        in_s && $0 ~ /^[[:space:]]*$/ { next }
        in_s && indent($0) <= hind { in_s=0; done=1 }
        in_s {
            for (i = 1; i <= NF; i++)
                if ($i == key ":") { print $(i + 1); exit }
        }
    ' "$CONFIG_FILE"
}

# Backwards-compatible shortcut for values under the "cluster:" mapping
cfg_cluster() {
    cfg_map cluster "$1"
}

# Print every item of a "- value" list section (at any depth), e.g.
#   users:
#     - user1
#     - user2
# Usage:  cfg_scalar_list users
cfg_scalar_list() {
    awk -v section="$1" '
        function indent(s) { match(s, /^ */); return RLENGTH }
        !in_s && !done && $0 ~ "^[[:space:]]*" section ":" { in_s=1; hind=indent($0); next }
        in_s && $0 ~ /^[[:space:]]*$/ { next }
        in_s && indent($0) <= hind { in_s=0; done=1 }
        in_s {
            for (i = 1; i <= NF; i++)
                if ($i == "-") { print $(i + 1); break }
        }
    ' "$CONFIG_FILE"
}

# Print "name ip" pairs for a list section (masters/workers, at any depth)
cfg_nodes() {
    awk -v section="$1" '
        function indent(s) { match(s, /^ */); return RLENGTH }
        !in_s && !done && $0 ~ "^[[:space:]]*" section ":" { in_s=1; hind=indent($0); next }
        in_s && $0 ~ /^[[:space:]]*$/ { next }
        in_s && indent($0) <= hind { in_s=0; done=1 }
        in_s {
            for (i = 1; i <= NF; i++) {
                if ($i == "name:") name = $(i + 1)
                if ($i == "ip:")   ip   = $(i + 1)
            }
            if (name != "" && ip != "") { print name, ip; name = ""; ip = "" }
        }
    ' "$CONFIG_FILE"
}

# Print just the node names for a list section (masters or workers)
cfg_node_names() {
    cfg_nodes "$1" | awk '{ print $1 }'
}

# Print a red error banner and exit. Meant to be wired to an ERR trap:
#   trap 'handle_failure $LINENO' ERR
handle_failure() {

    # Capture the exit code
    local exit_code=$?

    # Define color codes
    local red="\033[0;31m"
    local reset="\033[0m"

    # Print the error
    echo
    echo -e "${red}Error:${reset} Command failed on line ${red}$1${reset} with exit code ${red}$exit_code${reset}."
    echo
    exit $exit_code  # Exit with the same error code
}

# Print a green success banner for a given package/step name.
handle_success() {

    # Define borders
    local package_name=$1
    local length=${#package_name}
    local border_length=$((length + 50))  # 50 is the static part of the message

    # Define color codes
    local green="\033[0;32m"
    local reset="\033[0m"

    # Create a dynamic border based on the package name length
    local border=$(printf '#%.0s' $(seq 1 $border_length))

    # Print the message
    echo
    echo "$border"
    echo -e "# Package ${green}$package_name${reset} installed and configured successfully #"
    echo "$border"
    echo
}
