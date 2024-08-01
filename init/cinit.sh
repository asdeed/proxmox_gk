#!/bin/sh

BASEPATH="/cidata"

check_connectivity() {
  attempt=1
  while [ $attempt -le 3 ]; do
    # Vérifier la connectivité réseau
    ping -c 2 1.1.1.1 > /dev/null
    if [ $? -eq 0 ]; then
      echo '### INFOS-CINIT NETWORK CONNECTION : OK'
      return 0
    else
      echo '### ERROR-CINIT NETWORK CONNECTION : FAIL'
      sleep 4
      attempt=$((attempt+1))
    fi
  done
  echo "### ERROR-CINIT NETWORK CONNECTION : FAIL (failed after 3 attempts. Exiting.)"
  echo "CHECK YOUR NETWORK CONFIGURATION"
  exit 1
}

exec_cloudinit() {  
  cloud_init_version=$(cloud-init --version | cut -d ' ' -f 2 | cut -d '-' -f 1)
  major_version=$(echo "$cloud_init_version" | cut -d '.' -f 1)
  minor_version=$(echo "$cloud_init_version" | cut -d '.' -f 2)
  
  echo '### INFOS-CINIT loading cloud-init configuration'

  if [ "$major_version" -gt 23 ] || [ "$major_version" -eq 24 ] && [ "$minor_version" -ge 0 ] ; then
    # after v. 24.0.0
    echo "cloud-init version : $cloud_init_version | using current syntax cmd"
    cloud-init schema -c "$base_conf"
    sudo  cloud-init init --file "$base_conf"
    cloud-init modules --mode config --file "$base_conf"
    cloud-init modules --mode final --file "$base_conf"
    < /var/log/cloud-init.log grep ".*guest has been initialized" | awk -F': ' '{print $2}'
    cloud-init status --format json
  else
    # before v. 24.0.0
    echo "cloud-init version : $cloud_init_version | using old syntax cmd"
    cloud-init schema -c "$base_conf" --annotate
    cloud-init --file "$base_conf" init
    cloud-init --file "$base_conf" modules --mode config
    cloud-init --file "$base_conf" modules --mode final
    < /var/log/cloud-init.log grep ".*guest has been initialized" | awk -F': ' '{print $2}'
    cloud-init status --format json
  fi
}


