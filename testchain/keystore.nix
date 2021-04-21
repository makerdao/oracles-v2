{ pkgs ? import <nixpkgs> {} }: rec {
  keystorePath = ./keystore;
  passwordFile = ./keystore/password;
  # Return an account address for given account form the keystore:
  address = account: (pkgs.lib.importJSON ("${toString keystorePath}/${account}.json")).address;

}
