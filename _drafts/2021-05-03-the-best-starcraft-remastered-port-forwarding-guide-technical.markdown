---
layout: post
title:  "The best starcraft remastered networking guide: technical"
date:   2021-05-03 12:00:00 -0700
---

## Intro
In the previous post we went over a quick and dirty guide to get Starcraft Remastered networking functional. In this post, I will attempt to show the reason behind why the steps in the guide are taken. To understand how Starcraft Remastered networking functions, we first need to learn some fundamental networking concepts.

## The foundation
### IPv4
Starcraft Remastered -- being a 20 year old game -- uses the IPv4 networking standard to send messages between each of the computers running the Starcraft program in a multiplayer game. The [IPv4 standard](https://tools.ietf.org/html/rfc791) defines IP addresses to be a 32 bit field, which is commonly written as four numbers between [0-255] and separated by dots (for example 192.168.1.187 is the IP address of my computer running Starcraft at home).

At home your computer most likely only has a single IPv4 address (you can run `ipconfig` on windows or `ifconfig` on linux or OSX to see it). In some more complex cases a single machine can have multiple IPv4 addresses, but most home machines will only have a single address. The goal of IPv4 is to get messages from one computer to another. Once a computer receives an IPv4 message it needs to know which program that message should be forwarded to (the Starcraft program in this case) which is where UDP comes in.

### UDP
While IPv4 defines communication between **computers** UDP defines communication between **programs**. The [UDP standard](https://tools.ietf.org/html/rfc768) defines UDP ports to be a number between [0-25565]. You can think of a UDP port as the address of a program on a computer. Since IPv4 lets us exchange messages between **computers** and UDP lets us exchange messages between **programs** we can combine the two to allow communication between **programs on different computers**. This is done by embedding the UDP message within the IPv4 message.

![ipv4-udp-embedding](/assets/ipv4-udp-embedding.png)

### NAT
Since IPv4 addresses are 32 bits in length, there are 2^32 different possible IPv4 addresses -- around 4 billion in total. Despite 4 billion sounding like a lot, you have to take into account that 
