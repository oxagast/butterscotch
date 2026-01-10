#!/bin/bash
# oxagast / Marshall Whittaker
# oxasploits, llc. 2026
#
LEAVEN=6 # the number of snapshots trailing
REDO=0
CR=0
RO=0
TAKEN=0
YES=0
VER="v1.5.2"
SSDIR="/.snapshots/" # this is the dir under the btrfs mountpoint we should store snapshots in
SSDIRZFS="/.zfs/snapshot/"
SSDIRBTR="/.snapshots/"

function help {
  echo "Usage:"
  echo "   $0 -p /:/home -c -w"
  echo "   $0 -a -r -d 5"
  echo
  echo " -h       This help message."
  echo " -a       Snapshot all btrfs partitions.                                 Default:           off"
  echo " -p       Partitions to snapshot, seperated by colons. Mandatory.        Default:          none"
  echo " -d       Max number of snapshots to leave in trail, total.              Default:             6"
  echo " -r       If there is a previous snapshot taken on the same              Default:           off"
  echo "          day, should we remove it and resnap?"
  echo " -c       Immediately commit deletions.                                  Default:           off"
  echo " -w       Mark read-only.                                                Default:           off"
  echo " -L       Snapshot relative locations.  Must begin and end with '/'      Default:  /.snapshots/"
  echo " -q       Take a quicksnap. This assumes -a if not specified.            Default:           off"
  echo " -U       Unsupported OS override. Use at your own risk!                 Default:           off"
  echo " -l       List snapshots found in specified partitions. Pair with -p.    Default:          none"
  echo " -P       Purge all snapshots found in specified partitions. Asks for    Default:          none"
  echo "          confirmation before deletion.  Pair with -p or -a.                                   "
  echo " -y       Assume yes to all prompts.                                     Default:           off"
  echo " -V       Display version information.                                   Default:          none"
  echo
}

function ListSnaps {
  if [[ $(uname -s) == "FreeBSD" ]]; then
    SSDIR=$SSDIRZFS
  fi
  IFS=':'
  read -a PTN <<<"${PTNSTR}"
  for BASEP in "${PTN[@]}"; do
    P="${BASEP}${SSDIR}"
    P=$(echo "${P}" | tr -s '/')
    # put the snapshot list into an array to list later
    readarray -O "${#SHOTS[@]}" -t SHOTS < <(find "${P}" -maxdepth 1 -type d 2>/dev/null | grep snap-)
    MCOUNT=$(find "${P}" -maxdepth 1 -type d 2>/dev/null | grep snap- | wc -l)
    # the total snapshot count
    TCOUNT=$((MCOUNT + TCOUNT))
  done
  if [[ $TCOUNT -eq 0 ]]; then
    echo "No snapshots found."
    exit 1
  fi
  echo "Found ${TCOUNT} snapshots."
  printf "%s\n" ${SHOTS[@]}
  exit 0
}

function CreateDir {
  if [ ! -d "${BASEP}${SSDIR}" ]; then
    mkdir -p "${BASEP}${SSDIR}" && echo "Directory created..." || echo "Directory creation failed"
  fi
}

function RemoveZFS {
  if [[ $(uname -s) == "FreeBSD" ]]; then
    POOL=$(df /${BASEP} | cut -d ' ' -f 1 | grep -v Filesystem)
    # find the snapshots from -p and pipe them to xargs to be fed into zfs destroy
    find "/${BASEP}${SSDIRZFS}" -maxdepth 0 -exec ls -1ctr {} \; | ghead -n -${LEAVEN} | grep -v quick | xargs -I {} zfs destroy "${POOL}"@{} 2>&1 >/dev/null
  elif [[ $(uname -s) == "Linux" ]]; then
    find "/${BASEP}${SSDIRZFS}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | grep -v quick | xargs -I {} zfs destroy "${POOL}"@{} 2>&1 >/dev/null
  else
    echo "Unsupported OS for ZFS snapshot removal!"
  fi
}

function RemoveBTRFS {
  if [[ ${CR} -eq 0 ]]; then
    # find snaps and pie them to xargs to be fed into btrfs subvolume delete
    find "${BASEP}/${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | grep -v quick | xargs -I {} btrfs subvolume delete ${BASEP}/${SSDIR}/{} 2>&1 >/dev/null
  else
    find "${BASEP}/${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | grep -v quick | xargs -I {} btrfs subvolume delete -c ${BASEP}/${SSDIR}/{} 2>&1 >/dev/null
  fi
}

function TakeSnapZFS {
  if [ ! -d "${BASEP}${SSDIRZFS}${D}" ]; then
    # generate snapshot
    zfs snapshot "${POOL}@${D}" 2>&1 >/dev/null
    if [[ $? -eq 0 ]]; then
      echo "Subvolume snapshot taken: ${BASEP}"
    else
      echo "Error: Snapshot failed on partition: ${BASEP}!"
    fi
    if [ $RO -eq 1 ]; then
      echo "Setting RO not supported on zfs!"
    fi
  else
    echo "Already snapped today. Hint: Try -r to override."
    echo "Use -h for help."
    exit 1
  fi
}

