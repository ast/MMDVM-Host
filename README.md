# MMDVM-Host — Nix packaging fork

> **This is a fork of [g4klx/MMDVM-Host](https://github.com/g4klx/MMDVM-Host).**
> It adds a Nix package and changes nothing else. Maintained by Albin Stigo —
> **SM6WJM** (SE) / **AD8KM** (US) — for a Raspberry Pi 4 hotspot running
> NixOS.

## What this fork changes

**No C++ source is modified.** Every upstream file is byte-identical to
`g4klx/MMDVM-Host`, and this README header is the only change to a file that
existed upstream. That is deliberate: the packaging lives in new files so that
rebasing onto upstream stays a trivial operation.

| Path | What it is |
| --- | --- |
| `flake.nix` | Flake outputs: `packages`, an `overlays.default`, a `devShells.default`, and `checks` |
| `nix/package.nix` | The derivation |
| `.gitignore` | Ignores `result` symlinks and `.direnv/` |
| `README.md` | This header |

Three things about the upstream Makefile do not survive a Nix sandbox, and all
three are handled from `nix/package.nix` rather than by patching the Makefile:

- It hardcodes `CXX = c++`, ignoring the compiler in the environment and
  breaking cross compilation. The package passes `CXX` in explicitly.
- It generates `GitVersion.h` by shelling out to `git rev-parse HEAD`, and
  there is no `.git` in the sandbox — upstream's fallback is 40 zeroes. The
  flake passes the real revision in, so `MMDVM-Host --version` reports the
  commit it was built from.
- `make install` writes to `/usr/local/bin`, and `make install-service` calls
  `useradd` and `systemctl`. Neither is used; the package has its own install
  phase.

The version is parsed out of upstream's `Version.h` rather than restated, so a
rebase cannot leave a stale version number behind.

## Using it

```console
$ nix build                       # builds for the host platform
$ nix run . -- --version
$ nix develop                     # mosquitto + a compiler, for an in-tree `make`
$ nix flake check                 # builds and runs the package's install check
```

As a flake input, with the overlay:

```nix
{
  inputs.mmdvm-host = {
    url = "github:ast/MMDVM-Host";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
nixpkgs.overlays = [ inputs.mmdvm-host.overlays.default ];
environment.systemPackages = [ pkgs.mmdvm-host ];
```

Dependencies are `mosquitto` (MQTT status publishing, which upstream links
unconditionally) and the header-only `nlohmann_json` (pulled in by `Log.h` for
the JSON event feed).

## Provenance

The Nix packaging in this fork was written with [Claude
Code](https://claude.com/claude-code) (Anthropic) assisting, and reviewed
before being committed. The upstream MMDVM-Host source is entirely the work of
Jonathan Naylor G4KLX and its contributors, and is unmodified here.

---

These are the source files for building the MMDVM Host, the program that
interfaces to the MMDVM or DVMega on the one side, and a suitable network (via a
gateway) on the other. It supports D-Star, DMR, P25 Phase 1, NXDN, System Fusion,
POCSAG, and FM on the MMDVM, and D-Star, DMR, and System Fusion on the DVMega.

On the D-Star side the MMDVM Host interfaces with the D-Star Gateway, on DMR it
connects to the DMR Gateway to allow for connection to multiple DMR networks.
On System Fusion it connects to the DG-Id or YSF Gateway to allow
access to the FCS and YSF networks. On P25 it connects to the P25 Gateway. On
NXDN it connects to the NXDN Gateway which provides access to the NXDN and
NXCore talk groups. It uses the DAPNET Gateway to access DAPNET to receive
paging messages for transmission using POCSAG.

It builds on 32-bit and 64-bit Linux as well as on Windows using Visual Studio
2022 on x86 and x64.

This software is licenced under the GPL v2 and is primarily intended for amateur and
educational use.
