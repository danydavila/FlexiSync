#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

APP_NAME="flexisync"
APP_VERSION="1.0.0"
## Set some color for our text. Color constants
RESET_TEXT=$'\e[0m'
LIGHT_YELLOW_TEXT=$'\e[93m'
GREEN_TEXT=$'\e[92m'
GREEN_BLINK_TEXT=$'\e[5;32m'

function show_usage(){
   cat << EOF
${APP_NAME} (${APP_VERSION})

Usage: ./sync.sh [config_name] [push|pull] [remote|local] [run]

Examples:
- Synchronize local source to remote destination directory/files:
  Preview (--dry-run) perform a trial run that doesn't make any changes (and produces mostly the same output as a real run)
  ./sync.sh config_name push remote
  Run the process
  ./sync.sh config_name push remote run

- Synchronize remote source to a local destination directory/files:
  Preview (--dry-run) is very useful option when you want to simulate the execution of an sync without actually making any changes.
  ./sync.sh config_name pull remote
  Run the process
  ./sync.sh config_name pull remote run

- To Synchronize local source to local destination:
  Preview (--dry-run)
  ./sync.sh config_name push local
  ./sync.sh config_name pull local
  Run the sync process
  ./sync.sh config_name push local run
  ./sync.sh config_name pull local run

EOF
   exit 1
}

