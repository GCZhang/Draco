#!/bin/bash

# Use:
# - Call from crontab using
#   <path>/regression-master.sh <build_type> <extra_params>

##---------------------------------------------------------------------------##
## Environment
##---------------------------------------------------------------------------##

# Enable job control
set -m

##---------------------------------------------------------------------------##
## Support functions
##---------------------------------------------------------------------------##
print_use()
{
    echo " "
    echo "Usage: $0 <build_type> [extra_params]"
    echo " "
    echo "   <build_type>   = { Debug, Release }."
    echo "   [extra_params] = { intel14, pgi, coverage, cuda,"
    echo "                      fulldiagnostics, nr }."
    echo " "
    echo "Extra parameters read from environment:"
    echo "   ENV{dashboard_type} = {Nightly, Experimental}"
    echo "   ENV{base_dir}       = {/var/tmp/$USER/cdash, /scratch/$USER/cdash}"
    echo "   ENV{regdir}         = {/home/regress, /home/$USER}"
}

fn_exists()
{
    type $1 2>/dev/null | grep -q 'is a function'
    res=$?
    echo $res
    return $res
}

##---------------------------------------------------------------------------##
## Main
##---------------------------------------------------------------------------##

# Defaults
if test "${dashboard_type}x" = "x"; then
    export dashboard_type=Nightly
fi

# Arguments
case $# in
1 )
    export build_type=$1
    export extra_params=""
;;
2 )
    export build_type=$1
    export extra_params=$2
;;
* )
    echo "FATAL ERROR: Wrong number of arguments provided to regression-master.sh."
    print_use
    exit 1
    ;; 
esac

# Build everything as the default action
projects="draco"

# Host based variables
export host=`uname -n | sed -e 's/[.].*//g'`

case ${host} in
ct-*)
    machine_name_long=Cielito
    machine_name_short=ct
    export regdir=/usr/projects/jayenne/regress
    # 
    ;;
ml-*)
    machine_name_long=Moonlight
    machine_name_short=ml
    result=`fn_exists module`
    if test $result -eq 0; then 
        echo 'module function is defined'
    else
        echo 'module function does not exist. defining a local function ...'
        source /usr/share/Modules/init/bash
    fi
    module purge
    export regdir=/usr/projects/jayenne/regress
    ;;
ccscs[0-9])
    machine_name_long="Linux64 on CCS LAN"
    machine_name_short=ccscs
    if ! test -d "${regdir}/draco/regression"; then
       export regdir=/home/regress
    fi
    ;;
*)
    echo "FATAL ERROR: I don't know how to run regression on host = ${host}."
    print_use
    exit 1
    ;;
esac

# Banner

echo "==========================================================================="
echo "regression-master.sh: Regression for $machine_name_long"
echo "Build: ${build_type}     Extra Params: $extra_params"
date
echo "==========================================================================="
echo " "
echo "Environment:"
echo "   build_type   = ${build_type}"
echo "   extra_params = ${extra_params}"
echo "   regdir       = ${regdir}"
echo " "
echo "Optional environment:"
echo "   dashboard_type = ${dashboard_type}"
echo "   base_dir       = ${base_dir}"
echo "   regdir         = ${regdir}"
echo " "

# Sanity Checks
case ${build_type} in
"Debug" | "Release" )
    # known $build_type, continue
    ;;
*)
    echo "FATAL ERROR: unsupported build_type = ${build_type}"
    print_use
    exit 1
    ;; 
esac

case ${dashboard_type} in
Nightly | Experimental)
    # known dashboard_type, continue
    ;;
*)
    echo "FATAL ERROR: unknown dashboard_type = ${dashboard_type}"
    print_use
    exit 1
    ;;
esac

epdash="-"

# use forking to reduce total wallclock runtime, but do not fork
# when there is a dependency:
# 
# draco --> capsaicin  --\ 
#       --> jayenne     --+--> asterisk

# special cases
case $extra_params in
coverage)
    projects="draco capsaicin jayenne asterisk"
    ;;
cuda)
    # do not build capsaicin with CUDA
    projects="draco jayenne"
    ;;
fulldiagnostics)
    # do not build capsaicin or milagro with full diagnostics turned on.
    projects="draco jayenne"
    ;;
