  
![Alt text](https://asded.fr/img/pgk_itxt00.svg)

*Proxmox GK aka **P**roxmox **G**uests **K**ickstart*  
Third-party Proxmox bash utility to automate deployment of LXC and QEMU/KVM guests, individually or in batches, via Cloud-init.

**Features list:**
- Batch and automate guests deployment
- Cloud-init integration for LXC and QEMU/KVM
- Fast provisioning Proxmox templates 

## Demo
![demo](https://asded.fr/img/pgk_dm01.gif)

**Datasheet of supported guests:**

| Distribution  | Version |  QEMU/KVM  |  LXC *1 | Cloud-init support |
| :------------ | :-----  | :--------: | :-----: | :----------------: |
| Devuan        |   4.0   |    ❌      |   ✅    |        ✅          |
| Debian        |   11    |    ✅      |   ✅    |        ✅          |
|               |   12    |    ✅      |   ✅    |        ✅          |
| Ubuntu        |  20.04  |    ✅      |   ✅    |        ✅          |
|               |  22.04  |    ✅      |   ✅    |        ✅          |
|               |  23.04  |    ✅      |   ✅    |        ✅          |
|               |  24.04  |    ✅      |   ✅    |        ✅          |
| Fedora        |   39    |    ✅      |   ✅    |        ✅          |
|               |   40    |    ✅      |   ✅    |        ✅          |
| CentOS stream |    9    |    ✅      |   ✅    |        ✅          |
| Alamalinux    |    8    |    ✅      |   ✅    |        ✅          |
|               |    9    |    ✅      |   ✅    |        ✅          |
| Rocky Linux   |    9    |    ✅      |   ✅    |        ✅          |
| OpenSUSE      |  15.4   |    ❌      |   ✅    |        ✅          |
|               |  15.5   |    ❌      |   ✅    |        ✅          |
| Arch Linux    | current |    ✅      |   ✅    |        ✅          |
| Alpine Linux  |   3.18  |    ✅      |   ✅    |        ✅          |
|               |   3.19  |    ✅      |   ✅    |        ✅          |
| Gentoo        | current |    ❌      |   ✅    |        ✅          |
| OpenBSD       |   7.5   |    ✅      |   ❌    |        ✅ *2       |
| FreeBSD       |   14    |    ✅      |   ❌    |        ✅ *2       |

\* 1 Based on container images from the official Proxmox repository  
\* 2 **FreeBSD** and **OpenBSD** don't officialy support cloud-init, These images come from bsd-cloud-image.org


## Usages

### Automatic Deployment

*usage: pgk -a lxc|kvm [IMAGE] [SHAPE]*

- **-a**:     Minimalist deployment option, pgk will define the appropriate parameters according to the image chosen, but it is still possible to pass a custom shape as an argument to adapt the deployment parameters.                      
- **[lxc|kvm]**                 Required argument for type of guests LXC or QEMU/KVM
- **[IMAGE]**                   Name of the image distribution, you can provide full namefile or use regex expression
- **[SHAPE]**                   Optional argument, specify a namefile for overide default guest settings

*Ex: Minimalist deployment of Fedora 39 based virtual machine, the regex syntax is used to filter all images available.* 

```shell
pgk -a kvm fedora.*39
```

> [!NOTE]
> If no shapefile provided, a default configuration will be applied and will perform a basic pre-configuration of the guest: default user setup, openssh configuration, qemu-guest-agent installation (only KVM/QEMU guest), timezone and locale.

### Batch Deployment

*usage: pgk -b lxc|kvm [IMAGE] [VMID(S)] [IP(S)] [SHAPE]*

**-b**:     Batch deployment option, unlike automatic mode, allows multiple Guests to be deployed from the same image.

- **[lxc|kvm]**                  Required argument for type of guests LXC or QEMU/KVM
- **[IMAGE]**                    Name of the image distribution, you can provide full namefile or use regex expression
- **[VMID(S)]**                  Required argument for available VMID, numerical value like '100' or '100,101,103' for batch deployement
- **[IP(S)]**                    Required argument for static adress like '192.168.2.100' or '192.168.2.100,101,102' for batch deployement, default CIDR is provided form configuration file.
- **[SHAPE]**                    Optional argument, specify a namefile for overide default guest settings


*Ex: Batch deploy three QEMU virtual machines based on alpine linux, with a VMID (100,101,102) for each of them, and a dedicated IP address in the format 192.168.2.\***.*

```shell
pgk -b kvm alpine 100,101,102 192.168.2.100,101,102
```

### Template provisionning

*usage: pgk -t lxc|kvm [IMAGE] [SHAPE]*

**-t**:     Provisionning a Proxmox template, the pre-configuration of template required a shape file.

- **[lxc|kvm]**                  Required argument for type of guests LXC or QEMU/KVM
- **[IMAGE]**                    Name of the image distribution, you can provide full namefile or use regex expression
- **[SHAPE]**                    Required argument, specify a namefile for overide default guest settings

*Ex: Creation of a "Proxmox template" based on alpine linux for an unprivileged container. In this case, a shape preset is used to overwrite the default settings of container, and contains additionnaly directives for docker installation.*

```shell
pgk -t lxc alpine ss_ulxc_alpine-docker.yaml
```

### Standard Options 

*usage: pgk -l [TYPE_FILE]*

**-l**:     Option for List available LXC/QEMU images & configurations files

- **-l img**                    list availability of guests images on pve host
- **-l lxc**                    list shape preset available for LXC guests
- **-l kvm**                    list shape preset available for QEMU/KVM guests
- **-l ci**                     list cloud-init yaml file (auto-generated by shape file)
- **-l fs**                     lists the expected required files and folders (debug)

*usage: pgk -u [TYPE_FILE]*

**-u**:     Update configuration files.
- **-u dshape**                 Regenerate all default shape
- **-u lxc_index**              Manual update of the lxc index images

*usage: pgk -e [TYPE_FILE] [NAMEFILE]*  
*usage: pgk -e [TYPE_FILE]*

**-e**:     Option to edit or create a new shape (LXC/QEMU). But also a quick way to edit the main configuration files 

- **-e lxc [NAMEFILE]**         Edit or create a shape preset file for lxc guest
- **-e kvm [NAMEFILE]**         Edit or create a shape preset file for QEMU/KVM guest
- **-e config**                 Edit main configuration file
- **-e kvm_index**              Edit QEMU/KVM index image
- **-e lxc_index**              Edit LXC index image  

*Ex: Edit a new shape configuration file:*

```shell
pgk -e kvm my_shape.yaml
```

> [!NOTE]
> In this example, if the file does not exist you will be asked to select a base template for the file depending on the distribution you want to customize.The preset shape will then be pre-populated with the default configuration of hardware settings, as well as the basic directives for cloud-init.You can then modify the file directly, from your favorite text-editor. To add your own instructions.

All shape files are structured in the same way and follow YAML syntax. Three blocks must be present:

- **gs_values:** contains the values, necessary for the creation of the lxc/qemu guest, they will be extracted and interpreted as environment variables.
- **extra_guest_config:** this is an optional block, containing the directives (one per line) that we would like to pass directly into the guest's PVE configuration file, /etc/pve/lxc/CTID.conf or / etc/pve/qemu-server/VMID.conf. Use with caution, the wrong instruction could prevent the guest from starting correctly.
- **cloud_init:** contains the directives that will be interpreted by cloud-init.

## Install

```shell
apt install make curl jq
git clone https://github.com/asdeed/pgk.git
cd pgk
make install 
#make uninstall
```

## Configure

The Proxmox storage model is very flexible, PGK needs to know where the different types of content are based on your Proxmox installation. The /etc/pve/storage.cfg file summarizes the status of all your storage. Make sure you then adapt the variables for the ‘data store’ and ‘image store’ in the main configuration file /etc/pgk/config.cfg.

```txt
HS_PATH_DATASTR=/var/lib/vz                                 # Full path of datastore  
# type of content required:  iso,vztmpl,snippets  
HS_LOCALVM=local-lvm                                        # Name of guests image store (zfs-local|btrfs-local)  
# type of content required: rootdir,images
HS_DATASTR=local                                            # Common name of datastore
HS_CIIMG=$HS_PATH_DATASTR/template/iso                      # Folder dedicated to QEMU/KVM cloud images  
HS_LXCIMG=$HS_PATH_DATASTR/template/cache                   # Folder dedicated to lxc images
HS_PATH_CONF=$HS_PATH_DATASTR/snippets                      # Folder dedicated to cloud-init config files (.yaml)
```

In addition, pgk uses your environment variable to store some secret for setup your guests:

- **GS_CIUSER**: Default username, for all guests
- **GS_CIPASSWD_PLAIN**: Default plain password for GS_CIUSER, required only for OpenBSD (bcrypt exception)
- **GS_CIPASSWD_SHA**: Default hashed password for GS_CIUSER

You must set these variables before run this program :

```shell
echo "export GS_CIUSER='YOUR_USERNAME'" | tee -a $HOME/.bashrc
echo "export GS_CIPASSWD_PLAIN='YOUR_PLAINTEXT_PASSWORD'" | tee -a $HOME/.bashrc
echo "export GS_CIPASSWD_SHA='$(openssl passwd -6 "YOUR_PLAINTEXT_PASSWORD")'" | tee -a $HOME/.bashrc
source  $HOME/.bashrc
```

## Roadmap:

- [ ] Function for adding lxc/kvm images from third-party repositories
- [ ] Function for updating/modifying cloud-init configuration of an existing guest
- [ ] Bash completion 
- [ ] Debian package
- [ ] Improve the logging function
- [ ] Improve cloud-init integration for LXC 
- [ ] Interactive (dialog) helper for first setup
- [ ] Built-in vault function for store secret, as replacement of environment variable
- [ ] Support for guests deployed in a clustered pve infrastructure 


## Licence

This program is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or any later version.
