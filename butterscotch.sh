#!/bin/bash
# oxagast
#
LEAVEN=6 # the number of snapshots trailing
REDO=0
CR=0
RO=0
VER="v1.1.2"
SSDIR="/.snapshots/" # this is the dir under the btrfs mountpoint we should store snapshots in

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
  echo " -w       Mark read-only.                                                 Default:           off"
  echo " -L       Snapshot relative locations.  Must begin and end with '/'      Default:  /.snapshots/"
  echo " -q       Take a quicksnap. This assumes -a if not specified.            Default:           off"
  echo
}

function createdir {
  if [ ! -d "${BASEP}${SSDIR}" ]; then
    mkdir -p "${BASEP}${SSDIR}" && echo "Directory created..." || echo "Directory creation failed"
  fi
}

function oldremovezfs {
  if [[ $(uname -s) == "FreeBSD" ]]; then
    SSDIR="/.zfs/snapshot/"
    POOL=$(df /${BASEP} | cut -d ' ' -f 1 | grep -v Filesystem)
    find "/${BASEP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | ghead -n -${LEAVEN} | xargs -I {} zfs destroy "${POOL}"@"/${BASEP}${SSDIR}"{}
  else
    find "/${BASEP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | xargs -I {} zfs destroy "${POOL}"@"/${BASEP}${SSDIR}"{}
  fi
}

function oldremovebtr {
  if [[ ${CR} == 0 ]]; then
    find "/${BASEP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | xargs -I {} -d '\n' btrfs subvolume delete "/${BASEP}${SSDIR}"{}
  else
    find "/${BASEP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | xargs -I {} -d '\n' btrfs subvolume delete -c "/${BASEP}${SSDIR}"{}
  fi
}

function takesnapzfs {
  if [ ! -d "${BASEP}${SSDIR}${D}" ]; then
    # generate snapshot
    zfs snapshot "${POOL}@${D}"
    if [[ $? == 0 ]]; then
      echo "Subvolume snapshot taken: ${BASEP}."
    else
      echo "Error: Snapshot failed on partition: ${BASEP}!"
    fi
    if [ $RO == 1 ]; then
      echo "Setting RO not supported on zfs!"
    fi
  else
    help
    echo "Already snapped today. Hint: Try -r to override."
    echo "Use -h for help."
    help
    exit 1
  fi
}

function takesnapbtr {
  if [ ! -d "${BASEP}${SSDIR}${D}" ]; then
    # generate snapshot
    btrfs subvolume snapshot ${BASEP} "${BASEP}${SSDIR}${D}"
    if [[ $? == 0 ]]; then
      echo "Subvolume snapshot taken: ${BASEP}."
    else
      echo "Error: Snapshot failed on partition: ${BASEP}!"
    fi
    # fix permissions on it
    fixperms
    if [ $RO == 1 ]; then
      # set the snapshot read-only
      setro
    fi
  else
    help
    echo "Already snapped today. Hint: Try -r to override."
    echo "Use -h for help."
    help
    exit 1
  fi
}

function setro {
  btrfs property set "${BASEP}${SSDIR}${D}" ro true
  if [[ $? == 0 ]]; then
    echo "Snapshot set as read-only."
  else
    echo "Warning: Failed to set snapshot as read-only!"
  fi
}

function fixperms {
  chmod a+rx,g+rx,u=rwx,o-w "${BASEP}${SSDIR}${D}"
  if [[ $? == 0 ]]; then
    echo "Permission earliest level fixed (a+rx,g+rx,u=rwx,o-w)."
  else
    echo "Warning: Failed to fix permissions on snapshot at earliest level!"
  fi
}

