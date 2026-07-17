variable "scope" {
  description = "Default scope for assignments (e.g. the Dev RG)"
  type        = string
}

variable "location" {
  type = string
}

variable "assignments" {
  description = "One entry per (DCR, OS) pair you want Azure to auto-associate"
  type = list(object({
    key             = string           # unique, e.g. "perf-linux"
    display_name    = string
    dcr_resource_id = string
    os_type         = string           # "Linux" or "Windows"
    resource_type   = optional(string, "Microsoft.Insights/dataCollectionRules")
    scope           = optional(string) # override var.scope for this one assignment
    effect          = optional(string, "DeployIfNotExists")
  }))
  validation {
    condition     = alltrue([for a in var.assignments : contains(["Linux", "Windows"], a.os_type)])
    error_message = "The os_type must be either 'Linux' or 'Windows'."
  }
}
