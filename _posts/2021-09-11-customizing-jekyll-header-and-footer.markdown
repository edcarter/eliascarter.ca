---
layout: post
title:  "Customizing Jekyll header and footer"
date:   2021-09-11 12:00:00 -0700
---

Today I was revisiting the website while doing research for a post on NAT passthrough (coming soon), but I wasn't very happy with the default Jekyll layout. I wanted to add a resume link to the site header, but to my knowledge the default Jekyll theme can only link to other pages inside of the site header. After doing a bunch of googling I couldn't find a good solution for adding an arbitrary link in the site header without installing plugins or writing a bunch of Javascript, so here is a guide to modifying the default Jekyll header and footers. I used this documentation as a reference: [https://jekyllrb.com/docs/themes/#overriding-theme-defaults](https://jekyllrb.com/docs/themes/#overriding-theme-defaults)

First, make a \_includes directory within the root Jekyll directory:
```bash
$ mkdir _includes
```

Find out where the default Jekyll theme lives on your machine:
```bash
$ bundle info --path minima
/home/elias/gems/gems/minima-2.5.1
```

Copy the header and footer html from the theme into your Jekyll \_includes directory:
```bash
$ cp /home/elias/gems/gems/minima-2.5.1/_includes/{header.html,footer.html} _includes/.
```

Now you can modify the header and footer html to your liking. For example I added a hard coded link to my resume within the website header:
{% raw %}
```html
<div class="trigger">
  {%- for path in page_paths -%}
    {%- assign my_page = site.pages | where: "path", path | first -%}
    {%- if my_page.title -%}
    <a class="page-link" href="{{ my_page.url | relative_url }}">{{ my_page.title | escape }}</a>
    {%- endif -%}
  {%- endfor -%}
  <a class="page-link" href="{{ site.baseurl }}/assets/resume.pdf">Resume</a>
</div>
```
{% endraw %}

The website source is here: [https://github.com/edcarter/eliascarter.ca](https://github.com/edcarter/eliascarter.ca)
