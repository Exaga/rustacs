# RUSTACS

**RUSTACS** - RustDedicated Server Administration & Control System.

RUSTACS is a collection of command-line tools, Bash scripts, a dot-env file 
and a systemd service unit for administering Linux-hosted RustDedicated 
servers. The idea is simple; keep a RustDedicated server's settings in a 
dot-env file and let the service unit, CLI tool, and the Bash scripts use 
the same values. That keeps the important environment variables in one place 
instead of repeating them across multiple locations.

**NOTE**: [Rust](https://rust.facepunch.com) is a multiplayer survival video 
game by [Facepunch Studios](https://facepunch.com/). Not to be confused with 
the Rust programming language. 

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
    - [What `rustserverbackup.sh` does](#what-rustserverbackupsh-does)
    - [Backup sequence](#backup-sequence)
    - [Running `rustserverbackup.sh`](#running-rustserverbackupsh)
    - [Backup files and retention](#backup-files-and-retention)
  - [`rustservergenesys.sh`](#rustservergenesyssh)
    - [What `rustservergenesys.sh` does](#what-rustservergenesyssh-does)
    - [Preparing a new map](#preparing-a-new-map)
    - [Applying `master.config`](#applying-masterconfig)
    - [`rustservergenesys.sh` command options](#rustservergenesyssh-command-options)
    - [`rustservergenesys.sh` backups](#rustservergenesyssh-backups)
  - [`rustserverlogswap.sh`](#rustserverlogswapsh)
    - [What `rustserverlogswap.sh` does](#what-rustserverlogswapsh-does)
    - [Running `rustserverlogswap.sh`](#running-rustserverlogswapsh)
    - [Log archive sequence](#log-archive-sequence)
  - [`rustservermod.sh`](#rustservermodsh)
    - [What `rustservermod.sh` does](#what-rustservermodsh-does)
    - [Installing Carbon](#installing-carbon)
    - [Installing Oxide](#installing-oxide)
    - [`rustservermod.sh` safeguards](#rustservermodsh-safeguards)
- [`rustserver.service`](#rustserverservice)
  - [Installing the service](#installing-the-service)
  - [Starting and stopping the service](#starting-and-stopping-the-service)
  - [What happens when the service starts](#what-happens-when-the-service-starts)
- [Automation with cron](#automation-with-cron)
- [Logs and backups](#logs-and-backups)
- [Troubleshooting RUSTACS](#troubleshooting-rustacs)
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

For other Linux distributions, install the equivalent system packages to suit 
the above.

## Download RUSTACS

Clone the repository from GitHub:

```bash
git clone https://github.com/Exaga/rustacs
cd rustacs
```

The cloned directory contains the RUSTACS files that require no compilation 
step. Because `rustacs` is written in Python 3 and the automation tools are 
written in Bash, both run immediately through their respective runtime 
interpreters. Unlike compiled languages (e.g. C++) they run immediately 
without requiring a separate ahead-of-time phase to build a standalone 
machine-code executable.

## What RUSTACS contains

RUSTACS consists of the following main parts:

```text
rustacs                  Python 3 WebRCON and service command tool
rustserverbackup.sh      RustDedicated server state backup script
rustservergenesys.sh     Rust world/map preparation and deployment script
rustserverlogswap.sh     RustDedicated server log serialisation and archive script
rustservermod.sh         Carbon/Oxide installation script
rustserver.service       systemd service unit for RustDedicated
.rustserver.env          RUSTACS dot-env file
```

These aren't unrelated utilities bundled together for convenience. They use 
the same dot-env file and are intended to work together as one management
system.

## Requirements

RUSTACS assumes you've already got a Linux system on which you intend to run 
a RustDedicated server. The supplied layout uses a `rust:rust` user/group. If 
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

Where you install the RUSTACS files is your prerogative. This document uses the
PATHs the project was written around so there's one complete working layout to
follow. If you change them, make the corresponding changes everywhere they're
used.

The supplied layout is:

```text
/home/rust/.rustacs/        RUSTACS dot-env and master files
/home/rust/bin/             RUSTACS tools and scripts
/home/rust/rustserver/      RustDedicated installation
/home/rust/backups/         RustDedicated server backups
/home/rust/logs/            RustDedicated server and RUSTACS logs
/etc/systemd/system/        systemd service units
```

Create the directories used by RUSTACS:

```bash
sudo mkdir -p /home/rust/.rustacs
sudo mkdir -p /home/rust/bin
sudo mkdir -p /home/rust/backups
sudo mkdir -p /home/rust/logs
```

Copy `rustacs` and the Bash script tools:

```bash
sudo cp rustacs /home/rust/bin/rustacs
sudo cp rustserverbackup.sh /home/rust/bin/
sudo cp rustservergenesys.sh /home/rust/bin/
sudo cp rustserverlogswap.sh /home/rust/bin/
sudo cp rustservermod.sh /home/rust/bin/
```

Make them executable (mode 770):

```bash
sudo chmod 770 /home/rust/bin/rustacs
sudo chmod 770 /home/rust/bin/rustserverbackup.sh
sudo chmod 770 /home/rust/bin/rustservergenesys.sh
sudo chmod 770 /home/rust/bin/rustserverlogswap.sh
sudo chmod 770 /home/rust/bin/rustservermod.sh
```

Copy the supplied dot-env and systemd service unit files:

```bash
sudo cp .rustserver.env /home/rust/.rustacs/.rustserver.env
sudo cp rustserver.service /etc/systemd/system/rustserver.service
```

Set user/group ownership on the RUSTACS directories:

```bash
sudo chown -R rust:rust /home/rust/.rustacs
sudo chown -R rust:rust /home/rust/bin
sudo chown -R rust:rust /home/rust/backups
sudo chown -R rust:rust /home/rust/logs
```

Set the dot-env file permissions (mode 640):

```bash
sudo chmod 640 /home/rust/.rustacs/.rustserver.env
```

If you want `rustacs` available as a normal system command, create a symbolic
link in `/usr/local/bin` rather than creating a copy:

```bash
sudo ln -s /home/rust/bin/rustacs /usr/local/bin/rustacs
```

Reload systemd daemon after installing or changing `rustserver.service`:

```bash
sudo systemctl daemon-reload
```

Don't start the RustDedicated server yet. Audit the dot-env file first.

## The dot-env file

The dot-env file is the *centre* of RUSTACS. The standard PATH is:

```text
/home/rust/.rustacs/.rustserver.env
```

The Bash tools source that file directly, `rustacs` reads it, and
`rustserver.service` loads it through systemd's `EnvironmentFile` directive.
The dot-env file is therefore authoritative for the server values used by
all RUSTACS files and processes.

Edit it before starting the server:

```bash
sudo nano /home/rust/.rustacs/.rustserver.env
```

**!! <u>IMPORTANT</u> !!**   

Do NOT treat the supplied values as automatic defaults for your server! 
Audit the dot-env file from top to bottom and set the correct values 
for the server you're actually running. Spending a few minutes ensuring 
that the correct values have been set in the dot-env file is going to 
save you from a lot of head-scratching and trouble-shooting later!

### Dot-env file permissions

The dot-env file contains the WebRCON password in plain text because
RustDedicated needs that value and `rustacs` needs to read it. That makes 
the file permissions important.

The project layout uses:

```text
owner: rust
group: rust
mode:  0640
```

Mode 640 permissions allow only the group to read it and the owner to read
and write to the file.

Set the dot-env ownership and mode 640 with:

```bash
sudo chown rust:rust /home/rust/.rustacs/.rustserver.env
sudo chmod 640 /home/rust/.rustacs/.rustserver.env
```

**Don't upload, commit, post or otherwise share your dot-env file publicly**
**while it contains a real RCON password! Not even for support purposes.**

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

This is the PATH to the RustDedicated server systemd service unit. `rustacs`,
`rustservergenesys.sh` and `rustservermod.sh` use it when checking or managing
the RustDedicated server systemd service.

**Rust user account and group**

```ini
RUST_USERNAME=rust
RUST_USERGROUP=rust
```

These are the user and group that own the RustDedicated server and RUSTACS 
server management files.

**Rust infrastructure PATHs**

```ini
RUST_USER_HOME=/home/rust
RUST_INSTALL_WORKDIR=/home/rust/rustserver
RUST_SERVER_FILEDIR=/home/rust/rustserver/server
RUST_BACKUP_DIR=/home/rust/backups
```

These identify the Rust user's home directory, the RustDedicated installation
PATH, the server data PATH and the backup PATH.

**RustDedicated server settings**

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

**Rust WebRCON settings**

```ini
RUST_RCON_WEB=1
RUST_RCON_IP=127.0.0.1
RUST_RCON_PORT=28016
RUST_RCON_PASSWORD=your-RCON-passwd
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

**Rust and RUSTACS logging**

```ini
RUST_LOGDIR=/home/rust/logs
RUST_SERVER_LOGFILE=rustserver
RUST_SERVER_MAX_LOGFILE=2
RUST_BACKUP_RETENTION=31
```

`RUST_LOGDIR` is the log directory PATH. `RUST_SERVER_MAX_LOGFILE` is the size,
in MiB, at which `rustserverlogswap.sh` archives the active RustDedicated 
server log.

### `master.config`

`master.config` belongs to `rustservergenesys.sh`. It represents the settings
prepared for the next RustDedicated server game world.

The normal PATH is:

```text
/home/rust/.rustacs/master.config
```

If master.config doesn't exist when `rustservergenesys.sh` needs it, 
`rustservergenesys.sh` creates it from the current dot-env file. The 
map-selection commands alter `master.config` but don't immediately 
overwrite the active dot-env file. Running `rustservergenesys.sh` later 
with no arguments performs the apply operation while the RustDedicated 
server is stopped. This is a manual step intentionally - the live dot-env
file should never be overwritten unless the server owner/admin specifically 
approves it.

That distinction matters:

```text
dot-env file     settings currently used by RUSTACS/RustDedicated
master.config    settings prepared for the next world
```

### Multi-server setup

If you're administering more than one RustDedicated server, give  
**each individual server its own separate and individual dot-env file!** 
Don't put two or more servers into one dot-env file and don't make any
other server(s) share values that need to be proprietary.

For example:

```text
/home/rust/.rustacs/server-one.env
/home/rust/.rustacs/server-two.env
/home/rust/.rustacs/server-three.env
```

Each server's dot-env file needs its own bespoke values, including its
identity, game port, query port, RCON port, server/data PATHs, service unit 
file, backup directory PATH and any other setting(s) that differentiates it 
from all other RustDedicated servers. Ignoring this precondition is a recipe
for disaster!

There are two different multi-server arrangements to consider.

**Multiple server definitions with one RustDedicated instance managed at a time**

The standard RUSTACS dot-env PATH is:

```text
/home/rust/.rustacs/.rustserver.env
```

If you keep several server-specific dot-env files but only manage one
RustDedicated instance at a time, `.rustserver.env` can be a symbolic link to
the dot-env file for the server you're currently working with.

For example:

```bash
cd /home/rust/.rustacs
ln -sfn server-one.env .rustserver.env
```

The result is:

```text
.rustserver.env -> server-one.env
```

To select `server-two.env` instead:

```bash
ln -sfn server-two.env .rustserver.env
```

The symbolic link is replaced, so the result is now:

```text
.rustserver.env -> server-two.env
```

The individual server dot-env files remain completely separate. Nothing is
merged, copied or shared between them. `.rustserver.env` is simply selecting
which server-specific dot-env file is reached through the standard PATH.

Check the link before doing anything destructive or service-related:

```bash
readlink -f /home/rust/.rustacs/.rustserver.env
```

**Multiple RustDedicated instances running at the same time**

If two or more RustDedicated instances run simultaneously on the same physical
or virtual server, don't use a changing `.rustserver.env` symbolic link as a
shared selector for those running instances.

Each running RustDedicated instance needs its own dot-env file, its own
correctly adapted systemd service unit, and non-conflicting game, query and
RCON ports. Each service unit should load the dot-env file belonging to that
specific RustDedicated instance.

For example:

```text
rustserver-one.service    -> server-one.env
rustserver-two.service    -> server-two.env
rustserver-three.service  -> server-three.env
```

`rustserverbackup.sh` can explicitly select the server dot-env file to use:

```bash
/home/rust/bin/rustserverbackup.sh --server server-one.env
/home/rust/bin/rustserverbackup.sh --server server-two.env
/home/rust/bin/rustserverbackup.sh --server server-three.env
```

The selected dot-env file supplies that server's identity, data PATH, backup
PATH, service unit and other server-specific values. If `--server` isn't
specified, `rustserverbackup.sh` uses the standard
`/home/rust/.rustacs/.rustserver.env` dot-env file.

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

#### What `rustserverbackup.sh` does

`rustserverbackup.sh` performs a transactional backup of a RustDedicated
server's state data. By default it uses the standard
`/home/rust/.rustacs/.rustserver.env` dot-env file. A specific server dot-env
file can instead be selected with `--server <dot-env>`.

The selected dot-env file determines the server identity, data PATH, backup
PATH, systemd service unit, Rust account and `rustacs` PATH.

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

When the systemd service unit defined by `RUST_SERVICE_PATH` in the selected
dot-env file is active, the script:

1. Announces maintenance 30 minutes before shutdown.
2. Announces it again at 15 minutes.
3. Announces it again at 5 minutes.
4. Sends a final 30-second warning.
5. Runs `server.save` through `rustacs`.
6. Waits 30 seconds and sends the final shutdown message.
7. Stops the selected server's systemd service unit.
8. Creates the xz-compressed backup archive.
9. Corrects archive ownership when necessary.
10. Starts the selected server's systemd service unit again because it was active
    before the backup.
11. Removes matching backup archives older than the retention period.

If the service is already `inactive` or `failed`, the warning/countdown and
stop/restart sequence is skipped and the script proceeds to the archive.

An unexpected service state causes the script to abort rather than guessing
what it should do.

#### Running `rustserverbackup.sh`

Run it manually with no arguments to use the standard dot-env file:

```bash
/home/rust/bin/rustserverbackup.sh
```

To back up a specific RustDedicated server, use `--server` with that server's
dot-env file:

```bash
/home/rust/bin/rustserverbackup.sh --server server-one.env
```

A relative filename is resolved beneath `/home/rust/.rustacs/`. An absolute
dot-env PATH can also be supplied.

```bash
/home/rust/bin/rustserverbackup.sh --server /home/rust/.rustacs/server-one.env
```

If `--server` isn't specified, the script uses:

```text
/home/rust/.rustacs/.rustserver.env
```

The script expects `RUSTACS_PATH` to point to an executable `rustacs` tool. It
also uses `sudo systemctl` and may use `sudo chown`, so the account running it
needs the corresponding permissions.

#### Backup files and retention

Backup archives are written beneath `RUST_BACKUP_DIR` and are named from the
server identity and timestamp:

```text
<RUST_SERVER_ID>-backup_<timestamp>.tar.xz
```

The archive-retention age is set by `RUST_BACKUP_RETENTION` in the selected
dot-env file and is calculated in days. The supplied value is 31 (days). The 
housekeeping pass deletes matching backup archives older than the specified 
retention value.

The script writes its own progress log as:

```text
${RUST_LOGDIR}/rustserverbackup.log
```

### `rustservergenesys.sh`

#### What `rustservergenesys.sh` does

`rustservergenesys.sh` manages the settings used for the next RustDedicated 
server world. It has two deliberately separate jobs:

1. **Prepare** map settings in `master.config`.
2. **Apply** `master.config` to the active dot-env file when the server is
   stopped.

Preparing the next map doesn't generate or deploy a RustDedicated game world 
immediately. RustDedicated uses the new seed/world-size settings when the 
prepared dot-env values are subsequently used to (re)start the service.

**NOTE**: The script doesn't remove player blueprints. Player blueprints are 
sacrosanct and their removal should always be at the discretion of the server 
owner or admin.

#### Preparing a new map

New RustDedicated server world maps can be randomly generated using the 
`rustservergenesys.sh +newmap` script argument. The formula for this is: 
`$(( $(od -An -N4 -tu4 /dev/urandom) % 2147483648 ))`

Example usage and output:

```bash
~$ echo $(( $(od -An -N4 -tu4 /dev/urandom) % 2147483648 ))
1846592356
```

This generates a pseudo-random integer between 0 and 2147483647 (inclusive)
which is the range of usable RustDedicated world map seeds. The `+server.seed`
convar (console variable) in a RustDedicated service unit accepts only integer 
values (i.e. whole numbers).

Generate a random RustDedicated world map by running this script with:

```bash
/home/rust/bin/rustservergenesys.sh +newmap
```

The `+newmap` argument changes the seed only. It doesn't silently change the 
existing world size or any other setting.

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

A new random seed and a new world map size can also be prepared together:

```bash
/home/rust/bin/rustservergenesys.sh +newmap +size 6000
```

The options may be supplied in either order where the combination is valid.
The script validates the whole command before it changes `master.config`, so a
bad second option won't leave a half-applied command behind.

These preparation operations can be performed while RustDedicated is running
because they update `master.config` and then exit. They don't deploy the new
settings to the active dot-env file.

Any changes to the `master.config` do not affect a RustDedicated server that 
is currently running or stopped (inactive).

#### Applying `master.config`

To apply the prepared `master.config`, stop the RustDedicated server and run 
`rustservergenesys.sh` with no arguments:

```bash
/home/rust/bin/rustservergenesys.sh
```

**NB**: This operation will not continue while the RustDedicated server 
service is active and running. It should be stopped beforehand.

If `master.config` and the active dot-env file are identical, there's nothing
to apply and the script exits without any further action.

If `master.config` and the active dot-env file differ, `rustservergenesys.sh`
script will:

1. Make sure the world-backup directory exists.
2. Back up the current dot-env file.
3. Copy `master.config` over the active dot-env file.
4. Restore the expected Rust ownership on the relevant files.
5. Log the completed operation.

#### `rustservergenesys.sh` command options

```text
+newmap          Generate a new random map seed
+seed <value>    Set a specific map seed (0-2147483647)
+size <value>    Set the map world size (1000-6000)
--help           Show command help
```

`+newmap` and `+seed` are mutually exclusive. Asking for both is an error.
`+newmap` may be combined with `+size`, and `+seed` may be combined with
`+size`.

A missing value, duplicate option, unknown option, seed outside the accepted
range or world size outside `1000-6000` is rejected before `master.config` is
changed.

Display the command usage with:

```bash
/home/rust/bin/rustservergenesys.sh --help
```

#### `rustservergenesys.sh` backups

Before `rustservergenesys.sh` applies a changed `master.config`, it backs up the current
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

#### What `rustserverlogswap.sh` does

`rustserverlogswap.sh` prevents the active RustDedicated log from growing
indefinitely. It checks the active log's raw byte size against
`RUST_SERVER_MAX_LOGFILE` from the dot-env file. That setting is expressed in
MiB (mebibytes).

The active log filename is built from RUST_SERVER_LOGFILE beneath
RUST_LOGDIR:

```text
<RUST_SERVER_LOGFILE>.log
```

If the log doesn't exist, or hasn't reached the configured size, the script has
nothing to do and exits.

#### Running `rustserverlogswap.sh`

Run it manually with:

```bash
/home/rust/bin/rustserverlogswap.sh
```

There are no command-line options. The script is intended to be safe for
regular scheduled execution because it only performs the archive sequence when
the active log has reached the configured threshold.

#### Log archive sequence

When the active log reaches the threshold, `rustserverlogswap.sh`:

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

#### What `rustservermod.sh` does

`rustservermod.sh` installs either Carbon or Oxide into the RustDedicated
install directory identified by `RUST_INSTALL_WORKDIR` in the active 
dot-env file.

It downloads the selected Linux release to a temporary directory, extracts 
it into the RustDedicated installation and then sets the installation 
ownership to the Rust user/group from the dot-env file.

This script is an installer. It does not claim to perform every 
framework-specific runtime setting that a particular Carbon or Oxide release 
may require.

**NB**: Installing any modding framework risks stripping a RustDedicated server 
of its vanilla status, forcing it to be listed under the 'Modded' tab instead of 
'Community' to comply with [Facepunch](https://support.facepunchstudios.com/hc/en-us/articles/360009062817-Guidelines-for-community-servers-using-plugins-mods) guidelines.

#### Installing Carbon

Make sure the RustDedicated server service is stopped, then run:

```bash
/home/rust/bin/rustservermod.sh carbon
```

Carbon is downloaded as a compressed tar archive and extracted directly into
`RUST_INSTALL_WORKDIR`.

#### Installing Oxide

Make sure the RustDedicated server service is stopped, then run:

```bash
/home/rust/bin/rustservermod.sh oxide
```

Oxide is downloaded as a ZIP archive and extracted directly into
`RUST_INSTALL_WORKDIR`. The `unzip` command is therefore required for an Oxide
installation.

#### `rustservermod.sh` safeguards

Before installing anything, the script checks that:

- a valid argument (`carbon` or `oxide`) was supplied;
- the RustDedicated installation PATH exists;
- the systemd service unit exists;
- the RustDedicated server service is inactive;
- `curl` is installed;
- `unzip` is installed when Oxide is selected; and
- the other mod framework hasn't already been detected.

Carbon and Oxide aren't intended to be installed together by this script. If it
detects an `oxide` directory while installing Carbon, or vice versa, it aborts.

Temporary downloads are removed automatically when the script exits.

The script writes its progress log to the directory defined in the dot-env 
file by `RUST_LOGDIR` variable, as:

```text
${RUST_LOGDIR}/rustservermod.log
```

## `rustserver.service`

`rustserver.service` is the supplied systemd service unit for RustDedicated. 
It isn't just a wrapper around the executable: it defines the account,
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

Enabling a service and starting it are different operations. `enable` will
cause systemd to start it at boot; it doesn't mean you have to start it right 
away.

### Starting and stopping the service

With `rustacs` you have an easy and convenient command to perform the status
operations of a RustDedicated server. Or you can do it via the long-hand, 
traditional `systemctl` way.

Using systemd directly:

```bash
sudo systemctl start rustserver.service
sudo systemctl stop rustserver.service
sudo systemctl restart rustserver.service
sudo systemctl status --no-pager rustserver.service
```

Using `rustacs`:

```bash
rustacs server start
rustacs server stop
rustacs server restart
rustacs server status
```

### What happens when the service starts

Before launching RustDedicated, the supplied unit runs SteamCMD anonymously 
and performs the RustDedicated server application update for: 
Steam App ID `258550`

It then launches RustDedicated with server values from the dot-env file, which
includes the server IP/ports, map, identity, hostname, player limit, tutorial
setting, tags, save interval and WebRCON settings. Among other possible and 
potential [convar](https://wiki.facepunch.com/rust/Creating-a-server) (console variable) settings. 

The supplied RUSTACS service unit also contains placeholders for server 
description, image and URL values. Read the file before using it on your 
own public server and change those values to suit your server.

The service unit is configured to restart RustDedicated on failure, with 
a delay between restart attempts. A deliberate service stop is still a 
deliberate stop.

## Automation with cron

*RUSTACS was very much designed with automation in mind and is ultimately* 
*`crontab` user-friendly and configurable.*

The Bash tools don't require an interactive terminal. `rustserverbackup.sh` 
and `rustserverlogswap.sh` tools can be scheduled with `cron` once you've 
tested them manually and know the required permissions are in place.

For working out any and all `cron` possibilities and settings, see the
[crontab guru](https://crontab.guru/) website by Cronitor. Which is one of the best resources 
for this on the Internet.

For example, a backup `cron job` might be:

```cron
0 4 * * * /home/rust/bin/rustserverbackup.sh
```

A regular log-size check might be:

```cron
*/15 * * * * /home/rust/bin/rustserverlogswap.sh
```

The above are examples, not prescribed schedules. Pick times that make sense
for your server. In particular, remember that an active-server backup using 
`rustserverbackup.sh` includes a 30-minute in-game player warning countdown 
before shutdown.

`rustacs` can also be called from cron for RustDedicated commands:

```cron
*/15 * * * * /home/rust/bin/rustacs server.save
```

Before relying on cron, run the exact command manually as the same account that
will run the cron job. RUSTACS scripts use absolute PATHs in several places,
but user/group permissions and `sudo` rules and policies still matter.

## Logs and backups

The actual PATHs come from the active dot-env file. With the supplied layout,
RUSTACS uses:

```text
/home/rust/logs/                 RUSTACS and RustDedicated logs
/home/rust/backups/              Rust state and archived server logs
/home/rust/backups/worldbackups/ rustservergenesys.sh dot-env backups
```

To ensure ease of identification and traceability during troubleshooting, 
each log file dynamically inherits the `basename` of its parent script:

```text
rustserverbackup.log
rustservergenesys.log
rustserverlogswap.log
rustservermod.log
```



Don't confuse those progress logs with the active RustDedicated server log.
`rustserverlogswap.sh` manages the RustDedicated log; it doesn't rotate the
RUSTACS tools' own progress logs.

## Troubleshooting RUSTACS

If `rustacs` says:

```text
Connection failed: Server is offline or RCON IP/port is misconfigured.
```

First establish whether RustDedicated systemd service is actually running:

```bash
rustacs server status
```

If the service is active, check the RCON IP and port in the active dot-env 
file. For the underlying WebSocket error, repeat the command using the 
`--verbose` argument:

```bash
rustacs status --verbose
```

If `rustacs` reports that the dot-env file can't be read, check that
`/home/rust/.rustacs/.rustserver.env` exists and that the user account 
running the command has the correct permissions to read it.

If a Bash tool behaves as though it's targeting the wrong server, check the
active dot-env file before doing anything else:

```bash
readlink -f /home/rust/.rustacs/.rustserver.env
```

If `.rustserver.env` is a regular file rather than a symbolic link, inspect 
it directly instead.

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
