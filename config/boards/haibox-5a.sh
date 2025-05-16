# shellcheck shell=bash

export BOARD_NAME="HaiBox 5A"
export BOARD_MAKER="Microduino"
export BOARD_SOC="Rockchip RK3588S"
export BOARD_CPU="ARM Cortex A76 / A55"
export UBOOT_PACKAGE="u-boot-radxa-rk3588"
export UBOOT_RULES_TARGET="haibox-5a-rk3588s"
export COMPATIBLE_SUITES=("jammy" "noble")
export COMPATIBLE_FLAVORS=("server" "desktop")

function config_image_hook__haibox-5a() {
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

        # shellcheck disable=SC2016
        echo 'SUBSYSTEM=="net", ACTION=="add", ATTR{address}=="88:00:*", NAME="$ENV{ID_NET_SLOT}"' > "${rootfs}/etc/udev/rules.d/99-radxa-aic8800.rules"

        # Enable the on-board bluetooth module AIC8800
        mkdir -p "${rootfs}/usr/lib/scripts/"
        cp "${overlay}/usr/bin/bt_test" "${rootfs}/usr/bin/bt_test"
        cp -r "${overlay}/lib/firmware/aic8800/SDIO/aic8800D80" "${rootfs}/usr/lib/firmware/aic8800/SDIO/"
        cp "${overlay}/usr/lib/scripts/aic8800-bluetooth.sh" "${rootfs}/usr/lib/scripts/aic8800-bluetooth.sh"
        cp "${overlay}/usr/lib/systemd/system/aic8800-bluetooth.service" "${rootfs}/usr/lib/systemd/system/aic8800-bluetooth.service"
        chroot "${rootfs}" systemctl enable aic8800-bluetooth

        # Install zh-hans language pack
        chroot "${rootfs}" apt-get -y install language-pack-zh-hans

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
