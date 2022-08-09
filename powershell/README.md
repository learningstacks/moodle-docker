- [PowerShell for moodle-docker](#powershell-for-moodle-docker)
  - [Objectives](#objectives)
  - [Features](#features)
  - [Prerequisites](#prerequisites)
  - [What is different from the shell script?](#what-is-different-from-the-shell-script)
  - [Quick Start](#quick-start)
  - [Working with the containers](#working-with-the-containers)
    - [Running Behat](#running-behat)
    - [Running PhpUnit](#running-phpunit)
  - [Customizing the Stack](#customizing-the-stack)
  - [Accessing the module](#accessing-the-module)
    - [Adding the moodle-docker module to PSModulePath](#adding-the-moodle-docker-module-to-psmodulepath)
    - [Importing the moodle-docker powershell module at login](#importing-the-moodle-docker-powershell-module-at-login)
  - [Using VSCode Open in Container](#using-vscode-open-in-container)

# PowerShell for moodle-docker

Powershell for Moodle provides a PowerShell module for working with Moodle.

## Objectives

* Provide the same features provided by the current shell and cmd scripts.
* Provide a single codebase usable on Windows, MacOS, Linux, and any platform capable of running PowerShell core.
* Provide a comprehesive unit and integration test suite.
* Provide features suitable for Developers who are managing a complete LMS. For example, include only specific extra services of specific versions to match the LMS they are maintaining.

## Features
* The ability to define the stack configuration in a file in your project workspace and have that file automatically loaded. i.e., no need to set environment variables.
* All calls to docker are made in a seperate process, using a PowerShell Job, keeping your environment clean.
* The ability to emit a single docker-compose.yml file that defines   the stack configuration with all environment variables resolved to their values. This allows use of base docker-compose (and podman-compose) calls without having to define a configuration. This also allows the use of VSCode open-in-container feature.
* The ability to add additional compose files and environment variables to extend and customize the stack configuration as needed.

## Prerequisites
* PowerShell Core 6 or higher installed
  - MacOS
  - Windows
  - Linux (including WSL)
* PowerShell module PowerShell-Yaml installed


## What is different from the shell script?
* DB defaults to postgres, no need to specify this

## Quick Start

This Quick Start assumes you will be working in a cloned copy of the moodle-docker repository at a location we will call projectdir.

1. Setup the project

   ```powershell
   # Clone the moodle-docker repo
   git clone git@moodle.com:moodlehq/moodle-docker.git projectdir

   # CD to the project directory
   Set-Location projectdir
   # or... cd myworkspace/project

   # Import the moodle-docker powershell module into your current session.
   Import-Module ./powershell/moodle-docker.psm1

   # Clone Moodle (or your specific variant)
   git clone git@moodle.com:moodle/moodle.git ./moodle

   # Copy the config template into moodle
   Copy-Item ./config.docker-template.php ./moodle/config.php
   ```

2. Create a stack configuration file stackdef.yml in your project folder. This example is the minimal stack. See [TBD] for additional options.

   ```yaml
   # stackdef.yml
   MOODLE_DOCKER_WWWROOT: ./moodle
   ```

3. Start the stack
   ```powershell
   # Start-Stack will look for and load staddef.yml, launch the stack and  wait for the DB service and, if applicable, moodleapp service to be ready
   Start-Stack
   ```

4. Work with the containers [see below](#working-with-the-containers)
   ```powershell
   Invoke-Stack 'arg arg arg ...'
   ```

5. Stop and remove the Stack
   ```powershell
   # TODO Implement
   Stop-Stack -Remove
   ```

## Working with the containers

### Running Behat

```powershell
# Initialize behat environment |
Invoke-Stack "exec webserver php admin/tool/behat/cli/init.php"

# Run some behat tests
# TODO Check if user is actually required
Invoke-Stack "exec -u www-data webserver php admin/tool/behat/cli/run.php --tags=@auth_manual"

```

### Running PhpUnit

## Customizing the Stack

## Accessing the module

### Adding the moodle-docker module to PSModulePath

### Importing the moodle-docker powershell module at login

## Examples

1. Complete automated test run
2. Config for using PhpStorm
3. Config for VSCode
4. A complete project
5. Using subtrees
6. Complete project template

## Contemplated Features
1. Enable Behat parallel.
   * Multiple selenium containers with ports etc.
   * config template
   * Env vars
   * Either via options or perhaps show how to do this using extension mechanism
2. Support VSCode open-in-container
3. Enable using tmpfs for DB and moodledata
4. Enable stop and start versus up and down
   * Stop-Stack should, perhaps, just stop and add a Remove-Stack function or perhaps
   * Start-Stack could look to see if containers exist and just to a start
5. Add Enable-XDebug and Disable-XDebug?
6. Windows variant using mixed containers (for the poor tech slobs who have to support an LMS on Windows)