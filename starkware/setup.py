from distutils.core import setup
setup(name='stark-cli',
      version='0.0',
      packages=['signature'],
      scripts=['stark_cli.py'],
      package_data={'': ['*.json']}
      )