intel14)
    # also build capsaicin
    projects="draco"
    ;;
nr)
    projects="draco jayenne"
    ;;
pgi)
    # Capsaicin does not support building with PGI (lacking vendor installations!)
    projects="draco jayenne"
    ;;
*)
    #projects="draco capsaicin clubimc wedgehog milagro asterisk"
    projects="draco capsaicin jayenne asterisk"
    epdash=""
    ;;
esac

# The job launch logic spawns a job for each project immediately, but
# the *-job-launch.sh script will spin until all dependencies (jobids)
# are met.  Thus, the ml-job-launch.sh for milagro will start
# immediately, but it will not do any real work until both draco and
# clubimc have completed.

export subproj=draco
if test `echo $projects | grep $subproj | wc -l` -gt 0; then
  cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
  cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
  echo "${subproj}: $cmd"
  eval "${cmd} &"
  sleep 1
  draco_jobid=`jobs -p | sort -gr | head -n 1`
fi

export subproj=jayenne
if test `echo $projects | grep $subproj | wc -l` -gt 0; then
  # Run the *-job-launch.sh script (special for each platform).
  cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
  # Spin until $draco_jobid disappears (indicates that draco has been
  # built and installed)
  cmd+=" ${draco_jobid}"
  # Log all output.
  cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
  echo "${subproj}: $cmd"
  eval "${cmd} &"
  sleep 1
  jayenne_jobid=`jobs -p | sort -gr | head -n 1`
fi

# export subproj=clubimc
# if test `echo $projects | grep $subproj | wc -l` -gt 0; then
#   # Run the *-job-launch.sh script (special for each platform).
#   cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
#   # Spin until $draco_jobid disappears (indicates that draco has been
#   # built and installed)
#   cmd+=" ${draco_jobid}"
#   # Log all output.
#   cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
#   echo "${subproj}: $cmd"
#   eval "${cmd} &"
#   sleep 1
#   clubimc_jobid=`jobs -p | sort -gr | head -n 1`
# fi

# export subproj=wedgehog
# if test `echo $projects | grep $subproj | wc -l` -gt 0; then
#   cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
#   # Wait for clubimc regressions to finish
#   cmd+=" ${clubimc_jobid}"
#   cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
#   echo "${subproj}: $cmd"
#   eval "${cmd} &"
#   sleep 1
#   wedgehog_jobid=`jobs -p | sort -gr | head -n 1`
# fi

# export subproj=milagro
# if test `echo $projects | grep $subproj | wc -l` -gt 0; then
#   cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
#   # Wait for clubimc regressions to finish
#   cmd+=" ${clubimc_jobid}"
#   cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
#   echo "${subproj}: $cmd"
#   eval "${cmd} &"
#   sleep 1
#   milagro_jobid=`jobs -p | sort -gr | head -n 1`
# fi

export subproj=capsaicin
if test `echo $projects | grep $subproj | wc -l` -gt 0; then
  cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
  # Wait for draco regressions to finish
  cmd+=" ${draco_jobid}"
  cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
  echo "${subproj}: $cmd"
  eval "${cmd} &"
  sleep 1
  capsaicin_jobid=`jobs -p | sort -gr | head -n 1`
fi

export subproj=asterisk
if test `echo $projects | grep $subproj | wc -l` -gt 0; then
  cmd="${regdir}/draco/regression/${machine_name_short}-job-launch.sh"
  # Wait for wedgehog and capsaicin regressions to finish
  cmd+=" ${jayenne_jobid} ${capsaicin_jobid}"
  cmd+=" &> ${regdir}/logs/${machine_name_short}-${build_type}-${extra_params}${epdash}${subproj}-joblaunch.log"
  echo "${subproj}: $cmd"
  eval "${cmd} &"
  sleep 1
  asterisk_jobid=`jobs -p | sort -gr | head -n 1`
fi

# Wait for all parallel jobs to finish
while [ 1 ]; do fg 2> /dev/null; [ $? == 1 ] && break; done

# set permissions
chgrp -R draco ${regdir}/logs
chmod -R g+rwX ${regdir}/logs

echo "All done"

##---------------------------------------------------------------------------##
## End of regression-master.sh
##---------------------------------------------------------------------------##
