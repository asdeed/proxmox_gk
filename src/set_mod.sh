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
# SET_VALUES FUNCTIONS                                                                         
##########################################################################################################

var_parser() {
  local in_qs_values=false
  while IFS=':' read -r object value; do
    if [[ "$object" == "gs_values" ]]; then
      in_qs_values=true
    elif [[ "$object" =~ ^[[:blank:]]+[A-Z_]+ ]]; then
      if $in_qs_values; then
        object=$(echo "$object" | tr -d '"' | xargs)
        value=$(echo "$value" | tr -d '"' | xargs)
        export "$object=$value"
      fi
    fi
  done <<< "$(grep -E '^gs_values:|^[[:blank:]]+[A-Z_]+:' "$yaml_file")"
}

display_shape(){
  if [[ "$1" == "kvm" ]]; then
    msg_info_inline "QEMU/KVM" 
    msg_syntax_nb " (guest_name:'$QS_NAME')"
    msg_info_inline "Qemu-agent"
    msg_syntax_nb " (value:'$QS_AGENT')"
    msg_info_inline "RAM" 
    msg_syntax_nb " (amount_memory:'$QS_MEMORY')"
    msg_info_inline "BIOS" 
    msg_syntax_nb " (bios_type:'$QS_BIOS')"
    msg_info_inline "CPU" 
    msg_syntax_nb " (cpu_type:'$QS_CPU', n_cores:'$QS_CORE')"
    msg_info_inline "Disk" 
    msg_syntax_nb " (scsi_controller:'$QS_SCSIHW', extend_space:'$QS_EXTEND')"
    msg_info_inline "Display" 
    msg_syntax_nb " (serial_port:'$QS_SOCKET', display:'$QS_VGA')"
    msg_info_inline "Network" 
    msg_syntax_nb " (device_type:'$QS_NET0', interface:'$QS_NET_ETH', bridge_set:'$GS_NETBR')"
    msg_info_inline "Network values" 
    msg_syntax_nb " (gateway:'$GS_GATE', attribute_ip:'$GS_NETCONF', cidr:'$GS_CIDR')"
    msg_info_inline "DNS/Search domain" 
    msg_syntax_nb " (DNS00:'$GS_DNS00', DNS01:'$GS_DNS01')"
    msg_info_inline "Start on boot" 
    msg_syntax_nb " (value:'$QS_ONBOOT')"
    msg_info_inline "Start immediatly after creation" 
    msg_syntax_nb " (value:'$QS_SBOOT')"
    msg_info_inline "Protection mode" 
    msg_syntax_nb " (value:'$QS_PROTECT')"
    msg_info_inline "User settings"
    msg_syntax_nb " (username:'$GS_CIUSER', ssh_authorized_keys:'$SSHKEY')"
    msg_info_inline "Timezone/Locales"
    msg_syntax_nb " (timezone:'$GS_CITZ', localization:'$GS_CILOC')"
  elif [[ "$1" == "lxc" ]]; then
    msg_info_inline "LXC" 
    msg_syntax_nb " (guest_name:'$CS_NAME')"
    msg_info_inline "RAM" 
    msg_syntax_nb " (amount_memory:'$CS_MEMORY')"
    msg_info_inline "CPU" 
    msg_syntax_nb " (cores:'$CS_CORE')"
    msg_info_inline "Disk" 
    msg_syntax_nb " (amount_storage:'$CS_SPACE')"
    msg_info_inline "Privileged mode" 
    msg_syntax_nb " (value:'$CS_PERM')"
    msg_info_inline "Enabled features"
    msg_syntax_nb " (features:'$CS_FEAT')"
    msg_info_inline "Network"
    msg_syntax_nb " (device_name:'$CS_NET_NAME', interface:'$CS_NET_ETH', bridge_set:'$GS_NETBR')"
    msg_info_inline "Network values"
    msg_syntax_nb " (gateway:'$GS_GATE', attribute_ip:'$GS_NETCONF', cidr:'$GS_CIDR')"
    msg_info_inline "DNS/Search domain" 
    msg_syntax_nb " (DNS00:'$GS_DNS00', DNS01:'$GS_DNS01')"
    msg_info_inline "Start on boot"
    msg_syntax_nb " (value:'$CS_ONBOOT')"
    msg_info_inline "Start immediatly after creation" 
    msg_syntax_nb " (value:'$CS_SBOOT')"
    msg_info_inline "Protection mode" 
    msg_syntax_nb " (value:'$CS_PROTECT')"
    msg_info_inline "User settings"
    msg_syntax_nb " (username:'$GS_CIUSER', ssh_authorized_keys:'$SSHKEY')"
    msg_info_inline "Timezone/Locales"
    msg_syntax_nb " (timezone:'$GS_CITZ', localization:'$GS_CILOC')"
  fi
}

