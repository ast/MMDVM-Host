# MMDVM-Host, packaged for Nix.
#
# Upstream builds with a hand-written Makefile that assumes /usr/local and a
# git checkout. Neither holds inside a Nix sandbox. The three mismatches are
# handled from this file rather than by patching the Makefile, deliberately:
# this repo is a fork that tracks g4klx/MMDVM-Host, and every upstream file
# left untouched is one that cannot conflict on the next rebase.
{
  lib,
  stdenv,
  mosquitto,
  nlohmann_json,

  # The commit this was built from. MMDVM-Host prints it at startup, and it is
  # the only thing distinguishing two builds carrying the same VERSION. Passed
  # in by the flake because the sandbox has no .git to read it from.
  gitVersion ? null,
}:

let
  # Upstream keeps the release version in Version.h and nowhere else -- there
  # are no tags on this repo. Parse it rather than restating it here, so that
  # rebasing onto upstream cannot quietly leave a stale version behind.
  version =
    let
      match = builtins.match ".*VERSION = \"([0-9]+)\".*" (builtins.readFile ../Version.h);
    in
    if match == null then
      throw "mmdvm-host: could not parse VERSION out of Version.h"
    else
      builtins.head match;

  # Same 40 zeroes the Makefile falls back to when .git is absent, so an
  # unknown revision looks the way upstream makes it look.
  rev = if gitVersion != null then gitVersion else lib.strings.replicate 40 "0";
in

stdenv.mkDerivation (finalAttrs: {
  pname = "mmdvm-host";
  inherit version;

  # cleanSource drops .git and editor debris. It matters for more than tidiness
  # here: without it every commit would change the source hash and force a
  # rebuild of a package whose inputs had not actually changed.
  src = lib.cleanSource ../.;

  buildInputs = [
    mosquitto # MQTT status publishing; upstream links it unconditionally
    nlohmann_json # header-only, pulled in by Log.h for the JSON event feed
  ];

  # Nothing here runs at build time, so keep host and build inputs distinct.
  strictDeps = true;

  # Safe only because GitVersion.h is written in preBuild: MMDVM-Host.cpp
  # includes it, and upstream's `MMDVM-Host: GitVersion.h $(OBJS)` rule lets
  # make start compiling objects before generating it.
  enableParallelBuilding = true;

  # Upstream hardcodes `CXX = c++`, which ignores the compiler stdenv puts in
  # the environment and defeats cross compilation.
  makeFlags = [ "CXX=${stdenv.cc.targetPrefix}c++" ];

  preBuild = ''
    # Upstream's rule for this shells out to `git rev-parse HEAD`. The rule has
    # no prerequisites, so make leaves the file alone once it exists.
    echo 'const char *gitversion = "${rev}";' > GitVersion.h
  '';

  # `make install` is not used: it writes to /usr/local/bin, and its sibling
  # install-service calls useradd and systemctl.
  installPhase = ''
    runHook preInstall

    install -Dm755 MMDVM-Host $out/bin/MMDVM-Host

    # Reference data rather than configuration. MMDVM-Host takes these paths
    # from the .ini, so a NixOS module can point at the store instead of
    # copying them into /etc. DMRIds.dat and NXDN.csv are only seeds -- the
    # host refreshes them itself every 24 h into a writable path.
    install -Dm644 MMDVM-Host.ini RSSI.dat DMRIds.dat NXDN.csv -t $out/share/mmdvm-host
    install -Dm644 RSSI/*.dat -t $out/share/mmdvm-host/RSSI

    runHook postInstall
  '';

  # Cheap proof that the thing actually runs, and that the version and commit
  # baked in above came out the far side intact.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck

    # Note: not `out=$(...)`, which would clobber $out.
    reported=$("$out/bin/MMDVM-Host" --version 2>&1)
    echo "$reported"

    echo "$reported" | grep -q '${version}' \
      || { echo "expected VERSION ${version} in --version output"; exit 1; }

    # Upstream prints only the first 7 characters of the commit.
    echo "$reported" | grep -q '${builtins.substring 0 7 rev}' \
      || { echo "expected commit ${builtins.substring 0 7 rev} in --version output"; exit 1; }

    runHook postInstallCheck
  '';

  meta = {
    description = "Host program for the MMDVM multi-mode digital voice modem";
    longDescription = ''
      MMDVM-Host drives an MMDVM or DVMega modem on one side and a network
      gateway on the other, supporting D-Star, DMR, P25 Phase 1, NXDN, System
      Fusion, POCSAG and FM.

      This is a fork of g4klx/MMDVM-Host carrying Nix packaging and no source
      changes.
    '';
    homepage = "https://github.com/ast/MMDVM-Host";
    license = lib.licenses.gpl2Plus;
    mainProgram = "MMDVM-Host";
    platforms = lib.platforms.linux;
    maintainers = [
      {
        name = "Albin Stigo (SM6WJM / AD8KM)";
        github = "ast";
        githubId = 130054;
      }
    ];
  };
})
