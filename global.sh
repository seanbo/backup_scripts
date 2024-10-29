#!/bin/bash

#  Copyright (c) 2024 Sean L. Ryle
#
#  This library is free software; you can redistribute it and/or
#  modify it under the terms of the GNU Lesser General Public
#  License as published by the Free Software Foundation; either
#  version 2.1 of the License, or (at your option) any later version.
#  See the file COPYING included with this distribution for more
#  information.

#Configuration File
CONF_DIR="$(dirname "$0")"
CONF_FILE="$CONF_DIR/backup.conf"

#Terminal Colors
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
BLUE="\e[34m"
MAGENTA="\e[35m"
CYAN="\e[36m"
WHITE="\e[97m"
CREAM="\e[1;40;33m"
ERROR="\e[5;40;31m"
RESET="\e[0m"

#color for tar output
#export TAR_COLORS='di=01;34:ln=01;36:ex=01;32:so=01;40:pi=01;40:bd=40;33:cd=40;33:su=0;41:sg=0;46'
