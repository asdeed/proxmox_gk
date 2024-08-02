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
# MAKE GUESTS QEMU                                                                          
##########################################################################################################

guest_qm_init() {
  msg_info "Make canevas for guest"
  # setup configuration QEMU
  declare -A slug_serv

  ## process entry
  read -ra vmid_array <<< "$(process_vmid_list "$GS_VMID")"
  read -ra network_array <<< "$(process_network_list "$GS_NETCONF")"

  # checking array
  if [ ${#vmid_array[@]} -ne ${#network_array[@]} ]; then
    msg_error "Error: The number of VMIDs does not match the number of IP addresses."
    exit 1
  fi

  ## create association array
  for ((i=0; i<${#vmid_array[@]}; i++)); do
    slug_serv[${vmid_array[$i]}]=${network_array[$i]}
  done

  ## display association array
    for key in "${!slug_serv[@]}"; do
      echo "ID $key => ${slug_serv[$key]}"

  ## VMID check for both QEMU machines and LXC containers
    if qm list | awk '{print $1}' | grep -Eq "^$key\$" || pct list | awk '{print $1}' | grep -Eq "^$key\$"; then
      msg_error "ID $key is already in use by a QEMU Machine or an LXC container."
      exit 1
    else
      msg_ok "ID $key is available."
    fi

  if [ "${QS_BIOS}" == "seabios" ]; then
    log_command "DEBUG-QEMU_BUILD" "qm create $key \
      --name $QS_NAME-$key \
      --agent $QS_AGENT \
      --memory $QS_MEMORY \
      --bios $QS_BIOS \
      --sockets 1 \
      --cores $QS_CORE \
      --cpu $QS_CPU \
      --net0 $QS_NET0,bridge=$GS_NETBR \
      --scsihw $QS_SCSIHW \
      --boot order=scsi0 \
      --onboot $QS_ONBOOT \
      --ide0 $HS_LOCALVM:cloudinit \
      --protection $QS_PROTECT \
      --serial0 $QS_SOCKET \
      --vga $QS_VGA" >/dev/null

  elif [ "${QS_BIOS}" == "ovmf" ]; then

    log_command "DEBUG-QEMU_BUILD" "qm create $key \
      --name $QS_NAME-$key \
      --agent $QS_AGENT \
      --memory $QS_MEMORY \
      --bios $QS_BIOS \
      --sockets 1 \
      --cores $QS_CORE \
      --cpu $QS_CPU \
      --net0 $QS_NET0,bridge=$GS_NETBR \
      --scsihw $QS_SCSIHW \
      --boot order=scsi0 \
      --onboot $QS_ONBOOT \
      --efidisk0 $HS_LOCALVM:0 \
      --ide0 $HS_LOCALVM:cloudinit \
      --protection $QS_PROTECT \
      --machine q35 \
      --serial0 $QS_SOCKET \
      --vga $QS_VGA" >/dev/null

  else
    msg_error "Unsupported BIOS type: ${QS_BIOS}"
    exit 1
  fi

  guest_qm_ipconfig
  guest_qm_importimg
  guest_qm_resizeimg
  guest_qm_ciconf
  guest_qm_extrasettings
  guest_qm_fingerprint
  guest_qm_sboot
done
}

guest_qm_ipconfig(){
  #### IP attribution
    if [ "$GS_NETCONF" == "dhcp" ]; then
      qm set "$key" --ipconfig"$QS_NET_ETH" ip=dhcp >/dev/null
      qm set "$key" --nameserver "$GS_DNS00 $GS_DNS01"  >/dev/null
#     TODO qm set "$key" --searchdomain "local" >/dev/null
    else
      qm set "$key" --ipconfig"$QS_NET_ETH" ip="${slug_serv[$key]}/$GS_CIDR,gw=$GS_GATE" >/dev/null
      qm set "$key" --nameserver "$GS_DNS00 $GS_DNS01"  >/dev/null
#     TODO qm set "$key" --searchdomain "local" >/dev/null
    fi  
}

guest_qm_importimg(){
  ### Import cloud img 
    if [[ $img == *qcow2* ]]; then
      fimg="qcow2"
    elif [[ $img == *raw* ]]; then
      fimg="raw"
    elif [[ $img == *qcow* ]]; then
      fimg="qcow"
    else
      msg_info "Unable to determine image format for $img."
      #msg_info "Processing import $img without image check"
      qm set "$key" --scsi0 "$HS_LOCALVM":0,import-from="$HS_CIIMG"/"$img" >/dev/null & PID=$! 
      spin $PID  "Processing import $img without image check ..." "Import complete !" 
      return
    fi
  #### Check image & import
    if ! qemu-img check -f $fimg "$HS_CIIMG/$img" >/dev/null; then
      msg_error "Error checking image $img."
      exit 1
    else
      msg_ok "$img image check completed successfully."
      #msg_info "Processing import $img"
      qm set "$key" --scsi0 "$HS_LOCALVM":0,import-from="$HS_CIIMG"/"$img" >/dev/null & PID=$!
      spin $PID "Processing import $img ..." "Import complete !"
    fi
}

guest_qm_resizeimg(){
  #### Resize cloud img 
  qm resize "$key" scsi0 +"$QS_EXTEND" >/dev/null
}

guest_qm_ciconf(){
  if [ -f "$GS_SHAPECONF" ]; then
    QS_CICONF=$(sed '/^cloud_init:/,$!d' "$GS_SHAPECONF")
    if [ -n "$QS_CICONF" ]; then
      sed '/^cloud_init:/,$!d' "$GS_SHAPECONF" | sed -e '1s/^cloud_init:/#cloud-config/' > "$HS_PATH_CONF/gs_kvm-$QS_NAME-$key.yaml"
      echo ""
      msg_syntax "Set Cloud-init configuration"
      qm set "$key" --citype "nocloud" --cicustom "user=$HS_DATASTR:snippets/gs_kvm-$QS_NAME-$key.yaml" >/dev/null
      qm cloudinit update "$key" >/dev/null
    else
      msg_syntax "No values provinded for cloud-init"
    fi

  else
    msg_syntax "No shape provinded for QEMU/KVM guest"
  fi
}

guest_qm_extrasettings(){
  #### Extra guest settings
  if [ -f "$GS_SHAPECONF" ]; then
    QS_EXTRA_CONFIG=$(sed -n '/extra_guest_config:/,/^$/{/extra_guest_config:/d;/^$/d;s/^[ \t]*- //p}' "$GS_SHAPECONF")
    if [ -n "$QS_EXTRA_CONFIG" ]; then
      echo "$QS_EXTRA_CONFIG" >> "/etc/pve/qemu-server/$key.conf"
    else
      msg_syntax "No exta settings for guest config"
    fi

  else
    msg_syntax "No shape provinded for QEMU/KVM guest"
  fi
}

guest_qm_fingerprint(){
  if [ -f "$GS_SHAPECONF" ]; then
  cat << EOF >> "/etc/pve/qemu-server/$key.conf"
# - base image: $img
# - base shape: $GS_SHAPECONF
# - cloud-init file: $HS_PATH_CONF/gs_kvm-$QS_NAME-$key.yaml
EOF
  fi
}

guest_qm_sboot(){
  if [ "$QS_SBOOT" = "1" ]; then
    echo ""
    msg_syntax "Immediate boot ...."
    qm start "$key"
  else
    echo ""
    msg_syntax "No immediate boot configured."
  fi
}


##########################################################################################################
# MAKE GUESTS LXC                                                                          
##########################################################################################################

guest_lxc_init() {
  msg_info "Make canevas for guest"
  # setup configuration QEMU
  declare -A slug_serv

  ## process entry
  read -ra vmid_array <<< "$(process_vmid_list "$GS_VMID")"
  read -ra network_array <<< "$(process_network_list "$GS_NETCONF")"

  # checking array
  if [ ${#vmid_array[@]} -ne ${#network_array[@]} ]; then
    msg_error "Error: The number of CTID/VMIDs does not match the number of IP addresses."
    exit 1
  fi

  ## create the association array
  for ((i=0; i<${#vmid_array[@]}; i++)); do
    slug_serv[${vmid_array[$i]}]=${network_array[$i]}
  done

  ## display association array
    for key in "${!slug_serv[@]}"; do
      echo "ID $key => ${slug_serv[$key]}"

  ## VMID check for both QEMU machines and LXC containers
    if qm list | awk '{print $1}' | grep -Eq "^$key\$" || pct list | awk '{print $1}' | grep -Eq "^$key\$"; then
      msg_error "ID $key is already in use by a QEMU Machine or an LXC container."
      exit 1
    else
      msg_ok "ID $key is available."
    fi

  log_command "DEBUG-LXC_BUILD" "pct create $key $HS_LXCIMG/$img \
    --cores $CS_CORE \
    --memory $CS_MEMORY \
    --swap $CS_MEMORY \
    --hostname $CS_NAME-$key \
    --onboot $CS_ONBOOT \
    --rootfs $HS_LOCALVM:$CS_SPACE \
    --protection $CS_PROTECT \
    --unprivileged $CS_PERM \
    --features $CS_FEAT" >/dev/null
  
  guest_lxc_ipconfig
  guest_lxc_ciconf
  guest_lxc_extrasettings
  guest_lxc_fingerprint
  guest_lxc_ciset
  guest_lxc_sboot
done
}

guest_lxc_ipconfig(){
  #### IP attribution
    if [ "$GS_NETCONF" == "dhcp" ]; then
      pct set "$key" --net"$CS_NET_ETH" \
      name="$CS_NET_NAME""$CS_NET_ETH",ip=dhcp,bridge="$GS_NETBR",gw="$GS_GATE" >/dev/null
      pct set "$key" --nameserver "$GS_DNS00 $GS_DNS01"  >/dev/null
#      pct set "$key" --searchdomain "local" >/dev/null
    else
      pct set "$key" --net"$CS_NET_ETH" \
      name="$CS_NET_NAME""$CS_NET_ETH",ip="${slug_serv[$key]}"/"$GS_CIDR",bridge="$GS_NETBR",gw="$GS_GATE" >/dev/null
      pct set "$key" --nameserver "$GS_DNS00 $GS_DNS01"  >/dev/null
#      pct set "$key" --searchdomain "local" >/dev/null
    fi  
}

guest_lxc_ciconf(){
  if [ -f "$GS_SHAPECONF" ]; then
    CS_CICONF=$(sed '/^cloud_init:/,$!d' "$GS_SHAPECONF")
    if [ -n "$CS_CICONF" ]; then
      sed '/^cloud_init:/,$!d' "$GS_SHAPECONF" | sed -e '1s/^cloud_init:/#cloud-config/' > "$HS_PATH_CONF/gs_lxc-$CS_NAME-$key.yaml"
      echo ""
      msg_syntax "Set Cloud-init configuration"
    else
      msg_syntax "No values provinded for cloud-init"
    fi

  else
    msg_syntax "No shape provinded for LXC guest"
  fi
}

guest_lxc_extrasettings(){
  if [ -f "$GS_SHAPECONF" ]; then
    CS_EXTRA_CONFIG=$(sed -n '/extra_guest_config:/,/^$/{/extra_guest_config:/d;/^$/d;s/^[ \t]*- //p}' "$GS_SHAPECONF")
    if [ -n "$CS_EXTRA_CONFIG" ]; then
      echo "$CS_EXTRA_CONFIG" >> "/etc/pve/lxc/$key.conf"
    else
      msg_syntax "No exta settings for guest config"
    fi

  else
    msg_syntax "No shape provinded for LXC guest"
  fi
}

guest_lxc_fingerprint(){
  if [ -f "$GS_SHAPECONF" ]; then
  cat << EOF >> "/etc/pve/lxc/$key.conf"
# - base image: $img
# - base shape: $GS_SHAPECONF
# - cloud-init file: $HS_PATH_CONF/gs_lxc-$CS_NAME-$key.yaml
EOF
  fi
}

guest_lxc_ciset(){
    # Set cloud-init configuration on guest
    pct start "$key" 
    pct mount "$key" >/dev/null
    pct exec "$key" mkdir /cidata/ 
    pct exec "$key" mkdir /cidata/import 
    pct push "$key" "$CS_CIINIT" cidata/cinit.sh -perms 700
    log_command "DEBUG-LXC_SETUP" "pct exec $key /cidata/cinit.sh guest_configure" & PID=$!
    spin $PID "Prepare LXC guest ..." "Finishing setup !" 

    # install cloud-init
    log_command "DEBUG-LXC_CLOUD-INIT_00" "pct exec $key /cidata/cinit.sh cloudinit_pkg" & PID=$!
    spin $PID "Installing cloud-init ..." "Install complete !" 

    # populate required files
    pct push "$key" "$HS_INIT_SHAPE/98-datasource.cfg" etc/cloud/cloud.cfg.d/98-datasource.cfg
    pct push "$key" "$HS_INIT_SHAPE/99-warnings.cfg" etc/cloud/cloud.cfg.d/99-warnings.cfg
    pct push "$key" "$HS_PATH_CONF/gs_lxc-$CS_NAME-$key.yaml" "cidata/gs_lxc-$CS_NAME-$key.yaml"
    log_command "DEBUG-LXC_CLOUD-INIT_01" "pct exec $key /cidata/cinit.sh load" & PID=$!
    spin $PID "Loading cloud-init configuration ..." "Configuration loaded !" 

    # set init arg for load cloud-init configuration
    pct unmount "$key"
    pct shutdown "$key"
}

guest_lxc_sboot(){
  if [ "$CS_SBOOT" = "1" ]; then
    echo ""
    msg_syntax "Immediate boot ...."
    pct start "$key"
  else
    echo ""
    msg_syntax "No immediate boot configured."
  fi
}

##########################################################################################################
# MAKE GUESTS COMMON                                                                         
##########################################################################################################

# Create template function for both QEMU and LXC
guest_convert_tmpl(){
  local guest_type="$1"
  if [ "$guest_type" = "qm" ]; then
    qm template "$key" > /dev/null
  elif [ "$guest_type" = "lxc" ]; then
    pct template "$key" > /dev/null
  fi
}

