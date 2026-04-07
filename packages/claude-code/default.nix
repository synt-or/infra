{ lib
, stdenv
, fetchurl
, autoPatchelfHook
, makeBinaryWrapper
, glibc
, gnupg
, jq
, ripgrep
, procps
, bubblewrap
, socat
}:

let
  versionInfo = lib.importJSON ./versions.json;
  version = versionInfo.version;
  cdnBase = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

  binary = fetchurl {
    url = "${cdnBase}/${version}/${versionInfo.platform}/claude";
    hash = versionInfo.binarySri;
  };

  manifest = fetchurl {
    url = "${cdnBase}/${version}/manifest.json";
    hash = versionInfo.manifestSri;
  };

  manifestSig = fetchurl {
    url = "${cdnBase}/${version}/manifest.json.sig";
    hash = versionInfo.manifestSigSri;
  };

  gpgKey = ../../keys/claude-code.asc;

in stdenv.mkDerivation {
  pname = "claude-code";
  inherit version;

  dontUnpack = true;
  dontStrip = true;

  nativeBuildInputs = [
    autoPatchelfHook
    makeBinaryWrapper
    gnupg
    jq
  ];

  buildInputs = [
    glibc
  ];

  buildPhase = ''
    runHook preBuild

    # Vérifier la signature GPG du manifest
    export GNUPGHOME=$(mktemp -d)
    gpg --batch --import ${gpgKey}
    gpg --batch --verify ${manifestSig} ${manifest}

    # Extraire le checksum attendu depuis le manifest signé
    expected=$(jq -r '.platforms."linux-arm64".checksum' ${manifest})

    # Vérifier le SHA256 du binaire contre le manifest
    actual=$(sha256sum ${binary} | cut -d' ' -f1)
    if [ "$expected" != "$actual" ]; then
      echo "ERREUR: SHA256 du binaire ne correspond pas au manifest signé !"
      echo "  manifest attend : $expected"
      echo "  binaire réel    : $actual"
      exit 1
    fi
    echo "Signature GPG vérifiée. Checksum du binaire correspond au manifest."

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    install -Dm755 ${binary} $out/libexec/claude-code/claude

    makeBinaryWrapper $out/libexec/claude-code/claude $out/bin/claude \
      --set DISABLE_AUTOUPDATER 1 \
      --set DISABLE_INSTALLATION_CHECKS 1 \
      --set-default FORCE_AUTOUPDATE_PLUGINS 1 \
      --unset DEV \
      --prefix PATH : ${lib.makeBinPath [
        procps
        ripgrep
        bubblewrap
        socat
      ]}

    runHook postInstall
  '';

  meta = {
    description = "Anthropic's agentic coding tool (native binary, GPG-verified)";
    homepage = "https://github.com/anthropics/claude-code";
    license = lib.licenses.unfree;
    platforms = [ "aarch64-linux" ];
    mainProgram = "claude";
  };
}
