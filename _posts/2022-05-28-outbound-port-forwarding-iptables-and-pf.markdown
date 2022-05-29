---
layout: post
title:  "Outbound port rewriting, iptables, and pf"
date:   2022-05-28 12:00:00 -0700
---

I recently did an investigation on two different network address translation systems which are commonly used: iptables (Linux) and pf (BSD). What I discovered is that iptables and pf have different default policies for source port modification during NAT traversal. The difference of defaults can have subtle effects when serving UDP traffic from behind a NAT.

A quick refresher on NAT. To expand the pool of routable IPv4 addresses, NAT allows "hiding" multiple [RFC 1918](https://datatracker.ietf.org/doc/html/rfc1918) private addresses behind a publicly routable IPv4 address. We will focus on the behaviour of NAT when packets traverse from the private address space out to the publicly routable IPv4 address space. For brevity, I will refer to an "IPv4 address" as an "IP".

At its most basic function, the NAT will overwrite the src\_ip of the outgoing packet to the public IP of the NAT device. This allows replies to be sent back to the publicly routable IP of the NAT device and forwarded to the requestor in the private IP space.

![img](/assets/nat_preserve_port.svg)

The NAT is also given discretion to overwrite the src\_port of the outgoing packet.

![img](/assets/nat_overwrite_port.svg)

The default policy for iptables is to preserve the src\_port number as long as there is not another conflicting connection. If there is a conflicting connection the src\_port of the outgoing packet is overwritten with a random port number. If iptables passes the NF\_NAT\_RANGE\_PROTO\_RANDOM\_ALL flag then a random port is always selected and source port numbers are not preserved. By default, iptables does not pass the NF\_NAT\_RANGE\_PROTO\_RANDOM\_ALL flag which means that the source port is preserved by default. [get\_unique\_tuple()](https://github.com/torvalds/linux/blob/e243f39685af1bd6d837fa7bff40c1afdf3eb7fa/net/netfilter/nf_nat_core.c#L504) defines the source port modification logic for iptables:
```c
if (maniptype == NF_NAT_MANIP_SRC &&
    !(range->flags & NF_NAT_RANGE_PROTO_RANDOM_ALL)) {
	/* try the original tuple first */
	if (in_range(orig_tuple, range)) {
		if (!nf_nat_used_tuple(orig_tuple, ct)) {
			*tuple = *orig_tuple;
			return;
		}
	} else if (find_appropriate_src(net, zone,
					orig_tuple, tuple, range)) {
		pr_debug("get_unique_tuple: Found current src map\n");
		if (!nf_nat_used_tuple(tuple, ct))
			return;
	}
}
```

The default policy for pf is to randomize the src\_port number of outgoing packets. When a 'static-port' rule is set, pfctl will set the low and high to 0 which enables source port preservation for that rule. [pf\_get\_sport()](https://github.com/openbsd/src/blob/308aaa404019ba82df3af9e8a13d726fb603ecb2/sys/net/pf_lb.c#L149) defines the source port modification logic for pf:
```c
if (!(pd->proto == IPPROTO_TCP || pd->proto == IPPROTO_UDP ||
    pd->proto == IPPROTO_ICMP || pd->proto == IPPROTO_ICMPV6)) {
	/* for non TCP, UDP, or ICMP packets the source port
         * is not overwritten. */
	key.port[sidx] = pd->nsport;
	if (pf_find_state_all(&key, dir, NULL) == NULL) {
		*nport = pd->nsport;
		return (0);
	}
} else if (low == 0 && high == 0) {
	/* if low == high == 0 we preserve the source port.
         * pfctl will set low == high == 0 when the 'static-port'
         * argument is specified in a rule. */
	key.port[sidx] = pd->nsport;
	if (pf_find_state_all(&key, dir, NULL) == NULL) {
		*nport = pd->nsport;
		return (0);
	}
} else if (low == high) {
        /* if low == hight we just set the source port to
         * the only available number */
	key.port[sidx] = htons(low);
	if (pf_find_state_all(&key, dir, NULL) == NULL) {
		*nport = htons(low);
		return (0);
	}
} else {
        /* for all other cases we randomize the port number
         * using arc4random_uniform() */
	u_int32_t tmp;

	if (low > high) {
		tmp = low;
		low = high;
		high = tmp;
	}
	/* low < high */
	cut = arc4random_uniform(1 + high - low) + low;
	/* low <= cut <= high */
	for (tmp = cut; tmp <= high && tmp <= 0xffff; ++tmp) {
		key.port[sidx] = htons(tmp);
		if (pf_find_state_all(&key, dir, NULL) ==
		    NULL && !in_baddynamic(tmp, pd->proto)) {
			*nport = htons(tmp);
			return (0);
		}
	}
	tmp = cut;
	for (tmp -= 1; tmp >= low && tmp <= 0xffff; --tmp) {
		key.port[sidx] = htons(tmp);
		if (pf_find_state_all(&key, dir, NULL) ==
		    NULL && !in_baddynamic(tmp, pd->proto)) {
			*nport = htons(tmp);
			return (0);
		}
	}
}
```	

What are the practical differences between always randomizing the source port (pf) and trying to retain the original source port (iptables)? When I [asked the OpenBSD misc list](https://marc.info/?l=openbsd-misc&m=165268931324273&w=2) why pf randomizes source ports by default, the answer I got was non-suprisingly "security". Apparently there are connection hijacking/termination exploits which become much harder to implement when source ports are randomized. I don't have too much experience with these exploits, but I do know that some devices use predictable port sequences when creating client connections. If an attacker can identify the device and knows the predictable port sequence they can send packets to connections which they do not own. For example an attacker could send a TCP FIN packet to terminate a connection it does not own. Randomizing the source port during NAT traversal makes it nearly impossible for an attacker to guess port numbers of connections it does not own, mitigating these attacks.

Preserving the port number by default does have some advantages, however. Retaining the original source port can work better out of the box when hosting UDP servers behind a NAT. NATs which implement the "Address and Port-Dependent Filtering" behaviour -- as defined in [RFC 4787](https://datatracker.ietf.org/doc/html/rfc4787#page-15) -- will block UDP replies when the source port of the UDP reply does not match the desination port of the original request. For example, hosting a starcraft remastered server behind a NAT which overwrites the source port of outgoing packets will not work (as seen in my [starcraft remastered networking guide](/2021/04/29/the-best-starcraft-remastered-port-forwarding-guide.html)).

![img](/assets/client_udp_request.svg)

![img](/assets/server_udp_response_blocked.svg)
<br/>
<br/>
<br/>
Luckly, source port preservation is available in pf through the [static-port](https://man.openbsd.org/pf.conf#static-port) parameter.

![img](/assets/server_udp_response_static.svg)
<br/>
<br/>
<br/>

When I originally started looking into NAT+UDP because my starcraft remastered server stopped working I never imagined diving this deep into the internals of NAT systems. It was an interesting experience and I am glad to learn more about the internals of iptables and pf. Despite there being RFCs for NAT there still appears to be a large amount of variance in the implementations. It is interesting to see how two different projects have made different decisions regarding something which is so fundamental to how the internet works.
