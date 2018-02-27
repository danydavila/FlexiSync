#!/usr/bin/env bash
set -o errexit
set -o pipefail
set -o nounset
#set -o xtrace

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
__CONFIGFOLDER="${__DIR}/config"
__LOGFOLDER="${__DIR}/log"
__CONFIGFILE="${__CONFIGFOLDER}/config"

cd $__DIR;

if [ ! -d ${__CONFIGFOLDER} ]
   then 
     echo "initialize Project";
     echo "copying config_example to config";
     cp -rv ${__DIR}/config_example ${__DIR}/config
     mv -v ${__DIR}/config/config.example ${__DIR}/config/config
fi

## Set some color for our text
LIGHT_CYAN_TEXT=$'\e[96m'; LIGHT_MAGENTA_TEXT=$'\e[35m'; LIGHTYELLOW_TEXT=$'\e[93m'; GREEN_TEXT=$'\e[92m'; 
GREEN_TEXT_BLINK=$'\e[5;32m'; YELLOW_TEXT=$'\e[5;33m'; RESET_TEXT=$'\e[25;0m';


function show_howto(){
     echo ""
     echo "usage : $(basename $0) [OPTION]...  [push|pull] [remote|local] [commit] "
     echo ""
     echo "Only one option is allow"
     echo "pull : Sync all my remote node files into my local computer"
     echo "push : Sync all my local files to the remote node"
	 echo "For more detailed help, please see the README file:"
	 echo ""
	 echo "https://github.com/danydavila/SyncThis"
     echo ""
     echo "Example: $(basename $0) push remote run"
     echo "Example: $(basename $0) pull remote run"
     echo "Example: $(basename $0) push local run"
}

if [ $# -eq 0 ] 
   then
	   	echo "${LIGHTYELLOW_TEXT} [x] Missing 1st argument: [ pull | push] ${RESET_TEXT}";
	    show_howto 
        exit 1;
fi
if [ $# -eq 1 ]
  then
	   	echo "${LIGHTYELLOW_TEXT} [x] Missing 2nd argument: [ remote | local] ${RESET_TEXT}";
	    show_howto 
        exit 1;
fi

if [ ! -f ${__CONFIGFILE} ]; then echo "Missing ${__CONFIGFILE} file"; exit 1; fi

## Load configuration file
source ${__CONFIGFILE}

## Preflight check some variable 
if [ -z ${DESKTOP_BASEPATH:+x} ]; then echo "Missing DESKTOP_BASEPATH from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${LAPTOP_BASEPATH:+x} ]; then echo "Missing LAPTOP_BASEPATH from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${REMOTE_IDENTITYKEY:+x} ]; then echo "Missing REMOTE_IDENTITYKEY from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${REMOTE_PORT:+x} ]; then echo "Missing REMOTE_PORT from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${REMOTE_USERNAME:+x} ]; then echo "Missing REMOTE_USERNAME from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${REMOTE_HOSTNAME:+x} ]; then echo "Missing REMOTE_HOSTNAME from ${__CONFIGFILE}"; exit 1; fi
if [ -z ${REMOTE_BASEPATH:+x} ]; then echo "Missing REMOTE_BASEPATH from ${__CONFIGFILE}"; exit 1; fi

## Source basepath
if [ "${DESKTOP_HOSTNAME}" == "${__HOSTNAME}" ]; then 
   SOURCE_BASEPATH="$(cd ${DESKTOP_BASEPATH} && pwd)"; 
fi

if [ "${LAPTOP_HOSTNAME}" == "${__HOSTNAME}" ]; then  
    SOURCE_BASEPATH="$(cd ${LAPTOP_BASEPATH} && pwd)"; 
fi

if [ -z ${SOURCE_BASEPATH:+x} ] 
   then 
   echo "Unable to determine if you are running on a laptop or deskptop."; 
   echo "Please review LAPTOP_HOSTNAME and DESKTOP_HOSTNAME in your config file"; 
   echo "Your Hostname: ${__HOSTNAME}";
   exit 1; 
fi

## Target basepath
if [ "$2" == "remote" ]
   then 
   TARGET_BASEPATH="${REMOTE_BASEPATH}"; 
fi

if [ "$2" == "local" ]
   then 
   TARGET_BASEPATH="${LOCAL_BASEPATH}"; 
fi

