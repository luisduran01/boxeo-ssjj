extends RefCounted
class_name McpServiceLocator

## Minimal service locator required by the installed Godot AI plugin version.
## The registry owns service resolution; this object only retains its runtime
## dependencies for custom-tool setup.
var connection
var log_buffer

func setup(next_connection, next_log_buffer) -> void:
	connection=next_connection
	log_buffer=next_log_buffer
