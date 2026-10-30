# sfax for Termux

sfax builds small `.sfx` application bundles and installs them from Termux. A bundle is a ZIP archive containing `manifest.json`, an app-specific `install.sh`, and optional setup hooks or a `data/` directory.

## Requirements

In Termux, install the archive tools:

```sh
pkg update
pkg install bash coreutils unzip zip
```

## Create a package

Create an app directory with `manifest.json` and `install.sh`:

```text
my-app/
├── manifest.json
├── install.sh
├── preinstall.sh    # optional
├── postinstall.sh   # optional
└── data/            # optional payload
```

Example `manifest.json`:

```json
{
  "name": "hello-termux",
  "version": "1.0.0",
  "architecture": "aarch64",
  "dependencies": [],
  "description": "Example Termux app"
}
```

The package's `install.sh` receives the extracted `data/` path as its first argument (or a path to an empty/nonexistent data directory if there is no payload). Keep installation paths inside `$PREFIX`; do not assume root access or use `apt`/`dpkg`. Install Termux dependencies with `pkg install` in `preinstall.sh` when needed.

Install the `build_sfx`:
```sh
sfax install sfax-build-sfx
```

Build the archive with `build_sfx`:

```sh
build_sfx ./my-app
```

The resulting archive is written to `my-app/dist/hello-termux-1.0.0-termux.sfx`. To choose another output directory:

```sh
build_sfx ./my-app ./output
```

## Install a package

Run the installer from Termux with a local archive:

```sh
sfax ./hello-termux-1.0.0-termux.sfx
```

The installer checks that it is running inside Termux, extracts to a temporary directory, runs the optional `preinstall.sh`, the package `install.sh`, and then the optional `postinstall.sh`. Temporary files are removed on exit.

## Package hooks

- `preinstall.sh` can install declared Termux packages with `pkg install -y ...`.
- `install.sh` performs the app-specific installation and can copy files from its first argument.
- `postinstall.sh` runs after installation completes successfully.

Hooks are shell scripts, run with `bash`, and receive the package data directory as their first argument. The manifest is descriptive; dependency installation is explicit in `preinstall.sh` so packages do not need a JSON parser just to bootstrap dependencies.

## Java package manager

The standalone package manager source, build instructions, and Termux CLI installer are in [`sfax/`](sfax/README.md). It supports repository listing, search, package details, dependency resolution, and `.sfx` installs.

## Package repository

Store ARM64 packages in [`repo/arm64/`](repo/arm64/) and publish them with `bash repo/publish.sh ./package.sfx`. The publisher adds the archive and its SHA-256 entry to the repository index. GitHub Pages deployment and setup are described in [`repo/README.md`](repo/README.md).
