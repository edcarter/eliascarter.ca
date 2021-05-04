---
layout: page
title: Chef
permalink: /chef/
---
Chef is the friendly neighbourhood cat who comes to visit quite often. She loves to sleep and be carried around the house.


<ul>
{% for post in site.tags.chef %}
      {{ post.excerpt }}
      <br/>
{% endfor %}
</ul>
