#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset

## Set some color for our text. Color constants
RESET_TEXT=$'\e[0m'
LIGHT_YELLOW_TEXT=$'\e[93m'
GREEN_TEXT=$'\e[92m'
GREEN_BLINK_TEXT=$'\e[5;32m'

## General Settings
APPNAME=$(basename $0 | sed "s/\.sh$//")
LOGNAME="${APPNAME}"
LOGDATE=$(date +"%Y-%m-%d_%H_%M")

# Magic variables
__RSYNC=$(which rsync)
__HOSTNAME=$(hostname -s)
__DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__FILE="${__DIR}/$(basename "${BASH_SOURCE[0]}")"
__BASE="$(basename ${__FILE} .sh)"
__CONFIG_FOLDER="${__DIR}/config"
__EXCLUDE_FOLDER="${__DIR}/config/exclude_list"
__INCLUDE_FOLDER="${__DIR}/config/include_list"
__LOG_FOLDER="${__DIR}/log"

cd $__DIR;

function show_howto(){
     echo ""
     echo "usage : $(basename $0) [OPTION]...  [config_name] [push|pull] [remote|local] [run] "
     echo ""
     echo "Only one option is allow"
     echo "pull : Sync all my remote node files into my local computer"
     echo "push : Sync all my local files to the remote node"
	  echo ""
	  echo ""
     echo ""
     echo "Example: $(basename $0) config_name push remote run"
     echo "Example: $(basename $0) config_name pull remote run"
     echo "Example: $(basename $0) config_name push local run"
     echo "Example: $(basename $0) config_name pull local run"
}

if [ $# -eq 0 ] 
   then
	   	echo "${LIGHTYELLOW_TEXT} [x] Missing argument: [configuration_file_name] [push|pull] [local|remote] ${RESET_TEXT}";
         echo "${LIGHTYELLOW_TEXT} [x] Missing 1st argument: [ configuration_file_name ] ${RESET_TEXT}";
	      show_howto 
      exit 1;
fi

if [ $# -eq 1 ]
   then
	   	echo "${LIGHTYELLOW_TEXT} [x] Missing 2nd argument: [ pull | push] ${RESET_TEXT}";
	    show_howto 
      exit 1;
fi

if [ $# -eq 2 ]
  then
	   	echo "${LIGHTYELLOW_TEXT} [x] Missing 3tr argument: [ remote | local] ${RESET_TEXT}";
	    show_howto 
      exit 1;
fi

__NAME=$1
__CONFIG_FILE="${__CONFIG_FOLDER}/$1.conf"

if [ ! -f ${__CONFIG_FILE} ]; then echo "Missing ${__CONFIG_FILE} file"; exit 1; fi

## Load configuration file
source ${__CONFIG_FILE}

## Preflight check some variable 
if [ -z ${SRC_BASEPATH:+x} ]; then echo "Missing SRC_BASEPATH from ${__CONFIG_FILE}"; exit 1; fi

if [ -z ${REMOTE_DEST_IDENTITYKEY:+x} ]; then echo "Missing REMOTE_DEST_IDENTITYKEY from ${__CONFIG_FILE}"; exit 1; fi
if [ -z ${REMOTE_DEST_PORT:+x} ]; then echo "Missing REMOTE_DEST_PORT from ${__CONFIG_FILE}"; exit 1; fi
if [ -z ${REMOTE_DEST_USERNAME:+x} ]; then echo "Missing REMOTE_DEST_USERNAME from ${__CONFIG_FILE}"; exit 1; fi
if [ -z ${REMOTE_DEST_HOSTNAME:+x} ]; then echo "Missing REMOTE_DEST_HOSTNAME from ${__CONFIG_FILE}"; exit 1; fi
if [ -z ${REMOTE_DEST_BASEPATH:+x} ]; then echo "Missing REMOTE_DEST_BASEPATH from ${__CONFIG_FILE}"; exit 1; fi

## Source basepath
SRC_BASEPATH="$(cd ${SRC_BASEPATH} && pwd)"; 

if [ -z ${SRC_BASEPATH:+x} ] 
   then 
   echo "Unable to determine if you are running on a laptop or desktop."; 
   echo "Please review SRC_BASEPATH in your config file"; 
   echo "Your Hostname: ${__HOSTNAME}";
   exit 1; 
fi

## Target basepath
if [ "$3" == "remote" ]
   then 
   TARGET_BASEPATH="${REMOTE_DEST_BASEPATH}"; 
fi

if [ "$3" == "local" ]
   then 
   TARGET_BASEPATH="${DEST_BASEPATH}"; 
fi

if [ -z ${TARGET_BASEPATH:+x} ]
   then 
   echo "Unable to determine if you want to push to remote or local"; 
   echo "Please make sure you parameter REMOTE_DEST_BASEPATH or LOCAL_BASEPATH is set "; 
   echo "Please review  your config file";
   exit 1; 
fi

## Folder/Files to Backup during a push to target
PUSH_BACKUPLIST=${__INCLUDE_FOLDER}/${PUSH_INCLUDE_LIST}

## Folder/Files to ignore or exclude during a push to target
PUSH_EXCLUTIONLIST=${__EXCLUDE_FOLDER}/${PUSH_EXCLUDE_LIST}

## Folder/Files to ignore or exclude during a pull to target
PULL_BACKUPLIST=${__INCLUDE_FOLDER}/${PULL_INCLUDE_LIST}

## Folder/Files to ignore or exclude during a pull to target
PULL_EXCLUTIONLIST=${__EXCLUDE_FOLDER}/${PULL_EXCLUDE_LIST}

## Logs file path
PUSH_LOGFILE=${__LOG_FOLDER}/"$LOGDATE"_$LOGNAME.${__NAME}.push.log
PULL_LOGFILE=${__LOG_FOLDER}/"$LOGDATE"_$LOGNAME.${__NAME}.pull.log

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

function showConfigVar(){
  echo "${GREEN_TEXT} Source Base Path:${RESET_TEXT} ${SRC_BASEPATH}"
  echo "${GREEN_TEXT} Target Base Path:${RESET_TEXT} ${TARGET_BASEPATH}"
  echo "${GREEN_TEXT} Rsync Option:${RESET_TEXT} ${RSYNC_OPTIONS} \ "
  echo "--exclude-from=${PUSH_EXCLUTIONLIST} \ ";
  echo "--files-from=${PUSH_BACKUPLIST} \ ";
  echo "--log-file=${PUSH_LOGFILE} \ ";
  echo "${GREEN_TEXT} Rsync Exclude Option:${RESET_TEXT} ${RSYNC_EXCLUDE_OSFILE}" 
  echo "${GREEN_TEXT} SSH Ciphers:${RESET_TEXT} ${SSH_OCIPHERS}"
}

if [ $# -eq 3 ]
  then
       echo "${GREEN_TEXT_BLINK} 4rd Parameter is missing running in test mode --dry-run${RESET_TEXT}"
       DRYRUN="--dry-run"
else
     #define process mode. dry-drun (test) or push to production
      case $4 in
        go)
             DRYRUN=""
            ;;
        commit)
             DRYRUN=""
            ;;
        run)
             DRYRUN=""
            ;;
          * )
             DRYRUN="--dry-run"
          ;;
     esac
