---
layout: post
title:  "Linux file system full"
date:   2023-07-30 12:00:00 -0700
---

Recently I did an investigation to figure out why the root file system on a large number of servers was filling up. Typically it is straight forward to figure out what files are filling up the disk -- my tool of choice tends to be ncdu (there is also gdu which is faster but it doesn't appear to be in all distro repositories).

ncdu only finds files which are discoverable by walking the file system, so it will not find temporary files (files opened with O\_TMPFILE) or files which have been deleted but still have an open file descriptor (the traditional/portable way to make tempfiles is to open the file normally and then delete it while keeping the descriptor open).

Here is a simple example of a program which opens a 10GB tempfile (note that O\_TMPFILE is a non-portable GNU extension):
```c
#define _GNU_SOURCE

#include <fcntl.h>
#include <signal.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/types.h>

int main() {
        int tmp_fd = open("/tmp", O_TMPFILE | O_RDWR);
        if (tmp_fd == -1) {
                perror("open()");
                return 1;
        }

        if (fallocate(tmp_fd, /*mode*/ 0, /*offset*/ 0, 10000000000) == -1) {
                perror("fallocate()");
                return 1;
        }
        kill(0, SIGSTOP);
        return 0;
}
```

The tempfile will not be listable by walking the file system, but we can find it using lsof (list open files):
```bash
$ gcc -Wall -Werror tmpfile.c -o tmpfile
$ ./tmpfile 

[1]+  Stopped                 ./tmpfile
$ ls /tmp
config-err-d82IHQ
snap-private-tmp
$ lsof / | grep deleted
tmpfile  74965 elias /tmp/#10879259 (deleted)
```

Usually, when ncdu cannot find the files filling up the disk it is due to deleted files with open file descriptors. A common case is a daemon writing to a deleted file which fills up the disk if the daemon/system is running for a long period of time.

File system journaling/snapshoting may also not be discoverable by walking the file system -- and therefore ncdu. When troubleshooting a full disk it is worth consulting the man pages for the file system to determine when the file system may reserve space for interal use.

Are there other ways the file system may fill up which are not discoverable by walking the file system with ncdu? The answer turns out to be yes, but first we will need a short introduction to loop devices.

[Loop](https://man7.org/linux/man-pages/man4/loop.4.html) devices are block devices backed by a file, opposed to a block device backed by a physical medium such as a hard drive or SSD. Loop devices are commonly used to back the file system of a VM/container as a file on the host system. [losetup](https://man7.org/linux/man-pages/man8/losetup.8.html) is one such tool to interact with loop devices. Despite the name 'losetup' the tool is also used for listing and deleting loop devices as well.

Here is an example of creating a loop device backed by a 10GB file:
```bash
$ fallocate -l 10G /tmp/backing_file
$ sudo losetup -f /tmp/backing_file
$ losetup -j /tmp/backing_file
/dev/loop9: [2050]:10879288 (/tmp/backing_file)
```

Now back to hidden files.

What I discovered is if the backing file for a loop device is deleted the backing file will still exist and take up space on the disk until the corresponding loop device is deleted. The only way to find these files is to list all loop devices and grep for deleted ones:
```bash
$ losetup -j /tmp/backing_file
/dev/loop9: [2050]:10879288 (/tmp/backing_file)
$ rm /tmp/backing_file
$ losetup -a | grep deleted
/dev/loop9: []: (/tmp/backing_file (deleted))
```

This is a particularly nasty way to fill up a disk because it is not shown by listing the file system, it is not shown by lsof, there is no mention of deleted files in the [loop(4)](https://man7.org/linux/man-pages/man4/loop.4.html) and [losetup(8)](https://man7.org/linux/man-pages/man8/losetup.8.html) manpages, and I can not find any mention of loop devices with a deleted backing file anywhere on the internet when searching for possible causes of a full disk. Maybe I am just incompetent, but I would wager 99% of system admins would take a few hours to find this failure mode.

Anyways, maybe google will index this page and we can add this to the pile of possible causes for "linux file system full". 
