{
  description = "A very basic flake";

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
        license_dir = "~/.config/houdini";
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
            dbus
            # remove
            linuxPackages.nvidia_x11
            gdb
        ];
        ld_library_path = with pkgs; builtins.concatStringsSep ":" [
          "${stdenv.cc.cc.lib}/lib64"
          (lib.makeLibraryPath (deps pkgs))
        ];
    in {
      packages.x86_64-linux.houdini-fhs = (
        pkgs.buildFHSUserEnv {
          name = "houdini";
          targetPkgs = deps;

          extraBuildCommands = ''
            mkdir -p $out/usr/lib/sesi
          '';

          #runScript = "${pkgs.undaemonize}/bin/undaemonize ${self.packages.x86_64-linux.houdini}/bin/houdini";

        }

      );

      packages.x86_64-linux.houdini = (with pkgs;
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

          buildInputs = [ bc ];
          installPhase = ''
            patchShebangs houdini.install
            mkdir -p $out
            sed -i "s|/usr/lib/sesi|${license_dir}|g" houdini.install
            ./houdini.install --install-houdini \
                              --no-install-menus \
                              --no-install-bin-symlink \
                              --auto-install \
                              --no-root-check \
                              --accept-EULA 2020-05-05 \
                              $out
            sed -i "s|/usr/lib/sesi|${license_dir}|g" $out/houdini/sbin/sesinetd_safe
            sed -i "s|/usr/lib/sesi|${license_dir}|g" $out/houdini/sbin/sesinetd.startup
            echo "export LD_LIBRARY_PATH=${ld_library_path}" >> $out/bin/app_init.sh
            echo "export LD_LIBRARY_PATH=${ld_library_path}" >> $out/houdini/sbin/app_init.sh
          '';
          postFixup = ''
            INTERPRETER="$(cat "$NIX_CC"/nix-support/dynamic-linker)"
            for BIN in $(find $out/bin $out/houdini/sbin -type f -executable); do
              if patchelf $BIN 2>/dev/null ; then
                echo "Patching ELF $BIN"
                patchelf --set-interpreter "$INTERPRETER" "$BIN" || true
              fi
            done
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
