# tflint settings. The built-in terraform ruleset with the "recommended"
# preset: unused declarations, missing version constraints, deprecated
# syntax, naming conventions. Cloud-specific rulesets are added together
# with the provider in Phase 5 (docs/adr/0003-local-only-environment.md).
config {
  # Lint the code of local modules through their calls too.
  call_module_type = "local"
}

plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}