function redoremovezfs {
  if [[ ${REDO} == 1 ]]; then
    SSDIR="/.zfs/snapshot/"
    echo "Checking if there is a snapshot from today that needs removing before we can continue..."
    POOL=$(df /${BASEP} | cut -d ' ' -f 1 | grep -v Filesystem)
    if [ -d "/${BASEP}${SSDIR}${D}" ]; then
      zfs destroy "${POOL}@${D}" # remove todays snapshot
      if [[ $? == 0 ]]; then
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

function redoremovebtr {
  if [[ ${REDO} == 1 ]]; then
    echo "Checking if there is a snapshot from today that needs removing before we can continue..."
    if [ -d "${BASEP}${SSDIR}${D}" ]; then
      if [[ ${CR} == 0 ]]; then
        btrfs subvolume delete "${BASEP}${SSDIR}${D}" # remove todays snapshot
        if [[ $? == 0 ]]; then
          echo "Successfully removed todays snapshot."
        else
          echo "Failed to remove todays snapshot. Cannot continue."
          exit 1
        fi
      else
        btrfs subvolume delete -c "${BASEP}${SSDIR}${D}" # remove todays snapshot
        if [[ $? == 0 ]]; then
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
  echo "This program requires the 'btrfs' command to be installed and in your PATH!"
  echo "Please install the btrfs-progs package for your distribution."
  echo "Use -h for help."
  help
  exit 1
fi
# generates date
D=$(date +snap-%d-%m-%Y)
while getopts ":hap:d:rwcqL:" OPTS; do
  case ${OPTS} in
  h) # display Help
    help
    exit 1
    ;;
  n) # how many to leave total
    LEAVEN=${OPTARG} ;;
  a) # all partitions
    PTNSTR=$(mount | grep btrfs | cut -d ' ' -f 3 | tr '\n' ':')
    ASET=1
    ;;
  L) # location
    SSDIR=${OPTARG} ;;
  r) # if we need to remove todays snapshot first (using this too much is hard on your disk!)
    REDO=1 ;;
  p) # the partitions string
    PTNSTR=${OPTARG}
    PSET=1
    ;;
  c) # commit removes
    CR=1
    ;;
  w) # read-only fs
    RO=1
    ;;
  q) # quicsnap
    echo "Quick snapshot selected. Snapshots will be saved as snap-quick."
    PTNSTR=$(mount | grep btrfs | cut -d ' ' -f 3 | tr '\n' ':')
    QUICK=1
    ASET=1
    REDO=1
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
banner
if [[ $(id -u) != 0 ]]; then
  echo "This program needs to be run as root!"
  echo "Use -h for help."
  help
  exit 1
fi
if [[ $(mount | grep btrfs | wc -l) == 0 ]]; then
  echo "No btrfs partitions seem to be mounted on this system! Please mount at least one."
  echo "Use -h for help."
  help
  exit 1
fi
# check if ${SSDIR} both begins and ends with a '/' char
if [[ ${SSDIR:0:1} != "/" || ${SSDIR: -1} != "/" ]]; then
  echo "The -L parameter must begin and end with a / character!"

  help
  exit 1
fi
if [[ ${PTNSTR} != *"/"* ]]; then
  echo "You need to specify a btrfs mount point (directory) for this to work!"
  echo "Use -h for help."
  help
  exit 1
fi
if [[ ${ASET} == 1 ]] && [[ ${PSET} == 1 ]]; then
  echo "The -a and -p option are incompatible!"
  echo "Use -h for help."
  help
  exit 1
fi
if [[ ${PTNSTR} == "" ]]; then
  echo "You need to specify at least one partition to snapshot.  Multiple snapshots are split by a colon (:)."
  echo "Use -h for help."
  help
  exit 1
fi
# so our seperator can be : instead of newline
# temporarily
IFS=':'
read -a PTN <<<"${PTNSTR}"
if [[ ${LEAVEN} < 1 ]]; then
  echo "You should leave at least one (1) backup snapshot!"
  echo "Use -h for help."
  help
  exit 1
fi
for BTRD in "${PTN[@]}"; do
  if [ ! -d "${BTRD}" ]; then
    echo "There is not a BTRFS partition mounted at: ${BTRD}."
    echo "Use -h for help."
    help
    exit 1
  fi
done
IFS=' '
for BASEP in "${PTN[@]}"; do
  # make the dir if it doesn't exist

  createdir
  if [[ ${QUICK} == 1 ]]; then
    D="snap-quick"
  fi

  # removes any snapshots older than x days while leaving at least y snapshots
  if [[ $(df -T /srv | awk '{print $2}' | grep -v Type) == "zfs" ]]; then
    oldremovezfs
    redoremovezfs
    takesnapzfs
  fi
  if [[ $(df -T /srv | awk '{print $2}' | grep -v Type) == "btrfs" ]]; then
    oldremovebtr
    redoremovebtr
    takesnapbtr # loop back around for next partition
  fi
  # unless the snapshot already exists
done
echo "Finished taking snapshots!"
# now we're done
