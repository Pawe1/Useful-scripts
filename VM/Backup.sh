#!/bin/bash
##

## Destination of backup files
## Script won't run if directory doesn't exist, and please note that this runs with a normal
## users privileges, so the $BACKUPDEST must be writable by the user running the VM.
BACKUPDEST="/backup"

## How many days a compressed version will be left on server
## Use for example "+30" for files older than 30 days
DAYS_TO_KEEP_TAR="+30"

## Exempt VMs - Place each VM with a space seperating them
## Example:    ( linux winxp win7 ) or
##         ( "Ubuntu 8.04" "Windows XP" ) or
##         ( None )
## More here: http://www.cyberciti.biz/faq/bash-for-loop-array/
## Run Command to find list of VMS:
## VBoxManage list vms | grep '"' | cut -d'"' -f2 2>/dev/null
EXEMPTION_ARRAY=( "Ubugit" "oracle" "Oracle_2013")

## No need to modify
HOST=`hostname`
DATEFILE=`/bin/date +%G-%m-%d`
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
   echo
   ## Check to see if BACKUPDEST exist
   if [ ! -d ${BACKUPDEST} ]; then
      echo "BACKUPDEST does not exist!! Exiting Program."
      exit 0
   fi
   ## If the archives directory does not  exist, create it
   if [ ! -d ${BACKUPDEST}/archives ]; then
      echo "${BACKUPDEST}/archives does not exist, creating . . ."
      mkdir "${BACKUPDEST}/archives"
      echo
   fi
   ## If the directories directory does not exist, create it
   if [ ! -d ${BACKUPDEST}/directories ]; then
      echo "${BACKUPDEST}/directories does not exist, creating . . ."
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
      VBoxManage controlvm ${VM} savestate
      echo "${VM} Suspended on `date`"
      echo
   else
      echo "${VM} was not suspended, not suspending - `date`"
      echo
    fi
}

##
## Backup VM
##
function doBackup {
   ## Display location of XML file
   XMLFILE=`VBoxManage showvminfo "${VM}" --machinereadable | grep "^\(CfgFile=\)" | cut -d'"' -f2 2>/dev/null`
   ## Display location of vdi file
   LOCATION=`VBoxManage showvminfo "${VM}" --machinereadable | grep ".vdi" | cut -d'"' -f4 2>/dev/null`
   
   ## If the directories directory does not exist, create it
   if [ ! -d ${BACKUPDEST}/directories/${VM} ]; then
      echo "${BACKUPDEST}/directories/${VM} does not exist, creating . . ."
      mkdir "${BACKUPDEST}/directories/${VM}"
      echo
   fi
   ## Backup VM (clonehd)
   echo "Backuping up "${VM}" to ${BACKUPDEST}/directories/${VM}/"
   rsync -aP --stats "${XMLFILE}" "${BACKUPDEST}/directories/${VM}/"
   rsync -aP --stats "${LOCATION}" "${BACKUPDEST}/directories/${VM}/"
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
   else
      echo "${VM} was not running, not resuming - `date`"
   fi
   echo
}

##
## Making a compressed and mobile backup
##
## If pv (sudo apt-get install pv) is installed then progress bar will show
##
function doTar {
   fileName="backup_${VM}-${DATEFILE}.tgz"   
   echo "taring up ${VM} to ${BACKUPDEST}/archives/${fileName}"
   if which pv >/dev/null; then
      cd "${BACKUPDEST}/directories/${VM}/"
      tar -cf - . \
      | pv -s $(du -sb . \
      | awk '{print $1}') | gzip > "${BACKUPDEST}/archives/${fileName}"
   else   
      tar -cf "${BACKUPDEST}/archives/${fileName}" -C "${BACKUPDEST}/directories/${VM}"
   fi
   echo
}

##
## Clean up any tars and logs that are older than DAYS_TO_KEEP_TAR
##
function doClean {
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
      sleep 5   ## bylo 3
   ## Do Backup
      doBackup
   ## Start if suspended
      doStart
   ## Compressing backup
      doTar
      sleep 5   ## bylo 3
   ## Clean old backups
      doClean
      sleep 5   ## bylo 3
      finishScript
   fi
## Reset exemption
   shift
done | tee "${BACKUPDEST}/${DATEFILE}-log"

#################################################################