# Check for required configuration name
if [ $# -lt 1 ]; then
      echo "${LIGHT_YELLOW_TEXT} [x] Missing 1st parameter: [ configuration_file_name ] ${RESET_TEXT}";
	   show_usage
fi

if [ $# -lt 2 ]; then
    echo "${LIGHT_YELLOW_TEXT} [x] Missing 2nd parameters: [ pull | push] ${RESET_TEXT}";
    show_usage
fi

if [ "$2" == "pull" ] || [ "$2" == "push" ]; then
   PULL_OR_PULL_ACTION=$2
else
   echo "${LIGHT_YELLOW_TEXT} [x] Second parameter must be 'pull' or 'push'. ${RESET_TEXT}";
   exit 1;
fi

if [ $# -lt 3 ]; then
    echo "${LIGHT_YELLOW_TEXT} [x] Missing 3rd parameters: [ remote | local] ${RESET_TEXT}";
    show_usage
fi

if [ "$3" == "local" ] || [ "$3" == "remote" ]; then
   LOCAL_OR_REMOTE=$3
else
   echo "${LIGHT_YELLOW_TEXT} [x] 3rd parameter must be 'remote' or 'local'. ${RESET_TEXT}";
   show_usage
fi

# Assign variables from arguments
CONFIG_NAME=$1
ACTION="${PULL_OR_PULL_ACTION}"
LOCATION="${LOCAL_OR_REMOTE}"
MODE=${4:-"--dry-run"}  # Default to dry-run if not specified

# Directories
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FOLDER="${DIR}/log"
CONFIG_FOLDER="${DIR}/config/enabled"
EXCLUDE_FOLDER="${DIR}/config/exclude_list"
INCLUDE_FOLDER="${DIR}/config/include_list"

# Define configuration
CONFIG_FILE="${CONFIG_FOLDER}/${CONFIG_NAME}.conf"

# Check if configuration file exists
if [ ! -f "${CONFIG_FILE}" ]; then
    echo "${LIGHT_YELLOW_TEXT}Error: Missing configuration file ${CONFIG_FILE}${RESET_TEXT}"
    echo "${LIGHTYELLOW_TEXT} [x] Missing 1st argument: [ configuration_file_name ] ${RESET_TEXT}";
    show_usage
fi

# Load configuration
source "${CONFIG_FILE}"

## General Settings
LOGNAME="${APP_NAME}"
LOGDATE=$(date +"%Y-%m-%d_%H_%M")

# Magic variables
__HOSTNAME=$(hostname -s)
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")"
__BASE="$(basename ${__FILE} .sh)"


## Preflight check some variable
if [ -z ${SRC_BASEPATH:+x} ]; then echo "Missing SRC_BASEPATH from ${__CONFIG_FILE}"; exit 1; fi

# Check required config variables
if [ "${LOCATION}" == "remote" ]
   then
   REQUIRED_VARS=(REMOTE_DEST_IDENTITYKEY REMOTE_DEST_PORT REMOTE_DEST_USERNAME REMOTE_DEST_HOSTNAME REMOTE_DEST_BASEPATH)
   for var in "${REQUIRED_VARS[@]}"; do
      if [ -z "${!var}" ]; then
         echo "${LIGHT_YELLOW_TEXT}Error: Missing configuration variable '$var'${RESET_TEXT}"
         exit 1
      fi
   done
fi

## Target basepath
# Set target base path based on location
if [ "${LOCATION}" == "remote" ]; then
    TARGET_BASEPATH="${REMOTE_DEST_BASEPATH}"
elif [ "${LOCATION}" == "local" ]; then
    TARGET_BASEPATH="${DEST_BASEPATH}"
else
    echo "${LIGHT_YELLOW_TEXT}Error: Invalid location '${LOCATION}' specified ${RESET_TEXT}"
    show_usage
fi

## Folder/Files to Backup during a push to target
PUSH_BACKUPLIST="${INCLUDE_FOLDER}/${PUSH_INCLUDE_LIST}"
PUSH_EXCLUTIONLIST="${EXCLUDE_FOLDER}/${PUSH_EXCLUDE_LIST}"

## Folder/Files to ignore or exclude during a pull to target
PULL_BACKUPLIST="${INCLUDE_FOLDER}/${PULL_INCLUDE_LIST}"
PULL_EXCLUTIONLIST="${EXCLUDE_FOLDER}/${PULL_EXCLUDE_LIST}"

LOGFILE="${LOG_FOLDER}/${LOGDATE}_${LOGNAME}_${CONFIG_NAME}_${ACTION}.log"

function touchListFiles(){
  if [ ! -f $1 ];
   then
   echo "Missing $1 file";
   echo "Creating file..."
   touch $1
  fi
}
touchListFiles ${PUSH_BACKUPLIST}
touchListFiles ${PUSH_EXCLUTIONLIST}
touchListFiles ${PULL_BACKUPLIST}
touchListFiles ${PULL_EXCLUTIONLIST}

function checkFileExistence() {
    if [ ! -f "$1" ]; then
        echo "${LIGHTYELLOW_TEXT} Missing $1 file"
        exit 1
    fi
}

function showConfigVar(){
   local source_path=$1
   local target_path=$2
   local exclude_path=$3
   local include_path=$4
   echo "${GREEN_TEXT} App:${RESET_TEXT} ${APP_NAME} (${APP_VERSION}) "
   echo "${GREEN_TEXT} Configuration Name:${RESET_TEXT} ${CONFIG_NAME} "
   echo "${GREEN_TEXT} Action:${RESET_TEXT} ${ACTION}"
   echo "${GREEN_TEXT} Location:${RESET_TEXT} ${LOCATION}"
   echo "${GREEN_TEXT} Mode:${RESET_TEXT} ${MODE}"
   echo "${GREEN_TEXT} Config Filepath:${RESET_TEXT} ${CONFIG_FILE}"
   echo "${GREEN_TEXT} Source Base Path:${RESET_TEXT} ${source_path}"
   echo "${GREEN_TEXT} Target Base Path:${RESET_TEXT} ${target_path}"
   echo "${GREEN_TEXT} Rsync Option:${RESET_TEXT} ${RSYNC_OPTIONS}"
   echo -e "--exclude-from=${exclude_path}";
   echo -e "--files-from=${include_path}";
   echo -e "--log-file=${LOGFILE}";
   echo "${GREEN_TEXT} Rsync Excludes Operating System files:${RESET_TEXT} ${RSYNC_EXCLUDE_OSFILE}"
}

if [ "${MODE}" == "--dry-run" ]; then
   echo "${GREEN_BLINK_TEXT} 4rd Parameter is missing running in test mode --dry-run${RESET_TEXT}"
   DRYRUN="--dry-run"
else
   DRYRUN=""
fi

# Default Rsync Options
# for more options visit =
# https://www.samba.org/ftp/rsync/rsync.html#OPTION_SUMMARY
RSYNC_OPTIONS="--archive"; #--archive, -a , archive mode is -rlptgoD (no -A,-X,-U,-N,-H)
                           # -r recurse into directories
                           # -p (--perms) preserve permissions
                           # -t (--times) preserve modification times
                           # -g (--groups) preserve group
                           # -o (--owner) preserve owner (super-user only)
RSYNC_OPTIONS="${RSYNC_OPTIONS} --human-readable";  # output numbers in a human-readable format
RSYNC_OPTIONS="${RSYNC_OPTIONS} --delete-after";    # receiver deletes after transfer, not during
RSYNC_OPTIONS="${RSYNC_OPTIONS} --progress";        # show progress during transfer
RSYNC_OPTIONS="${RSYNC_OPTIONS} --stats";           # give some file-transfer stats
RSYNC_OPTIONS="${RSYNC_OPTIONS} --checksum";        # skip based on checksum, not mod-time & size
RSYNC_OPTIONS="${RSYNC_OPTIONS} ${DRYRUN}";         # give some file-transfer stats

# if the variable RSYNC_FLAGS is defined then ignore the default option and use user define favirable
if [ ! -z ${RSYNC_FLAGS:+x} ];
   then
   RSYNC_OPTIONS=${RSYNC_FLAGS}
fi

RSYNC_PATH='rsync'
if [ ! -z ${REMOTE_BECOME_SUDO:+x} ] && [ "${REMOTE_BECOME_SUDO}" == 'yes' ];
   then
   RSYNC_PATH="sudo rsync"
fi

# exclude Windows and Mac system file
RSYNC_EXCLUDE_OSFILE="--exclude='\$RECYCLE.BIN' --exclude='\$Recycle.Bin' --exclude='.AppleDB' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.AppleDesktop' --exclude='.AppleDouble' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.com.apple.timemachine.supported' --exclude='.com.apple.timemachine.donotpresent'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.DocumentRevisions-V100*' --exclude='*/.DS_Store' --exclude='.DS_Store' --exclude='.dbfseventsd' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.fseventsd' --exclude='.PKInstallSandboxManager' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.Spotlight*' --exclude='.SymAV*' --exclude='.symSchedScanLockxz' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.TemporaryItems' --exclude='.Trash*' --exclude='.vol' --exclude='RECYCLER'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.VolumeIcon.icns' --exclude='hiberfil.sys' --exclude='lost+found'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='hiberfil.sys' --exclude='lost+found' --exclude='pagefile.sys' --exclude='Recycled' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='Thumbs.db' --exclude='._.TemporaryItems' --exclude='._.DS_Store' --exclude='._.com.apple.timemachine.donotpresent'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude={\"/dev/*\",\"/proc/*\",\"/sys/*\",\"/tmp/*\",\"/run/*\",\"/mnt/*\",\"/media/*\",\"/lost+found\"} ";

case "${ACTION}" in
	 pull)
         checkFileExistence ${PULL_EXCLUTIONLIST}
         checkFileExistence ${PULL_BACKUPLIST}

         # Display and log configuration
         showConfigVar ${TARGET_BASEPATH} \
         ${SRC_BASEPATH} \
         ${PULL_EXCLUTIONLIST} \
         ${PULL_BACKUPLIST} | tee -a ${LOGFILE}

         if [ "${LOCATION}" == "local" ]
         then
            rsync ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from="${PULL_EXCLUTIONLIST}" \
               --files-from="${PULL_BACKUPLIST}" \
               --log-file="${LOGFILE}" \
               ${TARGET_BASEPATH} ${SRC_BASEPATH}
         fi

         if [ "${LOCATION}" == "remote" ]
         then
            rsync ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
            --exclude-from="${PULL_EXCLUTIONLIST}" \
            --files-from="${PULL_BACKUPLIST}" \
            --log-file="${LOGFILE}" \
            -e "ssh -p ${REMOTE_DEST_PORT} -i ${REMOTE_DEST_IDENTITYKEY}" \
            --rsync-path="${RSYNC_PATH}" \
            "${REMOTE_DEST_USERNAME}@${REMOTE_DEST_HOSTNAME}:${REMOTE_DEST_BASEPATH}" ${SRC_BASEPATH}
         fi
    ;;
	 push)
         checkFileExistence ${PUSH_EXCLUTIONLIST}
         checkFileExistence ${PUSH_BACKUPLIST}

         # Display and log configuration
         showConfigVar ${SRC_BASEPATH} \
         ${TARGET_BASEPATH} \
         ${PUSH_EXCLUTIONLIST} \
         ${PUSH_BACKUPLIST} | tee -a ${LOGFILE}

         if [ "${LOCATION}" == "local" ]
         then
            rsync ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from="${PUSH_EXCLUTIONLIST}" \
               --files-from="${PUSH_BACKUPLIST}" \
               --log-file="${LOGFILE}" \
               ${SRC_BASEPATH} ${TARGET_BASEPATH}
         fi

         if [ "${LOCATION}" == "remote" ]
         then
            rsync ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
            --exclude-from="${PUSH_EXCLUTIONLIST}" \
            --files-from="${PUSH_BACKUPLIST}" \
            --log-file="${LOGFILE}" \
            -e "ssh -p ${REMOTE_DEST_PORT} -i ${REMOTE_DEST_IDENTITYKEY}" \
            --rsync-path="${RSYNC_PATH}" \
            ${SRC_BASEPATH} \
            "${REMOTE_DEST_USERNAME}@${REMOTE_DEST_HOSTNAME}:${REMOTE_DEST_BASEPATH}"
         fi
    ;;
    * )
      echo "${LIGHT_YELLOW_TEXT}Error: Invalid action '${ACTION}' specified${RESET_TEXT}"
	   show_usage
      exit 1;
    ;;
esac
