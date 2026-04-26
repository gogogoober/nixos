{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:

buildGoModule rec {
  pname = "blugo";
  version = "0.5.6";

  src = fetchFromGitHub {
    owner = "ivangsm";
    repo = "blugo";
    rev = "v${version}";
    hash = "sha256-x+nAWpr+wtJT5/wuKx+8WMhwjMaJQuFCLHO681CGXiA=";
  };

  vendorHash = "sha256-qQDFZYgwffIN9Wc2LRS6lldukSca38lbx7z+1AD1c4I=";

  subPackages = [ "cmd/blugo" ];

  meta = {
    description = "TUI bluetooth manager for Linux";
    homepage = "https://github.com/ivangsm/blugo";
    license = lib.licenses.mit;
    mainProgram = "blugo";
    platforms = lib.platforms.linux;
  };
}
