profile_rccr_control() {
	profile_standard
	title="RCCR Control Node"
	desc="RCCR Control Node - Alpine Linux cluster manager
		Includes Ansible, Python3 for cluster management
		SSH keys are temporary and auto-rotated on first setup"
	profile_abbrev="rccr-control"
	hostname="ReCyClusteR-Node"
	modloop_sign=no  # Disable kernel module signing (no private key)
	kernel_addons=""  # Disable xtables-addons (not available for rpi kernel)

	# Architecture to image format mapping table
	# RCCR_ARCH is passed from build script
	#
	# | Architecture  | Format  | Kernel  | Use Case                    |
	# |---------------|---------|---------|----------------------------|
	# | x86           | ISO     | lts     | 32-bit PC                  |
	# | x86_64        | ISO     | lts     | 64-bit PC/Server           |
	# | aarch64       | ISO     | lts     | ARM64 Server (non-RPi)     |
	# | rpi-aarch64   | IMG.GZ  | rpi     | Raspberry Pi 3/4/5         |
	# | armv7         | IMG.GZ  | rpi     | Raspberry Pi 2/3           |
	# | armhf         | IMG.GZ  | rpi     | Raspberry Pi 1/Zero        |
	#
	case "$RCCR_ARCH" in
		rpi-aarch64|armv7|armhf)
			# Raspberry Pi: IMG disk image (FAT32 boot + ext4 root)
			# Uses Alpine's create_image_imggz() from mkimg.arm.sh
			image_ext="img.gz"
			output_format="imggz"  # Alpine: create_image_imggz()
			kernel_flavors="rpi"
			kernel_cmdline="modules=loop,squashfs console=tty1"
			initfs_features="base squashfs"
			# Map RCCR_ARCH to Alpine arch
			case "$RCCR_ARCH" in
				rpi-aarch64)  arch="aarch64" ;;
				armv7)        arch="armv7" ;;
				armhf)        arch="armhf" ;;
			esac
			;;
		x86|x86_64|aarch64)
			# PC/Server: ISO image (CD/DVD boot)
			# Uses Alpine's create_image_iso() from mkimg.base.sh
			image_ext="iso"
			output_format="iso"
			kernel_flavors="lts"
			kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
			initfs_features="ata base ide scsi usb virtio"
			# Map RCCR_ARCH to Alpine arch (1:1 mapping)
			case "$RCCR_ARCH" in
				x86)      arch="x86" ;;
				x86_64)   arch="x86_64" ;;
				aarch64)  arch="aarch64" ;;
			esac
			;;
		*)
			echo "ERROR: Unknown architecture: $RCCR_ARCH" >&2
			exit 1
			;;
	esac

	# RCCR Control packages: Ansible, Docker, Python
	apks="$apks
		openssh openssh-client openssh-server openssh-keygen
		python3 py3-pip py3-yaml
		ansible
		docker docker-compose docker-cli-compose
		sudo
		"

	# Add Raspberry Pi firmware for ARM architectures
	case "$RCCR_ARCH" in
		rpi-aarch64|armhf|armv7)
			apks="$apks
				raspberrypi-bootloader
				"
			;;
	esac

	# Overlay generation script
	apkovl="genapkovl-rccr-control.sh"

	# Boot and default services
	boot_services="networking chronyd"
	default_services="docker sshd local"
}
