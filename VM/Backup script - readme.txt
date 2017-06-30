1. Dependencies
Main script to run requires installed:
  rsync (https://rsync.samba.org/)
  pv (http://www.ivarch.com/programs/pv.shtml)



2. Usage
Install for example by adding entry in crontab



3. Similar script



This script below is what I use to make backups of running Windows VMs, they are put into hibernation, then the drive is imaged, then the machine is woken back up. There is downtime with this method, but not much and it is easy to schedule as a low use-time service.


#!/bin/bash
##
## Destination of backup files
## Script won't run if directory doesn't exist, and please note that this runs with a normal
## users privileges, so the $BACKUPDEST must be writable by the user running the VM.
BACKUPDEST="/Backup/VMs/${USER}"

## How many days a compressed version will be left on server
DAYS_TO_KEEP_TAR="+7"

## Exempt VMs - Place each VM with a space seperating them
## Example: ( linux winxp win7 ) or
## ( "Ubuntu 8.04" "Windows XP" ) or
## ( None )
## More here: http://www.cyberciti.biz/faq/bash-for-loop-array/
## Run Command to find list of VMS:
## VBoxManage list vms | grep '"' | cut -d'"' -f2 2>/dev/null
EXEMPTION_ARRAY=( None )

## No need to modify below here
IFS=$'\n'
HOST=`hostname`
DATEFILE=`/bin/date +%Y%m%d`
VMLIST=`VBoxManage list vms | grep '"' | cut -d'"' -f2 2>/dev/null`

#################################################################
## Functions

##
## Notify the starting time of backup
##
function startScript {
echo "-----------------------------------------------------"
echo "START - ${VM}"
echo "Host: ${HOST}"
echo "Date: `date`"
echo "-----------------------------------------------------"
echo
}

##
## Create the backup directories if they do not exist
##
function doCheckDirectories {
## Check to see if BACKUPDEST exist
if [ ! -d ${BACKUPDEST} ]; then
echo "BACKUPDEST does not exist!! Exiting Program."
exit 0
fi
## If the archives directory does not exist, create it
if [ ! -d ${BACKUPDEST}/archives ]; then
echo "${BACKUPDEST}/archives directory does not exist, creating . . ."
mkdir "${BACKUPDEST}/archives"
echo
fi
## If the directories directory does not exist, create it
if [ ! -d ${BACKUPDEST}/directories ]; then
echo "${BACKUPDEST}/directories directory does not exist, creating . . ."
mkdir "${BACKUPDEST}/directories"
echo
fi
}

##
## If this VM is in our exempt array, set VM_EXEMPT to skip entirely.
##
function doCheckExempt {
VM_EXEMPT=false
## array, if we get a match, set VM_EXEMPT to true
for check_vm in "${EXEMPTION_ARRAY[@]}"; do
if [ "${check_vm}" = "${VM}" ]; then
echo "${VM} is on the exception list, skipping."
echo
VM_EXEMPT=true
fi
done
}

##
## Suspend VM if its running, skip it if not
##
function suspendVM {
## Check state of VM
VMSTATE=`VBoxManage showvminfo "${VM}" --machinereadable | grep "^\(VMState=\)" | cut -d'"' -f2 2>/dev/null`

echo "${VM} state is currently: ${VMSTATE}"

## If VM is running, suspend it, otherwise, move on
if [ "${VMSTATE}" = "running" ]; then
echo "Suspending ${VM} . . ."
## Stop vm by saving current state (pause|resume|reset|poweroff|savestate)
VBoxManage controlvm ${VM} savestate 2>/dev/null
[ $? ] && echo Success || echo Failure
echo "${VM} Suspended on `date`"
echo
else
echo "${VM} was not running, not suspending - `date`"
echo
fi
}

##
## Backup VM
##
function doBackup {
## Display location of XML file
XMLFILE=`VBoxManage showvminfo "${VM}" --machinereadable \
| grep "^\(CfgFile=\)" \
| cut -d'"' -f2 2>/dev/null`
## Display location of vdi file
## LOCATION=`VBoxManage showvminfo "${VM}" --machinereadable | grep ".vdi" | cut -d'"' -f4 2>/dev/null`
## Display location of vdi or vmdk file
LOCATION=`VBoxManage showvminfo "${VM}" --machinereadable \
| grep -e ".vdi" -e ".vmdk" \
| cut -d'"' -f4 2>/dev/null`

## If the directories directory does not exist, create it
if [ ! -d ${BACKUPDEST}/directories/${VM} ]; then
echo "${BACKUPDEST}/directories/${VM} does not exist, creating . . ."
mkdir "${BACKUPDEST}/directories/${VM}"
echo
fi
## Backup VM (clonehd)
echo "Backing up "${VM}" to ${BACKUPDEST}/directories/${VM}/"
rsync --inplace -a --stats "${XMLFILE}" "${BACKUPDEST}/directories/${VM}/"
[ $? ] && echo Success || echo Failure
rsync --inplace -a --stats "${LOCATION}" "${BACKUPDEST}/directories/${VM}/"
[ $? ] && echo Success || echo Failure
echo
}

##
## Start VM if suspened
##
function doStart {
if [ "${VMSTATE}" = "running" ]; then
echo "Starting ${VM} . . ."
## Resume VMs which were running [--type gui|sdl|vrdp|headless]
VBoxManage startvm ${VM} --type headless
echo "${VM} Resumed on `date`"
[ $? ] && echo Success || echo Failure
else
echo "${VM} was not running, not resuming - `date`"
fi
echo
}

##
## Making a compressed and mobile backup
##
function doTar {
fileName="backup_${VM}-${DATEFILE}.tgz"
echo "taring up ${VM} to ${BACKUPDEST}/archives/${fileName}"
tar -czf "${BACKUPDEST}/archives/${fileName}" "${BACKUPDEST}/directories/${VM}" 2>/dev/null
[ $? ] && echo Success || echo Failure
echo
}

##
## Clean up any tars or logs that are older than DAYS_TO_KEEP_TAR
##
function doCleanTar {
echo "Cleaning up tars older than ${DAYS_TO_KEEP_TAR} day(s) old"
find "${BACKUPDEST}/archives" -name "backup_${VM}*.tgz" -mtime ${DAYS_TO_KEEP_TAR} -exec rm -vf {} \;
[ $? ] && echo Success || echo Failure
echo "Cleaning up logs older than ${DAYS_TO_KEEP_TAR} day(s) old"
find "${BACKUPDEST}/" -name "*-log" -mtime ${DAYS_TO_KEEP_TAR} -exec rm -vf {} \;
[ $? ] && echo Success || echo Failure
}

##
## Notify the finishing time of backup
##
function finishScript {
echo
echo "-----------------------------------------------------"
echo "FINISH - ${VM}"
echo "Host: ${HOST}"
echo "Date: `date`"
echo "-----------------------------------------------------"
}

#################################################################
## Script

## Make sure we have the appropriate directories for backups
doCheckDirectories
## Start loop
for VM in ${VMLIST}; do
sleep 1
## Check exempt list
doCheckExempt
if [ "$VM_EXEMPT" = "false" ]; then
startScript
## Suspend VM
suspendVM
sleep 3
## Do Backup
doBackup
## Start if suspended
doStart
## Compressing backup
doTar
sleep 3
## Clean old backups
doCleanTar
sleep 3
finishScript
fi
## Reset exemption
shift
done >> ${BACKUPDEST}/${DATEFILE}-log
################################################################