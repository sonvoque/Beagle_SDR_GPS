#!/bin/sh
# wrapper for running the KiwiSDR app

CMD=$(basename $0)
case ${CMD} in
	"k")
		ARGS="+gps $*"
		;;
	"ng")
		ARGS="-gps $*"
		;;
	"g")
		ARGS="+gps -sdr -stats $*"
		;;
	"n")
		ARGS="-gps -sdr $*"
		;;
esac

# hack to see if we're running on a BBB
if test ! -f /etc/dogtag; then
	kiwi.bin ${ARGS}
	exit 0
fi

# Debian 7, PIO: load our cape-bone-S overlay via echo > slots
# Debian 7, SPIDEV: BB-SPIDEV0 loaded via echo > slots
# Debian 8, PIO: load our cape-bone-S overlay via echo > slots
# Debian 8, SPIDEV: Bug: BB-SPIDEV0 must be loaded via /boot/uEnv.txt to config pmux properly

USE_SPIDEV=1

SLOTS="/sys/devices/platform/bone_capemgr/slots"
if test ! -f ${SLOTS} ; then
	echo DEBIAN 7
	# do not use USE_SPIDEV on Debian 7
	USE_SPIDEV=0
	LOAD_SPIDEV=yes
	LOAD_SPIPIO=yes
	SLOTS=`ls /sys/devices/bone_capemgr.*/slots`
else
	echo DEBIAN 8
	LOAD_SPIDEV=no
	LOAD_SPIPIO=no
fi

DEV=kiwi
DEVID=cape-bone-${DEV}

if [ "x${USE_SPIDEV}" = "x1" ] ; then
	# use SPIDEV driver (with built-in DMA) for SPI:
	echo USE_SPIDEV
	DEV_SPI=SPIDEV0
	DEVID_SPI=BB-${DEV_SPI}
	LOAD_SPI=${LOAD_SPIDEV}
else
	echo USE_SPIPIO
	DEV_SPI=${DEV}-S
	DEVID_SPI=cape-bone-${DEV_SPI}
	LOAD_SPI=${LOAD_SPIPIO}
fi

echo LOAD_SPI = ${LOAD_SPI}

DEV_PRU=${DEV}-P
DEVID_PRU=cape-bone-${DEV_PRU}

CAPE=${DEVID}-00A0
SPI=${DEVID_SPI}-00A0
PRU=${DEVID_PRU}-00A0

# cape
if test \( ! -f /lib/firmware/${CAPE}.dtbo \) -o \( /lib/firmware/${CAPE}.dts -nt /lib/firmware/${CAPE}.dtbo \) ; then
	echo compile ${DEV} device tree;
	(cd /lib/firmware; dtc -O dtb -o ${CAPE}.dtbo -b 0 -@ ${CAPE}.dts);
# don't unload old slot because this is known to cause panics; must reboot
fi

if ! grep -q ${DEVID} ${SLOTS} ; then
	echo load ${DEV} device tree;
	echo ${DEVID} > ${SLOTS};
fi

# SPI
if test \( -f /lib/firmware/${SPI}.dts \) -a \( \( ! -f /lib/firmware/${SPI}.dtbo \) -o \( /lib/firmware/${SPI}.dts -nt /lib/firmware/${SPI}.dtbo \) \) ; then
	echo compile ${DEV_SPI} device tree;
	(cd /lib/firmware; dtc -O dtb -o ${SPI}.dtbo -b 0 -@ ${SPI}.dts);
# don't unload old slot because this is known to cause panics; must reboot
fi

if [ "x${LOAD_SPI}" = "xyes" ] ; then
	if ! grep -q ${DEVID_SPI} ${SLOTS} ; then
		echo load ${DEV_SPI} device tree;
		echo ${DEVID_SPI} > ${SLOTS};
	fi
fi

# PRU (future)
if test \( ! -f /lib/firmware/${PRU}.dtbo \) -o \( /lib/firmware/${PRU}.dts -nt /lib/firmware/${PRU}.dtbo \) ; then
	echo compile ${DEV_PRU} device tree;
	(cd /lib/firmware; dtc -O dtb -o ${PRU}.dtbo -b 0 -@ ${PRU}.dts);
# don't unload old slot because this is known to cause panics; must reboot
fi

if ! grep -q ${DEVID_PRU} ${SLOTS} ; then
	echo load ${DEV_PRU} device tree;
	echo ${DEVID_PRU} > ${SLOTS};
fi

kiwi.bin -use_spidev ${USE_SPIDEV} ${ARGS}
