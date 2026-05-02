# R2 endpoint URL must come from ${S3_ENDPOINT_URL} (Tofu-derived, surfaced via
# the cluster-vars ConfigMap), not hardcoded in manifests. Tofu backend configs
# are exempt because Terraform's backend block doesn't support variable
# interpolation; everything else should use the substitution.

package main

import rego.v1

# Files allowed to hardcode the R2 endpoint until they're migrated.
# TODO: drop minecraft entry when game-servers backups move to Velero.
allowed_paths := {"k8s/apps/game-servers/minecraft/backup-job.yaml"}

deny contains msg if {
	some i
	not input[i].path in allowed_paths
	some path, value
	walk(input[i].contents, [path, value])
	is_string(value)
	contains(value, "cloudflarestorage.com")
	msg := sprintf(
		"%s: hardcoded R2 endpoint at path %v — use ${S3_ENDPOINT_URL} from cluster-vars",
		[input[i].path, path],
	)
}
