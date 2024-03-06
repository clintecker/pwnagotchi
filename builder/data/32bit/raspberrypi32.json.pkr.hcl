packer {
  required_plugins {
    arm = {
      version = "1.0.0"
      source  = "github.com/cdecoux/builder-arm"
    }
    ansible = {
      source  = "github.com/hashicorp/ansible"
      version = ">= 1.1.1"
    }
  }
}

variable "pwn_hostname" {
  type = string
}

variable "pwn_version" {
  type = string
}

source "arm" "rpi32-pwnagotchi" {
  file_checksum_url             = "https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2023-12-06/2023-12-05-raspios-bullseye-armhf-lite.img.xz.sha256"
  file_urls                     = ["https://downloads.raspberrypi.com/raspios_oldstable_lite_armhf/images/raspios_oldstable_lite_armhf-2023-12-06/2023-12-05-raspios-bullseye-armhf-lite.img.xz"]
  file_checksum_type            = "sha256"
  file_target_extension         = "xz"
  file_unarchive_cmd            = ["unxz", "$ARCHIVE_PATH"]
  image_path                    = "../../pwnagotchi-32bit.img"
  qemu_binary_source_path       = "/usr/libexec/qemu-binfmt/arm-binfmt-P"
  qemu_binary_destination_path  = "/usr/libexec/qemu-binfmt/arm-binfmt-P"
  image_build_method            = "resize"
  image_size                    = "15G"
  image_type                    = "dos"
  image_partitions {
    name         = "boot"
    type         = "c"
    start_sector = "8192"
    filesystem   = "fat"
    size         = "256M"
    mountpoint   = "/boot"
  }
  image_partitions {
    name         = "root"
    type         = "83"
    start_sector = "532480"
    filesystem   = "ext4"
    size         = "0"
    mountpoint   = "/"
  }
}
build {
  name = "Raspberry Pi 32 Pwnagotchi"
  sources = ["source.arm.rpi32-pwnagotchi"]
  
  provisioner "shell" {
    inline = [
      "sed -i '/en_US.UTF-8/s/^#//g' /etc/locale.gen", // Uncomment the en_US.UTF-8 line
      "locale-gen", // Generate the locale
      "update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8", // Set the default system locale
      "timedatectl set-timezone UTC", // Set the timezone to UTC
    ]
  }
  
  provisioner "file" {
    destination = "/usr/bin/"
    sources     = [
      "data/32bit/usr/bin/bettercap-launcher",
      "data/32bit/usr/bin/hdmioff",
      "data/32bit/usr/bin/hdmion",
      "data/32bit/usr/bin/monstart",
      "data/32bit/usr/bin/monstop",
      "data/32bit/usr/bin/pwnagotchi-launcher",
      "data/32bit/usr/bin/pwnlib",
    ]
  }

  provisioner "shell" {
    inline = ["chmod +x /usr/bin/*"]
  }

  provisioner "file" {
    destination = "/etc/systemd/system/"
    
    sources     = [
      "data/32bit/etc/systemd/system/bettercap.service",
      "data/32bit/etc/systemd/system/pwnagotchi.service",
      "data/32bit/etc/systemd/system/pwngrid-peer.service",
    ]
  }
  provisioner "file" {
    destination = "/etc/update-motd.d/01-motd"
    source      = "data/32bit/etc/update-motd.d/01-motd"
  }
  provisioner "shell" {
    inline = ["chmod +x /etc/update-motd.d/*"]
  }
  provisioner "shell" {
    inline = ["apt-get -y --allow-releaseinfo-change update", "apt-get -y dist-upgrade", "apt-get install -y --no-install-recommends ansible"]
  }
  

  provisioner "file" {
    source      = "../../pwnagotchi"
    destination = "/usr/local/src/pwnagotchi"
  }

  provisioner "ansible-local" {
    command         = "ANSIBLE_FORCE_COLOR=1 PYTHONUNBUFFERED=1 PWN_VERSION=${var.pwn_version} PWN_HOSTNAME=${var.pwn_hostname} ansible-playbook"
    extra_arguments = ["--extra-vars \"ansible_python_interpreter=/usr/bin/python3\""]
    playbook_dir    = "data/32bit/extras/"
    playbook_file   = "data/32bit/raspberrypi32.yml"
  }
}
