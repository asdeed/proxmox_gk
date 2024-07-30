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
# LOGGING                                                               
##########################################################################################################

log_command() {
    local message="$1"
    local command="$2"
    local log_file="$HS_PATH_LOG"
    # shellcheck disable=SC2154

    cat << EOF >> "$log_file"

#### $(date +"%Y-%m-%d_%H-%M-%S") $message #########################################################
CMD: $command
EOF

    $command >> "$log_file" 2>&1
    local exit_code=$?

    echo "Command exited with code: $exit_code" >> "$log_file"
    return $exit_code
}

##########################################################################################################
# CHECK SECRET                                                              
##########################################################################################################

chk_var_secret() {
  local required_vars=(
    "GS_CIUSER"
    "GS_CIPASSWD_PLAIN"
    "GS_CIPASSWD_SHA"
  )

  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      msg_error "One or more required secret are not set on your environment variables."
      man pgk |  sed -n '151,167p'
      return 1
    fi
  done

  log_command "UPDATE-DSHAPE" "clean_dshape"
  return 0
}

##########################################################################################################
# CHECKING ARGS                                                             
##########################################################################################################

count_args() {
  if [ -z "$2" ]; then
    msg_error "The name of distribution must be provinded"
    exit 1
  fi
  if [ -z "$3" ]; then
    msg_error "An VMID or a list of VMID must be provinded"
    exit 1
  fi
  if [ -z "$4" ]; then
    msg_error "A IP or list of IP adress must be provinded"
    exit 1
  fi
}

