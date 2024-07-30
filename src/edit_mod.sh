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
# IMPORT INDEX FUNCTIONS                                                                          
##########################################################################################################
# TODO manage index(s)

##########################################################################################################
# ADD/EDIT GUESTS SHAPES FUNCTIONS                                                                          
##########################################################################################################

edit_qemu_shape() {
  if [ -f "$HS_KVM_SHAPE/$1" ]; then
    $HS_EDIT "$HS_KVM_SHAPE/$1" 
  else
    # Edit VAR. from config file
    GS_CIPASSWD_SHA=$(echo "$GS_CIPASSWD" | mkpasswd --stdin --method=SHA-512 --rounds=4096)
    export GS_CIPASSWD_SHA
    
    GS_SSHKEY=$(cat "$SSHKEY" | grep -E "^ssh" | xargs -iXX echo "  - XX")
    export GS_SSHKEY

    # Select base 
    msg_info "Select your image base: "
    PS3="Select: "
    options=("Debian-systemd" "RHEL" "Archlinux" "Alpine" "FreeBSD" "OpenBSD")
    select opt in "${options[@]}"
    do
      case $opt in
        "Debian-systemd")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_deb-sysd.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0
          ;;
        "RHEL")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_rhel.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0           
          ;;
        "Archlinux")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_arch.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0             
          ;;
        "Alpine")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_alpine.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0          
          ;;
        "FreeBSD")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_fbsd.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0          
          ;;
        "OpenBSD")
          envsubst < "$HS_INIT_SHAPE/ds_kvm_opbsd.conf" > "$HS_KVM_SHAPE/$1"
          $HS_EDIT "$HS_KVM_SHAPE/$1"
          return 0
          ;;
        *) 
          msg_error "invalid option $REPLY"
          return 1
          ;;
      esac
    done
  fi
}

edit_lxc_shape() {
  if [ -f "$HS_LXC_SHAPE/$1" ]; then
    $HS_EDIT "$HS_LXC_SHAPE/$1" 
  else
    # Edit VAR. from config file
    GS_CIPASSWD_SHA=$(echo "$GS_CIPASSWD" | mkpasswd --stdin --method=SHA-512 --rounds=4096)
    export GS_CIPASSWD_SHA
    
    GS_SSHKEY=$(cat "$SSHKEY" | grep -E "^ssh" | xargs -iXX echo "  - XX")
    export GS_SSHKEY

    # Select base 
    msg_info "Select your image base: "
    PS3="Select: "
    options=("Debian-systemd" "Debian-sysvinit" "RHEL" "OpenSUSE" "Archlinux" "Alpine" "Gentoo")
    select opt in "${options[@]}"
    do
      case $opt in
        "Debian-systemd")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_deb-sysd.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        "Debian-sysvinit")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_deb-init.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        "RHEL")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_rhel.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        "OpenSUSE")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_suse.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        "Archlinux")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_arch.conf" > "$HS_LXC_SHAPE/$1"
         $HS_EDIT "$HS_LXC_SHAPE/$1"
         return 0
          ;;
        "Alpine")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_alpine.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        "Gentoo")
          envsubst < "$HS_INIT_SHAPE/ds_lxc_gentoo.conf" > "$HS_LXC_SHAPE/$1"
          $HS_EDIT "$HS_LXC_SHAPE/$1"
          return 0
          ;;
        *) 
          msg_error "invalid option $REPLY"
          return 1
          ;;
      esac
    done
  fi
}

##########################################################################################################
# EDIT CONFIG FILES FUNCTIONS                                                                          
##########################################################################################################

edit_index() {
  if [[ "$1" == "kvm" ]]; then
    $HS_EDIT "$HS_INDEX_KVM" 

  elif [[ "$1" == "lxc" ]]; then
    $HS_EDIT "$HS_INDEX_LXC" 
  fi
}

edit_confile() {
  $HS_EDIT "/etc/pgk/config.cfg"
}