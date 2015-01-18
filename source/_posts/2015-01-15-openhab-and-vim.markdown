---
layout: post
title: "OpenHAB and vim"
date: 2015-01-15 11:13:36 +0100
comments: true
share: true
categories: openhab, vim
---

Recently I started using [OpenHAB](http://openhab.org/) to automate my house. Unfortunately the OpenHAB Designer is a real PAI for the default use case in my opinion.
Usually I would expect that the core runtime is installed on a linux box (e.g. a Raspberry PI or something) and the designer is used on a Desktop.
So how does the data get to the server?

One possibility would be to use Dropbox, using the Dropbox bundle to have OpenHAB fetch the folder and reload it's config. I found this to be relatively uncomfortable for development, since you don't get instant feedback if it works as expected.
So I decided to ssh into the box running openhab and edit the files directly in the configuration folder. Well I guess the problem is clear. To use the designer, one would need to have a graphical interface or X-Forwarding enabled (including having all the necessary libraries installed which also not an option on the server).

Therefore I created a vim syntax file, which can be downloaded from <https://github.com/cyberkov/openhab-vim>. As of now it works, but I don't feel like I'm really using all the features of syntax highlighting of vim. Especially I don't think the folding features are working and the automatic indentation.

I still hope it's helping and I would be glad about any pull requests and improvements :-)
