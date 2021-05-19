---
layout: post
title:  "Strace magic: finding the damn config file"
date:   2021-05-18 12:00:00 -0700
---

Somebody at work asked me for some help configuring an interactive LaTeX editor -- texmaker. There is documentation online on how to configure texmaker per user (~/.config/xm1/texmaker.ini) but my coworker wanted to configure texmaker globally for all users.

Well behaved UNIX like programs will handle layered configuration like so:
- global configuration (`/etc`)
- user configuration (preferably `$XDG_CONFIG_HOME`, but `~/.config/` and `~/` are used as well)
- environment variables
- command line arguments

Later (more local) settings override earlier (more global) ones which forms a powerful mechanism for [configuring programs in layers](http://www.catb.org/~esr/writings/taoup/html/ch10s02.html).

Back to texmaker. I was able to find documentation for the texmaker user configuration, but there was not one mention anywhere -- stackoverflow, forums, official documentation -- on how to configure texmaker globally.

My next step was to look at the source code. The project is still stuck in the 1990s apparently because there isn't a public VCS system, so I guess we are downloading a tarball:

![tarball](/assets/texmaker-tarball.png)

Lets try a quick grep for `texmaker.ini` because that is what the config file should be named:
```bash
$ grep -r texmaker.ini
texmaker.cpp:QSettings *config=new QSettings(QCoreApplication::applicationDirPath()+"/texmaker.ini",QSettings::IniFormat);
texmaker.cpp:QSettings config(QCoreApplication::applicationDirPath()+"/texmaker.ini",QSettings::IniFormat);
```

It looks like the configuration file paths are hidden behind some QT framework boilerplate which I really don't feel like learning. Grepping for `applicationDirPath()` didn't help me figure out where the path was set.


### Strace to the rescue
Strace is a very useful tool which allows you to watch the program as it executes to see how the program behaves. Using strace, we can see where the texmaker program tries to open configfiles to figure out where we should create a global configuration file. Julia Evans is a strace evangelist, so instead of explaining strace and it's many uses I will direct you to their [strace blog posts](https://jvns.ca/categories/strace/).

Here is the command I used to find the global configuration file location for texmaker:
```bash
strace -e open,openat 2>&1 -- texmaker | grep texmaker.ini
```

Lets break the command down:
1. Run strace and watch to see if the monitored program calls the 'open' or 'openat' system calls.
```bash
strace -e open,openat
```

2. Strace writes to stderr so we redirect stderr to stdout so we can pipe the strace output to grep later.
```bash
2>&1
```

3. The double dash tells strace that everything after the double dash is the command which should be monitored.
```bash
--
```

4. Call texmaker
```bash
texmaker
```

5. Pipe the output of strace and texmaker to grep and search for lines containing 'texmaker.ini' 
```
| grep texmaker.ini
```

Bingo!
```bash
$ strace -e open,openat 2>&1 -- texmaker | grep texmaker.ini
open("/home/elias/.config/xm1/texmaker.ini", O_RDONLY|O_CLOEXEC) = 9
open("/etc/xm1/texmaker.ini", O_RDONLY|O_CLOEXEC) = -1 ENOENT (No such file or directory)
```

You can see that texmaker tries to open the file `/etc/xm1/texmaker.ini` but the file doesn't exist. This is our mystery global configuration file.