function TakeSnapBTRFS {
  if [ ! -d "${BASEP}${SSDIR}${D}" ]; then
    # generate snapshot
    btrfs subvolume snapshot ${BASEP} "${BASEP}${SSDIR}${D}" 2>&1 >/dev/null
    if [[ $? -eq 0 ]]; then
      echo "Subvolume snapshot taken: ${BASEP}"
    else
      echo "Error: Snapshot failed on partition: ${BASEP}!"
    fi
    if [ $RO -eq 1 ]; then
      # set the snapshot read-only
      SetRO
    fi
  else
    echo "Already snapped today. Hint: Try -r to override."
    echo "Use -h for help."
    exit 1
  fi
}

function SetRO {
  btrfs property set "${BASEP}${SSDIR}${D}" ro true 2>&1 >/dev/null
  if [[ $? -eq 0 ]]; then
    echo "Snapshot set as read-only."
  else
    echo "Warning: Failed to set snapshot as read-only!"
  fi
}

function RedoRemoveZFS {
  if [[ ${REDO} -eq 1 ]]; then
    echo "Checking if there is a snapshot from today that needs removing before we can continue..."
    # find the zfs pool name
    POOL=$(df /${BASEP} | cut -d ' ' -f 1 | grep -v Filesystem)
    if [ -d "/${BASEP}${SSDIRZFS}${D}" ]; then
      zfs destroy "${POOL}@${D}" 2>&1 >/dev/null # remove todays snapshot
      if [[ $? -eq 0 ]]; then
        echo "Successfully removed todays snapshot."
      else
        echo "Failed to remove todays snapshot. Cannot continue."
        exit 1
      fi
    else
      echo "There was no snapshot from today to remove..."
    fi
  fi
}

function RedoRemoveBTRFS {
  if [[ ${REDO} -eq 1 ]]; then
    echo "Checking if there is a snapshot from today that needs removing before we can continue..."
    if [ -d "${BASEP}${SSDIR}${D}" ]; then
      if [[ ${CR} -eq 0 ]]; then
        btrfs subvolume delete "${BASEP}${SSDIR}${D}" 2>&1 >/dev/null # remove todays snapshot
        if [[ $? -eq 0 ]]; then
          echo "Successfully removed todays snapshot."
        else
          echo "Failed to remove todays snapshot. Cannot continue."
          exit 1
        fi
      else
        btrfs subvolume delete -c "${BASEP}${SSDIR}${D}" 2>&1 >/dev/null # remove todays snapshot
        if [[ $? -eq 0 ]]; then
          echo "Successfully removed todays snapshot."
        else
          echo "Failed to remove todays snapshot. Cannot continue."
          exit 1
        fi
      fi
    else
      echo "There was no snapshot from today to remove..."
    fi
  fi
}

function banner {
  echo "ButterScotch ${VER}, (c) 2025 oxasploits, llc."
  echo "Designed by oxagast / Marshall Whittaker."
  echo
}

if [[ $# -eq 0 ]]; then
  help
  echo "An argument is required."
  exit 1
fi
# Check if btrfs is installed
if [[ $(which btrfs) == "" && $(which zfs) == "" ]]; then
  echo "This program requires the 'btrfs' or 'zfs' command(s) to be installed and"
  echo "in your PATH!"
  echo "Use -h for help."
  exit 1
fi
# generates date
D=$(date +snap-%d-%m-%Y)
while getopts "hVlap:d:rPUywcqL:" OPTS; do
  case ${OPTS} in
  h) # display Help
    help
    exit 1
    ;;
  d) # how many to leave total
    LEAVEN=${OPTARG}
    ;;
  y) # assume yes to prompts
    YES=1
    ;;
  a) # all partitions
    # grep mount for btrfs or zfs and filter out unwanted
    # mounts then retrieve mount points to make -p compatible
    PTNSTR=$(mount | grep "btrfs\|zfs" | grep -v crash | grep -v audit | grep -v tmp | grep -v mail | cut -d ' ' -f 3 | tr '\n' ':')
    ASET=1
    ;;
  l) # list snapshots
    PTNSTR=$(mount | grep "btrfs\|zfs" | grep -v crash | grep -v audit | grep -v tmp | grep -v mail | cut -d ' ' -f 3 | tr '\n' ':')
    LIST=1
    ;;
  L) # location
    SSDIR=${OPTARG}
    SSDIRBTR=${OPTARG}
    ;;
  r) # if we need to remove todays snapshot first (using this
    # too much is hard on your disk!)
    REDO=1 ;;
  p) # the partitions string
    PTNSTR=${OPTARG}
    PSET=1
    ;;
  U) # unsupported OS override
    UNSUPPPORTED=1
    ;;
  V) # version string
    echo "Version: ${VER}"
    exit 0
    ;;
  c) # commit removes
    CR=1
    ;;
  w) # read-only fs
    RO=1
    ;;
  P) # purge all snapshots
    PURGE=1
    ;;
  q) # quicsnap
    if [[ $(uname -s) == "Linux" ]]; then
      echo "Quick snapshot selected. Snapshots will be saved as snap-quick."
      PTNSTR=$(mount | grep btrfs | cut -d ' ' -f 3 | tr '\n' ':')
      QUICK=1
      ASET=1
      REDO=1
    else
      echo "Quicksnap only works in Linux!"
      exit 1
    fi
    ;;
  \?) # invalid opt
    echo "ButterScotch ${VER}, (c) 2025 oxasploits, llc."
    echo "Designed by oxagast / Marshall Whittaker."
    echo "Error: Invalid option"
    echo "Use -h for help."
    help
    exit 1
    ;;
  esac