chk_args(){
    if  [ "$1" == "distrib" ]; then # syntax of distribution name 
        if ! [[ $3 =~ ^[[:alnum:][:punct:]]+$ ]]; then
            msg_error "Argument: '$3' for distribution name not provinded, or not follow the required nomenclature"
            exit 1
        fi
    elif  [ "$1" == "iplist" ]; then # syntax of list ip adresse like 192.168.2.XX,XX.XX
        if ! [[ $3 =~ ^(([0-9]{1,3}\.){3}[0-9]{1,3}(,[0-9]{1,3})*$)|^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
            msg_error "Argument: '$3' for IP list does not follow the required nomenclature"
            exit 1
        fi
    elif  [ "$1" == "vmid" ]; then # syntax of list vmimd like 100,101,102,103 
        IFS=',' read -ra nums <<< "$3"

        for num in "${nums[@]}"; do
            if ! [[ "$num" =~ ^[0-9]+$ ]] || ! (( num >= 100 && num <= 9999 )); then
                msg_error "Argument: '$num' must be an integer between 100 and 9999, list must be separted by comas."
                exit 1
            fi
        done
    fi
}

##########################################################################################################
# CHECK EDIT                                                              
##########################################################################################################

check_shape_yaml(){
  # igmore if not provinded
  if [ -z "$2" ]; then
    return
  fi

  if ! [[ $2 =~ ^[[:alnum:][:punct:]]+\.yaml$ ]]; then
    msg_error "The argument does not follow the required nomenclature: it should be a valid filename ending in .yaml"
    exit 1
  fi
}

##########################################################################################################
# CHECK STORAGE                                                             
##########################################################################################################

chk_local_lvm() {
  # Check if $HS_LOCALVM value exists in /etc/pve/storage.cfg
  if grep -q "${HS_LOCALVM}" /etc/pve/storage.cfg; then

    # Get all lines from $HS_LOCALVM until the next empty line
    config_block=$(awk -v var="$HS_LOCALVM" 'BEGIN{RS=""; FS="\n"} $1 ~ var' /etc/pve/storage.cfg)

    # Check if "content" line exist
    if echo "${config_block}" | grep -q "content"; then

      # Check if "content" line contains "images" and "rootdir"
      if echo "${config_block}" | grep "content" | grep -q "images" && \
         echo "${config_block}" | grep "content" | grep -q "rootdir"; then
         return
      else
        msg_error "Error: Storage $HS_LOCALVM is not configured for store all these required content ments (image|rootdir)"
        msg_info "Enable this type of content, and check your configuration 'pgk -e config'"
        man pgk |  sed -n '138,150p'
        exit 1
      fi
    fi
  else
    msg_error "Error: Storage $HS_LOCALVM does not exist"
    msg_info "check your configuration 'pgk -e config'"
    man pgk |  sed -n '138,150p'
    exit 1
  fi
}

chk_local() {
  # Check if HS_PATH_DATASTR value exists in /etc/pve/storage.cfg
  if grep -q "${HS_PATH_DATASTR}" /etc/pve/storage.cfg; then

    # Get all lines from $HS_LOCALVM until the next empty line
    config_block=$(awk -v var="$HS_PATH_DATASTR" 'BEGIN{RS=""; FS="\n"} $1 var' /etc/pve/storage.cfg)

    # Check if "content" line exist
    if echo "${config_block}" | grep -q "content"; then

      # Check if "content" line contains "images" and "rootdir"
      if echo "${config_block}" | grep "content" | grep -q "vztmpl" && \
         echo "${config_block}" | grep "content" | grep -q "snippets" && \
         echo "${config_block}" | grep "content" | grep -q "iso"; then
         return
      else
        msg_error "Error: Storage $HS_PATH_DATASTR is not configured for store all these required content (vztmpl|snippets|iso)"
        msg_info "Enable this type of content, and check your configuration 'pgk -e config'"
        man pgk |  sed -n '138,150p'
        exit 1
      fi
    fi
  else
    msg_error "Error: Storage $HS_PATH_DATASTR does not exist"
    msg_info "check your configuration 'pgk -e config'"
    man pgk |  sed -n '138,150p'
    exit 1
  fi
 }

##########################################################################################################
# CHECK DEPENDENCIES                                                             
##########################################################################################################

chk_pkg(){
  pkglist=(
  "curl"
  "jq")

  for pkg in "${pkglist[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
      msg_error "$pkg is not installed. Please install this package to continue"
      exit 1
    fi
done
}

##########################################################################################################
# CHECK BASE FOLDERS/FILES                                                         
##########################################################################################################
chk_ctrl_files(){
  integ_fileset=(
  "/etc/pgk/config.cfg"
  "$SSHKEY"
  "$HS_INDEX_LXC"
  "$HS_INDEX_KVM"
  "$CS_CIINIT"
  "$HS_PATH_LOG")

  for file in "${integ_fileset[@]}"; do
    if [ -f "$file" ]; then
      echo "#### $(date +"%Y-%m-%d_%H-%M-%S") CONTROL_FILES Required $file found" >> "$HS_PATH_LOG"
    else
      msg_error "Required $file unavailable"
      msg_info "check your configuration 'pgk -e config'"
      man pgk |  sed -n '138,150p'
      return 1
    fi
  done
}

chk_ctrl_folders(){
    integ_folderset=(
    "$HS_CIIMG"
    "$HS_LXCIMG"
    "$HS_PATH_SHAPE"
    "$HS_LXC_SHAPE"
    "$HS_KVM_SHAPE"
    "$HS_INIT_SHAPE"
    "$HS_PATH_CONF")
  
  for folder in "${integ_folderset[@]}"; do
    if [ -d "$folder" ]; then
      echo "#### $(date +"%Y-%m-%d_%H-%M-%S") CONTROL_FILES Required $folder found" >> "$HS_PATH_LOG"
    else
      msg_error "Required $folder unavailable"
      msg_info "check your configuration 'pgk -e config'"
      man pgk |  sed -n '138,150p'
      return 1
    fi
  done
}


##########################################################################################################
# CHECK SHAPE/CLOUD CONFIG                                                         
##########################################################################################################

chk_guest_confiles(){
  shape_fileset=(
    "$HS_INIT_SHAPE/ss_ulxc_alpine-docker.conf"
    "$HS_INIT_SHAPE/ss_plxc_alpine-docker.conf"
    "$HS_INIT_SHAPE/ss_kvm_alpine-docker.conf"
    "$HS_INIT_SHAPE/ds_lxc_alpine.conf"
    "$HS_INIT_SHAPE/ds_kvm_alpine.conf"
    "$HS_INIT_SHAPE/ds_lxc_arch.conf"
    "$HS_INIT_SHAPE/ds_kvm_arch.conf"
    "$HS_INIT_SHAPE/ds_lxc_deb-sysd.conf"
    "$HS_INIT_SHAPE/ds_lxc_deb-init.conf"
    "$HS_INIT_SHAPE/ds_kvm_deb-sysd.conf"
    "$HS_INIT_SHAPE/ds_lxc_rhel.conf"
    "$HS_INIT_SHAPE/ds_kvm_rhel.conf"
    "$HS_INIT_SHAPE/ds_kvm_fbsd.conf"
    "$HS_INIT_SHAPE/ds_kvm_obsd.conf"
    "$HS_INIT_SHAPE/ds_lxc_gentoo.conf"
    "$HS_INIT_SHAPE/ds_lxc_suse.conf")
    
  for file in "${shape_fileset[@]}"; do
    if [ -f "$file" ]; then
      echo "Required $file found"
    else
      echo "Required $file unavailable, check your configuration and $HS_INIT_SHAPE folder"
      exit 1
    fi
  done
}

chk_kvm_shape(){
  shape_fileset=(
    "$HS_KVM_SHAPE/ds_kvm_alpine.yaml"
    "$HS_KVM_SHAPE/ds_kvm_arch.yaml"
    "$HS_KVM_SHAPE/ds_kvm_deb-sysd.yaml"
    "$HS_KVM_SHAPE/ds_kvm_rhel.yaml"
    "$HS_KVM_SHAPE/ds_kvm_fbsd.yaml"
    "$HS_KVM_SHAPE/ds_kvm_obsd.yaml"
    "$HS_KVM_SHAPE/ss_kvm_alpine-docker.yaml")
    
  for file in "${shape_fileset[@]}"; do
    if [ -f "$file" ]; then
      echo "File $file found"
    else
      echo "$file unavailable, start generation ..."
      
      # Rationalize namefile
      file_name=$(basename "$file" | cut -d'.' -f1)
      export file_name 
    
      GS_SSHKEY=$(cat "$SSHKEY" | grep -E "^ssh" | xargs -iXX echo "  - XX")
      export GS_SSHKEY
      # Pass VAR. to new shape file
      envsubst < "$HS_INIT_SHAPE/$file_name.conf" > "$HS_KVM_SHAPE/$file_name.yaml"
    fi
  done
}

chk_lxc_shape(){
  shape_fileset=(
    "$HS_LXC_SHAPE/ds_lxc_alpine.yaml"
    "$HS_LXC_SHAPE/ds_lxc_arch.yaml"
    "$HS_LXC_SHAPE/ds_lxc_deb-sysd.yaml"
    "$HS_LXC_SHAPE/ds_lxc_deb-init.yaml"
    "$HS_LXC_SHAPE/ds_lxc_rhel.yaml"
    "$HS_LXC_SHAPE/ds_lxc_suse.yaml"
    "$HS_LXC_SHAPE/ds_lxc_gentoo.yaml"
    "$HS_LXC_SHAPE/ss_ulxc_alpine-docker.yaml"
    "$HS_LXC_SHAPE/ss_plxc_alpine-docker.yaml")
    
  for file in "${shape_fileset[@]}"; do
    if [ -f "$file" ]; then
      echo "File $file found"
    else
      echo "$file unavailable, start generation ..."
      
      # Rationalize namefile
      file_name=$(basename "$file" | cut -d'.' -f1)
      export file_name 
    
      GS_SSHKEY=$(cat "$SSHKEY" | grep -E "^ssh" | xargs -iXX echo "  - XX")
      export GS_SSHKEY
      # Pass VAR. to new shape file
      envsubst < "$HS_INIT_SHAPE/$file_name.conf" > "$HS_LXC_SHAPE/$file_name.yaml"
    fi
  done
}

clean_dshape(){
  shape_fileset=(
    "$HS_LXC_SHAPE/ds_lxc_alpine.yaml"
    "$HS_LXC_SHAPE/ds_lxc_arch.yaml"
    "$HS_LXC_SHAPE/ds_lxc_deb-sysd.yaml"
    "$HS_LXC_SHAPE/ds_lxc_deb-init.yaml"
    "$HS_LXC_SHAPE/ds_lxc_rhel.yaml"
    "$HS_LXC_SHAPE/ds_lxc_suse.yaml"
    "$HS_LXC_SHAPE/ds_lxc_gentoo.yaml"
    "$HS_LXC_SHAPE/ss_ulxc_alpine-docker.yaml"
    "$HS_LXC_SHAPE/ss_plxc_alpine-docker.yaml"
    "$HS_KVM_SHAPE/ds_kvm_alpine.yaml"
    "$HS_KVM_SHAPE/ds_kvm_arch.yaml"
    "$HS_KVM_SHAPE/ds_kvm_deb-sysd.yaml"
    "$HS_KVM_SHAPE/ds_kvm_rhel.yaml"
    "$HS_KVM_SHAPE/ds_kvm_fbsd.yaml"
    "$HS_KVM_SHAPE/ds_kvm_obsd.yaml"
    "$HS_KVM_SHAPE/ss_kvm_alpine-docker.yaml")

  for file in "${shape_fileset[@]}"; do
    echo "cleanning file $file"
    rm $file
  done
}

##########################################################################################################
# UPDATE LXC_INDEX
##########################################################################################################

index_lxc_gen() {
    files=($(pveam available --section system | awk '{print $2}'))
    local json_data='['
    for file in "${files[@]}"; do
        if [[ "$file" =~ ^(alpine|alpinelinux|alpine_linux|alpine-linux|'alpine linux') ]]; then
            default_shape="ds_lxc_alpine.yaml"
        elif [[ "$file" =~ ^(archlinux|arch_linux|arch-linux|'arch linux') ]]; then
            default_shape="ds_lxc_arch.yaml"
        elif [[ "$file" =~ ^(debian|ubuntu) ]]; then
            default_shape="ds_lxc_deb-sysd.yaml"
        elif [[ "$file" =~ ^(devuan) ]]; then
            default_shape="ds_lxc_deb-init.yaml"
        elif [[ "$file" =~ ^(fedora|centos|cent-os|cent_os|rockylinux|rocky_linux|rocky-linux|'rocky linux'|almalinux|alma_linux|almalinux|'alma linux') ]]; then
            default_shape="ds_lxc_rhel.yaml"
        elif [[ "$file" =~ ^(gentoo) ]]; then
            default_shape="ds_lxc_gentoo.yaml"
        elif [[ "$file" =~ ^(opensuse) ]]; then
            default_shape="ds_lxc_suse.yaml"
        else
            default_shape=""
        fi
        
        json_data+=$'\n  {'
        json_data+=$'\n    "lxc_img": "'$file'",'
        json_data+=$'\n    "lxc_dlink": "'$HS_LXCREPO'/'$file'",'
        json_data+=$'\n    "lxc_dshape": "'$default_shape'"'
        json_data+=$'\n  },'
    done
    json_data=${json_data%,}
    json_data+=$'\n]'
    echo "$json_data"
}

chk_index_lxc_update() {
    json_output=$(index_lxc_gen)
    echo "$json_output" > "$HS_INDEX_LXC"
}

chk_lxc_index() {
  if [ ! -f "$HS_INDEX_LXC" ]; then
    chk_index_lxc_update
  else 
    echo "LXC index found"
  fi
}