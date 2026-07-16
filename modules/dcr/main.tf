resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = var.kind
  description         = var.description
  tags                = var.tags

  destinations {
    log_analytics {
      name                  = "lawdestination-log"
      workspace_resource_id = var.law_id
    }
  }

  dynamic "data_flow" {
    for_each = var.data_flows
    content {
      streams            = data_flow.value.streams
      destinations       = ["lawdestination-log"]
      output_stream      = try(data_flow.value.output_stream, null)
      transform_kql      = try(data_flow.value.transform_kql, null)
      built_in_transform = try(data_flow.value.built_in_transform, null)
    }
  }

  dynamic "data_sources" {
    for_each = (
      length(var.performance_counters) > 0 ||
      length(var.windows_event_logs) > 0 ||
      length(var.syslog_sources) > 0
    ) ? [1] : []

    content {
      dynamic "performance_counter" {
        for_each = var.performance_counters
        content {
          name                          = performance_counter.value.name
          streams                       = performance_counter.value.streams
          sampling_frequency_in_seconds = performance_counter.value.sampling_frequency_in_seconds
          counter_specifiers            = performance_counter.value.counter_specifiers
        }
      }

      dynamic "windows_event_log" {
        for_each = var.windows_event_logs
        content {
          name           = windows_event_log.value.name
          streams        = windows_event_log.value.streams
          x_path_queries = windows_event_log.value.x_path_queries
        }
      }

      dynamic "syslog" {
        for_each = var.syslog_sources
        content {
          name           = syslog.value.name
          streams        = syslog.value.streams
          facility_names = syslog.value.facility_names
          log_levels     = syslog.value.log_levels
        }
      }
    }
  }
}
