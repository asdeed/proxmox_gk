
## SYNOPSIS

pgk [-b]... [TYPE_GUEST] [IMAGE] [ID(S)] [IP(S)] [SHAPE]  
pgk [-a]... [TYPE_GUEST] [IMAGE] [SHAPE]  
pgk [-t]... [TYPE_GUEST] [IMAGE] [SHAPE]  
pgk [-l]... [TYPE_FILE]  
pgk [-e]... [TYPE_FILE] [NAMEFILE]  
pgk [-e]... [TYPE_FILE]  
pgk [-u]... [TYPE_FILE]


## DESCRIPTION

**PGK** aka **Proxmox GK**, is a bash utility to automate deployment of LXC and QEMU/KVM guests, individually or in batches, via Cloud-init.

## OPTIONS

### Batch Deployment

*usage: pgk -b [TYPE_GUEST] [IMAGE] [ID(S)] [IP(S)] [SHAPE]*

**-b**  : Batch deployment of your LXC or QEMU/KVM guests from a same image. pgk will define the appropriate parameters according to the image chosen, but it is still possible to pass a custom shape as an argument to adapt the deployment parameters.

- **[TYPE_GUEST]**  Required argument for select type of guests, string value lxc or kvm
- **[IMAGE]**       Required argument for name of the image distribution, you can provide full namefile or use regex expression
- **[ID(S)]**       Required argument for available CTID/VMID, numerical value like '100' or '100,101,103' for batch deployement
- **[IP(S)]**       Required argument for static adress like '192.168.2.100' or '192.168.2.100,101,102' for batch deployement, default CIDR is provided form configuration file.
- **[SHAPE]**       Optional argument, specify a namefile for overide default guest settings

### Automatic Deployment

*usage: pgk -a [TYPE_GUEST] [IMAGE] [SHAPE]*

**-a**  : Minimalistic deployment option, pgk will define the appropriate parameters according to the image chosen, but it is still possible to pass a custom shape as an argument to adapt the deployment parameters.

- **[TYPE_GUEST]**  Required argument for select type of guests, string value lxc or kvm
- **[IMAGE]**       Required argument for name of the image distribution, you can provide full namefile or use regex expression
- **[SHAPE]**       Optional argument, specify a namefile for overide default guest settings

### Template provining

*usage: pgk -t [TYPE_GUEST] [IMAGE] [SHAPE]*

**-t**  : Provisionning a Proxmox template, the pre-configuration of template required a shape file.

- **[TYPE_GUEST]**  Required argument for select type of guests, string value lxc or kvm
- **[IMAGE]**       Required argument for name of the image distribution, you can provide full namefile or use regex expression
- **[SHAPE]**       Required argument, specify a namefile for overide default guest settings


### Standard Options

*usage: pgk -l [TYPE_FILE]*

**-l**  : Option for List available LXC/QEMU images & configurations files

- **-l img**       list availability of guests images on pve host.
- **-l lxc**       list shape preset available for LXC guests.
- **-l kvm**       list shape preset available for QEMU/KVM guests.
- **-l ci**        list generated cloud-init configuration file.
- **-l fs**        lists the expected required files and folders (debug).

*usage: pgk -u [TYPE_FILE]*

**-u**   : Update configuration files.

- **dshape**                 Regenerate all default shape
- **lxc_index**              Manual update of the lxc index images

*usage: pgk -e [TYPE_FILE] [NAMEFILE]*  
*usage: pgk -e [TYPE_FILE]*

**-e**   : Option to edit or create a new shape (LXC/QEMU). But also a quick way to edit the main configuration file

- **-e lxc [NAMEFILE]**         Edit or create a shape preset file for lxc guest
- **-e kvm [NAMEFILE]**         Edit or create a shape preset file for QEMU/KVM guest
- **-e config**                 Edit main configuration file.
- **-e kvm_index**              Edit QEMU/KVM image index.
- **-e lxc_index**              Edit LXC image index.

## EXAMPLES

*Ex: Batch deployment of three alpine Linux based virtual machines with a VMID (100,101,102) for each of them, and a dedicated IP address in the format 192.168.2.\***. In this example, as no shape file is supplied, a default configuration will be applied and will perform a basic pre-configuration of the guest: default user setup, OpenSSH configuration, qemu-guest-agent installation (only for KVM/QEMU guest), timezone and locales.*

```pgk -b kvm alpine 100,101,102 192.168.2.100,101,102```

*Ex: Minimalist deployment of Fedora 39 based virtual machine, the regex syntax is used to filter all images available.* 

```pgk -a kvm fedora.*39```

