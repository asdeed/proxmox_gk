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
# LIST FUNCTIONS                                                                          
##########################################################################################################

# List all available QEMU image (LINUX,BSD)
kvm_index() {
  local mode="$1"
  readarray -t json_data < "$HS_INDEX_KVM"

  kvm_imgs=()
  declare -A download_links

  for line in "${json_data[@]}"; do
    if [[ $line == *'"kvm_img":'* ]]; then
      kvm_img=$(echo "$line" | cut -d':' -f2 | tr -d '", ')
      kvm_imgs+=("$kvm_img")
    fi
    if [[ $line == *'"kvm_dlink":'* ]]; then
      kvm_dlink=$(echo "$line" | cut -d':' -f2,3 | tr -d '", ')
      download_links["$kvm_img"]="$kvm_dlink"
    fi
  done

  case "$mode" in
    name)
      for kvm_img in "${kvm_imgs[@]}"; do
        echo "$kvm_img"
      done
    ;;
    index)
      for i in "${!kvm_imgs[@]}"; do
        echo "${kvm_imgs[$i]} - ${download_links[${kvm_imgs[$i]}]}"
      done
    ;;
  esac
}

lxc_index() {
  local mode="$1"
  readarray -t json_data < "$HS_INDEX_LXC"

  lxc_imgs=()
  declare -A download_links

  for line in "${json_data[@]}"; do
    if [[ $line == *'"lxc_img":'* ]]; then
      lxc_img=$(echo "$line" | cut -d':' -f2 | tr -d '", ')
      lxc_imgs+=("$lxc_img")
    fi
    if [[ $line == *'"lxc_dlink":'* ]]; then
      lxc_dlink=$(echo "$line" | cut -d':' -f2,3 | tr -d '", ')
      download_links["$lxc_img"]="$lxc_dlink"
    fi
  done

  case "$mode" in
    name)
      for lxc_img in "${lxc_imgs[@]}"; do
        echo "$lxc_img"
      done
    ;;
    index)
      for i in "${!lxc_imgs[@]}"; do
        echo "${lxc_imgs[$i]} - ${download_links[${lxc_imgs[$i]}]}"
      done
    ;;
  esac
}

set_image_availability() {
  local template=$1
  local available_templates=$2

  if [[ ${available_templates[*]} =~ $template ]]; then
    printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${GREEN}%-26s${NC} ${YELLOW}|${NC}\n" "$template" "ON_LOCAL"
  else
    printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${RED}%-26s${NC} ${YELLOW}|${NC}\n" "$template" "NOT_ON_LOCAL"
  fi
}


ls_lxc() {
  # Create table header
  avail_header "LXC Images"

  mapfile -t available_templates < <(lxc_index name)
  mapfile -t local_templates < <(pveam list local | awk '{print $1}' | sed 1d)

  for template in "${available_templates[@]}"; do
    # Check local list
    set_image_availability "$template" "${local_templates[*]}"
  done
      # Create table footer
  print_footer
}

ls_qemu() {
  # Create table header
  avail_header "QEMU/KVM Images"

  mapfile -t available_templates < <(kvm_index name)
  mapfile -t local_templates < <(find "$HS_CIIMG" -type f -exec basename {} \;)


  for template in "${available_templates[@]}"; do
    # Check local list
    set_image_availability "$template" "${local_templates[*]}"
  done
    # Create table footer
  print_footer
}

ls_folderset(){
    # Check integrity of pgqs file-set
    integrity_folderset=(
    "$HS_CIIMG"
    "$HS_LXCIMG"
    "$HS_PATH_SHAPE"
    "$HS_LXC_SHAPE"
    "$HS_KVM_SHAPE"
    "$HS_INIT_SHAPE"
    "$HS_PATH_CONF")

    avail_header "Folders Integrity Status"

    for folder in "${integrity_folderset[@]}"; do
    if [ -d "$folder" ]; then
      folder_permissions=$(stat --format="%A %U:%G" "$folder")
      printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${GREEN}%-26s${NC} ${YELLOW}|${NC}\n" "$folder" "$folder_permissions"
    else
      printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${RED}%-26s${NC} ${YELLOW}|${NC}\n" "$folder" "NOT_FOUND"
    fi
  done
print_footer
}

ls_fileset(){
  integrity_fileset=(
  "/etc/pgk/config.cfg"
  "$SSHKEY"
  "$HS_INDEX_KVM"
  "$HS_INDEX_LXC"
  "$CS_CIINIT"
  "$HS_PATH_LOG")

  avail_header "Files Integrity Status"

    for file in "${integrity_fileset[@]}"; do
    if [ -f "$file" ]; then
      file_permissions=$(stat --format="%A %U:%G" "$file")
      printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${GREEN}%-26s${NC} ${YELLOW}|${NC}\n" "$file" "$file_permissions"
    else
      printf "${YELLOW}|${NC} ${BLUE}%-59s${NC} ${YELLOW}|${NC} ${RED}%-26s${NC} ${YELLOW}|${NC}\n" "$file" "NOT_FOUND"
    fi
  done
print_footer
}

ls_lxcshape(){
  simple_header "Available LXC Shapes -- $HS_LXC_SHAPE" 
  templates=$(find "$HS_LXC_SHAPE" -type f -exec basename {} \;)
  for template in $templates; do
  printf "${YELLOW}|${NC} ${BLUE}%-88s${NC} ${YELLOW}|${NC}\n" "$template"
  done
  print_footer
}

ls_qmshape(){
  simple_header "Available QEMU/KVM Shapes -- $HS_KVM_SHAPE" 
  templates=$(find "$HS_KVM_SHAPE" -type f -exec basename {} \;)
  for template in $templates; do
  printf "${YELLOW}|${NC} ${BLUE}%-88s${NC} ${YELLOW}|${NC}\n" "$template"
  done
  print_footer
}

ls_ciconf() {
  simple_header "Generated Cloud-init Configurations -- $HS_PATH_CONF" 
  templates=$(find "$HS_PATH_CONF" -type f -name 'gs_*-*.yaml' -exec basename {} \;)
  for template in $templates; do
  printf "${YELLOW}|${NC} ${BLUE}%-88s${NC} ${YELLOW}|${NC}\n" "$template"
  done
  print_footer
}
