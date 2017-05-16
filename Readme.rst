VCVars Overview
===============

VCVars is a pure Powershell 5 module for adding, pushing, and popping MSVC
environment variables to your system PATH. It's released under the MIT License.

Get buck wild.

Installation
============

VCVars is currently published on the PowershellGallery_::

  Install-Module -Name VCVars

If you are not in an administrator powershell instance, and lack the
permissions to launch one, simply install to the ``CurrentUser`` scope::

  Install-Module -Name VCVars -Scope CurrentUser

Implicit module importing should handle the rest. Because VCVars is not
supported prior to Powershell 5, there is not other supported way of installed
VCVars.

Features
========

VCVars currently has a small, but decent set of features:

 * (optional) stack based environment variable control
 * All Visual Studio editions support (Including BuildTools, the minimal C++
   installation!)
 * Universal Windows Platform support
 * Parameters to set cross compiling
 * *Some* argument completion behavior

Cmdlets and Aliases
===================

VCVars cmdlets effectively work on hashtables that represent a set of
environment variables. Eventually it *will* affect your Powershell ``env:``
drive.

VCVars provides the following commands:

 * ``Push-VCVars`` -- Pushes a new environment onto the stack
 * ``Pop-VCVars`` -- Pops an environment off the stack and returns it
 * ``Invoke-VCVars`` -- Calls a ``vcvarsall.bat`` and returns an environment
 * ``Find-VCVars`` -- Returns a list of all ``vcvarsall.bat`` files
 * ``Set-VCVars`` -- Forcibly sets the environment variables
 * ``Clear-VCVars`` -- Attempts to remove all VCVars from the environment
 * ``Find-VCWindowsKitsVersions`` -- Returns a list of currently installed
   Windows Kits.

VCVars utilizes the ``Find-VCWindowsKitsVersions`` cmdlet as an argument
completer for the ``Invoke-VCVars``'s ``SDK`` parameter.

VCVars also provides a few aliases for the common commands:

 * ``pushvc`` -> ``Push-VCVars``
 * ``popvc`` -> ``Pop-VCVars``
 * ``vcvars`` -> ``Invoke-VCVars``
 * ``setvc`` -> ``Set-VCVars``

Roadmap
=======

VCVars isn't fully polished, but it works right now. I'd rather get some
feedback than miss the boat entirely. That said, future plans for VCVars are:

 * Write better documentation
 * (possibly) Support older versions of Visual Studio
 * Better checking of various VSSetup components, such as android or linux
   support.

Example Usage
=============

The simplest (and arguably most common) way to use VCVars is with the following
command::

  setvc (vcvars)

This will set your environment variables using the most recently installed
Visual Studio installation, without Universal Windows Platform support, on an
amd64 host, targeting amd64. Running ``Get-Help Invoke-VCVars`` will show you
parameters on how to configure your environment.

Why Does This Exist?
====================

If you're like me, you like to work from the commandline when using the
Microsoft Visual C++ Compiler (also known as MSVC) or when writing Rust.
However, it still requires you to use a batch file alongside cmd.exe to run
commands. This isn't acceptable in this, the year of our Goku 2017. This module
gives several Powershell cmdlets for interacting with (and setting) the
environment variables that MSVC requires. It also offers a few 'intrinsic'
cmdlets to peer into some information regarding your various MSVC 2017 installs

This kind of module has been done several times, and some of them support older
versions of MSVC (such as 2013 or 2015). However, those rely on a tool known
as ``vswhere.exe``, which either requires a user to download it themselves, or
for me to distribute an already built version. I prefer a pure Powershell
approach. As such, VCVars requires the VSSetup powershell module. If VSSetup
does not know how to find versions of Visual Studio before 2017, then neither
will VCVars. It also currently requires Powershell 5 and assumes you're on an
amd64 architecture machine (it does support declaring cross compiling, or
forcing an x86 host). Some work could likely be done to get it down to
Powershell 3 and x86 hosts, but I'm lazy.

Pull requests are welcome.

.. _PowershellGallery: https://www.powershellgallery.com/
