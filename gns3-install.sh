#!/bin/bash
function isRoot() {
	if [ "$EUID" -ne 0 ]; then
		return 1
	fi
}
function checkOS() {
	if [[ -e /etc/debian_version ]]; then
		OS="debian"
		source /etc/os-release

		if [[ $ID == "debian" || $ID == "raspbian" ]]; then
			if [[ $VERSION_ID -lt 10 ]]; then
				echo "Your version of Debian is not supported."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		elif [[ $ID == "ubuntu" ]]; then
			OS="ubuntu"
			MAJOR_UBUNTU_VERSION=$(echo "$VERSION_ID" | cut -d '.' -f1)
			if [[ $MAJOR_UBUNTU_VERSION -lt 16 ]]; then
				echo "Your version of Ubuntu is not supported."
				echo ""
				until [[ $CONTINUE =~ (y|n) ]]; do
					read -rp "Continue? [y/n]: " -e CONTINUE
				done
				if [[ $CONTINUE == "n" ]]; then
					exit 1
				fi
			fi
		fi
	elif [[ -e /etc/system-release ]]; then
		source /etc/os-release
		if [[ $ID == "fedora" || $ID_LIKE == "fedora" ]]; then
			OS="fedora"
		fi
		if [[ $ID == "centos" || $ID == "rocky" || $ID == "almalinux" ]]; then
			OS="centos"
			if [[ $VERSION_ID -lt 7 ]]; then
				echo "Your version of CentOS is not supported."
				echo ""
				exit 1
			fi
		fi
	elif [[ -e /etc/arch-release ]]; then
		OS=arch
	else
		echo "Looks like you aren't running this installer on a Debian, Ubuntu, Fedora or Arch Linux system"
		exit 1
	fi
}
function initialCheck() {
	if ! isRoot; then
		echo -e "Please, run this with sudo or from root"
		exit 1
	fi
	checkOS
}
function initialQuestions() {
	echo "GNS3 installation"
	echo "NOTE: if you want to change virtual network interface you must change addVirbr0 function of script on 143 line"
	echo "WARNINIG: current version of script works with Debian and Ubuntu distros only"
	until [[ $UBRIDGE =~ (y|n) ]]; do
		read -rp "Do you want build and install Ubridge? [Y|n]: " -e -i y UBRIDGE
	done
	
	until [[ $DYNAMIPS =~ (y|n) ]]; do
		read -rp "Do you want build and install dynamips? [Y|n]: " -e -i y DYNAMIPS
	done
	
	until [[ $VPCS =~ (y|n) ]]; do
		read -rp "Do you want build and install VPCS? [Y|n]: " -e -i y VPCS
	done
	
	until [[ $DOCKER =~ (y|n) ]]; do
		read -rp "Do you want add Docker repos and install it? [y|N]: " -e -i n DOCKER
	done
	
	until [[ $WIRESHARK =~ (y|n) ]]; do
		read -rp "Do you want install Wireshark? [Y|n]: " -e -i y WIRESHARK
	done
}
function installUbridge() {
	if [[ $OS =~ (debian|ubuntu) ]]; then
		apt-get install -y git build-essential pcaputils  libpcap-dev
		git clone https://github.com/GNS3/ubridge.git /tmp/ubridge
		cd /tmp/ubridge
		make
		sudo make install
		rm -rf /tmp/ubridge
	fi
}
function installDynamips() {
	if [[ $OS =~ (debian|ubuntu) ]]; then
		apt-get install -y libelf-dev  cmake
		git clone https://github.com/GNS3/dynamips.git /tmp/dynamips
		mkdir /tmp/dynamips/build
		cd /tmp/dynamips/build
		cmake /tmp/dynamips
		make install
		rm -rf /tmp/dynamips
	fi
}
function installVPCS() {
	if [[ $OS =~ (debian|ubuntu) ]]; then
		git clone https://github.com/GNS3/vpcs.git /tmp/vpcs
		cd /tmp/vpcs/src/
		sh ./mk.sh
		cp ./vpcs /usr/bin/vpcs
		rm -rf /tmp/vpcs
	fi
}
function installDocker() {
	if [[ $OS =~ (debian|ubuntu) ]]; then
		apt-get install -y ca-certificates curl gnupg lsb-release
		mkdir -m 0755 -p /etc/apt/keyrings
		if [[ $OS == "ubuntu" ]]; then
			curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		elif [[ $OS == "debian" ]]; then
			curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
			echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
		fi
		chmod a+r /etc/apt/keyrings/docker.gpg
		apt-get update
		apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
		usermod -aG docker $(logname)
		systemctl enable docker
	fi
}
function installWireshark() {
	if [[ $OS =~ (debian|ubuntu) ]]; then
		apt-get install -y wireshark
		usermod -aG wireshark $(logname)
	fi
}

function addVirbr0() {
	cat > /tmp/default.xml <<EOL
<network>
<name>default</name>
<bridge name="virbr0"/>
<forward mode="nat"/>
<ip address="192.168.133.0" netmask="255.255.255.0">
	<dhcp>
		<range start="192.168.133.10" end="192.168.133.254"/>
	</dhcp>
</ip>
</network>
EOL
	
	virsh net-define /tmp/default.xml
	virsh net-start default
	virsh net-autostart default
}

function installGNS() {
	if [[ $OS == "debian" ]]; then
		apt-get install -y python3-pip python3-pyqt5 python3-pyqt5.qtsvg python3-pyqt5.qtwebsockets qemu qemu-kvm qemu-utils libvirt-clients libvirt-daemon-system virtinst xtightvncviewer apt-transport-https ca-certificates curl gnupg2 software-properties-common
		pip3 install gns3-server
		pip3 install gns3-gui
	elif [[ $OS == "ubuntu" ]]; then
		add-apt-repository ppa:gns3/ppa
		apt-get update                                
		apt-get install -y gns3-gui gns3-server gns3-iou
	fi
}

initialCheck
initialQuestions
if [[ $UBRIDGE == "y" ]]; then installUbridge; fi
if [[ $DYNAMIPS == "y" ]]; then installDynamips; fi
if [[ $VPCS == "y" ]]; then installVPCS; fi
if [[ $DOCKER == "y" ]]; then installDocker; fi
if [[ $WIRESHARK  == "y" ]]; then installWireshark; fi
cd ~
installGNS
addVirbr0
sed -i "88i\"VPCS\": {\"vpcs_path\": \"/usr/bin/vpcs\"}," ~/.config/GNS3/*/gns3_gui.conf
until [[ $REBOOT =~ (y|n) ]]; do
		read -rp "Reboot now? [y|N]: " -e -i n REBOOT
done
if [[ $REBOOT == "y" ]]; then reboot; fi


