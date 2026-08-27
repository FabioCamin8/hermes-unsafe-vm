# Cloud-Init boundary

`user-data.example.yaml` documents the minimal seed contract: hostname,
locked `hermes` user, and an operator-supplied public SSH key. The actual
Proxmox helper uses `qm` fields for the key and DHCP configuration. Do not
render a private key, password, OAuth value, or Proxmox credential into a seed.

Cloud-Init provides initial identity/bootstrap only. The repository scripts
perform the debuggable guest runtime installation and can be rerun.
