---
layout: post
title: "pushing metrics with mqtt"
date: 2015-01-15 11:37:01 +0100
comments: true
categories: openhab, mqtt, monitoring, icinga, nagios
published: false
---

I came across a really good post from J.P.Mens, who wrote the brilliant mqttwarn script to effectively send MQTT messages to different types of services.
Since I was in the mood to finally switch my Nagios instance running on the old monitoring box to Icinga, I decided to give mqttwarn a shot as wll.

Until now I'm really impressed how easy the setup, despite there is no debian package for it (I defintely should create one :) ).

Since I tried to get the metrics from openhab over the internet into my InfluxDB instance running on my webserver and failed, I wanted to have something more reliable in place. Thats when I found mqttwarn to replace it.

- Install the mqtt-presistence in openhab
- setup openhab.cfg with your mqtt server (I'm using RabbitMQ but I guess Mosqitto would do as well)
- add the persistence file for mqtt
- Setup mqttwarn on the server
- enable the Grahite input in InfluxDB (Port 2003)
- ...
- Profit!
