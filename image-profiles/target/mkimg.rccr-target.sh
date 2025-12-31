profile_rccr_target() {
	profile_standard
	title="RCCR Target Node"
	desc="RCCR Target Node - Alpine Linux cluster worker
		Minimal setup with Docker and Python3
		Managed by RCCR Control nodes"
	profile_abbrev="rccr-target"
	image_ext="iso"
	arch="x86 x86_64 aarch64 armv7 armhf"
	output_format="iso"
	kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
	hostname="ReCyClusteR-Target"
	modloop_sign=no  # Disable kernel module signing (no private key)
	kernel_addons=""  # Disable xtables-addons (not available for rpi kernel)

	# Use Raspberry Pi kernel for ARM architectures
	case "$ARCH" in
		armhf|armv7|aarch64)
			kernel_flavors="rpi"
			;;
		*)
			kernel_flavors="lts"
			;;
	esac

	# RCCR Target packages: minimal Docker + Python
	apks="$apks
		openssh openssh-server
		python3
		bash
		docker docker-compose docker-cli-compose
		avahi dbus
		sudo
		"

	# Overlay generation script
	apkovl="genapkovl-rccr-target.sh"

	# Boot and default services
	boot_services="networking chronyd"
	default_services="docker sshd avahi-daemon local"
}
