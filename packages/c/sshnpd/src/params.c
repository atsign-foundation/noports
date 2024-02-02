#include "params.h"

void apply_default_values_to_params(sshnpd_params *params) {
  params->device = "default";
  params->sshpublickey = 0;
  params->unhide = 0;
  params->verbose = 0;
  params->ssh_algorithm = ED25519;
  params->ephemeral_permission = "";
  params->root_domain = "root.atsign.org";
  params->local_sshd_port = 22;
}
