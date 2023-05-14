# Lights

I am using a Libre Computer Le Potato currently:

* [Libre Computer "Le Potato" (AML-S905X-CC) Product Page](https://libre.computer/products/aml-s905x-cc/)
* [Libre Computer "Le Potato" Hub - Resources & Guides](https://hub.libre.computer/t/aml-s905x-cc-le-potato-overview-resources-and-guides/288)
* [Purchase on Amazon: Libre Computer Board AML-S905X-CC by LoveRPi](https://amazon.ca/dp/B074N5B8KZ)

I originally tried to do the build with a Banana Pi M64, but unfortunately their design runs exclusively on 3.3V and doesn't bother to power the 5V pins on the GPIO connector. The relay board (below) requires 5V and thus doesn't function on the Banana Pi M64. It does function on Le Potato, though :-)

As with any Pi type computer, this requires a Micro SD card to act as the "hard drive". I bought this one:

* [Purchase on Amazon: SanDisk 32GB Extreme microSDHC UHS-1](https://amazon.ca/dp/B06XWMQ81P)

In my early attempts with the Banana Pi M64, I encountered problems with it overheating while doing such mundane tasks as compiling code. To combat this, I installed heat sinks:

* [Purchase on Amazon: Enokay 8 Pieces 14x12x5.5mm Cooling Copper Heatsink](https://amazon.ca/dp/B014KKY3KI)

Ultimately, what made the biggest difference was altering the OS's power management policies to `powersave`, which was done by putting the line:

```
GOVERNOR=powersave
```

...into the file `/etc/default/cpufrequtils`. This application doesn't need a blazing-fast computer, and it probably saves a few pennies of electricity to run it slower. :-)

This same configuration can be used with Le Potato.

The lights are controlled with a "hat" with four mains voltage relays on it:

* [Purchase on Amazon: RPi Power Relay Board Expansion Module](https://amazon.ca/dp/B08B681CYD)

In order to avoid aggravating the overheating problem, I purchased an extension cable to allow the relay board to be physically separate from the Banana Pi board:

* [Purchase on Amazon: GPIO Cable 40 Pin Female to Female](https://amazon.ca/dp/B07F128VSW)
* [Purchase on Amazon: IDE 40 Pin Male to Male Hard Drive Adapter](https://amazon.ca/dp/B08XHW7KYC)

Instead of slapping an adapter on a standard Female to Female cable, you can also buy Female to Male 40 Pin cables, but for some reason they are considerably more expensive. The Male-to-Male adapter shown here seems to work just fine.

With all of these bits assembled, the rest is all in software. I installed Armbian 23.02.2, which is linked to from the Le Potato official product page:

* [Armbian for Libre Computer boards](https://www.armbian.com/download/?tx_maker=libre-computer)

The first step was to figure out _how_ to talk to the GPIO pins. I discovered that the most straightforward way to do this, at least on this particular platform, is via the filesystem, which has dev nodes that interact with GPIO.

* GPIO dev nodes live in `/sys/class/gpio`
* Pins need to be "exported" to be interacted with
* Exporting a pin is done by opening the dev node `export` and writing the pin number followed by a newline. The driver responds by exposing that pin in a folder containing dev nodes that is linked to from `/sys/class/gpio/gpioPINNUMBER`
* GPIO pins can be used for input or output. You must explicitly configure the newly-exported pin for output by writing the word "out" to the dev node `direction` in the pin's folder.
* The state of the pin is controlled by writing 0 or 1 to the dev node `value` in the pin's folder. Experimentally, I found that with this relay board, the logic is reversed; a value of 0 turns the relay on, and a value of 1 turns the relay off.

With some trial and error, I identified the GPIO pin numbers corresponding to the four relays:

* Relay 0: Pin PL8, pin #360
* Relay 1: Pin PL7, pin #359
* Relay 2: Pin PL12, pin #364
* Relay 3: Pin PB6, pin #38

This information is encapsulated in the `pins` subdirectory in this repository.

I created an initialization script that, run as root, exports these four pins. This is in the `init` subdirectory in this repository. I configured this script to run on system startup by referencing it from `/etc/rc.local`.

Then I created a straightforward abstraction of the control mechanism, which is in the `control` subdirectory in this repository. The `on` and `off` scripts take a relay number and do all the necessary translation internally to control the corresponding pin. For instance, `on 1` turns on relay #1, which, behind the scenes, means that it sets the value of pin PL7 to 0.

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