if [ -z ${TARGET_BASEPATH:+x} ]
   then 
   echo "Unable to determine if you want to push to remote or local"; 
   echo "Please make sure you parameter is set"; 
   echo "Please review LAPTOP_HOSTNAME and DESKTOP_HOSTNAME in your config file";
   exit 1; 
fi

## Folder/Files to Backup during a push to target
PUSH_BACKUPLIST=${__CONFIGFOLDER}/push.include.txt

## Folder/Files to ignore or exclude during a push to target
PUSH_EXCLUTIONLIST=${__CONFIGFOLDER}/push.exclude.txt

## Folder/Files to ignore or exclude during a pull to target
PULL_BACKUPLIST=${__CONFIGFOLDER}/pull.include.txt

## Folder/Files to ignore or exclude during a pull to target
PULL_EXCLUTIONLIST=${__CONFIGFOLDER}/pull.exclude.txt

## Logs file path
PUSH_LOGFILE=${__LOGFOLDER}/"$LOGDATE"_$LOGNAME.push.log
PULL_LOGFILE=${__LOGFOLDER}/"$LOGDATE"_$LOGNAME.pull.log

function showConfigVar(){
  echo "${GREEN_TEXT} Desktop Base Path:${RESET_TEXT} ${DESKTOP_BASEPATH}"
  echo "${GREEN_TEXT} Laptop Base Path:${RESET_TEXT} ${LAPTOP_BASEPATH}"
  echo "${GREEN_TEXT} Source Base Path:${RESET_TEXT} ${SOURCE_BASEPATH}"
  echo "${GREEN_TEXT} Target Base Path:${RESET_TEXT} ${TARGET_BASEPATH}"
  echo "${GREEN_TEXT} Rsync Option:${RESET_TEXT} ${RSYNC_OPTIONS} \ "
  echo "--exclude-from=${PUSH_EXCLUTIONLIST} \ ";
  echo "--files-from=${PUSH_BACKUPLIST} \ ";
  echo "--log-file=${PUSH_LOGFILE} \ ";
  echo "${GREEN_TEXT} Rsync Exclude Option:${RESET_TEXT} ${RSYNC_EXCLUDE_OSFILE}" 
  echo "${GREEN_TEXT} SSH Ciphers:${RESET_TEXT} ${SSH_CIPHERS}"
}

