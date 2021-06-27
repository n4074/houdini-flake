{
  description = "A very basic flake";

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        deps = pkgs: with pkgs; [
            bc
            less
            libGL
            libGLU
            libxkbcommon
            xlibs.libICE
            xlibs.libSM
            xorg.libX11
            xorg.libxcb
            xorg.libXcomposite
            xorg.libXcursor
            xorg.libXdamage
            xorg.libXfixes
            xorg.libXi
            xorg.libXrender
            xorg.libXtst
            xorg.libXScrnSaver
            xorg.libXext
            pciutils
            alsa-lib
            nss
            nspr
            expat
            fontconfig
            freetype
            zlib
            libpng
            libjpeg
            udev
            gcc6
            dbus
            # remove
            linuxPackages.nvidia_x11
        ];

        ld_library_path = builtins.concatStringsSep ":" [
          "${pkgs.stdenv.cc.cc.lib}/lib64"
          (pkgs.lib.makeLibraryPath (deps pkgs))
        ];
    in {

      packages.x86_64-linux.houdini-fhs = (
        pkgs.buildFHSUserEnvBubblewrap {
          name = "houdini";
          targetPkgs = deps;

          runScript = ''
            ${pkgs.undaemonize}/bin/undaemonize ${self.packages.x86_64-linux.houdini-unwrapped}/bin/houdini;
          '';
        }

      );

      packages.x86_64-linux.houdini = pkgs.writeScriptBin "houdini" ''
        #!${pkgs.stdenv.shell}
        ${self.packages.x86_64-linux.houdini-unwrapped}/houdini/sbin/sesinetd -c -D &
        ${self.packages.x86_64-linux.houdini-fhs}/bin/houdini
      '';

      packages.x86_64-linux.houdini-unwrapped = (with pkgs;
        stdenv.mkDerivation rec {
          version = "18.5.596";
          pname = "houdini";

          src = requireFile rec {
            name = "houdini-${version}-linux_x86_64_gcc6.3.tar.gz";
            sha256 = "0kppc9kn5kj3zi5r0bgj3zr92bhba2zailspzqcan4mfj2yzcspa";
            message = ''
              This nix expression requires that ${name} is already part of the store.
              Download it from https://www.sidefx.com and add it to the nix store with:
                  nix-prefetch-url <URL>
              This can't be done automatically because you need to create an account on
              their website and agree to their license terms before you can download
              it. That's what you get for using proprietary software.
            '';
          };

          nativeBuildInputs = [
            autoPatchelfHook
          ];

          buildInputs = [ bc makeWrapper pkgs.stdenv.cc.cc.lib ];
          installPhase = ''
            export dontAutoPatchelf=1
            patchShebangs houdini.install
            mkdir -p $out
            ./houdini.install --install-houdini \
                              --no-install-menus \
                              --no-install-bin-symlink \
                              --auto-install \
                              --no-root-check \
                              --accept-EULA 2020-05-05 \
                              $out
            #echo "export LD_LIBRARY_PATH=${ld_library_path}" >> $out/bin/app_init.sh
            #echo "export LD_LIBRARY_PATH=${ld_library_path}" >> $out/houdini/sbin/app_init.sh
          '';

          preFixup = ''
            makeWrapper $out/houdini/sbin/sesinetd $out/bin/sesinetd
          '';

          postFixup = ''
            INTERPRETER="$(cat "$NIX_CC"/nix-support/dynamic-linker)"
            for BIN in $(find $out/bin $out/houdini/sbin -type f -executable); do
              if patchelf $BIN 2>/dev/null ; then
                echo "Patching ELF $BIN"
                patchelf --set-interpreter "$INTERPRETER" "$BIN"
              fi
            done

            autoPatchelf "$out/houdini/sbin/sesinetd"
          '';

          meta = {
            description = "3D animation application software";
            homepage = "https://www.sidefx.com";
            license = lib.licenses.unfree;
            platforms = lib.platforms.linux;
            hydraPlatforms = [ ]; # requireFile src's should be excluded
            maintainers = [ lib.maintainers.canndrew ];
          };
        }
      );
      
      defaultPackage.x86_64-linux = self.packages.x86_64-linux.houdini;
  };
}
