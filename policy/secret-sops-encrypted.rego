# Every Kubernetes Secret committed to git must be SOPS-encrypted.
# SOPS-encrypted files have a top-level `sops:` field containing the recipient
# metadata. Plaintext Secrets in git is the worst-case credential leak.

package main

import rego.v1

deny contains msg if {
	some i
	doc := input[i].contents
	doc.kind == "Secret"
	not doc.sops
	msg := sprintf(
		"%s: Secret %q is not SOPS-encrypted (missing top-level 'sops:' field)",
		[input[i].path, doc.metadata.name],
	)
}
