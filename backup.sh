#!/bin/bash

SCRIPT_DIR="$(dirname "$0")"
ARGV_TARGET=("$@")

###########################################
##               VARIABLES               ##
###########################################
source $SCRIPT_DIR/global.sh

###########################################
##               FUNCTIONS               ##
###########################################
source $SCRIPT_DIR/funcs.sh

###########################################
##               OPERATION               ##
###########################################

#Must rotate logs before any processing
get_log_file

#Begin backups
update_task "Started" "Backup"

	#Load backup configuration from config file
	read_config

	#Create tar backup of files. We will do this regardless of backup share
	#to ensure we at least have a good backup locally even if
	#we are unable to save it to the SMB share
	FLAG=""
	tar_files
	if [[ "$?" -eq 0 ]]; then
		FLAG="Success"
	else
		FLAG="Failure"
	fi
	send_email "$FLAG" "$LOG_FILE"
	
update_task "Completed" "Backup"