fi

# for more options visit 
#https://www.samba.org/ftp/rsync/rsync.html
RSYNC_OPTIONS="--recursive";                        # recurse into directories
#RSYNC_OPTIONS="${RSYNC_OPTIONS} --itemize-changes"; # output a change-summary for all updates
RSYNC_OPTIONS="${RSYNC_OPTIONS} --copy-links";      # transform symlink into referent file/dir
RSYNC_OPTIONS="${RSYNC_OPTIONS} --perms";           # -p (--perms) preserve permissions
RSYNC_OPTIONS="${RSYNC_OPTIONS} --times";           # -t (--times) preserve modification times
RSYNC_OPTIONS="${RSYNC_OPTIONS} --group";           # -g (--groups) preserve group
RSYNC_OPTIONS="${RSYNC_OPTIONS} --owner";           # -o (--owner) preserve owner (super-user only)
RSYNC_OPTIONS="${RSYNC_OPTIONS} --one-file-system"; # -x,(--one-file-system)don't cross filesystem boundaries
RSYNC_OPTIONS="${RSYNC_OPTIONS} --human-readable";  # output numbers in a human-readable format
RSYNC_OPTIONS="${RSYNC_OPTIONS} --delete-after";    # receiver deletes after transfer, not during
RSYNC_OPTIONS="${RSYNC_OPTIONS} --progress";        # show progress during transfer
RSYNC_OPTIONS="${RSYNC_OPTIONS} --stats";           # give some file-transfer stats
#RSYNC_OPTIONS="${RSYNC_OPTIONS} --hard-links";      # -H (--hard-links) preserve hard links.
RSYNC_OPTIONS="${RSYNC_OPTIONS} --specials";        # This option causes rsync to transfer special files such as named sockets and fifos.
RSYNC_OPTIONS="${RSYNC_OPTIONS} --devices";         # This option causes rsync to transfer character and block device files to the remote
                                                    # system to recreate these devices. This option has no effect if the receiving rsync 
                                                    # is not run as the super-user.
RSYNC_OPTIONS="${RSYNC_OPTIONS} --checksum";       # skip based on checksum, not mod-time & size
RSYNC_OPTIONS="${RSYNC_OPTIONS} ${DRYRUN}";         # give some file-transfer stats

# Overwrite Rsync options
if [ ! -z ${RSYNC_FLAGS:+x} ]; 
   then 
   RSYNC_OPTIONS=${RSYNC_FLAGS}
