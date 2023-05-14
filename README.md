# Lights

I am using a Libre Computer Le Potato currently:

* [Libre Computer "Le Potato" (AML-S905X-CC) Product Page](https://libre.computer/products/aml-s905x-cc/)
* [Libre Computer "Le Potato" Hub - Resources & Guides](https://hub.libre.computer/t/aml-s905x-cc-le-potato-overview-resources-and-guides/288)
* [Purchase on Amazon: Libre Computer Board AML-S905X-CC by LoveRPi](https://amazon.ca/dp/B074N5B8KZ)

I originally tried to do the build with a Banana Pi M64, but unfortunately their design runs exclusively on 3.3V and doesn't bother to power the 5V pins on the GPIO connector. The relay board (below) requires 5V and thus doesn't function on the Banana Pi M64. It does function on Le Potato, though :-)

As with any Pi type computer, this requires a Micro SD card to act as the "hard drive". I bought this one:

* [Purchase on Amazon: SanDisk 32GB Extreme microSDHC UHS-1](https://amazon.ca/dp/B06XWMQ81P)

The Le Potato does not have an integrated Wi-Fi adapter. This USB device seems to do the trick:

* [Purchase on Amazon: Mini USB WiFi Adapter 300mbps 2.4GHz](https://amazon.ca/gp/product/B07FDQ217P)

In my early attempts with the Banana Pi M64, I encountered problems with it overheating while doing such mundane tasks as compiling code. To combat this, I installed heat sinks:

* [Purchase on Amazon: Enokay 8 Pieces 14x12x5.5mm Cooling Copper Heatsink](https://amazon.ca/dp/B014KKY3KI)

Even with heat sinks, the Banana Pi would consistently overheat with the default governor, which defaulted to `performance`. Changing the M64's governor to `powersave` was what finally solved the overheating problem. However, Le Potato's default governor is the more conservative `ondemand`, and it does not seem to have the heat problems of the M64 with the default configuration. (Ubuntu doesn't come with `cpufrequtils` installed. But, it is easy to install with `apt`.)

The lights are controlled with a "hat" with four mains voltage relays on it:

* [Purchase on Amazon: RPi Power Relay Board Expansion Module](https://amazon.ca/dp/B08B681CYD)

In order to avoid aggravating the overheating problem, I purchased an extension cable to allow the relay board to be physically separate from the Banana Pi board:

* [Purchase on Amazon: GPIO Cable 40 Pin Female to Female](https://amazon.ca/dp/B07F128VSW)
* [Purchase on Amazon: IDE 40 Pin Male to Male Hard Drive Adapter](https://amazon.ca/dp/B08XHW7KYC)

Instead of slapping an adapter on a standard Female to Female cable, you can also buy Female to Male 40 Pin cables, but for some reason they are considerably more expensive. The Male-to-Male adapter shown here seems to work just fine.

With all of these bits assembled, the rest is all in software. I installed Ubuntu 22.04.1, which is linked to from the Le Potato official product page:

* [Ubuntu for Libre Computer boards](https://distro.libre.computer/ci/ubuntu/22.04/)

Basic configuration of the OS:

* `dpkg-reconfigure console-setup` to change the font. (The largest possible font makes it much easier to use when it's up on a TV screen across the room.)
* `timedatectl set-timezone America/Winnipeg` sets the correct timezone. This appears to persist across reboots.
* Listing files in `/sys/class/net` identifies the name of the Wi-Fi adapter. In this case, `wlx3420032e4801`. I assume that's a MAC address or something, so yours will likely be completely different.
* Network configuration in `/etc/netplan/50-cloud-init.yaml`:

```
network:
  wifis:
    wlx3420032e4801:
      optional: true
      access-points:
        "Name of network":
          password: "password"
      dhcp4: true
```

* Installation of PowerShell by downloading the package from Microsoft's GitHub releases.
  * At the time of writing this, the latest release is 7.3.4, at the following URL:
    * `https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/powershell-7.3.4-linux-arm64.tar.gz`
  * Installation:
```
mkdir /powershell
cd /powershell
tar zvfx /tmp/powershell-7.3.4-linux-arm64.tar.gz
```

* This repository: `cd / ; git clone https://github.com/logiclrd/lights`
* User account to run the `lights` service: `adduser lights`
* Grant the `lights` user access to GPIO: `usermod -a -G dialout lights`

On the software side, the first step was to figure out _how_ to talk to the GPIO pins.

On the Banana Pi M64, the most straightforward way to do this seems to be via the filesystem, which has dev nodes that interact with GPIO. However, on the Libre Computer device, this interface is officially deprecated, and instead they would like you to use `gpioset`, which comes installed as part of the `gpiod` package.

With some trial and error, I identified the GPIO pin numbers corresponding to the four relays:

* Relay 0: Pin 83
* Relay 1: Pin 82
* Relay 2: Pin 84
* Relay 3: Pin 86

(I noticed after setting up this mapping and doing the wiring that the silkscreen on the board lists "LED1" through "LED4" in the _opposite_ order. Oh well :-) )

The mapping of relay numbers (0..3) to pin numbers is encapsulated in the `pins` subdirectory in this repository.

Then I created a straightforward abstraction of the control mechanism, which is in the `control` subdirectory in this repository. The `on` and `off` scripts take a relay number and do all the necessary translation internally to control the corresponding pin. For instance, `on 1` turns on relay #1, which, behind the scenes, means that it sets the value of pin #82 to 0.

Finally, the actual scheduling engine was written using PowerShell. The current shebang line assumes a PowerShell installation in `/powershell`. The schedule is defined in a custom-format text file `schedule.txt` in the `schedule` subdirectory, and the script `Run-Schedule.ps1` reads this file in and processes it, turning it into invocations of `control/on` and `control/off`.

The scheduling engine `Run-Schedule.ps1` is invoked using `systemctl`. A definition for a `systemctl` service was created, and a copy of it is committed to this repository in the `systemctl` subdirectory. I created a regular user `lights` to run the persistent script, and the `init` script updates the permission bits on the `value` dev nodes so that code doesn't need to be `root` to control the lights.

You can inspect the current state of the `lights` service with the command:

```
systemctl status lights
```

The output of this command includes the log tail, and the log tail includes the basic diagnostic output from the `RunSchedule.ps1` scheduling engine, e.g.:

```
Feb 15 14:53:49 bananapim64 RunSchedule.ps1[4019]: Current time: 02/15/2023 14:53:49
Feb 15 14:53:49 bananapim64 RunSchedule.ps1[4019]: Next switch: Turn light # 0 to the ON state at 02/15/2023 15:00:00
Feb 15 14:53:49 bananapim64 RunSchedule.ps1[4019]: Sleeping for 5 minutes
Feb 15 14:58:49 bananapim64 RunSchedule.ps1[4019]: Current time: 02/15/2023 14:58:49
Feb 15 14:58:49 bananapim64 RunSchedule.ps1[4019]: Next switch: Turn light # 0 to the ON state at 02/15/2023 15:00:00
Feb 15 14:58:49 bananapim64 RunSchedule.ps1[4019]: Sleeping for 71 seconds
Feb 15 15:00:00 bananapim64 RunSchedule.ps1[4019]: Sending control ON to 0
Feb 15 15:00:00 bananapim64 RunSchedule.ps1[4019]: Current time: 02/15/2023 15:00:00
Feb 15 15:00:00 bananapim64 RunSchedule.ps1[4019]: Next switch: Turn light # 2 to the ON state at 02/15/2023 18:00:00
Feb 15 15:00:00 bananapim64 RunSchedule.ps1[4019]: Sleeping for 90 minutes
```

I investigated NTP time synchronization as well, because I'm not sure how reliable the wall clock is on a Banana Pi M64, but I've decided to give it the benefit of the doubt. The NTP synchronization code is committed to the repository but I'm not currently using it.

Finally, this all needs to go into a case. [That's a different project](https://github.com/logiclrd/OpenSCADDesigns/tree/main/Light%20Controller%20Case), involving OpenSCAD and a 3D printer. :-)