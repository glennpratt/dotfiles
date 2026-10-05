# diffx: local web UI for reviewing git diffs and handing inline comments back
# to a coding agent. Not in nixpkgs; built from source like nixpkgs' `skills`.
# Agent skills that drive it: home/private_dot_claude/skills/diffx-*.
#
# To update: bump version, set both hashes to lib.fakeHash, and rebuild to get
# the real values.
{
  lib,
  stdenv,
  fetchFromGitHub,
  fetchPnpmDeps,
  pnpm_10,
  nodejs,
  pnpmConfigHook,
}:
let
  pnpm = pnpm_10;
in
stdenv.mkDerivation (finalAttrs: {
  pname = "diffx";
  version = "0.16.0";

  src = fetchFromGitHub {
    owner = "wong2";
    repo = "diffx";
    tag = "v${finalAttrs.version}";
    hash = "sha256-tNmc4eTnLp6BMn4800y1iokvqIAQ7lkkuhpl0jnv6w8=";
  };

  pnpmDeps = fetchPnpmDeps {
    fetcherVersion = 3;
    inherit (finalAttrs) pname version src;
    inherit pnpm;
    hash = "sha256-+R5ZDL16iLG7iodrCICwnGSP6QJ+6g/2yBK7h0rhG6U=";
  };

  nativeBuildInputs = [
    nodejs
    pnpmConfigHook
    pnpm
  ];

  buildInputs = [
    nodejs
  ];

  buildPhase = ''
    runHook preBuild

    pnpm run build

    runHook postBuild
  '';

  # cli.mjs reads ../package.json for --version and serves ./client.
  installPhase = ''
    runHook preInstall

    rm -rf node_modules
    pnpm install --force --offline --production --ignore-scripts

    mkdir -p $out/lib/node_modules/diffx-cli $out/bin
    cp -r dist node_modules package.json $out/lib/node_modules/diffx-cli

    ln -s $out/lib/node_modules/diffx-cli/dist/cli.mjs $out/bin/diffx
    chmod +x $out/lib/node_modules/diffx-cli/dist/cli.mjs
    patchShebangs $out/lib/node_modules/diffx-cli/dist/cli.mjs

    runHook postInstall
  '';

  meta = {
    description = "Local code review UI for git diffs, built for coding agent workflows";
    homepage = "https://github.com/wong2/diffx";
    license = lib.licenses.mit;
    mainProgram = "diffx";
  };
})
