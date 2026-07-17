output "remediation_ids" {
  value = { for k, v in module.dcr_association : k => v.remediation_id }
}