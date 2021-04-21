## Merge Criteria

- [ ] run `nix-env -i -f https://github.com/makerdao/oracles-v2/tarball/stable` and then run `nix-env -i -f .`
- [ ] install `omnia` as a *feed* on a clean VPS using `install-omnia`
  - [ ] make sure `systemctl status omnia` is `active` and hasn't exited
  - [ ] check that output from `journalctl -e -u omnia` looks reasonable
  - [ ] make sure `systemctl status ssb-server` is `active` and hasn't exited
  - [ ] check that output from `journalctl -e -u ssb-server` looks reasonable
  - [ ] reboot VPS and make sure services auto-start
- [ ] install `omnia` as a *relay* on a clean VPS using `install-omnia`
  - [ ] make sure `systemctl status omnia` is `active` and hasn't exited
  - [ ] check that output from `journalctl -e -u omnia` looks reasonable
  - [ ] make sure `systemctl status ssb-server` is `active` and hasn't exited
  - [ ] check that output from `journalctl -e -u ssb-server` looks reasonable
  - [ ] reboot VPS and make sure services auto-start