load() {
  base_conf=$(ls $BASEPATH/*.yaml)
  check_connectivity >/dev/null
  #check_yaml_config
  exec_cloudinit
}

reload() {
    base_conf=$(ls $BASEPATH/*.yaml)
    new_conf=$(ls -1t "$BASEPATH/import" | head -n 1)

    if [ -f "$base_conf" ] && [ -f "import/$new_conf" ]; then
        # manage diff
        diff_result=$(diff "$base_conf" "import/$new_conf")
        if [ "$diff_result" = "" ]; then
            echo "### INFOS-CINIT No patch configuration: no diff found"
        else
            diff -u "$base_conf" "import/$new_conf" > patchfile.patch
            if [ -s "patchfile.patch" ]; then
                # patch config
                patch "$base_conf" patchfile.patch
                rm patchfile.patch
                # Process loading new config with cloud-init
                check_connectivity >/dev/null
                exec_cloudinit >/dev/null
            fi
        fi
    else
        echo "### ERROR-CINIT Missing config file(s)"
    fi
}

# spliting for transparent execution order on main (conf. make_mod.sh l.358)
guest_configure() {
    if [ -f /etc/os-release ]; then
    # GNU/Linux distribution
    . /etc/os-release

    echo '### INFOS-CINIT Update & Install dependencies'

    # custom usecase
    case $ID in
        debian|ubuntu)
            check_connectivity
            # Refresh repo
            apt-get update -y > /dev/null
            # Process packages list
            set -- patch diffutils openssh-server sudo bash
            for PKG in "$@"; do
                if dpkg -l | grep "^$PKG" > /dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT install $PKG package"
                    apt-get install -y "$PKG" >/dev/null
                fi
            done
        ;;
        devuan)
            check_connectivity
            # Refresh repo
            apt-get update -y > /dev/null
            # Process packages list
            set -- patch diffutils openssh-server sudo bash
            for PKG in "$@"; do
                if dpkg -l | grep "^$PKG" > /dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT install $PKG package"
                    apt-get install -y "$PKG" >/dev/null
                fi
            done
        ;;
        fedora|centos|almalinux|rocky)
            check_connectivity
            # Refresh repo
            dnf update -y > /dev/null
            # Process packages list
            set -- patch diffutils openssh-server sudo bash
            for PKG in "$@"; do
                if dnf list --installed | grep "^$PKG" > /dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    dnf install -y "$PKG" >/dev/null
                fi
            done
        ;;
        opensuse-leap)
            check_connectivity
            # Refresh repo
            zypper -n refresh > /dev/null
            zypper -n update > /dev/null 
            # Process packages list
            set -- patch diffutils openssh-server sudo bash
            for PKG in "$@"; do
                if zypper search -i | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    zypper -n install "$PKG" >/dev/null
                fi
            done
        ;;
        arch)
            check_connectivity
            # Refresh repo
            #rm -r /etc/pacman.d/gnupg/*
            pacman-key --init && pacman-key --populate archlinux >/dev/null
            pacman -Sy archlinux-keyring --noconfirm && pacman -Su --noconfirm >/dev/null
            pacman -Sy --noconfirm base-devel >/dev/null
            # Process packages list
            set -- patch diffutils openssh sudo bash
            for PKG in "$@"; do
                if pacman -Q | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    pacman  -Sy --noconfirm "$PKG" >/dev/null
                fi
            done
        ;;
        alpine)
            check_connectivity
            # Refresh repo
            apk update > /dev/null
            apk upgrade --available && sync
            # Process packages list
            set -- patch diffutils openssh-server sudo bash
            for PKG in "$@"; do
                if apk info | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    apk add --no-cache "$PKG" >/dev/null
                fi
            done
        ;;
        gentoo)
            check_connectivity
            # Refresh repo
            emerge -fq --sync >/dev/null
            emerge -quDN --with-bdeps=y  @world >/dev/null

            # Process packages list
            set -- patch diffutils openssh sudo bash
            for PKG in "$@"; do
                if qlist -I | grep "$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    emerge "$PKG" >/dev/null
                fi
            done
        ;;
        *)
            echo "### ERROR-CINIT Distribution not currently supported"
            echo "Linux distribution $NAME ($VERSION)"
            echo "$ID"
        ;;
    esac
else
    echo "### ERROR-CINIT Unknown operating system"
    echo "Linux distribution $NAME ($VERSION)"
    echo "$ID"
    exit 1
fi
}

# spliting for transparent execution order on main (conf. make_mod.sh l.358)
cloudinit_pkg() {
    if [ -f /etc/os-release ]; then
    # GNU/Linux distribution
    . /etc/os-release

    set -- cloud-init

    echo '### INFOS-CINIT Install cloud-init'

    # custom usecase
    case $ID in
        debian|ubuntu)
            check_connectivity
            # Process packages list
            for PKG in "$@"; do
                if dpkg -l | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT install $PKG package"
                    apt-get install -y "$PKG" >/dev/null
                fi
            done
        ;;
        devuan)
            # Process packages list
            for PKG in "$@"; do
                if dpkg -l | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT install $PKG package"
                    apt-get install -y "$PKG" >/dev/null
                fi
            done
        ;;
        fedora|centos|almalinux|rocky)
            check_connectivity
            # Process packages list
            for PKG in "$@"; do
                if dnf list --installed | grep "^$PKG >/dev/null"; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    dnf install -y "$PKG" >/dev/null
                fi
            done
        ;;
        opensuse-leap)
            check_connectivity
            # Process packages list
            for PKG in "$@"; do
                if zypper search -i | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    zypper -n install "$PKG" >/dev/null
                fi
            done
        ;;
        arch)
            check_connectivity
            # Process packages list
            for PKG in "$@"; do
                if pacman -Q | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    pacman  -Sy --noconfirm "$PKG" >/dev/null
                fi
            done
        ;;
        alpine)
            check_connectivity
            for PKG in "$@"; do
                if apk info | grep "^$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    apk add --no-cache "$PKG" >/dev/null
                fi
            done
        ;;
        gentoo)
            check_connectivity
            for PKG in "$@"; do
                if qlist -I | grep "$PKG" >/dev/null; then
                    echo "### INFO-CINIT Package: $PKG already installed"
                else
                    echo "### INFO-CINIT Install $PKG package"
                    emerge "$PKG" >/dev/null
                fi
            done
        ;;
        *)
            echo "### ERROR-CINIT Distribution not currently supported"
            echo "Linux distribution $NAME ($VERSION)"
            echo "$ID"
        ;;
    esac
else
    echo "### ERROR-CINIT Unknown operating system"
    echo "Linux distribution $NAME ($VERSION)"
    echo "$ID"
    exit 1
fi
}

# ENTRYPOINT
$1