done
if [[ $(id -u) -ne 0 ]]; then
  echo "This program needs to be run as root!"
  echo "Use -h for help."
  exit 1
fi
# check if ${SSDIR} both begins and ends with a '/' char
if [[ ${SSDIR:0:1} != "/" || ${SSDIR: -1} != "/" ]]; then
  echo "The -L parameter must begin and end with a / character!"
  exit 1
fi
# make sure a mount point is specified by ensuring there is at least one '/' in the string
if [[ ${PTNSTR} != *"/"* ]]; then
  echo "You need to specify a mount point (directory) for this to work!  Hint: -p"
  echo "Use -h for help."
  exit 1
fi
if [[ ${ASET} -eq 1 ]] && [[ ${PSET} -eq 1 ]]; then
  echo "The -a and -p option are incompatible!"
  echo "Use -h for help."
  exit 1
fi
if [[ ${UNSUPPORTED} -ne 1 ]]; then
  if [[ $(uname -s) != "FreeBSD" ]] && [[ $(uname -s) != "Linux" ]]; then
    echo "This operating system has not been tested with ButterScotch!"
    echo "Haulting here to avoid any potential issues... use -U to override!"
    exit 1
  fi
fi
if [[ ${PTNSTR} == "" ]]; then
  echo "You need to specify at least one partition to snapshot.  Multiple snapshots are split by a colon (:)."
  echo "Use -h for help."
  exit 1
fi
if [[ ${LIST} -eq 1 ]]; then
  ListSnaps
  exit 0
fi
# so our seperator can be : instead of newline
# temporarily
IFS=':'
read -a PTN <<<"${PTNSTR}"
if [[ ${LEAVEN} -lt 1 ]] && [[ ${PURGE} -eq 0 ]]; then
  echo "You should leave at least one (1) backup snapshot!"
  echo "Use -h for help."
  exit 1
fi
IFS=' '
for BASEP in "${PTN[@]}"; do
  if [[ ${QUICK} -eq 1 ]]; then
    D="snap-quick"
  fi
  if [[ ${PURGE} -eq 1 ]]; then
    echo "Purging all snapshots found in partition: ${BASEP}"
    if [[ ${YES} -eq 1 ]]; then
      REPLY="y"
    else
      read -p "Are you sure? (y/n): " -n 1 -r REPLY
      echo
    fi
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      echo "Not confirmed, not removing..."
    else
      if [[ $(df -T | awk '{print $2}' | grep -v Type | grep zfs | wc -l) -ge 1 ]]; then
        SSDIR=${SSDIRZFS}
        # set LEAVEN 0 to remove all snapshots
        LEAVEN=0
        RemoveZFS
      fi
      if [[ $(df -T | awk '{print $2}' | grep -v Type | grep btrfs | wc -l) -ge 1 ]]; then
        SSDIR=${SSDIRBTR}
        LEAVEN=0
        # well still need the directory to be there
        CreateDir
        RemoveBTRFS
      fi
    fi
  fi
  if [[ ${PURGE} -ne 1 ]]; then
    # removes any snapshots older than x days while leaving at least y snapshots
    if [[ $(df -T | awk '{print $2}' | grep -v Type | grep zfs | wc -l) -ge 1 ]]; then
      SSDIR=${SSDIRZFS}
      RemoveZFS
      RedoRemoveZFS
      TakeSnapZFS
      ((TAKEN++))
    fi
    if [[ $(df -T | awk '{print $2}' | grep -v Type | grep btrfs | wc -l) -ge 1 ]]; then
      SSDIR=${SSDIRBTR}
      CreateDir
      RemoveBTRFS
      RedoRemoveBTRFS
      TakeSnapBTRFS # loop back around for next partition
      ((TAKEN++))
    fi
  fi
  # unless the snapshot already exists
done
if [[ $TAKEN -ge 1 ]]; then
  echo "Finished taking ${TAKEN} snapshot(s)!"
else
  if [[ ${PURGE} -ne 1 ]]; then
    echo "Error: Could not find any filesystems to snapshot..."
    exit 1
  fi
fi
# now we're done
