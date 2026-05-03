# Catches drift between prod (tools) and staging (tools-staging) environments.
#
# Each environment is a separate cluster but they share the same app manifests
# via Flux's postBuild substitution. The two ResourceSets must stay structurally
# aligned: input list (which apps deploy) and substitute keys (which variables
# the manifests reference). Values may legitimately differ between environments
# (e.g. HOSTNAME_GRAFANA values); keys and inputs must match modulo allow-list.

package main

import rego.v1

# Inputs that legitimately exist on one cluster only. Update when adding a new
# asymmetric Flux Kustomization (e.g. a tools-only app or staging-only test).
allowed_tools_only := {"identity", "vault"}

allowed_staging_only := set()

# Index ResourceSet manifests by their CLUSTER_NAME substitute value.
# Note: conftest --combine wraps each file as {contents, path}; unwrap via .contents.
cluster_resource_set[cluster] := rs if {
	some i
	rs := input[i].contents
	rs.kind == "ResourceSet"
	cluster := rs.spec.resources[0].spec.postBuild.substitute.CLUSTER_NAME
}

# Set of input (Flux Kustomization) names per cluster.
cluster_inputs[cluster] := names if {
	rs := cluster_resource_set[cluster]
	names := {n | some i; n := rs.spec.inputs[i].name}
}

# Set of postBuild substitute keys per cluster.
cluster_substitute_keys[cluster] := keys if {
	rs := cluster_resource_set[cluster]
	subs := rs.spec.resources[0].spec.postBuild.substitute
	keys := {k | some k; _ := subs[k]}
}

# --- Sanity: both clusters must be present in the input set ---

deny contains msg if {
	not cluster_resource_set.tools
	msg := "could not find a ResourceSet with substitute.CLUSTER_NAME=tools — was it included in --combine inputs?"
}

deny contains msg if {
	not cluster_resource_set["tools-staging"]
	msg := "could not find a ResourceSet with substitute.CLUSTER_NAME=tools-staging — was it included in --combine inputs?"
}

# --- Drift in Flux Kustomization inputs ---

deny contains msg if {
	drift := (cluster_inputs.tools - cluster_inputs["tools-staging"]) - allowed_tools_only
	count(drift) > 0
	msg := sprintf("inputs only on tools, not on tools-staging (and not in allowed_tools_only): %v", [drift])
}

deny contains msg if {
	drift := (cluster_inputs["tools-staging"] - cluster_inputs.tools) - allowed_staging_only
	count(drift) > 0
	msg := sprintf("inputs only on tools-staging, not on tools (and not in allowed_staging_only): %v", [drift])
}

# --- Drift in postBuild substitute keys (values may legitimately differ; keys must match) ---

deny contains msg if {
	diff := cluster_substitute_keys.tools - cluster_substitute_keys["tools-staging"]
	count(diff) > 0
	msg := sprintf("substitute keys present on tools but missing on tools-staging: %v", [diff])
}

deny contains msg if {
	diff := cluster_substitute_keys["tools-staging"] - cluster_substitute_keys.tools
	count(diff) > 0
	msg := sprintf("substitute keys present on tools-staging but missing on tools: %v", [diff])
}
