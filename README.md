# webcc-monkey
This repository contains a modified version of the TransCC "driver" for Monkey's compiler, adapted slightly to work in web browsers.

## Introduction to WebCC

The WebCC project aims to maintain a fully functional port of [Monkey X](http://www.monkey-x.com/Monkey/about.php)'s compiler, for modern Web browsers. It does this by handling execution semantics, maintaining operating system behavior, and reimplementing a file-system atop HTML5 and related extensions. The main functionality of Monkey's compiler is developed by Blitz Research and Monkey's community. Source code responsible for compiling Monkey source can be found in the [official repository](https://github.com/blitz-research/monkey).

**You can find out more about WebCC by [clicking here](http://regal-internet-brothers.github.io/wccexplain/).**

## Repository Contents

This repository contains the required (Modified) portions of TransCC's source code. In addition to this source code, recent versions of Monkey's modules, and related files (Required to execute) are found in the *"[webcc.data](/webcc.data)"* folder. 

## Installation Notes

**A brief glossary of WebCC's components, and how they are glued together can be [found here](http://regal-internet-brothers.github.io/wccexplain/#source-code-and-setup). (*Bottom*)**

The only abnormal thing about this repository is that the *'Web'* version of the 'os' module, '[regal.virtualos](https://github.com/Regal-Internet-Brothers/virtualos)', is a git sub-module. Because of this, you will need to recursively clone this repository.

This can be done like so, from your preferred shell (URI available above):
> git clone --recursive https://github.com/Regal-Internet-Brothers/webcc-monkey.git

NOTE: *You must be using git version 1.6.5 or newer to recursively clone a repository.*

In the event you are unable to clone recursively, you will need to manually clone the '[virtualos](https://github.com/Regal-Internet-Brothers/virtualos)' repository. If done manually, that module should reside in *"[webcc.data/modules](/webcc.data/modules)"*, with the name **"os"**.

## TODO

* Integrate 'brl.filestream' with 'virtualos'.
* Integrate 'brl.filesystem' with 'virtualos'.
* Integrate 'brl.process' with 'virtualos'.
