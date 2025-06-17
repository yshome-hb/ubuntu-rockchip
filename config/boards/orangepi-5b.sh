# shellcheck shell=bash

export BOARD_NAME="Orange Pi 5B"
export BOARD_MAKER="Xulong"
export BOARD_SOC="Rockchip RK3588S"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="orangepi-5b-rk3588s"
export COMPATIBLE_SUITES=("jammy" "noble" "oracular" "plucky")
export COMPATIBLE_FLAVORS=("server" "desktop")

function config_image_hook__orangepi-5b() {
    local rootfs="$1"
    local overlay="$2"
    local suite="$3"

    if [ "${suite}" == "jammy" ] || [ "${suite}" == "noble" ]; then
        # Install panfork
        chroot "${rootfs}" add-apt-repository -y ppa:jjriek/panfork-mesa
        chroot "${rootfs}" apt-get update
        chroot "${rootfs}" apt-get -y install mali-g610-firmware
        chroot "${rootfs}" apt-get -y dist-upgrade

        # Install libmali blobs alongside panfork
        chroot "${rootfs}" apt-get -y install libmali-g610-x11

        # Install the rockchip camera engine
        chroot "${rootfs}" apt-get -y install camera-engine-rkaiq-rk3588

        # Enable bluetooth for AP6275P
        mkdir -p "${rootfs}/usr/lib/scripts"
        cp "${overlay}/usr/lib/systemd/system/ap6275p-bluetooth.service" "${rootfs}/usr/lib/systemd/system/ap6275p-bluetooth.service"
        cp "${overlay}/usr/lib/scripts/ap6275p-bluetooth.sh" "${rootfs}/usr/lib/scripts/ap6275p-bluetooth.sh"
        cp "${overlay}/usr/bin/brcm_patchram_plus" "${rootfs}/usr/bin/brcm_patchram_plus"
        chroot "${rootfs}" systemctl enable ap6275p-bluetooth

        # Enable USB 2.0 port
        cp "${overlay}/usr/lib/systemd/system/enable-usb2.service" "${rootfs}/usr/lib/systemd/system/enable-usb2.service"
        chroot "${rootfs}" systemctl --no-reload enable enable-usb2

        # Install wiring orangepi package 
        chroot "${rootfs}" apt-get -y install wiringpi-opi libwiringpi2-opi libwiringpi-opi-dev
        echo "BOARD=orangepi5" > "${rootfs}/etc/orangepi-release"

        cp -r ../packages/adb/rockchip-adbd.deb ${rootfs}/tmp
        chroot "${rootfs}" dpkg -i /tmp/rockchip-adbd.deb
        echo "BUILD_ID=$(date +'%Y-%m-%d')" >> "${rootfs}/etc/os-release"

    cat << EOF | chroot "${rootfs}"
export DEBIAN_FRONTEND=noninteractive
export LANG=zh_CN.UTF-8

/usr/sbin/oem-config-remove
userdel --force --remove oem || true
systemctl set-default graphical.target || true
systemctl disable oem-config.service || true
systemctl disable oem-config.target || true
rm -f /lib/systemd/system/oem-config.* || true

sed -i 's/^# *\(zh_CN.UTF-8\)/\1/' /etc/locale.gen
echo "LANG=zh_CN.UTF-8" > /etc/default/locale
dpkg-reconfigure locales

useradd haibox -m -u 1000 -s /bin/bash -G sudo,netdev,audio,video,disk,tty,users,games,dialout,plugdev,input,bluetooth,systemd-journal,render
(
echo "111111"
echo "111111"
) | passwd "root" > /dev/null 2>&1

(
echo "111111"
echo "111111"
) | passwd "haibox" > /dev/null 2>&1


sed -i -r \
    -e "s/^#[ ]*AutomaticLoginEnable =.*\$/AutomaticLoginEnable=true/" \
    -e "s/^#[ ]*AutomaticLogin =.*\$/AutomaticLogin=haibox/" \
    /etc/gdm3/custom.conf

ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
echo "Asia/Shanghai" >/etc/timezone
echo "haibox-ubuntu" >/etc/hostname

echo "127.0.0.1   localhost
127.0.1.1   haibox-ubuntu
::1         localhost haibox-ubuntu ip6-localhost ip6-loopback
fe00::0     ip6-localnet
ff00::0     ip6-mcastprefix
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters" > /etc/hosts

EOF
    fi

    return 0
}