if [ $# -eq 2 ]
  then
       echo "${GREEN_TEXT_BLINK}3rd Parameter is missing running in test mode --dry-run${RESET_TEXT}"
       DRYRUN="--dry-run"
else
     #define process mode. dry-drun (test) or push to production
      case $3 in
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
RSYNC_OPTIONS="${RSYNC_OPTIONS} --itemize-changes"; # output a change-summary for all updates
RSYNC_OPTIONS="${RSYNC_OPTIONS} --copy-links";      # transform symlink into referent file/dir
RSYNC_OPTIONS="${RSYNC_OPTIONS} --perms";           # -p (--perms) preserve permissions
RSYNC_OPTIONS="${RSYNC_OPTIONS} --times";           # -t (--times) preserve modification times
RSYNC_OPTIONS="${RSYNC_OPTIONS} --group";           # -g (--groups) preserve group
RSYNC_OPTIONS="${RSYNC_OPTIONS} --owner";           # -o (--owner) preserve owner (super-user only)
RSYNC_OPTIONS="${RSYNC_OPTIONS} --one-file-system"; # -x,(--one-file-system)don't cross filesystem boundaries
RSYNC_OPTIONS="${RSYNC_OPTIONS} --human-readable";  # output numbers in a human-readable format
RSYNC_OPTIONS="${RSYNC_OPTIONS} --delete";          # delete extraneous files from dest dirs
RSYNC_OPTIONS="${RSYNC_OPTIONS} --progress";        # show progress during transfer
RSYNC_OPTIONS="${RSYNC_OPTIONS} --stats";           # give some file-transfer stats
RSYNC_OPTIONS="${RSYNC_OPTIONS} --hard-links";      # -H (--hard-links) preserve hard links.
RSYNC_OPTIONS="${RSYNC_OPTIONS} --specials";        # This option causes rsync to transfer special files such as named sockets and fifos.
RSYNC_OPTIONS="${RSYNC_OPTIONS} --devices";         # This option causes rsync to transfer character and block device files to the remote
                                                    # system to recreate these devices. This option has no effect if the receiving rsync 
                                                    # is not run as the super-user.
#RSYNC_OPTIONS="${RSYNC_OPTIONS} --checksum";       # skip based on checksum, not mod-time & size
RSYNC_OPTIONS="${RSYNC_OPTIONS} ${DRYRUN}";         # give some file-transfer stats

# Overwrite Rsync options
if [ ! -z ${RSYNC_FLAGS:+x} ]; 
   then 
   RSYNC_OPTIONS=${RSYNC_FLAGS}
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
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.DocumentRevisions-V100*' --exclude='.DS_Store' --exclude='.dbfseventsd' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.fseventsd' --exclude='.PKInstallSandboxManager' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.Spotlight*' --exclude='.SymAV*' --exclude='.symSchedScanLockxz' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.TemporaryItems' --exclude='.Trash*' --exclude='.vol' --exclude='RECYCLER'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='.VolumeIcon.icns' --exclude='hiberfil.sys' --exclude='lost+found'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='hiberfil.sys' --exclude='lost+found' --exclude='pagefile.sys' --exclude='Recycled' ";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude='Thumbs.db' --exclude='._.TemporaryItems' --exclude='._.DS_Store' --exclude='._.com.apple.timemachine.donotpresent'";
RSYNC_EXCLUDE_OSFILE="${RSYNC_EXCLUDE_OSFILE} --exclude={\"/dev/*\",\"/proc/*\",\"/sys/*\",\"/tmp/*\",\"/run/*\",\"/mnt/*\",\"/media/*\",\"/lost+found\"} ";

case $1 in
	 pull)
            if [ "$2" == "local" ]
            then 
                # run rsync command
                # example : rsync -rlptgochu [source] [target]
                ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
                --exclude-from=${PULL_EXCLUTIONLIST} \
                --files-from=${PULL_BACKUPLIST} \
                --log-file=${PULL_LOGFILE} \
                ${TARGET_BASEPATH} ${SOURCE_BASEPATH}
            fi

            if [ "$2" == "remote" ]
            then 
               # run rsync command
               # example : rsync -rlptgochu -e "ssh -p 22 -i ~/id_rsa" nas@nas.server.com:~/[source] [target]
               ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from=${PULL_EXCLUTIONLIST} \
               --files-from=${PULL_BACKUPLIST} \
               --log-file=${PULL_LOGFILE} \
               -e "ssh -oCiphers=${SSH_OCIPHERS} -T -o Compression=no -x -p ${REMOTE_PORT} -i ${REMOTE_IDENTITYKEY}" ${REMOTE_USERNAME}@${REMOTE_HOSTNAME}:${REMOTE_BASEPATH} ${SOURCE_BASEPATH}
            fi
    ;;
	 push)
            if [ "$2" == "local" ]
            then 
                # run rsync command
                # example : rsync -rlptgochu [source] [target]
                ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
                --exclude-from=${PUSH_EXCLUTIONLIST} \
                --files-from=${PUSH_BACKUPLIST} \
                --log-file=${PUSH_LOGFILE} \
                ${SOURCE_BASEPATH} ${TARGET_BASEPATH}
            fi

            if [ "$2" == "remote" ]
            then 
               # run rsync command
               # example : rsync -rlptgochu [source] -e "ssh -p 22 -i ~/id_rsa" nas@nas.server.com:~/[target]
               ${__RSYNC} ${RSYNC_OPTIONS} ${RSYNC_EXCLUDE_OSFILE} \
               --exclude-from=${PUSH_EXCLUTIONLIST} \
               --files-from=${PUSH_BACKUPLIST} \
               --log-file=${PUSH_LOGFILE} \
               ${SOURCE_BASEPATH} -e "ssh -oCiphers=${SSH_OCIPHERS} -T -o Compression=no -x -p ${REMOTE_PORT} -i ${REMOTE_IDENTITYKEY}" ${REMOTE_USERNAME}@${REMOTE_HOSTNAME}:${REMOTE_BASEPATH}
               # SSH Option:
               # -T : turn off pseudo-tty to decrease cpu load on destination.
               # -o : Compression=no : Turn off SSH compression.
               # -x : turn off X forwarding if it is on by default.
               # -c : try hardware accelerated AES-NI instructions.
               # -oCiphers :  connect by specifying an allowed Cipher
            fi
    ;;
    * )
	     show_howto
       exit 1;
    ;;
esac

# Display configuration 
showConfigVar

exit 0; #Success