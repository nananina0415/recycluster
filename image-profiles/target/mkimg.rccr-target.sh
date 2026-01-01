profile_rccr_target() {
	profile_standard
	title="RCCR Target Node"
	desc="RCCR Target Node - Alpine Linux cluster worker
		Minimal setup with Docker and Python3
		Managed by RCCR Control nodes"
	profile_abbrev="rccr-target"
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

	# RCCR Target packages: minimal Docker + Python
	apks="$apks
		openssh openssh-server
		python3
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
	apkovl="genapkovl-rccr-target.sh"

	# Boot and default services
	boot_services="networking chronyd"
	default_services="docker sshd local"
}
