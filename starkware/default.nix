{ python38Packages }:

python38Packages.buildPythonPackage {
  pname = "stark-cli";
  version = "0.0.0";

  src = ./.;

  propagatedBuildInputs = with python38Packages; [ mpmath sympy ];

  doCheck = false;
}
