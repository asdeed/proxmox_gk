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
## MSG/COLOR FUNCTIONS
##########################################################################################################

# Bold
msg_bold() {
  local msg="$1"
  echo -e "\033[1m$msg\033[0m"
}

# Yellow bold
msg_info() {
  local msg="$1"
  echo -e "\033[1;33m$msg\033[0m" 
}

# Yellow inline
msg_info_inline() {
  local msg="$1"
  echo -ne "\033[1;33m$msg\033[0m"
}

# Yellow regular
msg_info_nb() {
  local msg="$1"
  echo -e "\033[33m$msg\033[0m"
}

# Blue bold
msg_syntax() {
  local msg="$1"
  echo -e "\033[1;36m$msg\033[0m"
}

# Blue regular
msg_syntax_nb() {
  local msg="$1"
  echo -e "\033[36m$msg\033[0m"
}

# Green bold
msg_ok() {
  local msg="$1"
  echo -e "\033[1;32m$msg\033[0m"
}

# Green regular
msg_ok_nb() {
  local msg="$1"
  echo -e "\033[32m$msg\033[0m"
}

# Red bold
msg_error() {
  local msg="$1"
  echo -e "\033[1;31m$msg\033[0m"
}

# Red regular
msg_error_nb() {
  local msg="$1"
  echo -e "\033[31m$msg\033[0m"
}

# Blue bold
msg_inline() {
  local msg="$1"
  echo -ne "\033[1;36m$msg\033[0m"
}

# Blue regular
msg_inline_nb() {
  local msg="$1"
  echo -ne "\033[36m$msg\033[0m"
}

##########################################################################################################
## COLOR FUNCTIONS
##########################################################################################################
# shellcheck disable=SC2034
RED='\033[1;31m'
# shellcheck disable=SC2034
GREEN='\033[1;32m'
# shellcheck disable=SC2034
BLUE='\033[1;36m'
# shellcheck disable=SC2034
YELLOW='\033[1;33m'
# shellcheck disable=SC2034
NC='\033[0m' # No Color


##########################################################################################################
## HEADERS ARRAY FUNCTIONS
##########################################################################################################
avail_header() {
  echo -e "${YELLOW}--------------------------------------------------------------------------------------------${NC}"
  printf "${YELLOW}|${NC} ${YELLOW}%-59s${NC} ${YELLOW}|${NC} ${BLUE}%-26s${NC} ${YELLOW}|${NC}\n" "$1" "Availability" 
  echo -e "${YELLOW}--------------------------------------------------------------------------------------------${NC}"
}

simple_header() {
  echo -e "${YELLOW}--------------------------------------------------------------------------------------------${NC}"
  printf "${YELLOW}|${NC} ${YELLOW}%-88s${NC} ${YELLOW}|${NC}\n" "$1"
  echo -e "${YELLOW}--------------------------------------------------------------------------------------------${NC}"
}

print_footer() {
  echo -e "${YELLOW}--------------------------------------------------------------------------------------------${NC}"
}

##########################################################################################################
## ELEMENTS FUNCTIONS
##########################################################################################################


pb_dlimg() {
  local_path="$1"
  url="$2"
  track_pid="$3"
  size_total=$(curl -sIL "$url" 2>&1 | grep -i Content-Length | sed -n '{s/.*: //;p}' | tr -d '\r' | tail -1)

  while kill -0 "$track_pid" &>/dev/null; do
    size_local=$(stat -c %s "${local_path}/$(basename "$url")" 2>/dev/null || echo 0)
    percentage=$((size_local * 100 / size_total))
    bar=""

  for ((i=0; i<percentage/2; i++)); do
    bar+="▇"
  done

    echo -ne "\r${YELLOW}${bar}${NC} ${percentage}%  "
    sleep 1
  done

  # check import
  if [ ! -f "${local_path}/$(basename "$url")" ]; then
    msg_error "Error: File not created"
    return 1
  fi

  # check weight
  file_size=$(stat -c %s "${local_path}/$(basename "$url")")
  export file_size
  if [ "$file_size" -ne "$size_total" ]; then
    msg_error "Error: File size mismatch (expected $size_total, got $file_size"
    return 1
  fi

  echo # switch
}

spin() {
  tput civis

  local pid=$1
  local start_msg=$2
  local end_msg=$3
  local i=0

  local -a sp=(
    ">        " ">>       " ">>>      " " >>>     " "  >>>    " "   >>>   "
    "    >>>  " "     >>> " "      >>>" "       >>" "        >" "         "
  )

  printf "${YELLOW}\n%s\n${NC}" "$start_msg"

  while kill -0 "$pid" 2>/dev/null
  do
    printf "${BLUE}\r%s${NC}" "${sp[i]}"
    i=$((i+1))
    i=$((i%${#sp[@]}))
    sleep 0.1
  done
  
  printf "${GREEN}\n%s\n${NC}" "$end_msg"

  tput cnorm
}
