# Cloning and first boot

After template conversion, clone through Proxmox and boot the clone. Debian
and Proxmox must generate a new machine identity and SSH host keys. Validate
that the clone has an empty vault, absent authenticated browser state, a new
machine-id/host-key set, Hermes installed, and loopback CDP before onboarding.

If template conversion or clone validation is not executed, record that fact;
do not infer clone safety from a local sanitation run alone.