*Ex: Creation of a "Proxmox template" based on alpine linux for an unprivileged container. In this case, a shape preset is used to overwrite the default settings of container, and contains additionnaly directives for docker installation.*

```pgk -t lxc alpine ss_ulxc_alpine-docker.yaml```

*Ex: Creation of a custom shape for a vm, I will then be asked to choose a pre-filled base model depending on the distribution chosen. The file is then edited using the default text editor to make any necessary changes.*

```pgk -e kvm my_shape.yaml```

## FILES

- **/etc/pgk/config.cfg**  
the main configuration file

- **/var/lib/pgk**:  
Contains the basic/custom shapes for the different types of guest, and the indexes. Also contains certain files needed to initialise cloud-init for containers. 
  - **init/ds_kvm_*.conf**: default shape for kvm guests
  - **init/ds_lxc_*.conf**: default shape for lxc guests
  - **init/cinit.sh**: payload required for cloud-init configuration of containers.
  - **lxc_index.json**: auto-generated index, contains the addresses of the various container images and their default shape.
  - **kvm_index.json**: index containing the addresses of the various QEMU/KVM guest images.

- **/usr/lib/pgk**  
contains the scripts that execute the main functions.
    - **/usr/lib/pgk/pgk.sh > /usr/bin/pgk**: Main executable, symlinked to /usr/bin/pgk.

- **/var/log/pgk.log**  
Supports tracking when guests are created, as well as the cloud-init configuration process for containers. 


## NOTES

### Configuration base storage
The Proxmox storage model is very flexible, PGK needs to know where the different types of content are based on your Proxmox installation.  
The /etc/pve/storage.cfg file summarizes the status of all your storage.  
Make sure you then adapt the variables for the ‘data store’ and ‘image store’ in the main configuration file /etc/pgk/config.cfg.

*HS_PATH_DATASTR=/var/lib/vz                                 # Full path of datastore*  
*# type of content required:  iso,vztmpl,snippets*  
*HS_LOCALVM=local-lvm                                        # Name of guests image store (local-zfs|local-btrfs)*  
*# type of content required: rootdir,images*  
*HS_DATASTR=local                                            # Common name of datastore*  
*HS_CIIMG=$HS_PATH_DATASTR/template/iso                      # Folder dedicated to QEMU/KVM cloud images*  
*HS_LXCIMG=$HS_PATH_DATASTR/template/cache                   # Folder dedicated to lxc images*  
*HS_PATH_CONF=$HS_PATH_DATASTR/snippets                      # Folder dedicated to cloud-init config files (.yaml)*  

### Set secret on environment variable
PGK use your environment variable to store some secret  

- **GS_CIUSER**: Default username, for all guests
- **GS_CIPASSWD_PLAIN**: Default plain password for GS_CIUSER, required only for OpenBSD (bcrypt exception)
- **GS_CIPASSWD_SHA**: Default hashed password for GS_CIUSER  

You must set all these variables before run this program :

*echo "export GS_CIUSER='YOUR_USERNAME'" | tee -a $HOME/.bashrc*  
*echo "export GS_CIPASSWD_PLAIN='YOUR_PLAINTEXT_PASSWORD'" | tee -a $HOME/.bashrc*  
*echo "export GS_CIPASSWD_SHA='$(openssl passwd -6 "YOUR_PLAINTEXT_PASSWORD")'" | tee -a $HOME/.bashrc*  
*source $HOME/.bashrc*  

### Custom shape file 

When you create a custom shape, the pre-filled fields are made according to your parameters in the main configuration file ``/etc/pgk/config.cfg``. All the shape files are structured in the same way and follow YAML syntax. Three blocks must be present:

- **gs_values:** contains the values needed to create the lxc/qemu guest, they will be extracted and interpreted as environment variables, and only concern the creation of the vm or container (essentially interacting with ```/usr/bin/pct``` and ```/usr/bin/qm```).

- **extra_guest_config:** this is an optional block, containing directives (one per line) that we'd like to pass directly into the guest's PVE configuration file, /etc/pve/lxc/CTID.conf or /etc/pve/qemu-server/VMID.conf. Use with caution, as the wrong instruction could prevent the guest from starting up correctly.

- **cloud_init:** contains the directives that will be interpreted by Cloud-init to configure the guest.



## BUGS

You are welcome to submit bug reports via the PGK bug tracker (https://github.com/asdeed/proxmox_gk/issues).

## AUTHOR 

PGK.1 written by Alexandre JAN <alexandre_jan@nodeswarm.eu>


## COPYRIGHT

Copyright (C) <2023-2024> Alexandre JAN

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, 
or any later version.
