#!/bin/bash
# Clipboard history picker: cliphist + fuzzel dmenu.
set -euo pipefail

cliphist list | fuzzel --dmenu --prompt "Clipboard: " | cliphist decode | wl-copy
