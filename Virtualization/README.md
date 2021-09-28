These scripts are for enabling and running a VM instance within your machine
without needing VirtualBox.

You can run the qemu-debian instance without any further modification besides
updating the script to point to your kernel source KNL_SRC


Another useful resource:
https://www.youtube.com/watch?v=AAfFewePE7c


Running with QEMU ----------------------------------------------

Directions:

1) First make sure you have the needed packages installed on your machine
PreReqs: 
$ sudo dnf install qemu kvm debootstrap

2) Make sure you have a compiled image of your kernel using the minimal debian
	instance config file.

$ cp config-qemu-debian-min ~/KNL_SRC/.config # copy over config to kernel source
$ cd ~/KNL_SRC
$ make -j80
(Do not need to do make module install)

3) install the Debian
$ cd ~/Utils-Scrips/Virtualization
$ sudo ./install-debian.sh

4) Boot the QEMU instance using ./run-qemu-debian.sh
$ sudo ./run-qemu-debian.sh

Now you can seamlessly copy over files from your host machine to the
QEMU instance by simply putting them in the linux-chroot/ directory
$ cp TEST ~/Utils-Scrips/Virtualization/linux-chroot

Running with QCOW2 ----------------------------------------------

Similar to above except you need to:
1) Create a HDD image
2) Install the OS onto the HDD image
	- Need to download Fedora 34, Ubuntu, or Debian \*.iso file for this.

3) Update the script to reference these pieces
4) Then you need a mount script to mount folders to your QEMU VM

5) and then you can use it like normal
