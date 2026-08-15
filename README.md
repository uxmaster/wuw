# wuw

`wuw` means “what’s up with”. It gives a compact, systemd-style status view
for a service managed by runit or a traditional SysV init script, without
requiring systemd.

It reports the service definition, enabled and active state, main process,
descendant processes, resource use, and recent logs when they are readable.
Runit services and their dedicated loggers are discovered under the usual
Devuan paths. If no runit service is available, `wuw` falls back to
`/etc/init.d/SERVICE status`.

## Installation

On a machine configured to use the Enabla Devuan repository:

```sh
sudo apt update
sudo apt install wuw
```

## Usage

```text
wuw [-n lines] SERVICE
```

Examples:

```sh
wuw ssh
wuw mysql
wuw -n 30 sshguard
```

The default is 12 log lines. Set `WUW_COLOR=always` or `WUW_COLOR=never` to
override automatic terminal colour detection. The standard `NO_COLOR`
environment variable is also honoured.

The exit status is 0 for an active service, 3 for an inactive or unknown
service state, 4 when the service cannot be found, and 2 for invalid usage.
Reading protected service logs may require membership in `adm` or running the
command through `sudo`.

## Building the Debian package

Install the Debian packaging tools and build from the repository root:

```sh
sudo apt install build-essential debhelper
dpkg-buildpackage -us -uc -b
```

The resulting architecture-independent package is written to the parent
directory.

## License

Copyright © 2026 Jacek Stypuła. Licensed under the WTFPL, version 2. See
[`LICENSE`](LICENSE).