getshape(){
  if [ -z "$2" ] && [ "$1" = "kvm" ]; then
    yaml_file="$HS_KVM_SHAPE/$(cat $HS_INDEX_KVM | jq -r --arg kvm_img "$img" '.[] | select(.kvm_img == $kvm_img) | .kvm_dshape')"
    var_parser
    msg_info "No argument provided for custom shape, default QEMU/KVM value loaded."
    display_shape kvm

  elif [ -z "$2" ] && [ "$1" = "lxc" ]; then
    yaml_file="$HS_LXC_SHAPE/$(cat $HS_INDEX_LXC | jq -r --arg lxc_img "$img" '.[] | select(.lxc_img == $lxc_img) | .lxc_dshape')"
    var_parser
    msg_info "No argument provided for custom shape, default LXC value loaded."
    display_shape lxc

  elif [ -f "$HS_KVM_SHAPE/$2" ]; then
    yaml_file="$HS_KVM_SHAPE/$2"
    var_parser
    msg_ok "The QEMU/KVM values have been successfully imported from $2"
    display_shape kvm

  elif [ -f "$HS_LXC_SHAPE/$2" ]; then
    yaml_file="$HS_LXC_SHAPE/$2"
    var_parser
    msg_ok "The LXC values have been successfully imported from $2"
    display_shape lxc

  else
    msg_error "Error: The shape file $2 does not exist in the specified path: $HS_PATH_SHAPE"
    exit 1
  fi
}

qm_getdistrib(){
  available_images=$(kvm_index name)
  mapfile -t local_images < <(find "$HS_CIIMG" -type f)

  found=false

  # check local list
  for local_image in "${local_images[@]}"; do
      if [[ $(grep -i "$1" <<< "$local_image") ]]; then
          img=$(grep -i "$1" <<< "$available_images" | head -n 1)
          if [ -f "$HS_CIIMG/$img" ]; then
            found=true 
          else 
            found=false
          fi
          break
      fi
  done

if [ "$found" = false ]; then
    if [[ $(grep -i "$1" <<< "$available_images") ]]; then
        img=$(grep -i "$1" <<< "$available_images" | head -n 1)
        url=$(kvm_index index | grep "$img" | sed 's/.*- //')
        call_url=$(curl -s --head "$url"| head -n 1)
          if [[ "$call_url" =~ 20 || "$call_url" =~ 30 ]]; then
            msg_inline "$img"
            msg_info " image not available on local storage, process downloading ..."
            curl -o "$HS_CIIMG/$img" "$url" &>/dev/null & PID=$!
            pb_dlimg "$HS_CIIMG" "$url" "$PID"
            msg_ok "Download complete !"
          else
            msg_error "Image $img not available on remote repository"
            exit 1
          fi
    else
      msg_error "QEMU image $1 not exist"
      exit 1
    fi
else
    msg_inline "$img"
    msg_ok " image available"
fi
}

lxc_getdistrib(){
  #available_templates=$(pveam available --section system | awk '{print $2}')
  available_templates=$(lxc_index name)
  mapfile -t local_templates < <(pveam list local | awk '{print $1}' | sed 1d)

  found=false

  # check local list
  for local_template in "${local_templates[@]}"; do
      if [[ $(grep -i "$1" <<< "$local_template") ]]; then
          img=$(grep -i "$1" <<< "$available_templates" | head -n 1)
          if [ -f "$HS_LXCIMG/$img" ]; then
            found=true 
          else 
            found=false
          fi
          break
      fi
  done

if [ "$found" = false ]; then
    if [[ $(grep -i "$1" <<< "$available_templates") ]]; then
        img=$(grep -i "$1" <<< "$available_templates" | head -n 1)
        url=$(lxc_index index | grep "$img" | sed 's/.*- //')
        call_url=$(curl -s --head "$url"| head -n 1)
          if [[ "$call_url" =~ 20 || "$call_url" =~ 30 ]]; then
            msg_inline "$img"
            msg_info " image not available on local storage, process downloading ..."
            curl -o "$HS_LXCIMG/$img" "$url" &>/dev/null & PID=$!
            pb_dlimg "$HS_LXCIMG" "$url" "$PID"
            msg_ok "Download complete !"
          else
            msg_error "Template $img not available on remote repository"
            exit 1
          fi
    else
      msg_error "LXC template $1 not exist"
      exit 1
    fi
else
    msg_inline "$img"
    msg_ok " template available"
fi
}