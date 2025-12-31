profile_rccr_control() {
	profile_standard
	title="RCCR Control Node"
	desc="RCCR Control Node - Alpine Linux cluster manager
		Includes Ansible, Python3, nmap for cluster management
		SSH keys are temporary and auto-rotated on first setup"
	profile_abbrev="rccr-control"
	image_ext="iso"
	arch="x86_64 aarch64"
	output_format="iso"
	kernel_flavors="lts"
	kernel_cmdline="modules=loop,squashfs,sd-mod,usb-storage quiet"
	hostname="ReCyClusteR-Control"

	# RCCR Control packages: Ansible, Docker, Python, networking tools
	apks="$apks
		openssh openssh-client openssh-server openssh-keygen
		python3 py3-pip py3-yaml
		nmap ansible
		bash curl wget git
		docker docker-compose docker-cli-compose
		avahi dbus
		sudo
		"

	# Overlay generation script
	apkovl="genapkovl-rccr-control.sh"

	# Boot and default services
	boot_services="networking chronyd"
	default_services="docker sshd avahi-daemon local"
}
