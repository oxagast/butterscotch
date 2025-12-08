#!/bin/bash
# oxagast
#
# these are the user definable vars defaults
LEAVEN=6 # the number of snapshots trailing the one you created that aren't deleted
REDO=0
CR=0
RO=0
VER="v1.1"
SSDIR="/.snapshots/" # this is the dir under the btrfs mountpoint we should store backups in
#
function help
{
  echo
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
  echo " -w       Mark read-only                                                 Default:           off"
  echo " -L       Snapshot locations (relative to btrfs mountpoint)              Default:  /.snapshots/"
  echo " -q       Take a quicksnap.                                              Default:           off"
  echo
}
if [[ $# -eq 0 ]]; then
  echo "ButterScotch ${VER}, (c) 2025 oxasploits, llc."
  echo "Designed by oxagast / Marshall Whittaker."
  help
  echo "The -p argument is required."
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
      CR=1 ;;
    w) # read-only fs
      RO=1 ;;
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
echo "ButterScotch ${VER}, (c) 2025 oxasploits, llc."
echo "Designed by oxagast / Marshall Whittaker."
echo
if [[ $(mount | grep btrfs | wc -l) == 0 ]]; then
  echo "No btrfs partitions seem to be mounted on this system! Please mount at least one."
  echo "Use -h for help."
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
if [[ $(id -u) != 0 ]]; then
  echo "This program needs to be run as root!"
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
for BTRFSP in "${PTN[@]}"; do
  if [ ! -d "${BTRFSP}${SSDIR}" ]; then
    mkdir -p "${BTRFSP}${SSDIR}" && echo "Directory created..." || echo "Directory creation failed"
  fi
  # removes any snapshots older than x days while leaving at least y snapshots
  if [[ ${CR} == 0 ]]; then
    find "/${BTRFSP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | xargs -I {} -d '\n' btrfs subvolume delete "/${BTRFSP}${SSDIR}"{}
  else
    find "/${BTRFSP}${SSDIR}" -maxdepth 0 -exec ls -1ctr {} \; | head -n -${LEAVEN} | xargs -I {} -d '\n' btrfs subvolume delete -c "/${BTRFSP}${SSDIR}"{}
  fi
  # check if redo is set and remove today's snap if it is
  if [[ ${QUICK} == 1 ]]; then
    #REDO=1
    D="snap-quick"
  fi

  if [[ ${REDO} == 1 ]]; then
    echo "Checking if there is a snapshot from today that needs removing before we can continue..."
    if [ -d "${BTRFSP}${SSDIR}${D}" ]; then
      if [[ ${CR} == 0 ]]; then
        btrfs subvolume delete "${BTRFSP}${SSDIR}${D}" && echo "Removed todays snapshot..." # remove todays snapshot
      else
        btrfs subvolume delete -c "${BTRFSP}${SSDIR}${D}" && echo "Removed todays snapshot..." # remove todays snapshot
      fi
    else
      echo "There was no snapshot from today to remove..."
    fi
  fi
  # unless the snapshot already exists
  if [ ! -d "${BTRFSP}${SSDIR}${D}" ]; then
    # generate snapshot
    btrfs subvolume snapshot ${BTRFSP} "${BTRFSP}${SSDIR}${D}" && echo "Subvolume snapshot taken: ${BTRFSP}."
    # fix permissions on it
    chmod a+rx,g+rx,u=rwx,o-w "${BTRFSP}${SSDIR}${D}" && echo "Permission earliest level fixed (a+rx,g+rx,u=rwx,o-w)."
    if [ $RO == 1 ]; then
      btrfs property set "${BTRFSP}${SSDIR}${D}" ro true
      echo "Snapshot set as read-only."
    fi
  else
    help
    echo "Already snapped today. Hint: Try -r to override."
    echo "Use -h for help."
    help
    exit 1
  fi
  # loop back around for next
done
# now we're done
