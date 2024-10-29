#!/bin/bash

function purge_file() {
	local ROTATE_DIR="$1"
	local PREFIX="$2"
	local KEEP=$(("$3"-1))

	if [ ! -d "$ROTATE_DIR" ]; then
		return 1
	fi

	DEL_LIST=$(ls -t $ROTATE_DIR/$PREFIX* | awk "NR>$KEEP")
	update_task "Deleting" "$DEL_LIST"

	if [[ ! -z "$DEL_LIST" ]]; then
		rm -f $DEL_LIST
	fi

}

function strip_trailing_slash() {
	echo ${@%/}
}

function get_value() {
	KEY=$1

	VAL=$(jq -c -r "$KEY" "$CONF_FILE")
	if [[ -z "$VAL" ]]; then
		logger "No value found for key: $KEY" false
		fail 2
	fi

	echo $VAL
}

function get_log_file() {

	local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	echo -e "${GREEN}[$timestamp]${CYAN} Configuration File: ${YELLOW}${CONF_FILE}${RESET}"

	local LOG_FMT=$(jq -c -r ".main.log.file_format" "$CONF_FILE")
	local LOG_PFX=$(jq -c -r ".main.log.file_prefix" "$CONF_FILE")
	local LOG_SFX=$(jq -c -r ".main.log.file_suffix" "$CONF_FILE")
	LOG_DIR=$(strip_trailing_slash $(jq -c -r ".main.log.directory" "$CONF_FILE"))
	LOG_NAME=${LOG_PFX}-$(date +"$LOG_FMT").${LOG_SFX}
	LOG_FILE="$LOG_DIR/$LOG_NAME"
	LOG_KEEP=$(jq -c -r ".main.log.keep" "$CONF_FILE")

	echo -e "${GREEN}[$timestamp]${CYAN} Logfile: ${YELLOW}${LOG_FILE}${RESET}"
	purge_file "$LOG_DIR" "$LOG_PFX" "$LOG_KEEP"

}

function logger() {
	#get the last parmeter in the list
	local localecho="${!#}"
	if [[ "$localecho" == true || "$localecho" == false ]]; then
		#reset the parameter list without the last element
		set -- "${@:1:$#-1}"
	else
		localecho=true
	fi

	local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
	local message="${GREEN}[$timestamp]${CYAN} $@ ${RESET}"

	if [[ "$localecho" == true ]]; then
		echo -e "$message"
	fi

	#Strip control characters from log file
	echo "$message" | sed 's/[\x01-\x1F\x7F]//g' >> "$LOG_FILE"
}

function update_task() {
	local STATUS=$1
	local TASK=$2
	logger "${STATUS}: ${YELLOW}${TASK}"
}

