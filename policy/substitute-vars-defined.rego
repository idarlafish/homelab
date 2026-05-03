# Every ${VAR} reference in a manifest must correspond to a defined substitute
# variable. Two sources count as "defined":
#   1. The postBuild.substitute block on the prod ResourceSet (parity policy
#      ensures staging matches; this policy reads tools as the canonical source).
#   2. The Tofu-managed cluster-vars ConfigMap (POD_CIDR, S3_ENDPOINT_URL).
#
# Limitation: SOPS-encrypted Secret values are opaque at lint time, so ${VAR}
# references inside encrypted stringData fields aren't checked here. They get
# substituted correctly by Flux at apply time after decryption.

package main

import rego.v1

# Variables exposed by the Tofu-managed cluster-vars ConfigMap.
configmap_vars := {"POD_CIDR", "S3_ENDPOINT_URL"}

# Variables that look like Flux substitutes but are actually runtime env-var
# expansion done by the workload at startup. These MUST be escaped in source
# manifests as $${VAR} so Flux passes them through as literal ${VAR}; the
# workload then expands them from the pod env. Without escaping, Flux replaces
# them with empty string at apply time.
runtime_vars := {
	"TELEGRAM_BOT_TOKEN",
	"TELEGRAM_CHAT_ID",
	"GIT_PAT",
}

cluster_resource_set[cluster] := rs if {
	some i
	rs := input[i].contents
	rs.kind == "ResourceSet"
	cluster := rs.spec.resources[0].spec.postBuild.substitute.CLUSTER_NAME
}

substitute_keys := keys if {
	rs := cluster_resource_set.tools
	keys := {k | some k; _ := rs.spec.resources[0].spec.postBuild.substitute[k]}
}

allowed_vars := substitute_keys | configmap_vars | runtime_vars

referenced_vars contains var if {
	some i
	some path, value
	walk(input[i].contents, [path, value])
	is_string(value)
	matches := regex.find_all_string_submatch_n(`\$\{([A-Z_][A-Z0-9_]*)\}`, value, -1)
	some m in matches
	var := m[1]
	_ = path # silence unused-var lint; walk requires both bindings
}

deny contains msg if {
	some var in referenced_vars
	not var in allowed_vars
	msg := sprintf(
		"undefined substitute variable ${%s} referenced — typo, or missing from substitute block / cluster-vars?",
		[var],
	)
}
