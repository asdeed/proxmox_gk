#!/usr/bin/env bash
#
# Author : Alexandre JAN
# website : https://asded.fr
# Created : 18/12/2023
# Version : 0.1
# License : GPL-3.0 (GNU General Public License v3.0)
#
# This file is a part of PGK.
#
# PGK is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# PGK is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with PGK.  If not, see <http://www.gnu.org/licenses/>.

##########################################################################################################
# FUNCTIONS (VMID/NET)                                                                     
##########################################################################################################

next_available_vmid() {
  qm_ids=$(qm list | awk '{print $1}')
  pct_ids=$(pct list | awk '{print $1}')
  for (( i=100; i<=9999; i++ )); do
    if ! echo "$qm_ids" | grep -q -w "$i" && ! echo "$pct_ids" | grep -q -w "$i"; then
      GS_VMID="$i"
      return
    fi
  done
  msg_error "No available virtual machine ID found in the range 100 to 9999"
}

check_vmid_list() {
  # Get vmid list
  qm_ids=$(qm list | awk '{print $1}')
  pct_ids=$(pct list | awk '{print $1}')

  # convert array
  IFS=',' read -r -a vmid_list <<< "$GS_VMID"

# check vmid availability
  is_vmid_available() {
    local vmid=$1
    if echo "$qm_ids" | grep -q -w "$vmid" || echo "$pct_ids" | grep -q -w "$vmid"; then
      return 1 # ID no available
    else
      return 0 # ID available
    fi
  }

  # check vmid list
  all_vmid_available=true
  for vmid in "${vmid_list[@]}"; do
    if ! is_vmid_available "$vmid"; then
      all_vmid_available=false
      msg_error "ID $vmid not available in specified range"
      exit 1
    fi
  done

  if $all_vmid_available; then
    msg_info "All CTID/VMIDs on your range are available: ${vmid_list[*]}"
    return
  fi
}

expand_range() {
    IFS='-' read -r start end <<< "$1"
    for ((i=start; i<=end; i++)); do
        echo $i
    done
}

# Process vmid input
process_vmid_list() {
  local vmids=("${1//,/ }")
  local expanded_vmids=()
    for vmid in "${vmids[@]}"; do
      if [[ $vmid == *-* ]]; then
        # extend range
        expanded_vmids+=( "$(expand_range "$vmid")" )
      else
        expanded_vmids+=( "$vmid" )
      fi
    done
  echo "${expanded_vmids[@]}"
}

process_network_list() {
    if [ "$GS_NETCONF" == "dhcp" ]; then
      echo "dhcp"
      return
    fi

    local expanded_networks=()
    IFS=',' read -ra networks <<< "$1"

    for network in "${networks[@]}"; do
        if [[ $network =~ ^([0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3})$ ]]; then
            expanded_networks+=("$network")
        else
            IFS='.' read -ra parts <<< "$network"
            new_ip=${parts[-1]}
            last_ip="${expanded_networks[-1]}"
            trimmed_last_ip=${last_ip%.*}
            new_network="${trimmed_last_ip}.${new_ip}"
            expanded_networks+=("$new_network")
        fi
    done
    echo "${expanded_networks[@]}"
}
