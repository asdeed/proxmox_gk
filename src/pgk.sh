#!/usr/bin/env bash
#
# Author : Alexandre JAN
# website : https://asded.fr
# Created : 18/12/2023
# Version : 0.1
# License : GPL-3.0 (GNU General Public License v3.0)
#
# This file is a main part of PGK.
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
# DEBUG/TRACE                                                                     
##########################################################################################################

set -a
set -e
set -o errexit
set -o errtrace
set -o pipefail

source /etc/pgk/config.cfg
source "$HS_MAIN_SRCS/basic_mod.sh"
source "$HS_MAIN_SRCS/list_mod.sh"
source "$HS_MAIN_SRCS/edit_mod.sh"
source "$HS_MAIN_SRCS/set_mod.sh"
source "$HS_MAIN_SRCS/id_mod.sh"
source "$HS_MAIN_SRCS/make_mod.sh"
source "$HS_MAIN_SRCS/chk_mod.sh"

##########################################################################################################
# HELPER FUNCTIONS                                                                          
##########################################################################################################

helper() {
  echo ""
  msg_info "   ____                                       ____ _  __ "
  msg_info "  |  _ \ _ __ _____  ___ __ ___   _____  __  / ___| |/ / "
  msg_info "  | |_) | '__/ _ \ \/ / '_ ' _ \ / _ \ \/ / | |  _| ' /  "
  msg_info "  |  __/| | | (_) >  <| | | | | | (_) >  <  | |_| | . \  "
  msg_info "  |_|   |_|  \___/_/\_\_| |_| |_|\___/_/\_\  \____|_|\_\ "
  msg_info ""
  echo ""
  msg_syntax "Description:"
  echo "Proxmox automator for deploy LXC and QEMU/KVM guests, with Cloud-init." 
  echo ""
  msg_syntax "Usage:"
  echo "pgk [-b]... [TYPE_GUEST] [IMAGE] [ID(S)] [IP(S)] [SHAPE]"
  echo "pgk [-a]... [TYPE_GUEST] [IMAGE] [SHAPE]"
  echo "pgk [-t]... [TYPE_GUEST] [IMAGE] [SHAPE]"
  echo "pgk [-l]... [TYPE_FILE]"
  echo "pgk [-e]... [TYPE_FILE] [NAMEFILE]"
  echo "pgk [-e]... [TYPE_FILE]"
  echo "pgk [-u]... [TYPE_FILE]"
  echo ""
  msg_syntax "Options:"
  echo "-b batching deployement"
  echo "-a automated deploiement"
  echo "-t template provisioning"
  echo "-l listing configuration files and images"
  echo "-e editing configuration files"
  echo "-u updating configuration"
  echo ""
  msg_syntax "Arguments:"
  echo "[TYPE_GUEST]: Required argument for type of guests lxc|kvm"
  echo "[IMAGE]:      Name of the image distribution, accepts regex expressions"
  echo "[ID]:         Required argument for available CTID/VMID, numerical value like '100' or '100,101,103' for batch deployement"
  echo "[IP]:         Required argument for static adress like '192.168.2.100' or '192.168.2.100,101,102' for batch deployement"
  echo "[SHAPE]:      Optional argument, specify a shape namefile for overide default guest settings"
  echo "[TYPE_FILE]   Configuration files and/or fileset img|lxc|kvm|ci|fs|dshape|lxc_index|kvm_index"
  echo "[NAMEFILE]    Name of YAML shape file"
  echo ""
  msg_syntax "Example usage:"
  echo "Deployment of Fedora 39 based virtual machine, using regex syntax for filter all images available."
  msg_bold "    pgk -a kvm fedora.*39"
  echo "Batch deployment of three virtual machines based on alpine linux, with dedicated IP address"
  msg_bold "    pgk -b kvm alpine 100,101,102 192.168.2.100,101,102"
  echo "Make a "Proxmox template" based on alpine linux with custom configuration shape, for docker installation."
  msg_bold "    pgk -t lxc alpine ss_ulxc_alpine-docker.yaml"
  echo ""
  msg_info "Check manual for more information 'man pgk'"
  echo ""
}

