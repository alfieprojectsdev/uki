---
title: "USB token authentication on Linux"
source: "https://linuxconfig.org/linux-authentication-login-with-usb-device"
author:
  - "[[Luke Reynolds]]"
published: 2021-12-20
created: 2026-03-10
description: "Learn how to set up USB authentication on Linux using PAM. Secure login with USB tokens, and configure two-factor authentication effortlessly."
tags:
  - "clippings"
---
This article describes a method how to use a USB memory device as an authentication token to log in into a Linux system instead of traditional password. This can be accomplished by use of Pluggable Authentication Modules ( PAM ) and some sort of USB storage device such as USB memory stick of Mobile phone with SD card attached.

This authentication technique can be also further expanded into Two-Factor authentication where two authentication methods involving USB token and one-time password can be merged together to produce a greater security. This article is written using Ubuntu Linux systems. However, users of other Linux distributions should be able to follow below described steps to achieve the same results.

**In this tutorial you will learn:**

- How to install PAM USB authentication on major Linux distros
- How to configure login with USB stick
![USB token authentication on Linux](https://linuxconfig.org/wp-content/uploads/2013/03/01-linux-authentication-login-with-usb-device.avif)

USB token authentication on Linux

| Category | Requirements, Conventions or Software Version Used |
| --- | --- |
| System | Any [Linux system](https://linuxconfig.org/linux-download) |
| Software | pam\_usb |
| Other | Privileged access to your Linux system as root or via the `sudo` command. |
| Conventions | **#** – requires given [linux commands](https://linuxconfig.org/linux-commands) to be executed with root privileges either directly as a root user or by use of `sudo` command   **$** – requires given [linux commands](https://linuxconfig.org/linux-commands) to be executed as a regular non-privileged user |

## Install PAM authentication on major Linux distros

---

---


The `pam_usb` software, once widely available for installation on any major Linux distro, no longer exists in any package repositories. However, it is [maintained on GitHub](https://github.com/mcdope/pam_usb). We will be using this version to setup PAM authentication for our USB stick.

The first thing we need to do is install the prerequisites for `pam_usb`, and then download the program and compile it on our system.

You can use the appropriate command below to install the `pam_usb` prerequisites with your system’s [package manager](https://linuxconfig.org/comparison-of-major-linux-package-management-systems).

To install the `pam_usb` prerequisites on [Ubuntu](https://linuxconfig.org/ubuntu-linux-download), [Debian](https://linuxconfig.org/debian-linux-download), and [Linux Mint](https://linuxconfig.org/linux-mint-download):

```
$ sudo apt install git libxml2-dev libpam0g-dev libudisks2-dev libglib2.0-dev gir1.2-udisks-2.0 python3 python3-gi
```

To install the `pam_usb` prerequisites on [Fedora](https://linuxconfig.org/fedora-linux-download), [CentOS](https://linuxconfig.org/centos-linux-download), [AlmaLinux](https://linuxconfig.org/almalinux-download), and [Red Hat](https://linuxconfig.org/red-hat-linux-download):

```
$ sudo dnf install git libxml2-devel pam-devel libudisks2-devel glib2-devel python3-gobject
```

Next, we will clone the `pam_usb` GitHub repository and compile the code to install it.

```
$ git clone https://github.com/mcdope/pam_usb.git
$ cd pam_usb/
$ make
$ sudo make install
```

## Add USB device to PAM configuration

In the next step, we will add a USB device which we intend to use with PAM authentication. This can be done with a `pamusb-conf` command or manually by editing `/etc/pamusb.conf` file. Using the `pamusb-conf` command greatly reduces time and difficulty of this operation. Connect your USB device and execute a following [linux command](https://linuxconfig.org/linux-commands) with the name of your USB device as an argument. The name can be anything you wish. In this case, we use “my-usb-stick”:

```
$ sudo pamusb-conf --add-device my-usb-stick
Please select the device you wish to add.
* Using "Verbatim STORE N GO (Verbatim_STORE_N_GO_07A10D0894492625-0:0)" (only option)

Which volume would you like to use for storing data ?
0) /dev/sdb2 (UUID: A842-0654)
1) /dev/sdb1 (UUID: CAAF-0882)

[0-1]: 0

Name            : my-usb-stick
Vendor          : Verbatim
Model           : STORE N GO
Serial          : Verbatim_STORE_N_GO_07A10D0894492625-0:0
UUID            : A842-0654

Save to /etc/pamusb.conf ?
[Y/n] Y
Done.
```

The `pamusb-conf` is smart enough to discover our USB device, including multiple partitions. After completing this step a block of XML code had been added into the `/etc/pamusb.conf` configuration file to define our USB device.

```
Verbatim


            STORE N GO


            Verbatim_STORE_N_GO_07A10D0894492625-0:0


            A842-0654
```

## Define a user for PAM authentication

---

---


It is obvious, but it should be mentioned that we can add several USB devices into PAM configuration, and at the same time we can define multiple users for one or more USB devices. In our example, we will keep things straightforward by defining a USB device to be used as credentials by a single user. If the user “ubuntu-user” exists on our system, we can add him to PAM configuration with a following linux command:
```
$ sudo pamusb-conf --add-user ubuntu-user
Which device would you like to use for authentication ?
* Using "my-usb-stick" (only option)

User            : ubuntu-user
Device          : my-usb-stick

Save to /etc/pamusb.conf ?
[Y/n] y
Done.
```

Definition of a `pam_usb` user had been added into into `/etc/pamusb.conf` configuration:

```
my-usb-stick
```

## Configure PAM to use pam\_usb library

At this point, we have defined a USB device “my-usb-stick” to be used as an authentication credential for a user “ubuntu-user”. However, the system wide PAM library is not aware of the `pam_usb` module yet. To add `pam_usb` into a system authentication process, we need to edit the `/etc/pam.d/common-auth` file.

NOTE: If you are using RedHat or Fedora Linux system this file can be known as `/etc/pam/system-auth`. Your default PAM common-auth configuration should include a following line:

```
auth    required        pam_unix.so nullok_secure
```

This is a current standard which uses `/etc/passwd` and `/etc/shadow` to authenticate a user. The “required” option means that the correct password must be supplied in order the user will be granted access to the system. Alter your configuration to:

NOTE: Before you do any changes to `/etc/pam.d/common-auth`, open up a separate terminal with root access. This is just in case that something goes wrong, and you need a root access to change `/etc/pam.d/common-auth` back to the original configuration.

```
auth    sufficient      pam_usb.so
auth    required        pam_unix.so nullok_secure
```

At this point, user “ubuntu-user” can authenticate with its relevant USB device pluged-in. This is defined by a “sufficient” option for pam\_usb library.

```
$ su ubuntu-user
* pam_usb v0.4.2
* Authentication request for user "ubuntu-user" (su)
* Device "my-usb-stick" is connected (good).
* Performing one time pad verification...
* Regenerating new pads...
* Access granted.
```

NOTE: If you get an error:

```
Error: device /dev/sdb1 is not removable
* Mount failed
```

Normally this error should not happen however as a temporary solution add a full path to your block USB device into /etc/pmount.allow. For example if a login error or command:

```
$ sudo fdidk -l
```

listed my USB device and partition as /dev/sdb1, add a line:

```
/dev/sdb1
```

into `/etc/pmount.allow` to solve this problem. This is just a temporary solution as your USB device can be recognized differently every time it is connected to the system. In this case one solution can be to write USB udev rules.

In case the USB device defined for a “ubuntu-user” is not present in the system the user will need to enter a correct password. To force user have both authentication routines in place before granting an access to the system change a “sufficient” to “required”:

```
auth    required      pam_usb.so
auth    required        pam_unix.so nullok_secure
```

---

---


Now the user will need to enter a correct password as well as insert USB device.
```
$ su ubuntu-user
* pam_usb v0.4.2
* Authentication request for user "ubuntu-user" (su)
* Device "my-usb-stick" is connected (good).
* Performing one time pad verification...
* Access granted.
Password:
```

Let’s test it with USB device unplugged and correct password:

```
$ su ubuntu-user
* pam_usb v0.4.2
* Authentication request for user "ubuntu-user" (su)
* Device "my-usb-stick" is not connected.
* Access denied.
Password:
su: Authentication failure
```

## USB device event and pam\_usb

In addition to USB user authentication a USB device event can be defined to be triggered every time a user disconnect or connect USB device from a system. For example, `pam_usb` can lock a screen when a user disconnects USB device and unlock it again when a user connects USB device. This can be accomplished by a simple modification of user definition XML code block in `/etc/pamusb.conf` file.

## Closing Thoughts

In this tutorial, we saw how to install the `pam_usb` package on a Linux system, and use PAM authentication to configure login access to a USB thumb drive. This is a great alternative to typing a password in every time you need to login, and can be more secure, too.

---

---

**Comments and Discussions**
![Linux Forum](https://linuxconfig.org/wp-content/uploads/2024/04/linuxconfig-forum-logo-1.webp)
