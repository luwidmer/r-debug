# This flake was initially generated by fh, the CLI for FlakeHub (version 0.1.6)
{
  # A helpful description of your flake
  description = "R-devel";

  # Flake inputs
  inputs = { nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable"; };

  outputs = { self, nixpkgs }:
    let
      allSystems =
        [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" "aarch64-linux" ];

      # Commit info from r-source repo
      commit = "ac5687a7cc477d4461176013babe38ec4adfafeb";
      commit-date = "2023-11-23";
      svn-id = "85618";
      sha256 = "sha256-ssQ0GUG+QtLcKn/86e/LDvKoUOu7xR8HMppQccCunyk=";

      forEachSupportedSystem = f:
        nixpkgs.lib.genAttrs allSystems (system:
          f rec {
            pkgs = import nixpkgs { inherit system; };
            inherit system;
            r-source = pkgs.fetchgit {
              url = "https://github.com/wch/r-source.git";
              # rev = "trunk";
              rev = commit;
              sha256 = sha256;
            };
            inherit svn-id;
          });

      withRecommendedPackages = true;
      enableStrictBarrier = false;
      enableMemoryProfiling = false;
      static = false;

    in {
      packages = forEachSupportedSystem
        ({ pkgs, system, r-source, svn-id, ... }: {

          default = pkgs.stdenv.mkDerivation {
            name = "R-devel";
            src = r-source;

            enableParallelBuilding = true;

            dontUseImakeConfigure = true;

            nativeBuildInputs = [ pkgs.pkg-config ];

            buildInputs = with pkgs;
              [
                git # For making a simulated SVN checkout
                rsync # For rsync-recommended
                bzip2
                gfortran
                xorg.libX11
                xorg.libXmu
                xorg.libXt
                libjpeg
                libpng
                libtiff
                ncurses
                pango
                pcre2
                perl
                readline
                (texliveSmall.withPackages (ps:
                  with ps; [
                    inconsolata
                    helvetic
                    ps.texinfo
                    fancyvrb
                    cm-super
                    rsfs
                  ]))
                xz
                zlib
                less
                texinfo
                graphviz
                icu
                bison
                xorg.imake
                which
                blas
                lapack
                curl
                tcl
                tk
                jdk
                tzdata
              ] ++ lib.optionals stdenv.isDarwin [
                darwin.apple_sdk.frameworks.Cocoa
                darwin.apple_sdk.frameworks.Foundation
                darwin.libobjc
                libcxx
              ];

            postUnpack = ''
              cd $sourceRoot
              tools/rsync-recommended
              cd ..
            '';

            setupHook = ./setup-hook.sh;

            # patches = [ ./no-usr-local-search-paths.patch ];

            # Test of the examples for package 'tcltk' fails in Darwin sandbox. See:
            # https://github.com/NixOS/nixpkgs/issues/146131
            postPatch = pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              substituteInPlace configure \
                --replace "-install_name libRblas.dylib" "-install_name $out/lib/R/lib/libRblas.dylib" \
                --replace "-install_name libRlapack.dylib" "-install_name $out/lib/R/lib/libRlapack.dylib" \
                --replace "-install_name libR.dylib" "-install_name $out/lib/R/lib/libR.dylib"
              substituteInPlace tests/Examples/Makefile.in \
                --replace "test-Examples: test-Examples-Base" "test-Examples:" # do not test the examples
            '';

            dontDisableStatic = static;

            preConfigure = ''
              configureFlagsArray=(
                --disable-lto
                --with${
                  pkgs.lib.optionalString (!withRecommendedPackages) "out"
                }-recommended-packages
                --with-blas="-L${pkgs.blas}/lib -lblas"
                --with-lapack="-L${pkgs.lapack}/lib -llapack"
                --with-readline
                --with-tcltk --with-tcl-config="${pkgs.tcl}/lib/tclConfig.sh" --with-tk-config="${pkgs.tk}/lib/tkConfig.sh"
                --with-cairo
                --with-libpng
                --with-jpeglib
                --with-libtiff
                --with-ICU
                ${
                  pkgs.lib.optionalString enableStrictBarrier
                  "--enable-strict-barrier"
                }
                ${
                  pkgs.lib.optionalString enableMemoryProfiling
                  "--enable-memory-profiling"
                }
                ${
                  if static then "--enable-R-static-lib" else "--enable-R-shlib"
                }
                AR=$(type -p ar)
                AWK=$(type -p gawk)
                CC=$(type -p cc)
                CXX=$(type -p c++)
                FC="${pkgs.gfortran}/bin/gfortran" F77="${pkgs.gfortran}/bin/gfortran"
                JAVA_HOME="${pkgs.jdk}"
                RANLIB=$(type -p ranlib)
                r_cv_have_curl728=yes
                R_SHELL="${pkgs.stdenv.shell}"
            '' + pkgs.lib.optionalString pkgs.stdenv.isDarwin ''
              --disable-R-framework
              --without-x
              OBJC="clang"
              CPPFLAGS="-isystem ${pkgs.lib.getDev pkgs.libcxx}/include/c++/v1"
              LDFLAGS="-L${pkgs.lib.getLib pkgs.libcxx}/lib"
            '' + ''
              )
              echo >>etc/Renviron.in "TCLLIBPATH=${pkgs.tk}/lib"
              echo >>etc/Renviron.in "TZDIR=${pkgs.tzdata}/share/zoneinfo"
            '';

            postConfigure = ''
              # Do some stuff to simulate an SVN checkout.
              # https://github.com/wch/r-source/wiki
              (cd doc/manual && make front-matter html-non-svn)
              echo 'Revision: ${svn-id}' > SVN-REVISION
              echo 'Last Changed Date: ${commit-date}' >>  SVN-REVISION
            '';

            # The store path to "which" is baked into src/library/base/R/unix/system.unix.R,
            # but Nix cannot detect it as a run-time dependency because the installed file
            # is compiled and compressed, which hides the store path.
            postFixup = ''
              mkdir -p $out/nix-support/
              echo ${pkgs.which} > $out/nix-support/undetected-runtime-dependencies
            '';

          };
        });

      # Development environments
      devShells = forEachSupportedSystem ({ pkgs, system, r-source, ... }: {
        default = pkgs.mkShell {
          # Get the nativeBuildInputs from packages.default
          inputsFrom = [ self.packages.${system}.default ];

          packages = with pkgs; [ git ];

          shellHook = ''
            echo "R-devel shell"
          '';
        };
      });
    };
}