##########################################################################################################
# NERVE OPTIONS                                                            
##########################################################################################################

# Check root 
if [[ $EUID -ne 0 ]]; then
  msg_error "This script must be run as root"
  exit 1
fi

# control boot 
log_command "CHECK-BOOT" "chk_lxc_index"

# control exec
pre_exec(){
  chk_pkg
  chk_ctrl_folders
  chk_ctrl_files
  chk_local
  chk_local_lvm
  chk_var_secret
  log_command "CHECK-EXEC" "clean_dshape" 
  log_command "CHECK-EXEC" "chk_guest_confiles" 
  log_command "CHECK-EXEC" "chk_lxc_shape"
  log_command "CHECK-EXEC" "chk_kvm_shape" 
}

# helper default display
if [[ $# == 0 ]]; then
    helper
else

# Main options for build guests
while getopts "b:a:t:l:e:u:" opt; do
    case $opt in
    b)
      pre_exec
      if [[ "$OPTARG" == "kvm" ]]; then
          count_args "$OPTARG" "$3" "$4" "$5" 
          chk_args distrib "$OPTARG" "$3"
          chk_args vmid "$OPTARG" "$4" 
          chk_args iplist "$OPTARG" "$5"
          GS_VMID="$4"
          GS_NETCONF="$5"
          check_vmid_list
          qm_getdistrib "$3"
          getshape kvm "$6" # optional used for overriding default value
         #GS_SHAPECONF="$HS_KVM_SHAPE/$6"
          GS_SHAPECONF="$yaml_file"
          guest_qm_init
          msg_ok "KVM guest(s) initialised !"

      elif [[ "$OPTARG" == "lxc" ]]; then
          count_args "$OPTARG" "$3" "$4" "$5"          
          chk_args distrib "$OPTARG" "$3"
          chk_args vmid "$OPTARG" "$4" 
          chk_args iplist "$OPTARG" "$5"
          # shellcheck disable=SC2034
          GS_VMID="$4"
          GS_NETCONF="$5"
          check_vmid_list          
          lxc_getdistrib "$3"
          getshape lxc "$6" # optional used for overdide defautl var.
          #GS_SHAPECONF="$HS_LXC_SHAPE/$6"
          GS_SHAPECONF="$yaml_file"
          guest_lxc_init
          msg_ok "LXC guest(s) initialised !"
      else
         msg_error "'$OPTARG' is an invalid argument, you need to select a type for your guest: lxc|kvm"
      fi
      ;;
    a)
      pre_exec
      if [[ "$OPTARG" == "kvm" ]]; then
          chk_args distrib "$OPTARG" "$3"
          check_shape_yaml "$OPTARG" "$4"
          next_available_vmid
          GS_NETCONF="dhcp"
          qm_getdistrib "$3"
          getshape kvm "$4" # optional used for overriding default value
          #GS_SHAPECONF="$HS_KVM_SHAPE/$4"
          GS_SHAPECONF="$yaml_file"
          guest_qm_init
          msg_ok "KVM guest(s) initialised !"

      elif [[ "$OPTARG" == "lxc" ]]; then
          chk_args distrib "$OPTARG" "$3"
          check_shape_yaml "$OPTARG" "$4"
          next_available_vmid
          GS_NETCONF="dhcp"
          lxc_getdistrib "$3"
          getshape lxc "$4" # optional used for overdide defautl var.
          #GS_SHAPECONF="$HS_LXC_SHAPE/$4"
          GS_SHAPECONF="$yaml_file"
          guest_lxc_init
          msg_ok "LXC guest(s) initialised !"
      else
         msg_error "'$OPTARG' is an invalid argument, select type for your guest: lxc|kvm"
      fi
      ;;
    t)
      pre_exec
      if [[ "$OPTARG" == "kvm" ]]; then
          chk_args distrib "$OPTARG" "$3"
          check_shape_yaml "$OPTARG" "$4"
          next_available_vmid
          GS_NETCONF="dhcp"
          qm_getdistrib "$3"
          getshape kvm "$4" # needed for overriding default value
          GS_SHAPECONF="$yaml_file"
          QS_SBOOT="0"
          guest_qm_init
          guest_convert_tmpl qm
          msg_ok "KVM template created !"

      elif [[ "$OPTARG" == "lxc" ]]; then
          chk_args distrib "$OPTARG" "$3"
          check_shape_yaml "$OPTARG" "$4"
          next_available_vmid
          # shellcheck disable=SC2034
          GS_NETCONF="dhcp"
          lxc_getdistrib "$3"
          getshape lxc "$4" # needed for overriding default value
          # shellcheck disable=SC2034
          GS_SHAPECONF="$yaml_file"
          CS_SBOOT="0"
          guest_lxc_init
          guest_convert_tmpl lxc
          msg_ok "LXC template created !"
      else
         msg_error "'$OPTARG' is an invalid argument, select type for your guest: lxc|kvm"
      fi
      ;;
    l)
      if [[ "$OPTARG" == "img" ]]; then
        ls_qemu
        ls_lxc
      elif [[ "$OPTARG" == "kvm" ]]; then
        ls_qmshape
      elif [[ "$OPTARG" == "lxc" ]]; then
        ls_lxcshape
      elif [[ "$OPTARG" == "ci" ]]; then
        ls_ciconf
      elif [[ "$OPTARG" == "fs" ]]; then
        ls_fileset
        ls_folderset
      else
        msg_error "'$OPTARG' is an invalid argument, use one of the following: img|kvm|lxc|ci|fs"
      fi
      ;;
    e)
      if [[ "$OPTARG" == "kvm" ]]; then
        if [ -z "$3" ]; then
          msg_error "Error: your kvm shape require namefile" >&2
          exit 1
        else 
          check_shape_yaml "$OPTARG" "$3"
          edit_qemu_shape "$3"
        fi
      elif [[ "$OPTARG" == "lxc" ]]; then
        if [ -z "$3" ]; then
          msg_error "Error: your lxc shape require namefile" >&2
          exit 1
        else 
          check_shape_yaml "$OPTARG" "$3"
          edit_lxc_shape "$3"
        fi
      elif [[ "$OPTARG" == "config" ]]; then
        edit_confile
      elif [[ "$OPTARG" == "kvm_index" ]]; then
        edit_index kvm
      elif [[ "$OPTARG" == "lxc_index" ]]; then
        edit_index lxc
      else
         msg_error "'$OPTARG' is an invalid argument, use one of the following: kvm|lxc|config|kvm_index|lxc_index"
      fi
      ;;
    u)
      if [[ "$OPTARG" == "dshape" ]]; then
        log_command "CHECK-CLEAN_DSHAPE" "clean_dshape"
      elif [[ "$OPTARG" == "lxc_index" ]]; then
        chk_index_lxc_update
      # TODO function for update cloud-init config guests
      else
        msg_error "'$OPTARG' is an invalid argument, use one of the following: dshape|lxc_index"
      fi
      ;;
    *)
      msg_error "Argument needed for $1 option"
        if [[ "$1" == "-l" ]]; then
          msg_info "Use one of the following arguments: img|kvm|lxc|ci|fs"
        elif [[ "$1" == "-b" ]]; then
          msg_info "Use one of the following arguments: lxc|kvm"
        elif [[ "$1" == "-a" ]]; then
          msg_info "Use one of the following arguments: lxc|kvm"
        elif [[ "$1" == "-t" ]]; then
          msg_info "Use one of the following arguments: lxc|kvm"
        elif [[ "$1" == "-e" ]]; then
          msg_info "Use one of the following arguments: kvm|lxc|config|kvm_index|lxc_index"
        elif [[ "$1" == "-u" ]]; then
          msg_info "Use the following arguments: dshape|lxc_index"
        fi
      exit 1
      ;;
    esac
done
fi
