variable "name" {
  description = "Name of the Data Collection Rule."
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kind" {
  description = "DCR kind. Windows and Linux restrict which data source types are allowed (Linux blocks windows_event_log, Windows blocks syslog). Leave null to allow both."
  type        = string
  default     = null

  validation {
    condition     = var.kind == null ? true : contains(["Windows", "Linux", "AgentDirectToStore", "WorkspaceTransforms"], var.kind)
    error_message = "kind must be one of Windows, Linux, AgentDirectToStore, WorkspaceTransforms, or null."
  }
}

variable "description" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "law_id" {
  description = "Resource ID of the destination Log Analytics workspace."
  type        = string
}

variable "data_flows" {
  description = "List of data flows mapping input streams to the destination, with optional transform/output stream overrides."
  type = list(object({
    streams            = list(string)
    output_stream      = optional(string)
    transform_kql      = optional(string)
    built_in_transform  = optional(string)
  }))
}

variable "performance_counters" {
  description = "Performance counter data sources."
  type = list(object({
    name                           = string
    streams                        = list(string)
    sampling_frequency_in_seconds  = number
    counter_specifiers             = list(string)
  }))
  default = []
}

variable "windows_event_logs" {
  description = "Windows event log data sources."
  type = list(object({
    name           = string
    streams        = list(string)
    x_path_queries = list(string)
  }))
  default = []
}

variable "syslog_sources" {
  description = "Syslog data sources. Use streams = [\"Microsoft-Syslog\"] for plain syslog or [\"Microsoft-CommonSecurityLog\"] for CEF. Keep facilities used for CEF out of the plain-syslog block to avoid duplicate ingestion."
  type = list(object({
    name           = string
    streams        = list(string)
    facility_names = list(string)
    log_levels     = list(string)
  }))
  default = []
}