function get_strlen() {
	str=$1
	echo ${#str}
}

function get_largest_number() {
  local max=$1 

  for num in "${@:2}"; do 
    if [[ $num -gt $max ]]; then 
      max=$num 
    fi 
  done 

  echo "$max" 
}

function display_config() {

    logger "--------------------------------------------------"
    logger "--            Configuration Values              --"
    logger "--------------------------------------------------"
    logger "-- ${YELLOW}Backup Directory: ${CREAM}$BACKUP_DIR"
    logger "-- ${YELLOW}Share Directory : ${CREAM}$SHARED_DIR"
	logger "-- ${YELLOW}Log Directory   : ${CREAM}$LOG_DIR"
    logger "--------------------------------------------------"
	
}

function read_config() {
	update_task "Reading Configuration File" "$CONF_FILE"

	if [[ ! -f "$CONF_FILE" ]]; then
		logger "${ERROR}ERROR:${RESET} ${YELLOW}Configuration file not found: $CONF_FILE"
		fail 1
	fi

	BACKUP_DIR=$(strip_trailing_slash $(get_value ".main.backup.local_directory"))
	SHARED_DIR=$(strip_trailing_slash $(get_value ".main.backup.shared_directory"))

	display_config

}

function fail() {
	local exitcode="$1"
	logger "${ERROR}ERROR:${RESET} ${YELLOW}Cannot continue. Exiting. ${RED}(exit code: $exitcode)"
	exit $exitcode
}

function check_backup_dir() {

	update_task "Checking Backup Directory" "$BACKUP_DIR"

	if [ ! -d "$BACKUP_DIR" ]; then
		update_task "Directory missing" "$BACKUP_DIR"
		fail 3
	fi

	if [ ! -x "$BACKUP_DIR" ]; then
		logger "Invalid Permissions: ${YELLOW}execute permissions: $BACKUP_DIR"
		logger "Current Permissions: ${YELLOW}$(ls -ld $BACKUP_DIR|awk '{print $1;}'): $BACKUP_DIR"
		fail 4
	fi

	if [ ! -w "$BACKUP_DIR" ]; then
		logger "Invalid Permissions: ${YELLOW}write permissions: $BACKUP_DIR"
		logger "Current Permissions: ${YELLOW}$(ls -ld $BACKUP_DIR|awk '{print $1;}'): $BACKUP_DIR"
		fail 5
	fi

}

function check_remote_dir() {

	update_task "Checking Remote Directory" "$SHARED_DIR"

	if mountpoint -q "$SHARED_DIR"; then

		update_task "Checking Mount" "Mounted: $SHARED_DIR"
	else
		update_task "Checking Mount" "Mounted: $SHARED_DIR"
		update_task "Mounting" "$SHARED_DIR"
		mount $SHARED_DIR
			if [[ $? -eq 0 ]]; then
				update_task "Mount" "Success"
			else
				update_task "Mount" "Failed ${RED}(exit code: $?)"
				fail 6
			fi
	fi

}

function copy_file() {
	local TASK="Copy Files"
	update_task "Started" "${TASK}"

	local TAR_FILE=$1

	update_task "Checking Folder" "SHARED_DIR"
	check_remote_dir

	cp -p "$TAR_FILE" "$SHARED_DIR/"
	if [[ "$?" -ne 0 ]]; then
		update_task "Copy File" "${TAR_FILE} ${RESET}${RED}Failed"
	fi

	update_task "Completed" "${TASK}"

}

function tar_it() {

	local TARG=$1
	local FLAG=0

    jq -c ".targets[] | select(.name==\"$TARG\")" "$CONF_FILE" | while read i; do
		local TARGET=$(echo $i | jq -c -r ".name")
		local TARGET_DIR=$(echo $i | jq -c -r ".directory")
		local BACKUP_FILE_OWNER=$(echo $i | jq -c -r ".owner")
		local BACKUP_FILE_GROUP=$(echo $i | jq -c -r ".group")
		local TAR_FMT=$(echo $i | jq -c -r ".file_format")
		local TAR_SFX=$(echo $i | jq -c -r ".file_suffix")
		local TAR_KEEP=$(echo $i | jq -c -r ".keep")
		local TAR_NAME=$TARGET-$(date +"$TAR_FMT").$TAR_SFX
		local TAR_FILE=$BACKUP_DIR/$TAR_NAME
		local TAR_EXCL=""

		local SHARED_FILE="$SHARED_DIR/$TAR_NAME"

		update_task "Target" "$TARGET"
		update_task "Target Directory" "$TARGET_DIR"
		update_task "Backup File" "$TAR_FILE"
		update_task "Remote File" "$SHARED_FILE"

		TAR_EXCL+=$(echo $i | jq -c -r '.exclude.folders[]?|.path' | while read EXCL_DIR; do
			if [[ ${EXCL_DIR:0:1} == "/" ]] ; then
            	echo ' --exclude='$EXCL_DIR' '
			else
            	echo $TAR_EXCL' --exclude='$TARGET_DIR/$EXCL_DIR' '
			fi
		done)

		check_backup_dir
		if [[ "$?" -ne 0 && "$FLAG" -eq 0 ]]; then
			FLAG="$?"
		fi

		if [[ ! -z "$TAR_EXCL" ]]; then 
			update_task "Exclude Folders" "$TAR_EXCL"
		fi

		purge_file "$BACKUP_DIR" "$TARGET" "$TAR_KEEP"

		update_task "Building tar file" "$TAR_FILE"
		tar -czv -f $TAR_FILE $TAR_EXCL $TARGET_DIR

		if [[ -f "$TAR_FILE" ]]; then
			logger "Setting target file permissions"
			logger "Setting: ${YELLOW}Owner->${MAGENTA}$BACKUP_FILE_OWNER, ${YELLOW}Group->${MAGENTA}$BACKUP_FILE_GROUP"

			chown $BACKUP_FILE_OWNER:$BACKUP_FILE_GROUP $TAR_FILE
		
			update_task "Settings Permissions" "chmod 0640 $TAR_FILE"
			chmod 0640 $TAR_FILE

			update_task "Rotating Remote File" "$SHARED_FILE"
			purge_file "$SHARED_DIR" "$TARGET" "$TAR_KEEP"

			update_task "Started" "Copy: $TAR_FILE"
			copy_file "$TAR_FILE"
			update_task "Completed" "Copy: $TAR_FILE"
		else
			logger "${ERROR}File missing:${RESET} ${YELLOW}$TAR_FILE"
		    if [[ "$FLAG" -eq 0 ]]; then
				FLAG=1
			fi
		fi
    done

	return $FLAG

}

function tar_files() {

	local FLAG=0

	local TASK="Archiving Files"
    update_task "Started" "${TASK}"

        ARGV_COUNT="${#ARGV_TARGET[@]}"

		if [[ "$ARGV_COUNT" -eq 0 || "${ARGV_TARGET[0]}" == "all" ]]; then
			logger "Processing all targets"
			jq -c -r '.targets[] | .name' $CONF_FILE | while read z; do
				update_task "Processing target" "$z"
				tar_it "$z"
    			if [[ "$?" -ne 0 && "$FLAG" -eq 0 ]]; then
        			FLAG="$?"
    			fi
			done
		else
			for TARG in "${ARGV_TARGET[@]}"; do
				update_task "Processing target" "$TARG"
				tar_it "$TARG"
			    if [[ "$?" -ne 0 && "$FLAG" -eq 0 ]]; then
			        FLAG="$?"
			    fi
			done
		fi

	update_task "Completed" "${TASK}"

}

send_email() {

	local FLAG="$1"
	local LOGFILE="$2"
	local LOG=$(printf '%s\n' "$LOGFILE" | sed 's/[\/&]/\\&/g')

	RECIPIENT="obnaes@proton.me"
	SUBJECT="BACKUP: $(date +"%Y.%m.%d") : $FLAG"

	# Replace placeholders in the template
	sed -e "s/\$RECIPIENT/$RECIPIENT/" \
	    -e "s/\$SUBJECT/$SUBJECT/" \
	    -e "s/\$LOGFILE/$LOG/" \
	    $CONF_DIR/email_template.txt | sendmail -t

}
