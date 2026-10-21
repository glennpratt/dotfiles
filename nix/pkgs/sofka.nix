# sofka: keyboard-driven Kubernetes TUI in Rust, inspired by k9s. Not in
# nixpkgs; built from source like diffx.
#
# To update: bump version, set both hashes to lib.fakeHash, and rebuild to get
# the real values.
{
  lib,
  rustPlatform,
  fetchFromGitHub,
  cmake,
}:

rustPlatform.buildRustPackage (finalAttrs: {
  pname = "sofka";
  version = "0.31.14";

  src = fetchFromGitHub {
    owner = "nklmilojevic";
    repo = "sofka";
    tag = "v${finalAttrs.version}";
    hash = "sha256-ke6EgYwuEMhJpaZT9T36Yhvgy2FrjgFF/zfHn2zBOy4=";
  };

  cargoHash = "sha256-op5SPbb/QDem0oVqjS5cjyvC2zW7pbrFUgB7crx1uV8=";

  # aws-lc-sys (the TLS crypto backend) builds its C sources with cmake.
  nativeBuildInputs = [ cmake ];

  # The test suite builds a rustls-backed kube client, which needs native root
  # CA certs that the network-less build sandbox does not have. CI runs tests.
  doCheck = false;

  meta = {
    description = "A Kubernetes TUI, reimagined in Rust";
    homepage = "https://github.com/nklmilojevic/sofka";
    changelog = "https://github.com/nklmilojevic/sofka/releases/tag/v${finalAttrs.version}";
    license = with lib.licenses; [
      mit
      asl20
    ];
    mainProgram = "sofka";
    platforms = lib.platforms.unix;
  };
})
