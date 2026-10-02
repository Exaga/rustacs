# RUSTACS

**RUSTACS** --- Rust Administration & Control System.

RUSTACS is a collection of command-line tools, Bash scripts, a dot-env file 
and a systemd service unit for administering Linux-hosted Rust servers. The 
idea is simple; keep a Rust server's settings in a dot-env file and let the
service unit, CLI tool, and the Bash scripts use the same values. That keeps 
the important environment variables in one place instead of repeating them 
across multiple scripts.

### NOTES:

In this document:

Upper-case **RUSTACS** is the umbrella project name and its associated files.  
Lower-case `rustacs` is the Python 3 command-line tool that comes with it.  
They're not the same thing. So, where you see:

- **RUSTACS** - it's the name of the project and related files.
- `rustacs` - it's referring to the Python 3 command-line tool.

RUSTACS was developed and tested on [Ubuntu 26.04 LTS](https://documentation.ubuntu.com/release-notes/26.04/)

RUSTACS is released under the [MIT License](LICENSE).

## Contents

- [Prerequisites](#Prerequisites)
- [Download RUSTACS](#download-rustacs)
- [What RUSTACS contains](#what-rustacs-contains)
- [Requirements](#requirements)
- [Installation](#installation)
- [The dot-env file](#the-dot-env-file)
  - [Dot-env file permissions](#dot-env-file-permissions)
  - [Dot-env settings](#dot-env-settings)
  - [`master.config`](#masterconfig)
  - [Multi-server setup](#multi-server-setup)
- [RUSTACS tools](#rustacs-tools)
  - [`rustacs`](#rustacs)
    - [What `rustacs` does](#what-rustacs-does)
    - [WebRCON commands](#webrcon-commands)
    - [systemd service commands](#systemd-service-commands)
    - [`rustacs` options](#rustacs-options)
    - [`--verbose`](#--verbose)
  - [`rustserverbackup.sh`](#rustserverbackupsh)
    - [What the backup script does](#what-the-backup-script-does)
    - [Backup sequence](#backup-sequence)
    - [Running the backup script](#running-the-backup-script)
    - [Backup files and retention](#backup-files-and-retention)
  - [`rustservergenesys.sh`](#rustservergenesyssh)
    - [What genesys does](#what-genesys-does)
    - [Preparing a new map](#preparing-a-new-map)
    - [Applying `master.config`](#applying-masterconfig)
    - [Genesys command options](#genesys-command-options)
    - [Genesys backups](#genesys-backups)
  - [`rustserverlogswap.sh`](#rustserverlogswapsh)
    - [What logswap does](#what-logswap-does)
    - [Running logswap](#running-logswap)
    - [Log archive sequence](#log-archive-sequence)
  - [`rustservermod.sh`](#rustservermodsh)
    - [What the mod installer does](#what-the-mod-installer-does)
    - [Installing Carbon](#installing-carbon)
    - [Installing Oxide](#installing-oxide)
    - [Mod installer safeguards](#mod-installer-safeguards)
- [`rustserver.service`](#rustserverservice)
  - [Installing the service](#installing-the-service)
  - [Starting and stopping the service](#starting-and-stopping-the-service)
  - [What happens when the service starts](#what-happens-when-the-service-starts)
- [Automation with cron](#automation-with-cron)
- [Logs and backups](#logs-and-backups)
- [Troubleshooting](#troubleshooting)
- [License](#license)

######################

## Prerequisites

Debian/Ubuntu systems:   
You should download and install the following packages to ensure RUSTACS
runs without any issues on your system:

```bash
sudo apt update
sudo apt install bash python3 python3-websockets sudo curl unzip tar xz-utils
```

Further package installation is explained throughout this document.

## Download RUSTACS

Clone the repository from GitHub:

```bash
git clone https://github.com/Exaga/rustacs
cd rustacs
```

The cloned directory contains the RUSTACS files. Nothing needs compiling.
`rustacs` is written in Python 3, and the automation tools are Bash. Both 
are scripting languages executed line-by-line at runtime by a program called 
an interpreter, rather than being translated into machine code beforehand.

## What RUSTACS contains

RUSTACS consists of the following main parts:

```text
rustacs                  Python 3 WebRCON and service command tool
rustserverbackup.sh      Rust server state backup script
rustservergenesys.sh     Rust world/map preparation and deployment script
rustserverlogswap.sh     Rust server log serialisation and archive script
rustservermod.sh         Carbon/Oxide installation script
rustserver.service       systemd service unit for RustDedicated
.rustserver.env          RUSTACS dot-env file
```

These aren't unrelated utilities bundled together for convenience. They use 
the same dot-env file and are intended to work together as one management
system.

## Requirements

RUSTACS assumes you've already got a Linux system on which you intend to run 
a Rust server. The supplied layout uses a `rust` user and `rust` group. If 
you use different account names or PATHs, change the relevant values and
files to suit your system.

The tools themselves require:

- Bash for the administration scripts.
- Python 3 for `rustacs`.
- The Python 3 `websockets` module for WebRCON access.
- systemd for `rustserver.service` and the service-management functions.
- SteamCMD at `/usr/games/steamcmd` for the supplied service unit.
- `sudo` where a RUSTACS tool needs to perform an administrative operation.
- `curl` for `rustservermod.sh`.
- `unzip` when `rustservermod.sh` is used to install Oxide.
- Standard Linux utilities used by the scripts, including `tar`, `xz`, `awk`,
  `find`, `stat`, `cp`, `mv`, `chown`, `cmp` and `od`.

## Installation

Where you install the RUSTACS files is your prerogative. This README uses the
PATHs the project was written around so there's one complete working layout to
follow. If you change them, make the corresponding changes everywhere they're
used.

The supplied layout is:

```text
/home/rust/.rustacs/        RUSTACS dot-env and master files
/home/rust/bin/             RUSTACS tools and scripts
/home/rust/rustserver/      RustDedicated installation
/home/rust/backups/         Rust server backups
/home/rust/logs/            Rust server and RUSTACS logs
/etc/systemd/system/        systemd service units
```

Create the directories used by RUSTACS:

```bash
sudo mkdir -p /home/rust/.rustacs
sudo mkdir -p /home/rust/bin
sudo mkdir -p /home/rust/backups
sudo mkdir -p /home/rust/logs
```

Copy `rustacs` and the Bash tools:

```bash
sudo cp rustacs /home/rust/bin/rustacs
sudo cp rustserverbackup.sh /home/rust/bin/
sudo cp rustservergenesys.sh /home/rust/bin/
sudo cp rustserverlogswap.sh /home/rust/bin/
sudo cp rustservermod.sh /home/rust/bin/
```

Make them executable:

```bash
sudo chmod 770 /home/rust/bin/rustacs
sudo chmod 770 /home/rust/bin/rustserverbackup.sh
sudo chmod 770 /home/rust/bin/rustservergenesys.sh
sudo chmod 770 /home/rust/bin/rustserverlogswap.sh
sudo chmod 770 /home/rust/bin/rustservermod.sh
```

Copy the supplied dot-env file and systemd service unit:

```bash
sudo cp .rustserver.env /home/rust/.rustacs/.rustserver.env
sudo cp rustserver.service /etc/systemd/system/rustserver.service
```

Set ownership on the RUSTACS directories:

```bash
sudo chown -R rust:rust /home/rust/.rustacs
sudo chown -R rust:rust /home/rust/bin
sudo chown -R rust:rust /home/rust/backups
sudo chown -R rust:rust /home/rust/logs
```

Set the dot-env file permissions:

```bash
sudo chmod 640 /home/rust/.rustacs/.rustserver.env
```

If you want `rustacs` available as a normal system command, create a symbolic
link in `/usr/local/bin` rather than moving the RUSTACS copy:

```bash
sudo ln -s /home/rust/bin/rustacs /usr/local/bin/rustacs
```

Reload systemd after installing or changing `rustserver.service`:

```bash
sudo systemctl daemon-reload
```

Don't start the Rust server yet. Read and edit the dot-env file first.

## The dot-env file

The dot-env file is the centre of RUSTACS. The standard PATH is:

```text
/home/rust/.rustacs/.rustserver.env
```

The Bash tools source that file directly, `rustacs` reads it, and
`rustserver.service` loads it through systemd's `EnvironmentFile` directive.
The dot-env file is therefore authoritative for the server values used by
RUSTACS.

Edit it before starting the server:

```bash
sudo nano /home/rust/.rustacs/.rustserver.env
```

Don't treat the supplied values as magic defaults for somebody else's server.
Read the file from top to bottom and set the values for the server you're
actually running.

### Dot-env file permissions

The dot-env file contains the WebRCON password in plain text because
RustDedicated needs that value and `rustacs` needs to read it. That makes the
file permissions important.

The project layout uses:

```text
owner: rust
group: rust
mode:  0640
```

Set them with:

```bash
sudo chown rust:rust /home/rust/.rustacs/.rustserver.env
sudo chmod 640 /home/rust/.rustacs/.rustserver.env
```

Don't publish your live dot-env file with a real RCON password in it.

### Dot-env settings

The supplied dot-env file is divided into sections. These are the settings the
current RUSTACS files use.

**RUST global settings**

```ini
RUST_SERVER_ENV="/home/rust/.rustacs/.rustserver.env"
RUST_MASTER_CONFIG="/home/rust/.rustacs/master.config"
```

`RUST_SERVER_ENV` is the PATH of the active dot-env file.
`RUST_MASTER_CONFIG` is the PATH used by `rustservergenesys.sh` for
`master.config`.

**systemd service**

```ini
RUST_SERVICE_PATH=/etc/systemd/system/rustserver.service
```

This is the PATH to the Rust server systemd service unit. `rustacs`,
`rustservergenesys.sh` and `rustservermod.sh` use it when checking or managing
the service.

**Rust account**

```ini
RUST_USERNAME=rust
RUST_USERGROUP=rust
```

These are the user and group that own the Rust server and RUSTACS files.

**Infrastructure PATHs**

```ini
RUST_USER_HOME=/home/rust
RUST_INSTALL_WORKDIR=/home/rust/rustserver
RUST_SERVER_FILEDIR=/home/rust/rustserver/server
RUST_BACKUP_DIR=/home/rust/backups
```

These identify the Rust user's home directory, the RustDedicated installation
PATH, the server data PATH and the backup PATH.

**Rust server settings**

The dot-env file contains the values passed to RustDedicated for the server IP,
hostname, identity, game port, query port, map seed, world size, level, maximum
players, tutorial setting, tags and save interval.

The relevant variable names are:

```text
RUST_SERVER_IP
RUST_SERVER_HOSTNAME
RUST_SERVER_ID
RUST_SERVER_PORT
RUST_SERVER_QUERYPORT
RUST_SERVER_SEED
RUST_SERVER_WORLDSIZE
RUST_SERVER_LEVEL
RUST_SERVER_MAXPLAYERS
RUST_SERVER_TUTORIAL
RUST_SERVER_TAGS
RUST_SERVER_SAVEINTERVAL
```

`RUST_SERVER_ID` is particularly important. RustDedicated uses the server
identity for its server data directory, and `rustserverbackup.sh` uses the same
value when locating the data it backs up.

**WebRCON settings**

```ini
RUST_RCON_WEB=1
RUST_RCON_IP=127.0.0.1
RUST_RCON_PORT=28016
RUST_RCON_PASSWORD=your-RCON-password
```

`rustacs` reads the RCON IP, port and password from the dot-env file whenever it
sends a WebRCON command. `rustserver.service` uses the RCON port, password and
WebRCON enable setting when it starts RustDedicated.

**`rustacs` PATH**

```ini
RUSTACS_PATH=/home/rust/bin/rustacs
```

`rustserverbackup.sh` uses this PATH to call `rustacs` for maintenance messages
and `server.save`.

**Logging**

```ini
RUST_LOGDIR=/home/rust/logs
RUST_SERVER_LOGFILE=rustserver
RUST_SERVER_MAX_LOGFILE=2
```

`RUST_LOGDIR` is the log directory PATH. `RUST_SERVER_MAX_LOGFILE` is the size,
in MiB, at which `rustserverlogswap.sh` archives the active Rust server log.

### `master.config`

`master.config` belongs to `rustservergenesys.sh`. It represents the settings
prepared for the next Rust server world.

The normal PATH is:

```text
/home/rust/.rustacs/master.config
```

If it doesn't exist when genesys needs it, genesys creates it from the current
dot-env file. The map-selection commands alter `master.config`; they don't
immediately overwrite the active dot-env file. Running genesys later with no
arguments performs the apply operation while the Rust server is stopped.

That distinction matters:

```text
dot-env file     settings currently used by RUSTACS/RustDedicated
master.config    settings prepared for the next world
```

### Multi-server setup

If you're administering more than one Rust server, give **each server its own
complete dot-env file**. Don't put several servers into one dot-env file and
don't make unrelated servers share values that need to be different.

For example:

```text
/home/rust/.rustacs/server-one.env
/home/rust/.rustacs/server-two.env
/home/rust/.rustacs/server-three.env
```

Each server's dot-env file needs its own appropriate values, including its
identity, game port, query port, RCON port, server/data PATHs, service-unit PATH,
backup PATH and any other setting that differs from the other servers.

The current RUSTACS tools read this fixed active dot-env PATH:

```text
/home/rust/.rustacs/.rustserver.env
```

One straightforward way of keeping individual dot-env files is to make that
active PATH a symbolic link to the dot-env file for the server you're working
with:

```bash
cd /home/rust/.rustacs
ln -sfn server-one.env .rustserver.env
```

To select another dot-env file:

```bash
ln -sfn server-two.env .rustserver.env
```

Check the link before doing anything destructive or service-related:

```bash
readlink -f /home/rust/.rustacs/.rustserver.env
```

There are two important points here.

First, the supplied `rustserver.service` also loads the fixed
`/home/rust/.rustacs/.rustserver.env` PATH. If you run multiple RustDedicated
instances **at the same time**, each instance needs its own correctly adapted
systemd service unit and non-conflicting game, query and RCON ports. Don't point
a running service at a different server's dot-env file underneath it.

Second, the current `rustserverbackup.sh` explicitly checks, stops and starts
`rustserver.service` by that unit name. If you adapt RUSTACS for simultaneously
running multiple service units, adapt that script for the corresponding unit as
well. The README isn't going to pretend the stock script dynamically selects a
service unit when it doesn't.

Each server should also have its own `master.config` PATH in its dot-env file.
For example:

```ini
RUST_MASTER_CONFIG="/home/rust/.rustacs/server-one-master.config"
```

and:

```ini
RUST_MASTER_CONFIG="/home/rust/.rustacs/server-two-master.config"
```

That keeps a prepared map for one server from being applied to another one.

## RUSTACS tools

This section documents each tool supplied with RUSTACS. `rustacs` comes first;
the Bash tools follow alphabetically.

### `rustacs`

#### What `rustacs` does

`rustacs` is the Python 3 command-line tool supplied with RUSTACS. RustDedicated
doesn't listen to standard input on Linux, so `rustacs` sends console commands
to RustDedicated through its WebRCON WebSocket interface.

It also provides a small set of local systemd service commands so you don't
have to switch between RCON commands and `systemctl` for routine administration.

`rustacs` always reads its RCON and service values from:

```text
/home/rust/.rustacs/.rustserver.env
```

Running it with no arguments displays its help and exits with a non-zero status.

#### WebRCON commands

The general form is:

```text
rustacs <command> [arguments]
```

Examples:

```bash
rustacs status
rustacs serverinfo
rustacs say "Hello World!"
rustacs server.save
```

`rustacs status` is a RustDedicated WebRCON command. It is **not** the same as
checking the local systemd service.

Commands that aren't one of the local `rustacs server ...` service commands are
joined together and sent to RustDedicated through WebRCON. That means the tool
isn't limited to the four examples above.

`serverinfo` receives special handling: when RustDedicated returns JSON in the
message, `rustacs` formats it so it's readable rather than dumping one long JSON
string onto the terminal.

#### systemd service commands

The local service commands are:

```bash
rustacs server start
rustacs server stop
rustacs server restart
rustacs server status
```

`start`, `stop` and `restart` call `systemctl` through `sudo` using the service
unit PATH defined by `RUST_SERVICE_PATH` in the dot-env file.

`status` runs `systemctl is-active` and doesn't use WebRCON:

```bash
rustacs server status
```

So remember the difference:

```text
rustacs status           ask RustDedicated for its status through WebRCON
rustacs server status    ask systemd whether the local service is active
```

#### `rustacs` options

```text
-h, -?, --help          Show command help
-v, --version           Show version information
-U, --url               Show the official RUSTACS project URL
-L, --license           Show the MIT licence text
<command> --verbose     Show detailed errors for an RCON command
```

The informational options don't require RustDedicated to be running:

```bash
rustacs --help
rustacs --version
rustacs --url
rustacs --license
```

#### `--verbose`

By default, a WebRCON connection failure is deliberately short:

```text
Connection failed: Server is offline or RCON IP/port is misconfigured.
```

Add `--verbose` when you need the underlying exception as well:

```bash
rustacs status --verbose
```

`--verbose` is primarily useful for failures. It doesn't add extra output to a
successful RCON response.

### `rustserverbackup.sh`

#### What the backup script does

`rustserverbackup.sh` performs a transactional backup of the Rust server's
state data. It uses the active dot-env file to determine the server identity,
data PATH, backup PATH, Rust account and `rustacs` PATH.

The script backs up selected state beneath:

```text
${RUST_SERVER_FILEDIR}/${RUST_SERVER_ID}
```

including the server `cfg/`, loadouts, server emoji data, companion ID,
relationship databases, player databases, clan databases, server-file
databases, save files and map files matched by the script.

It doesn't blindly stop an active server without warning. If the service is
active, players get a maintenance countdown through `rustacs` first.

#### Backup sequence

When `rustserver.service` is active, the script:

1. Announces maintenance 30 minutes before shutdown.
2. Announces it again at 15 minutes.
3. Announces it again at 5 minutes.
4. Sends a final 30-second warning.
5. Runs `server.save` through `rustacs`.
6. Waits 30 seconds and sends the final shutdown message.
7. Stops `rustserver.service`.
8. Creates the xz-compressed backup archive.
9. Corrects archive ownership when necessary.
10. Starts `rustserver.service` again because it was active before the backup.
11. Removes matching backup archives older than the retention period.

If the service is already `inactive` or `failed`, the warning/countdown and
stop/restart sequence is skipped and the script proceeds to the archive.

An unexpected service state causes the script to abort rather than guessing
what it should do.

#### Running the backup script

Run it manually with:

```bash
/home/rust/bin/rustserverbackup.sh
```

There are no command-line options. Its settings come from the active dot-env
file and from values defined inside the script.

The script expects `RUSTACS_PATH` to point to an executable `rustacs` tool. It
also uses `sudo systemctl` and may use `sudo chown`, so the account running it
needs the corresponding permissions.

#### Backup files and retention

Backup archives are written beneath `RUST_BACKUP_DIR` and are named from the
server identity and timestamp:

```text
<RUST_SERVER_ID>-backup_<timestamp>.tar.xz
```

The current script sets its archive-retention age internally to 63 days. Its
housekeeping pass removes matching backup archives older than that age.

The script writes its own progress log as:

```text
${RUST_LOGDIR}/rustserverbackup.log
```

### `rustservergenesys.sh`

#### What genesys does

`rustservergenesys.sh` manages the settings used for the next Rust server world.
It has two deliberately separate jobs:

1. **Prepare** map settings in `master.config`.
2. **Apply** `master.config` to the active dot-env file when the server is
   stopped.

Preparing the next map doesn't generate or deploy a Rust world immediately.
RustDedicated uses the new seed/world-size settings when the prepared dot-env
values are subsequently used to start the service.

The script doesn't remove player blueprints.

#### Preparing a new map

A random seed can be prepared with:

```bash
/home/rust/bin/rustservergenesys.sh +newmap
```

`+newmap` changes the seed only. It doesn't silently change the existing world
size.

Set a specific seed with:

```bash
/home/rust/bin/rustservergenesys.sh +seed 123456789
```

Set only the world size with:

```bash
/home/rust/bin/rustservergenesys.sh +size 4500
```

Seed and size can be set together:

```bash
/home/rust/bin/rustservergenesys.sh +seed 123456789 +size 6000
```

A new random seed and a new size can also be prepared together:

```bash
/home/rust/bin/rustservergenesys.sh +newmap +size 6000
```

The options may be supplied in either order where the combination is valid.
The script validates the whole command before it changes `master.config`, so a
bad second option won't leave a half-applied command behind.

These preparation operations can be performed while RustDedicated is running
because they alter `master.config` and then exit. They don't deploy the new
settings to the active dot-env file.

#### Applying `master.config`

To apply the prepared `master.config`, stop the Rust server and run genesys with
no arguments:

```bash
/home/rust/bin/rustservergenesys.sh
```

The apply operation refuses to continue while the Rust server service is
active.

If `master.config` and the active dot-env file are identical, there's nothing
to apply and the script exits without replacing anything.

If they're different, genesys:

1. Makes sure the world-backup directory exists.
2. Backs up the current dot-env file.
3. Copies `master.config` over the active dot-env file.
4. Restores the expected Rust ownership on the relevant files.
5. Logs the completed operation.

#### Genesys command options

```text
+newmap          Generate a new random map seed
+seed <value>    Set a specific map seed (0-2147483647)
+size <value>    Set the map world size (1000-6000)
--help           Show command help
```

`+newmap` and `+seed` are mutually exclusive. Asking for both is an error.
`+newmap` may be combined with `+size`, and `+seed` may be combined with
`+size`.

A missing value, duplicate option, unknown option, seed outside its accepted
range or world size outside `1000-6000` is rejected before `master.config` is
changed.

Display the command usage with:

```bash
/home/rust/bin/rustservergenesys.sh --help
```

#### Genesys backups

Before genesys applies a changed `master.config`, it backs up the current
dot-env file beneath:

```text
${RUST_BACKUP_DIR}/worldbackups/
```

The backup filename records the current seed, world size and timestamp. These
are dot-env backups associated with world changes; they're separate from the
Rust state archives created by `rustserverbackup.sh`.

The script writes its progress log as:

```text
${RUST_LOGDIR}/rustservergenesys.log
```

### `rustserverlogswap.sh`

#### What logswap does

`rustserverlogswap.sh` prevents the active RustDedicated log from growing
indefinitely. It checks the active log's raw byte size against
`RUST_SERVER_MAX_LOGFILE` from the dot-env file. That setting is expressed in
MiB.

The active log filename is built from RUST_SERVER_LOGFILE beneath
RUST_LOGDIR:

```text
<RUST_SERVER_LOGFILE>.log
```

If the log doesn't exist, or hasn't reached the configured size, the script has
nothing to do and exits.

#### Running logswap

Run it manually with:

```bash
/home/rust/bin/rustserverlogswap.sh
```

There are no command-line options. The script is intended to be safe for
regular scheduled execution because it only performs the archive sequence when
the active log has reached the configured threshold.

#### Log archive sequence

When the active log reaches the threshold, logswap:

1. Copies the active log to a timestamped temporary log file.
2. Truncates the original active log in place so the service can continue
   writing to the same file.
3. Creates an xz-compressed tar archive of the copied log.
4. Verifies the archive with `tar`.
5. Removes the copied source log only after the archive passes verification.
6. Checks the archive ownership and resets it to the Rust user/group when
   necessary.

If the copy fails, the active log isn't truncated. If archive creation or
verification fails, the shifted copy is preserved rather than thrown away.

The resulting archive is written beneath `RUST_BACKUP_DIR` with a timestamp and
server hostname in its filename.

The script's own progress log is:

```text
${RUST_LOGDIR}/rustserverlogswap.log
```

### `rustservermod.sh`

#### What the mod installer does

`rustservermod.sh` installs either Carbon or Oxide into the RustDedicated
installation identified by `RUST_INSTALL_WORKDIR` in the active dot-env file.

It downloads the selected Linux release to a temporary directory, extracts it
into the RustDedicated installation and then sets the installation ownership to
the Rust user/group from the dot-env file.

The script is an installer. It doesn't claim to perform every framework-specific
runtime setting that a particular Carbon or Oxide release may require.

#### Installing Carbon

Make sure the Rust server service is stopped, then run:

```bash
/home/rust/bin/rustservermod.sh carbon
```

Carbon is downloaded as a compressed tar archive and extracted directly into
`RUST_INSTALL_WORKDIR`.

#### Installing Oxide

Make sure the Rust server service is stopped, then run:

```bash
/home/rust/bin/rustservermod.sh oxide
```

Oxide is downloaded as a ZIP archive and extracted directly into
`RUST_INSTALL_WORKDIR`. The `unzip` command is therefore required for an Oxide
installation.

#### Mod installer safeguards

Before installing anything, the script checks that:

- a valid argument (`carbon` or `oxide`) was supplied;
- the RustDedicated installation PATH exists;
- the systemd service unit exists;
- the Rust server service is inactive;
- `curl` is installed;
- `unzip` is installed when Oxide is selected; and
- the other mod framework hasn't already been detected.

Carbon and Oxide aren't intended to be installed together by this script. If it
detects an `oxide` directory while installing Carbon, or a `carbon` directory
while installing Oxide, it aborts.

Temporary downloads are removed automatically when the script exits.

The script writes its progress log as:

```text
${RUST_LOGDIR}/rustservermod.log
```

## `rustserver.service`

`rustserver.service` is the supplied systemd service unit for RustDedicated. It
isn't just a wrapper around the executable: it defines the account,
RustDedicated working directory, update step, restart behaviour, startup
arguments and logging used by the supplied RUSTACS layout.

The supplied service unit loads:

```text
/home/rust/.rustacs/.rustserver.env
```

through systemd's `EnvironmentFile` directive and runs RustDedicated as the
`rust` user and `rust` group.

### Installing the service

Copy it into the systemd unit directory if you haven't already done so:

```bash
sudo cp rustserver.service /etc/systemd/system/rustserver.service
sudo systemctl daemon-reload
```

Enable it at boot if that's what you want:

```bash
sudo systemctl enable rustserver.service
```

Enabling a service and starting it are different operations. `enable` arranges
for systemd to start it at boot; it doesn't mean you have to start it right now.

### Starting and stopping the service

Using systemd directly:

```bash
sudo systemctl start rustserver.service
sudo systemctl stop rustserver.service
sudo systemctl restart rustserver.service
systemctl status rustserver.service
```

Or, for the operations supported by `rustacs`:

```bash
rustacs server start
rustacs server stop
rustacs server restart
rustacs server status
```

### What happens when the service starts

Before launching RustDedicated, the supplied unit runs SteamCMD anonymously and
performs the Rust Dedicated Server application update for Steam App ID `258550`.

It then launches RustDedicated with server values from the dot-env file,
including the server IP/ports, map, identity, hostname, player limit, tutorial
setting, tags, save interval and WebRCON settings.

The supplied service unit also contains project-specific server description,
image and URL values. Read the unit before using it on your own public server
and change those values to your own. Don't accidentally publish somebody
else's server identity because you skipped reading the file.

The unit is configured to restart RustDedicated on failure, with a delay between
restart attempts. A deliberate service stop is still a deliberate stop.

## Automation with cron

The Bash tools don't require an interactive terminal, so the backup and logswap
tools can be scheduled with `cron` once you've tested them manually and know
the required permissions are in place.

For example, a backup job might be:

```cron
0 4 * * * /home/rust/bin/rustserverbackup.sh
```

A regular log-size check might be:

```cron
*/15 * * * * /home/rust/bin/rustserverlogswap.sh
```

Those are examples, not prescribed schedules. Pick times that make sense for
your server. In particular, remember that an active-server backup includes a
30-minute player-warning countdown before shutdown.

`rustacs` can also be called from cron for RustDedicated commands:

```cron
*/15 * * * * /home/rust/bin/rustacs server.save
```

Before relying on cron, run the exact command manually as the same account that
will run the cron job. RUSTACS scripts use absolute PATHs in several places,
but permissions and `sudo` rules still matter.

## Logs and backups

The actual PATHs come from the active dot-env file. With the supplied layout,
RUSTACS uses:

```text
/home/rust/logs/                 RUSTACS and RustDedicated logs
/home/rust/backups/              Rust state and archived server logs
/home/rust/backups/worldbackups/ genesys dot-env backups
```

Each Bash tool uses its own program name for its progress log:

```text
rustserverbackup.log
rustservergenesys.log
rustserverlogswap.log
rustservermod.log
```

Don't confuse those progress logs with the active RustDedicated server log.
`rustserverlogswap.sh` manages the RustDedicated log; it doesn't rotate the
RUSTACS tools' own progress logs.

## Troubleshooting

If `rustacs` says:

```text
Connection failed: Server is offline or RCON IP/port is misconfigured.
```

first establish whether RustDedicated is actually running:

```bash
rustacs server status
```

If the service is active, check the RCON IP and port in the active dot-env file.
For the underlying WebSocket error, repeat the command with `--verbose`:

```bash
rustacs status --verbose
```

If `rustacs` reports that the dot-env file can't be read, check that
`/home/rust/.rustacs/.rustserver.env` exists and that the account running the
command has permission to read it.

If a Bash tool behaves as though it's targeting the wrong server, check the
active dot-env file before doing anything else:

```bash
readlink -f /home/rust/.rustacs/.rustserver.env
```

If `.rustserver.env` is a regular file rather than a symbolic link, inspect it
directly instead.

If systemd doesn't see a newly installed or changed service unit, reload its
unit files:

```bash
sudo systemctl daemon-reload
```

For service startup failures, inspect systemd's own status and journal output;
those are the authoritative places to see why systemd or RustDedicated failed
to start.

## License

RUSTACS is released under the [MIT License](LICENSE).

Copyright © 2026 Exaga - penthux.net

#EOF<*>
