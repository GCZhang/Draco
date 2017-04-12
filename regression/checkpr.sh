#!/bin/bash
##---------------------------------------------------------------------------##
## File  : regression/checkpr.sh
## Date  : Wednesday, Mar 22, 2017, 16:01 pm
## Author: Kelly Thompson <kgt@lanl.gov>
## Note  : Copyright (C) 2017, Los Alamos National Security, LLC.
##         All rights are reserved.
##---------------------------------------------------------------------------##

# Use:
#   <path>/checkpr.sh [options]
#
# Options:
#   -p <project>  - project name, {draco, jayenne, capasaicin}
#   -f <number>   - pr number
#   -h            - help message
#   -r            - special run mode that uses the regress account's
#                   credentials.
#
# <number> must be an integer value that represents the pull request.

##---------------------------------------------------------------------------##
## Environment
##---------------------------------------------------------------------------##

# Enable job control
set -m

# load some common bash functions
export rscriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [[ -f $rscriptdir/scripts/common.sh ]]; then
  source $rscriptdir/scripts/common.sh
else
  echo " "
  echo "FATAL ERROR: Unable to locate Draco's bash functions: "
  echo "   looking for .../regression/scripts/common.sh"
  echo "   searched rscriptdir = $rscriptdir"
  exit 1
fi

# defaults
export target=`uname -n | sed -e 's/[.].*//g'`
scratchdir=`selectscratchdir`
export regdir="$scratchdir/$USER"
export logdir="$HOME/logs"
pr=develop
project=draco
regress_mode="off"

if ! [[ -d $logdir ]]; then
  run "mkdir -p $logdir"
fi

##---------------------------------------------------------------------------##
## Support functions
##---------------------------------------------------------------------------##

print_use()
{
  echo " "
  echo "Usage: ${0##*/} -h -p [draco|jayenne|capsaicin]"
  echo "       -f <git branch name> -r"
  echo " "
  echo "All arguments are optional,  The first value listed is the default value."
  echo "   -h    help           prints this message and exits."
  echo "   -f    git feature branch, default=develop"
  echo "         common: 'develop', '42'"
  echo "   -p    project name = { draco, jayenne, capsaicin }"
  echo "   -r    special run mode that uses the regress account's credentials."
  echo " "
  echo "Examples:"
  echo "  ${0##*/} -p jayenne -f 42"
  echo "  ${0##*/} -p draco"
  echo "  ${0##*/} -p capsaicin -f develop"
  echo " "
}

##---------------------------------------------------------------------------##
## Command options
##---------------------------------------------------------------------------##

while getopts ":f:hp:" opt; do
case $opt in
f)  pr=$OPTARG ;;
h)  print_use; exit 0 ;;
p)  project=$OPTARG ;;
r)  regress_mode="on" ;;
\?) echo "" ;echo "invalid option: -$OPTARG"; print_use; exit 1 ;;
:)  echo "" ;echo "option -$OPTARG requires an argument."; print_use; exit 1 ;;
esac
done

##---------------------------------------------------------------------------##
## Sanity Checks for input
##---------------------------------------------------------------------------##

case $project in
  draco | jayenne | capsaicin ) # known projects, continue
    ;;
  *)  echo "" ;echo "FATAL ERROR: unknown project name (-p) = ${proj}"
    print_use; exit 1 ;;
esac

if [[ $regress_mode == "on" ]]; then
  if ! [[ $LOGNAME == "kellyt" ]]; then
    echo ""; echo "FATAL ERROR: invalid use of -r"
    print_use; exit 1
  fi
fi
export regress_mode

#------------------------------------------------------------------------------#
# Banner
#------------------------------------------------------------------------------#

echo "Starting checkpr.sh $@ ..."
echo "   project      = $project"
echo "   pr           = $pr"
echo "   target       = $target"
echo "   scratchdir   = $scratchdir"
echo "   regdir       = $regdir"
echo "   logdir       = $logdir"
echo "   rscriptdir   = $rscriptdir"
echo "   regress_mode = $regress_mode"

#------------------------------------------------------------------------------#
# Kick of a regregression
#------------------------------------------------------------------------------#

function startCI()
{
  local project=$1
  local build_type=$2
  local extra=$3
  local pr=$4
  if ! [[ ${pr} == "develop" ]]; then
    pr=pr${pr}
  fi
  if [[ ${extra} == 'na' ]]; then
    extra=""
    edash=""
    eflag=""
  else
    extrastring="(${extra}) "
    edash="-"
    eflag="-e"
  fi
  if [[ ${regress_mode} == "on" ]]; then
    rflag="-r"
  fi

  logfile=${logdir}/${machine_name_short}-${project}-${build_type}${edash}${extra}-master-${pr}.log
  allow_file_to_age $logfile 600
  echo " "
  echo "- Starting CI regression ${extrastring}for ${pr}."
  echo "  Log: $logfile"
  echo " "
  cmd="$rscriptdir/regression-master.sh ${rflag} -b ${build_type}"
  cmd="$cmd ${eflag} ${extra} -p ${project} -f ${pr} &> $logfile"
  echo "$cmd"
  eval "$cmd"
}

#------------------------------------------------------------------------------#
# Prepare for Jayenne/Capsaicin
# Do we need to build/install a new draco-develop to link against?
#------------------------------------------------------------------------------#

case $target in
  ccscs*) machine_name_short=ccscs ;;
  ml*) machine_name_short=ml ;;
  sn*) machine_name_short=sn ;;
  tt*) machine_name_short=tt ;;
  darwin*) machine_name_short=darwin ;;
esac

case $project in
  jayenne|capsaicin)
    # Do we need to build draco? Only build draco-develop once per day.
    eval "$(date +'today=%F now=%s')"
    midnight=$(date -d "$today 0" +%s)
    draco_tag_file=$logdir/last-draco-develop-${machine_name_short}.log
    draco_last_built=$(date +%s -r $draco_tag_file)
    build_draco=0
    if [[ $midnight -gt $draco_last_built ]]; then
      echo " "
      echo "Found a Jayenne or Capsaicin PR, but we need to build draco-develop first..."
      echo " "

      # Call this script recursively to build the draco 'develop' branch.
      $rscriptdir/checkpr.sh draco

      # Reset the modified date on the file used to determine when draco was
      # last built.
      date &> $draco_tag_file
    fi
    ;;
esac

#------------------------------------------------------------------------------#
# Process the build.
#------------------------------------------------------------------------------#

echo " "
case $target in
  # CCS-NET: Coverage (Debug) & Valgrind (Debug)
  ccscs*)
    startCI ${project} Debug coverage $pr
    startCI ${project} Debug valgrind $pr
    ;;

  # Moonlight: Fulldiagnostics (Debug)
  ml-fey*) startCI ${project} Debug fulldiagnostics $pr ;;

  # Snow: Debug
  sn-fe*) startCI ${project} Debug na $pr ;;

  # Trinitite: Release
  tt-fe*) startCI ${project} Release na $pr ;;

  # Darwin: Disabled
  darwin-fe*)
    # startCI ${project} Release na $pr
    ;;

  *) echo "Unknown target machine: target = $target" ; exit 1 ;;

esac

# Wait for all subprocesses to finish before exiting this script
if [[ `jobs -p | wc -l` -gt 0 ]]; then
  echo " "
  echo "Jobs still running (if any):"
  for job in `jobs -p`; do
    echo "  waiting for job $job to finish..."
    wait $job
    echo "  waiting for job $job to finish...done"
  done
fi

echo " "
echo "All done."

#------------------------------------------------------------------------------#
# end checkpr.sh
#------------------------------------------------------------------------------#