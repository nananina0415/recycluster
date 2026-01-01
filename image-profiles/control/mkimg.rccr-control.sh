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

	# Use Raspberry Pi kernel and IMG format for Raspberry Pi architectures
	# RCCR_ARCH is passed from build script (e.g., rpi-aarch64, armhf, armv7)
	case "$RCCR_ARCH" in
		rpi-aarch64|armhf|armv7)
			# Raspberry Pi: Use IMG disk image format (not ISO)
			# Alpine's mkimage.sh uses build_rpi_img() for output_format="rpi"
			image_ext="img.gz"
			arch="aarch64 armv7 armhf"
			output_format="rpi"
			kernel_flavors="rpi"
			kernel_cmdline="modules=loop,squashfs console=tty1"
			;;
		*)
			# x86/x86_64: Use ISO format
			image_ext="iso"
			arch="x86 x86_64"
			output_format="iso"
			kernel_flavors="lts"
			kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
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
