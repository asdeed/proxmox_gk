# PGKS Makefile
# Usage:
# - make install
# - make DESTDIR=/tmp/packaging install

NAME:= pgk
VERSION:= 0.1.0

# quick tools
INSTALL  = install
LK	     = ln -sf
RM_F  	 = rm -f 
RM_R	 = rm -rf 
ADD      = touch 

# List folders
#DESTDIR 	  ?=
BINDIR		  = /usr/bin
BASEDIR		  = /usr/lib/pgk
CONFDIR	      = /etc/pgk
SHAREDIR	  = /var/lib/pgk
MANDIR		  = /usr/share/man/man
LOGDIR		  = /var/log

# List files
SRCS		= pgk.sh basic_mod.sh list_mod.sh edit_mod.sh set_mod.sh id_mod.sh make_mod.sh chk_mod.sh
MANPAGES1	= pgk.1
CONFILES	= config.cfg 
INDEXFILES  = kvm_index.json
SAMPLES		= ss_kvm_alpine-docker.conf ss_ulxc_alpine-docker.conf ss_plxc_alpine-docker.conf
CONF_INIT   = cinit.sh 98-datasource.cfg 99-warnings.cfg 
DF_KVM		= ds_kvm_alpine.conf ds_kvm_arch.conf ds_kvm_deb-sysd.conf ds_kvm_rhel.conf ds_kvm_fbsd.conf ds_kvm_obsd.conf 
DF_LXC		= ds_lxc_alpine.conf ds_lxc_arch.conf ds_lxc_deb-sysd.conf ds_lxc_deb-init.conf ds_lxc_rhel.conf ds_lxc_suse.conf ds_lxc_gentoo.conf

install: install_files link_exec create_files

## DESTDIR only for pkg create
install_files:
	$(INSTALL) -d $(DESTDIR)$(CONFDIR)
	$(INSTALL) -d $(DESTDIR)$(BASEDIR)
	$(INSTALL) -d $(DESTDIR)$(SHAREDIR)
	$(INSTALL) -d $(DESTDIR)$(SHAREDIR)/gs_lxc
	$(INSTALL) -d $(DESTDIR)$(SHAREDIR)/gs_kvm
	$(INSTALL) -d $(DESTDIR)$(SHAREDIR)/init	
	$(INSTALL) -d $(DESTDIR)$(MANDIR)1
	$(INSTALL) -m 755 $(addprefix init/,$(CONF_INIT)) $(DESTDIR)$(SHAREDIR)/init
	$(INSTALL) -m 755 $(addprefix init/,$(DF_KVM)) $(DESTDIR)$(SHAREDIR)/init
	$(INSTALL) -m 755 $(addprefix init/,$(DF_LXC)) $(DESTDIR)$(SHAREDIR)/init
	$(INSTALL) -m 755 $(addprefix samples/,$(SAMPLES)) $(DESTDIR)$(SHAREDIR)/init
	$(INSTALL) -m 755 $(addprefix src/,$(SRCS)) $(DESTDIR)$(BASEDIR)
	$(INSTALL) -m 644 $(addprefix man/,$(MANPAGES1)) $(DESTDIR)$(MANDIR)1
	$(INSTALL) -m 644 $(CONFILES) $(DESTDIR)$(CONFDIR)
	$(INSTALL) -m 744 $(INDEXFILES) $(DESTDIR)$(SHAREDIR)
link_exec:
	$(LK) $(BASEDIR)/pgk.sh $(DESTDIR)$(BINDIR)/pgk
create_files:
	$(ADD) $(LOGDIR)/pgk.log 

# Rules uninstall 
uninstall: 
	$(RM_F) $(DESTDIR)$(BINDIR)/pgk 
	$(RM_F) $(LOGDIR)/pgk.log 
	$(RM_R) $(DESTDIR)$(BASEDIR) $(DESTDIR)$(CONFDIR) $(DESTDIR)$(SHAREDIR)
	$(RM_F) $(addprefix $(DESTDIR)$(MANDIR)1/, $(MANPAGES1))

.PHONY: install uninstall install_files create_files