fi

RSYNC_PATH='rsync'
if [ ! -z ${REMOTE_BECOME_SUDO:+x} ] && [ "${REMOTE_BECOME_SUDO}" == 'yes' ]; 
   then 
   RSYNC_PATH="sudo rsync"
fi


# Default SSH client cipher.
# To found out supported ciphers. user [server]$  ssh -Q cipher. 
# cipher ending with -ctr or -gcm: 
# for CTR mode aims at confidentiality 
# for GCM additionally aims at integrity
SSH_OCIPHERS="aes128-gcm@openssh.com,chacha20-poly1305@openssh.com,aes128-ctr"
# Overwrite Rsync Ciphers
if [ ! -z ${SSH_CIPHERS:+x} ]; 
   then 
   SSH_OCIPHERS=${SSH_CIPHERS}
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

echo ""
showConfigVar 
echo "" 

case $2 in
	 pull) 
            if [ ! -f ${PULL_EXCLUTIONLIST} ] || [ ! -f ${PULL_BACKUPLIST} ] ;
            then 

               echo "${LIGHTYELLOW_TEXT} Missing ${PULL_EXCLUTIONLIST} file"
               echo "${LIGHTYELLOW_TEXT} Missing ${PULL_BACKUPLIST} file"
               exit 1; 
            fi
            
            if [ "$3" == "local" ]
            then 
                # run rsync command
                # example : rsync -rlptgochu [source] [target]
                ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
                --exclude-from=${PULL_EXCLUTIONLIST} \
                --files-from=${PULL_BACKUPLIST} \
                --log-file=${PULL_LOGFILE} \
                ${TARGET_BASEPATH} ${SRC_BASEPATH}
            fi

            if [ "$3" == "remote" ]
            then 
               # run rsync command ${RSYNC_OPTIONS}
               # example : rsync -rlptgochu -e "ssh -p 22 -i ~/id_rsa" nas@nas.server.com:~/[source] [target]
               ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from=${PULL_EXCLUTIONLIST} \
               --files-from=${PULL_BACKUPLIST} \
               --log-file=${PULL_LOGFILE} \
               -e "ssh -oCiphers=${SSH_OCIPHERS} -T -o Compression=no -x -p ${REMOTE_DEST_PORT} -i ${REMOTE_DEST_IDENTITYKEY}" --rsync-path="${RSYNC_PATH}" ${REMOTE_DEST_USERNAME}@${REMOTE_DEST_HOSTNAME}:${REMOTE_DEST_BASEPATH} ${SRC_BASEPATH}
            fi

    ;;
	 push)
            if [ ! -f ${PUSH_EXCLUTIONLIST} ] || [ ! -f ${PUSH_BACKUPLIST} ] ;
            then 
               echo ""
               showConfigVar 
               echo ""
               echo "${LIGHTYELLOW_TEXT} Missing ${PUSH_EXCLUTIONLIST} file"
               echo "${LIGHTYELLOW_TEXT} Missing ${PUSH_BACKUPLIST} file"
               exit 1; 
            fi

            if [ "$3" == "local" ]
            then 
                # run rsync command
                # example : rsync -rlptgochu [source] [target]
                ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
                --exclude-from=${PUSH_EXCLUTIONLIST} \
                --files-from=${PUSH_BACKUPLIST} \
                --log-file=${PUSH_LOGFILE} \
                ${SRC_BASEPATH} ${TARGET_BASEPATH}
            fi

            if [ "$3" == "remote" ]
            then 

               # run rsync command
               # example : rsync -rlptgochu [source] -e "ssh -p 22 -i ~/id_rsa" nas@nas.server.com:~/[target]
               ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from=${PUSH_EXCLUTIONLIST} \
               --files-from=${PUSH_BACKUPLIST} \
               --log-file=${PUSH_LOGFILE} \
               ${SRC_BASEPATH} -e "ssh -oCiphers=${SSH_OCIPHERS} -T -o Compression=no -x -p ${REMOTE_DEST_PORT} -i ${REMOTE_DEST_IDENTITYKEY}"  --rsync-path="${RSYNC_PATH}" \
               ${REMOTE_DEST_USERNAME}@${REMOTE_DEST_HOSTNAME}:${REMOTE_DEST_BASEPATH}
               # SSH Option:
               # -T : turn off pseudo-tty to decrease cpu load on destination.
               # -o : Compression=no : Turn off SSH compression.
               # -x : turn off X forwarding if it is on by default.
               # -c : try hardware accelerated AES-NI instructions.
               # -oCiphers :  connect by specifying an allowed Cipher
            fi
    ;;
    * )
       echo "Unable to find process action"
	     show_howto
       exit 1;
    ;;
esac

# Display configuration 
showConfigVar

exit 0; #Success