############################################################################
#
# Hydra release jobset.
#
# The purpose of this file is to select jobs defined in default.nix and map
# them to all supported build platforms.
#
############################################################################

# The project sources
{ ouroroboros-network ? { outPath = ./.; rev = "abcdef"; }

# Function arguments to pass to the project
, projectArgs ? {
    config = { allowUnfree = false; inHydra = true; };
    gitrev = ouroroboros-network.rev;
  }

# The systems that the jobset will be built for.
, supportedSystems ? [ "x86_64-linux" "x86_64-darwin" ]

# The systems used for cross-compiling
, supportedCrossSystems ? [ "x86_64-linux" ]

# A Hydra option
, scrubJobs ? true

, withProblematicWindowsTests ? false

# Dependencies overrides
, sourcesOverride ? {}

# Import pkgs, including IOHK common nix lib
, pkgs ? import ./nix { inherit sourcesOverride; }

}:

with (import pkgs.iohkNix.release-lib) {
  inherit pkgs;
  inherit supportedSystems supportedCrossSystems scrubJobs projectArgs;
  packageSet = import ouroroboros-network;
  gitrev = ouroroboros-network.rev;
};

with pkgs.lib;

let
  testsSupportedSystems = [ "x86_64-linux" "x86_64-darwin" ];
  # Recurse through an attrset, returning all test derivations in a list.
  collectTests' = ds: filter (d: elem d.system testsSupportedSystems) (collect isDerivation ds);
  # Adds the package name to the test derivations for windows-testing-bundle.nix
  # (passthru.identifier.name does not survive mapTestOn)
  collectTests = ds: concatLists (
    mapAttrsToList (packageName: package:
      map (drv: drv // { inherit packageName; }) (collectTests' package)
    ) ds);

  disabledMingwW64Tests = if withProblematicWindowsTests then {} else {
    haskellPackages.ouroboros-network.checks.test-network = null;
    checks.tests.ouroboros-network.test-network = null;
    haskellPackages.Win32-network.checks.test-Win32-network = null;
    checks.tests.Win32-network.test-Win32-network = null;
    haskellPackages.network-mux.checks.test-network-mux = null;
    checks.tests.network-mux.test-network-mux.x86_64-linux = null;
  };

  inherit (systems.examples) mingwW64 musl64;

  jobs = {
    native = mapTestOn (__trace (__toJSON (packagePlatforms project)) (packagePlatforms project));
    "${mingwW64.config}" = recursiveUpdate (mapTestOnCross mingwW64 (packagePlatformsCross project)) disabledMingwW64Tests;
    # TODO: fix broken evals
    #musl64 = mapTestOnCross musl64 (packagePlatformsCross project);
  } // (mkRequiredJob (
      collectTests jobs.native.checks ++
      collectTests jobs.native.benchmarks
    ));

in jobs
