@tool
extends RefCounted

## Applies scene instance overrides to the source scene or reverts them on the current instance.
##
## Apply writes both scene files directly, so it cannot be undone through EditorUndoRedoManager.
## Instead, it backs up the original bytes and UIDs and restores the last Apply only while the resulting file hashes remain unchanged.

const BACKUP_DIRECTORY_PATH := "res://.godot/scene_instance_overrides"
const BACKUP_MANIFEST_FILE_NAME := "manifest.json"
const HOST_BACKUP_FILE_NAME := "host.bytes"
const SOURCE_BACKUP_FILE_NAME := "source.bytes"
const MAX_BACKUP_COUNT := 10
const SUPPORTED_SCENE_EXTENSIONS := ["tscn", "scn"]
const OWN_ADDON_DIRECTORY_PATH := "res://addons/scene_instance_overrides/"

var _editor_plugin: EditorPlugin
var _last_apply_manifest_path := ""


func setup(editor_plugin: EditorPlugin) -> void:
	_editor_plugin = editor_plugin


func apply_entries(context: Dictionary, entries: Array) -> Dictionary:
	var prepared_context: Dictionary = _prepare_apply_context(context)
	if not prepared_context.get("ok", false):
		return prepared_context

	var requested_entries: Array = _collect_requested_entries(entries)
	var entry_validation: Dictionary = _validate_apply_entries(requested_entries)
	if not entry_validation.get("ok", false):
		return entry_validation

	var instance_root: Node = prepared_context["instance_root"]
	var edited_scene_root: Node = prepared_context["edited_scene_root"]
	var host_path: String = prepared_context["host_path"]
	var source_path: String = prepared_context["source_path"]
	var instance_path_from_host: NodePath = edited_scene_root.get_path_to(instance_root)
	var initial_file_hashes: Dictionary = _capture_initial_scene_file_hashes(
		host_path,
		source_path
	)
	if not initial_file_hashes.get("ok", false):
		return initial_file_hashes

	var source_scene_result: Dictionary = _load_editable_source_scene(source_path)
	if not source_scene_result.get("ok", false):
		return source_scene_result
	var source_packed_scene: PackedScene = source_scene_result["packed_scene"]

	var candidate_result: Dictionary = _build_transaction_candidates(
		host_path,
		source_packed_scene,
		instance_path_from_host,
		instance_root,
		edited_scene_root,
		requested_entries
	)
	if not candidate_result.get("ok", false):
		return candidate_result

	var backup_result: Dictionary = _create_transaction_backup(host_path, source_path)
	if not backup_result.get("ok", false):
		return backup_result
	var manifest: Dictionary = backup_result["manifest"]
	var manifest_path: String = backup_result["manifest_path"]
	var candidate_input_guard: Dictionary = (
		_verify_backup_matches_initial_scene_file_hashes(
			manifest,
			initial_file_hashes
		)
	)
	if not candidate_input_guard.get("ok", false):
		manifest["status"] = "aborted_external_change"
		_write_manifest_file(manifest_path, manifest)
		_prune_old_transaction_backups()
		return candidate_input_guard

	# Do not overwrite files changed by an external tool between candidate creation and the actual write.
	var unchanged_result: Dictionary = _verify_files_match_manifest_hashes(manifest, "before")
	if not unchanged_result.get("ok", false):
		manifest["status"] = "aborted_external_change"
		_write_manifest_file(manifest_path, manifest)
		return unchanged_result

	var host_uid: int = int(str(manifest.get("host_uid", ResourceUID.INVALID_ID)))
	var source_uid: int = int(str(manifest.get("source_uid", ResourceUID.INVALID_ID)))
	var host_candidate: PackedScene = candidate_result["host_candidate"]
	var source_candidate: PackedScene = candidate_result["source_candidate"]

	var host_save_error: int = _save_packed_scene_with_preserved_uid(host_candidate, host_path, host_uid)
	if host_save_error != OK:
		return _rollback_failed_apply(
			manifest,
			manifest_path,
			"Failed to save the host scene: %s" % error_string(host_save_error)
		)

	var source_save_error: int = _save_packed_scene_with_preserved_uid(source_candidate, source_path, source_uid)
	if source_save_error != OK:
		return _rollback_failed_apply(
			manifest,
			manifest_path,
			"Failed to save the base scene: %s" % error_string(source_save_error)
		)

	var saved_file_validation: Dictionary = _validate_saved_scene_files(
		host_path,
		source_path,
		instance_path_from_host,
		requested_entries,
		host_uid,
		source_uid
	)
	if not saved_file_validation.get("ok", false):
		return _rollback_failed_apply(
			manifest,
			manifest_path,
			str(saved_file_validation.get("message", "Failed to validate the saved files."))
		)

	manifest["host_after_sha256"] = _get_file_sha256(host_path)
	manifest["source_after_sha256"] = _get_file_sha256(source_path)
	manifest["status"] = "applied"
	manifest["applied_entry_ids"] = _collect_entry_ids(requested_entries)
	manifest["applied_count"] = requested_entries.size()
	var manifest_write_error: int = _write_manifest_file(manifest_path, manifest)
	if manifest_write_error != OK:
		return _rollback_failed_apply(
			manifest,
			manifest_path,
			"Failed to save the Apply record: %s" % error_string(manifest_write_error)
		)

	_last_apply_manifest_path = manifest_path
	_prune_old_transaction_backups()
	var reload_paths: PackedStringArray = _refresh_saved_scene_files(host_path, source_path)
	print("Applied %d scene instance overrides to the base scene." % requested_entries.size())
	return _success_result(
		"Applied %d overrides to the base scene. Disk Apply cannot be undone with Ctrl+Z. You can use 'Undo Last Apply' until either file changes." % requested_entries.size(),
		{
			"applied_count": requested_entries.size(),
			"backup_id": str(manifest.get("backup_id", "")),
			"reload_paths": reload_paths,
			"undoable": false,
			"recent_apply_undo_available": true,
		}
	)


func apply_property_entries_without_saving_host(
		context: Dictionary,
		entries: Array
	) -> Dictionary:
	var prepared_context: Dictionary = _prepare_apply_context(context)
	if not prepared_context.get("ok", false):
		return prepared_context

	var requested_entries: Array = _collect_requested_entries(entries)
	var entry_validation: Dictionary = _validate_apply_entries(requested_entries)
	if not entry_validation.get("ok", false):
		return entry_validation
	for entry_value: Variant in requested_entries:
		var entry: Dictionary = entry_value
		if _normalize_entry_kind(str(entry.get("kind", ""))) != "property":
			return _failure_result(
				"Apply Without Saving Parent currently supports property overrides only."
			)

	var instance_root: Node = prepared_context["instance_root"]
	var edited_scene_root: Node = prepared_context["edited_scene_root"]
	var host_path: String = prepared_context["host_path"]
	var source_path: String = prepared_context["source_path"]
	var initial_file_hashes: Dictionary = _capture_initial_scene_file_hashes(
		host_path,
		source_path
	)
	if not initial_file_hashes.get("ok", false):
		return initial_file_hashes

	var source_scene_result: Dictionary = _load_editable_source_scene(source_path)
	if not source_scene_result.get("ok", false):
		return source_scene_result
	var source_candidate_result: Dictionary = _build_source_candidate_from_live_instance(
		source_scene_result["packed_scene"],
		instance_root,
		edited_scene_root,
		requested_entries
	)
	if not source_candidate_result.get("ok", false):
		return source_candidate_result

	var cleanup_result: Dictionary = _collect_live_property_cleanup_operations(
		instance_root,
		requested_entries
	)
	if not cleanup_result.get("ok", false):
		return cleanup_result
	var cleanup_operations: Array = cleanup_result["operations"]

	var backup_result: Dictionary = _create_transaction_backup(host_path, source_path)
	if not backup_result.get("ok", false):
		return backup_result
	var manifest: Dictionary = backup_result["manifest"]
	var manifest_path: String = backup_result["manifest_path"]
	var candidate_input_guard: Dictionary = (
		_verify_backup_matches_initial_scene_file_hashes(
			manifest,
			initial_file_hashes
		)
	)
	if not candidate_input_guard.get("ok", false):
		manifest["status"] = "aborted_external_change"
		_write_manifest_file(manifest_path, manifest)
		_prune_old_transaction_backups()
		return candidate_input_guard
	var unchanged_result: Dictionary = _verify_files_match_manifest_hashes(manifest, "before")
	if not unchanged_result.get("ok", false):
		manifest["status"] = "aborted_external_change"
		_write_manifest_file(manifest_path, manifest)
		return unchanged_result

	var cleanup_apply_result := _set_live_property_cleanup_values(
		cleanup_operations,
		"base_value"
	)
	if not cleanup_apply_result.get("ok", false):
		return cleanup_apply_result

	var source_uid: int = int(str(manifest.get("source_uid", ResourceUID.INVALID_ID)))
	var source_candidate: PackedScene = source_candidate_result["packed_scene"]
	var source_save_error: int = _save_packed_scene_with_preserved_uid(
		source_candidate,
		source_path,
		source_uid
	)
	if source_save_error != OK:
		_set_live_property_cleanup_values(cleanup_operations, "current_value")
		return _rollback_failed_source_only_apply(
			manifest,
			manifest_path,
			"Failed to save the base scene: %s" % error_string(source_save_error)
		)

	var saved_source_validation := _validate_saved_source_scene_file(
		source_path,
		requested_entries,
		source_uid
	)
	if not saved_source_validation.get("ok", false):
		_set_live_property_cleanup_values(cleanup_operations, "current_value")
		return _rollback_failed_source_only_apply(
			manifest,
			manifest_path,
			str(saved_source_validation.get("message", "Failed to validate the saved base scene."))
		)

	manifest["host_after_sha256"] = _get_file_sha256(host_path)
	manifest["source_after_sha256"] = _get_file_sha256(source_path)
	manifest["status"] = "applied_without_saving_host"
	manifest["host_saved"] = false
	manifest["applied_entry_ids"] = _collect_entry_ids(requested_entries)
	manifest["applied_count"] = requested_entries.size()
	var manifest_write_error: int = _write_manifest_file(manifest_path, manifest)
	if manifest_write_error != OK:
		_set_live_property_cleanup_values(cleanup_operations, "current_value")
		return _rollback_failed_source_only_apply(
			manifest,
			manifest_path,
			"Failed to save the Apply record: %s" % error_string(manifest_write_error)
		)

	_last_apply_manifest_path = manifest_path
	_prune_old_transaction_backups()
	var reload_paths: PackedStringArray = _refresh_saved_scene_files(host_path, source_path)
	var live_value_result := _set_live_property_cleanup_values(
		cleanup_operations,
		"current_value"
	)
	if not live_value_result.get("ok", false):
		_set_live_property_cleanup_values(cleanup_operations, "current_value")
		return _rollback_failed_source_only_apply(
			manifest,
			manifest_path,
			str(live_value_result.get("message", "Failed to synchronize the live parent scene."))
		)

	print(
		"Applied %d scene instance property overrides without saving the parent scene."
		% requested_entries.size()
	)
	return _success_result(
		"Applied %d property overrides to the base scene. The parent scene remains unsaved."
		% requested_entries.size(),
		{
			"applied_count": requested_entries.size(),
			"backup_id": str(manifest.get("backup_id", "")),
			"reload_paths": reload_paths,
			"host_saved": false,
			"undoable": false,
			"recent_apply_undo_available": false,
		}
	)


func revert_entries(context: Dictionary, entries: Array) -> Dictionary:
	var live_context: Dictionary = _prepare_live_context(context)
	if not live_context.get("ok", false):
		return live_context
	if _editor_plugin == null or not is_instance_valid(_editor_plugin):
		return _failure_result("The editor plugin is not ready, so the overrides cannot be reverted.")

	var requested_entries: Array = _collect_requested_entries(entries)
	var entry_validation: Dictionary = _validate_revert_entries(requested_entries)
	if not entry_validation.get("ok", false):
		return entry_validation

	var overlap_error: String = _find_overlapping_added_node_paths(requested_entries)
	if not overlap_error.is_empty():
		return _failure_result(overlap_error)

	var instance_root: Node = live_context["instance_root"]
	var edited_scene_root: Node = live_context["edited_scene_root"]
	var undo_redo: EditorUndoRedoManager = _editor_plugin.get_undo_redo()
	if undo_redo == null:
		return _failure_result("Could not access EditorUndoRedoManager.")

	var operation_result: Dictionary = _register_revert_undo_operations(
		undo_redo,
		instance_root,
		edited_scene_root,
		requested_entries
	)
	if not operation_result.get("ok", false):
		return operation_result

	undo_redo.commit_action()
	print("Reverted %d scene instance overrides on the current instance." % requested_entries.size())
	return _success_result(
		"Reverted %d overrides. Use Ctrl+Z to restore them." % requested_entries.size(),
		{
			"reverted_count": requested_entries.size(),
			"undoable": true,
		}
	)


func can_undo_last_apply() -> bool:
	var manifest_result: Dictionary = _load_latest_applied_manifest()
	if not manifest_result.get("ok", false):
		return false
	var manifest: Dictionary = manifest_result["manifest"]
	return _verify_files_match_manifest_hashes(manifest, "after").get("ok", false)


func undo_last_apply() -> Dictionary:
	var manifest_result: Dictionary = _load_latest_applied_manifest()
	if not manifest_result.get("ok", false):
		return manifest_result
	var manifest: Dictionary = manifest_result["manifest"]
	var manifest_path: String = manifest_result["manifest_path"]

	var hash_guard: Dictionary = _verify_files_match_manifest_hashes(manifest, "after")
	if not hash_guard.get("ok", false):
		return _failure_result(
			"Automatic restoration was stopped because the host or base scene file changed after the last Apply. The backup files were preserved.",
			{"backup_id": str(manifest.get("backup_id", "")), "hash_guard_failed": true}
		)

	var host_path: String = str(manifest.get("host_path", ""))
	var source_path: String = str(manifest.get("source_path", ""))
	var dirty_paths: PackedStringArray = find_open_dirty_dependency_paths({
		"host_path": host_path,
		"source_path": source_path,
	})
	if not dirty_paths.is_empty():
		return _failure_result(
			"The last Apply cannot be restored because related scenes have unsaved changes: %s" % ", ".join(dirty_paths),
			{"dirty_paths": dirty_paths}
		)

	var restore_result: Dictionary = _restore_files_from_manifest(manifest, "before")
	if not restore_result.get("ok", false):
		manifest["status"] = "undo_failed"
		_write_manifest_file(manifest_path, manifest)
		return restore_result

	manifest["status"] = "undone"
	manifest["undone_unix_msec"] = int(Time.get_unix_time_from_system() * 1000.0)
	var manifest_write_error: int = _write_manifest_file(manifest_path, manifest)
	if manifest_write_error != OK:
		return _failure_result(
			"The scene files were restored, but the Apply record state could not be saved: %s" % error_string(manifest_write_error),
			{"files_restored": true, "backup_id": str(manifest.get("backup_id", ""))}
		)

	_last_apply_manifest_path = ""
	var reload_paths: PackedStringArray = _refresh_saved_scene_files(host_path, source_path)
	print("Restored the latest Apply performed by Scene Instance Overrides from backup.")
	return _success_result(
		"Restored the host and base scenes to their state before the last Apply. This disk restoration cannot be undone with Ctrl+Z.",
		{
			"backup_id": str(manifest.get("backup_id", "")),
			"reload_paths": reload_paths,
			"undoable": false,
		}
	)


## Lets the UI block unsaved base and dependent scenes before opening the Apply confirmation dialog.
func find_open_dirty_dependency_paths(context: Dictionary) -> PackedStringArray:
	var host_path: String = _normalize_resource_path(str(context.get("host_path", "")))
	var source_path: String = _normalize_resource_path(str(context.get("source_path", "")))
	var dirty_paths := PackedStringArray()
	if source_path.is_empty() or not Engine.is_editor_hint():
		return dirty_paths

	var unsaved_scenes: PackedStringArray = EditorInterface.get_unsaved_scenes()
	for dirty_path_value: String in unsaved_scenes:
		var dirty_path: String = _normalize_resource_path(dirty_path_value)
		if dirty_path.is_empty():
			continue
		if dirty_path == host_path or dirty_path == source_path or _scene_file_depends_on(dirty_path, source_path):
			dirty_paths.append(dirty_path)
	return dirty_paths


## Exposes the open base and dependent scenes that must be reloaded after saving.
func find_open_dependency_scene_paths(context: Dictionary) -> PackedStringArray:
	var host_path: String = _normalize_resource_path(str(context.get("host_path", "")))
	var source_path: String = _normalize_resource_path(str(context.get("source_path", "")))
	var related_paths := PackedStringArray()
	if source_path.is_empty() or not Engine.is_editor_hint():
		return related_paths

	for open_path_value: String in EditorInterface.get_open_scenes():
		var open_path: String = _normalize_resource_path(open_path_value)
		if open_path.is_empty():
			continue
		if open_path == source_path or open_path == host_path or _scene_file_depends_on(open_path, source_path):
			if not related_paths.has(open_path):
				related_paths.append(open_path)
	return related_paths


func _prepare_apply_context(context: Dictionary) -> Dictionary:
	var live_context: Dictionary = _prepare_live_context(context)
	if not live_context.get("ok", false):
		return live_context

	var host_path: String = live_context["host_path"]
	var source_path: String = live_context["source_path"]
	if host_path == source_path:
		return _failure_result("The host and base scene paths are identical, so Apply cannot continue.")
	if not _is_supported_scene_file_path(host_path):
		return _failure_result("The host scene must be a .tscn or .scn file: %s" % host_path)
	if not _is_supported_scene_file_path(source_path):
		return _failure_result("Apply is not supported for imported sources or unsupported formats: %s" % source_path)
	if source_path.begins_with("res://addons/") and not source_path.begins_with(OWN_ADDON_DIRECTORY_PATH):
		return _failure_result("Third-party scenes under addons are excluded from Apply to preserve update safety: %s" % source_path)
	if not FileAccess.file_exists(host_path):
		return _failure_result("The saved host scene file was not found: %s" % host_path)
	if not FileAccess.file_exists(source_path):
		return _failure_result("The base scene file was not found: %s" % source_path)

	return live_context


func _prepare_live_context(context: Dictionary) -> Dictionary:
	var instance_root_value: Variant = context.get("instance_root")
	var edited_scene_root_value: Variant = context.get("edited_scene_root")
	if not instance_root_value is Node or not is_instance_valid(instance_root_value):
		return _failure_result("The target scene instance root is invalid.")
	if not edited_scene_root_value is Node or not is_instance_valid(edited_scene_root_value):
		return _failure_result("The current edited scene root is invalid.")

	var instance_root: Node = instance_root_value as Node
	var edited_scene_root: Node = edited_scene_root_value as Node
	if instance_root == edited_scene_root:
		return _failure_result("The edited scene itself cannot be used as an instance Apply target.")
	if not edited_scene_root.is_ancestor_of(instance_root):
		return _failure_result("The target instance is not part of the current edited scene.")

	var host_path: String = _normalize_resource_path(str(context.get("host_path", "")))
	var source_path: String = _normalize_resource_path(str(context.get("source_path", "")))
	if host_path.is_empty() or not host_path.begins_with("res://"):
		return _failure_result("A saved host scene path is required.")
	if source_path.is_empty() or not source_path.begins_with("res://"):
		return _failure_result("A valid base scene path is required.")

	var edited_root_path: String = _normalize_resource_path(edited_scene_root.scene_file_path)
	if edited_root_path != host_path:
		return _failure_result(
			"The current edited scene does not match the provided host scene path: %s / %s" % [edited_root_path, host_path]
		)
	var instance_scene_path: String = _normalize_resource_path(instance_root.scene_file_path)
	if instance_scene_path != source_path:
		return _failure_result(
			"The selected instance source does not match the provided base scene path: %s / %s" % [instance_scene_path, source_path]
		)

	return {
		"ok": true,
		"success": true,
		"instance_root": instance_root,
		"edited_scene_root": edited_scene_root,
		"host_path": host_path,
		"source_path": source_path,
	}


func _collect_requested_entries(entries: Array) -> Array:
	var requested_entries: Array = []
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry: Dictionary = entry_value
		requested_entries.append(entry)
	return requested_entries


func _validate_apply_entries(entries: Array) -> Dictionary:
	if entries.is_empty():
		return _failure_result("Select at least one override to apply.")
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		if not bool(entry.get("supported", false)) or kind == "unsupported":
			return _failure_result(
				"Unsupported overrides cannot be applied to the base scene: %s" % str(entry.get("id", "missing entry ID"))
			)
		if kind != "property" and kind != "added_node":
			return _failure_result("Unknown override kind: %s" % kind)
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		if not _is_safe_relative_node_path(node_path):
			return _failure_result("Node paths outside the instance boundary cannot be processed: %s" % node_path)
		if kind == "property" and str(entry.get("property_name", "")).is_empty():
			return _failure_result("The property override is missing a property name.")
		if kind == "added_node" and node_path == ".":
			return _failure_result("The instance root itself cannot be applied as an added node.")

	var overlap_error: String = _find_overlapping_added_node_paths(entries)
	if not overlap_error.is_empty():
		return _failure_result(overlap_error)
	return {"ok": true, "success": true}


func _validate_revert_entries(entries: Array) -> Dictionary:
	if entries.is_empty():
		return _failure_result("Select at least one override to revert.")
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		if kind != "property" and kind != "added_node":
			return _failure_result("This entry cannot be reverted automatically: %s" % str(entry.get("id", "missing entry ID")))
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		if not _is_safe_relative_node_path(node_path):
			return _failure_result("Node paths outside the instance boundary cannot be processed: %s" % node_path)
		if kind == "property" and str(entry.get("property_name", "")).is_empty():
			return _failure_result("The property override is missing a property name.")
		if kind == "added_node" and node_path == ".":
			return _failure_result("The instance root itself cannot be reverted as an added node.")
	return {"ok": true, "success": true}


func _load_editable_source_scene(source_path: String) -> Dictionary:
	var resource: Resource = ResourceLoader.load(source_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if resource == null or not resource is PackedScene:
		return _failure_result("Failed to load the base scene without using the cache: %s" % source_path)
	var packed_scene: PackedScene = resource as PackedScene
	if not packed_scene.can_instantiate():
		return _failure_result("Apply cannot target a base scene with no root node: %s" % source_path)
	if packed_scene.get_state().get_base_scene_state() != null:
		return _failure_result("Inherited scene roots are excluded from safe Apply targets: %s" % source_path)
	return {"ok": true, "success": true, "packed_scene": packed_scene}


func _build_transaction_candidates(
	host_path: String,
	source_packed_scene: PackedScene,
	instance_path_from_host: NodePath,
	live_instance_root: Node,
	live_edited_scene_root: Node,
	entries: Array
) -> Dictionary:
	var host_resource: Resource = ResourceLoader.load(host_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	if host_resource == null or not host_resource is PackedScene:
		return _failure_result("Failed to load the host scene without using the cache: %s" % host_path)
	var host_packed_scene: PackedScene = host_resource as PackedScene
	if not host_packed_scene.can_instantiate():
		return _failure_result("The host scene has no root node: %s" % host_path)

	var source_candidate_root: Node = source_packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if source_candidate_root == null:
		return _failure_result("Failed to instantiate the base scene candidate.")
	var host_candidate_root: Node = host_packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)
	if host_candidate_root == null:
		source_candidate_root.free()
		return _failure_result("Failed to instantiate the host scene candidate.")

	var candidate_host_instance: Node = host_candidate_root.get_node_or_null(instance_path_from_host)
	if candidate_host_instance == null:
		source_candidate_root.free()
		host_candidate_root.free()
		return _failure_result("Could not find the target instance path in the saved host scene: %s" % str(instance_path_from_host))
	if _normalize_resource_path(candidate_host_instance.scene_file_path) != _normalize_resource_path(live_instance_root.scene_file_path):
		source_candidate_root.free()
		host_candidate_root.free()
		return _failure_result("The target node in the saved host scene is not an instance of the same base scene.")

	var source_edit_result: Dictionary = _apply_entries_to_source_candidate(
		source_candidate_root,
		live_instance_root,
		live_edited_scene_root,
		entries
	)
	if not source_edit_result.get("ok", false):
		source_candidate_root.free()
		host_candidate_root.free()
		return source_edit_result

	var host_edit_result: Dictionary = _remove_applied_overrides_from_host_candidate(candidate_host_instance, entries)
	if not host_edit_result.get("ok", false):
		source_candidate_root.free()
		host_candidate_root.free()
		return host_edit_result

	var source_pack_result: Dictionary = _pack_and_validate_candidate(source_candidate_root, entries, true)
	if not source_pack_result.get("ok", false):
		host_candidate_root.free()
		return source_pack_result
	var host_pack_result: Dictionary = _pack_and_validate_host_candidate(
		host_candidate_root,
		instance_path_from_host,
		entries
	)
	if not host_pack_result.get("ok", false):
		return host_pack_result

	return {
		"ok": true,
		"success": true,
		"source_candidate": source_pack_result["packed_scene"],
		"host_candidate": host_pack_result["packed_scene"],
	}


func _build_source_candidate_from_live_instance(
		source_packed_scene: PackedScene,
		live_instance_root: Node,
		live_edited_scene_root: Node,
		entries: Array
	) -> Dictionary:
	var source_candidate_root: Node = source_packed_scene.instantiate(
		PackedScene.GEN_EDIT_STATE_MAIN
	)
	if source_candidate_root == null:
		return _failure_result("Failed to instantiate the base scene candidate.")
	var source_edit_result: Dictionary = _apply_entries_to_source_candidate(
		source_candidate_root,
		live_instance_root,
		live_edited_scene_root,
		entries
	)
	if not source_edit_result.get("ok", false):
		source_candidate_root.free()
		return source_edit_result
	return _pack_and_validate_candidate(source_candidate_root, entries, true)


func _collect_live_property_cleanup_operations(
		instance_root: Node,
		entries: Array
	) -> Dictionary:
	var operations: Array = []
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var node_path: String = _normalize_relative_node_path(
			str(entry.get("node_path", "."))
		)
		var target_node: Node = _find_relative_node(instance_root, node_path)
		if target_node == null:
			return _failure_result(
				"Could not find the live property target in the parent scene: %s"
				% node_path
			)
		var property_name := StringName(str(entry.get("property_name", "")))
		if not _object_has_property(target_node, property_name):
			return _failure_result(
				"The live property target no longer has this property: %s.%s"
				% [node_path, property_name]
			)
		operations.append({
			"node": target_node,
			"property_name": property_name,
			"base_value": entry.get("base_value"),
			"current_value": entry.get("current_value"),
		})
	return {"ok": true, "success": true, "operations": operations}


func _set_live_property_cleanup_values(
		operations: Array,
		value_key: String
	) -> Dictionary:
	for operation_value: Variant in operations:
		var operation: Dictionary = operation_value
		var target_node := operation.get("node") as Node
		if not is_instance_valid(target_node):
			return _failure_result(
				"The live parent scene changed while applying property overrides."
			)
		var property_name: StringName = operation["property_name"]
		if not _object_has_property(target_node, property_name):
			return _failure_result(
				"The live property disappeared while applying: %s" % property_name
			)
		target_node.set(property_name, operation.get(value_key))
	return {"ok": true, "success": true}


func _apply_entries_to_source_candidate(
	source_candidate_root: Node,
	live_instance_root: Node,
	live_edited_scene_root: Node,
	entries: Array
) -> Dictionary:
	var added_entries: Array = []
	var property_entries: Array = []
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		if kind == "added_node":
			added_entries.append(entry)
		elif kind == "property":
			property_entries.append(entry)
	added_entries.sort_custom(_sort_entry_paths_shallowest_first)

	for entry_value: Variant in added_entries:
		var entry: Dictionary = entry_value
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		var live_added_node: Node = _find_relative_node(live_instance_root, node_path)
		if live_added_node == null:
			return _failure_result("Could not find the added node in the current instance: %s" % node_path)
		if not live_instance_root.is_ancestor_of(live_added_node):
			return _failure_result("The added node is outside the target instance boundary: %s" % node_path)

		var parent_path: String = _get_relative_parent_path(node_path)
		var source_parent: Node = _find_relative_node(source_candidate_root, parent_path)
		if source_parent == null:
			return _failure_result("Could not find the added node's parent in the base scene: %s" % parent_path)
		if source_parent.has_node(NodePath(str(live_added_node.name))):
			return _failure_result("The base scene already contains a child with the same name: %s" % node_path)

		var duplicated_node: Node = live_added_node.duplicate()
		if duplicated_node == null:
			return _failure_result("Failed to duplicate the added node subtree: %s" % node_path)
		source_parent.add_child(duplicated_node)
		var target_index: int = mini(live_added_node.get_index(), source_parent.get_child_count() - 1)
		source_parent.move_child(duplicated_node, target_index)
		_copy_subtree_owners_for_source_candidate(
			live_added_node,
			duplicated_node,
			source_candidate_root,
			live_instance_root,
			live_edited_scene_root
		)

	for entry_value: Variant in property_entries:
		var entry: Dictionary = entry_value
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		var target_node: Node = _find_relative_node(source_candidate_root, node_path)
		if target_node == null:
			return _failure_result("Could not find the property target node in the base scene candidate: %s" % node_path)
		var property_name := StringName(str(entry.get("property_name", "")))
		if not _object_has_property(target_node, property_name):
			return _failure_result("The property does not exist in the base scene candidate: %s.%s" % [node_path, property_name])
		target_node.set(property_name, entry.get("current_value"))

	return {"ok": true, "success": true}


func _remove_applied_overrides_from_host_candidate(host_instance_root: Node, entries: Array) -> Dictionary:
	var added_entries: Array = []
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		if kind == "property":
			var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
			var target_node: Node = _find_relative_node(host_instance_root, node_path)
			if target_node == null:
				return _failure_result("Could not find the property target node in the host scene candidate: %s" % node_path)
			var property_name := StringName(str(entry.get("property_name", "")))
			if not _object_has_property(target_node, property_name):
				return _failure_result("The property does not exist in the host scene candidate: %s.%s" % [node_path, property_name])
			target_node.set(property_name, entry.get("base_value"))
		elif kind == "added_node":
			added_entries.append(entry)

	added_entries.sort_custom(_sort_entry_paths_deepest_first)
	for entry_value: Variant in added_entries:
		var entry: Dictionary = entry_value
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		var added_node: Node = _find_relative_node(host_instance_root, node_path)
		if added_node == null:
			return _failure_result("Could not find the added node to remove from the host scene candidate: %s" % node_path)
		var parent: Node = added_node.get_parent()
		if parent == null:
			return _failure_result("Could not find the added node's parent: %s" % node_path)
		parent.remove_child(added_node)
		added_node.free()

	return {"ok": true, "success": true}


func _pack_and_validate_candidate(candidate_root: Node, entries: Array, expect_applied: bool) -> Dictionary:
	var packed_scene := PackedScene.new()
	var pack_error: int = packed_scene.pack(candidate_root)
	candidate_root.free()
	if pack_error != OK:
		return _failure_result("Failed to pack the base scene candidate: %s" % error_string(pack_error))
	if not packed_scene.can_instantiate():
		return _failure_result("The packed base scene candidate could not be instantiated.")

	var validation_root: Node = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if validation_root == null:
		return _failure_result("Failed to create a validation instance for the base scene candidate.")
	var validation_result: Dictionary = _validate_entry_effects_on_root(validation_root, entries, expect_applied)
	validation_root.free()
	if not validation_result.get("ok", false):
		return validation_result
	return {"ok": true, "success": true, "packed_scene": packed_scene}


func _pack_and_validate_host_candidate(
	host_candidate_root: Node,
	instance_path_from_host: NodePath,
	entries: Array
) -> Dictionary:
	var packed_scene := PackedScene.new()
	var pack_error: int = packed_scene.pack(host_candidate_root)
	host_candidate_root.free()
	if pack_error != OK:
		return _failure_result("Failed to pack the host scene candidate: %s" % error_string(pack_error))
	if not packed_scene.can_instantiate():
		return _failure_result("The packed host scene candidate could not be instantiated.")

	var validation_root: Node = packed_scene.instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if validation_root == null:
		return _failure_result("Failed to create a validation instance for the host scene candidate.")
	var validation_instance: Node = validation_root.get_node_or_null(instance_path_from_host)
	if validation_instance == null:
		validation_root.free()
		return _failure_result("Could not find the target instance while validating the host scene candidate.")
	var validation_result: Dictionary = _validate_entry_effects_on_root(validation_instance, entries, false)
	validation_root.free()
	if not validation_result.get("ok", false):
		return validation_result
	return {"ok": true, "success": true, "packed_scene": packed_scene}


func _validate_entry_effects_on_root(root: Node, entries: Array, expect_applied: bool) -> Dictionary:
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		if kind == "added_node":
			var added_node: Node = _find_relative_node(root, node_path)
			if expect_applied and added_node == null:
				return _failure_result("The added node is missing during candidate validation: %s" % node_path)
			if not expect_applied and added_node != null:
				return _failure_result("The applied added node remains in the host scene candidate: %s" % node_path)
		elif kind == "property":
			var target_node: Node = _find_relative_node(root, node_path)
			if target_node == null:
				return _failure_result("Could not find the property target node during candidate validation: %s" % node_path)
			var property_name := StringName(str(entry.get("property_name", "")))
			if not _object_has_property(target_node, property_name):
				return _failure_result("The property is missing during candidate validation: %s.%s" % [node_path, property_name])
			var expected_value: Variant = entry.get("current_value") if expect_applied else entry.get("base_value")
			if not _variant_values_match(target_node.get(property_name), expected_value):
				return _failure_result("The property value does not match during candidate validation: %s.%s" % [node_path, property_name])
	return {"ok": true, "success": true}


func _copy_subtree_owners_for_source_candidate(
	original_subtree: Node,
	duplicated_subtree: Node,
	source_candidate_root: Node,
	live_instance_root: Node,
	live_edited_scene_root: Node
) -> void:
	var original_nodes: Array[Node] = [original_subtree]
	original_nodes.append_array(original_subtree.find_children("*", "Node", true, false))
	for original_node: Node in original_nodes:
		var relative_path: NodePath = original_subtree.get_path_to(original_node)
		var duplicated_node: Node = duplicated_subtree if str(relative_path) == "." else duplicated_subtree.get_node_or_null(relative_path)
		if duplicated_node == null:
			continue
		var original_owner: Node = original_node.owner
		if original_owner == null:
			duplicated_node.owner = null
		elif original_owner == live_edited_scene_root or original_owner == live_instance_root:
			duplicated_node.owner = source_candidate_root
		elif original_owner == original_subtree or original_subtree.is_ancestor_of(original_owner):
			var owner_relative_path: NodePath = original_subtree.get_path_to(original_owner)
			var duplicated_owner: Node = duplicated_subtree if str(owner_relative_path) == "." else duplicated_subtree.get_node_or_null(owner_relative_path)
			duplicated_node.owner = duplicated_owner if duplicated_owner != null else source_candidate_root
		else:
			# If a locally added node points to another owner in the host scene, replace it with the root owner inside the base scene boundary.
			duplicated_node.owner = source_candidate_root


func _create_transaction_backup(host_path: String, source_path: String) -> Dictionary:
	var backup_root_absolute_path: String = ProjectSettings.globalize_path(BACKUP_DIRECTORY_PATH)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(backup_root_absolute_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure_result(
			"Failed to create the Apply backup directory: %s" % error_string(directory_error)
		)

	var host_bytes_result: Dictionary = _read_file_bytes(host_path)
	if not host_bytes_result.get("ok", false):
		return host_bytes_result
	var source_bytes_result: Dictionary = _read_file_bytes(source_path)
	if not source_bytes_result.get("ok", false):
		return source_bytes_result

	var backup_id: String = _create_unique_backup_id(backup_root_absolute_path)
	var backup_directory_absolute_path: String = backup_root_absolute_path.path_join(backup_id)
	directory_error = DirAccess.make_dir_recursive_absolute(backup_directory_absolute_path)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		return _failure_result(
			"Failed to create the Apply backup set: %s" % error_string(directory_error)
		)

	var host_backup_path: String = backup_directory_absolute_path.path_join(HOST_BACKUP_FILE_NAME)
	var source_backup_path: String = backup_directory_absolute_path.path_join(SOURCE_BACKUP_FILE_NAME)
	var write_error: int = _write_file_bytes(host_backup_path, host_bytes_result["bytes"])
	if write_error != OK:
		return _failure_result("Failed to back up the host scene: %s" % error_string(write_error))
	write_error = _write_file_bytes(source_backup_path, source_bytes_result["bytes"])
	if write_error != OK:
		return _failure_result("Failed to back up the base scene: %s" % error_string(write_error))

	var manifest: Dictionary = {
		"format_version": 1,
		"backup_id": backup_id,
		"created_unix_msec": int(Time.get_unix_time_from_system() * 1000.0),
		"status": "prepared",
		"host_path": host_path,
		"source_path": source_path,
		"host_backup_file": HOST_BACKUP_FILE_NAME,
		"source_backup_file": SOURCE_BACKUP_FILE_NAME,
		# Store UIDs as strings so JSON number precision cannot truncate them.
		"host_uid": str(ResourceLoader.get_resource_uid(host_path)),
		"source_uid": str(ResourceLoader.get_resource_uid(source_path)),
		"host_before_sha256": _calculate_bytes_sha256(host_bytes_result["bytes"]),
		"source_before_sha256": _calculate_bytes_sha256(source_bytes_result["bytes"]),
	}
	var manifest_path: String = backup_directory_absolute_path.path_join(BACKUP_MANIFEST_FILE_NAME)
	write_error = _write_manifest_file(manifest_path, manifest)
	if write_error != OK:
		return _failure_result("Failed to save the Apply backup record: %s" % error_string(write_error))

	return {
		"ok": true,
		"success": true,
		"manifest": manifest,
		"manifest_path": manifest_path,
	}


func _save_packed_scene_with_preserved_uid(packed_scene: PackedScene, path: String, uid: int) -> int:
	var save_error: int = ResourceSaver.save(packed_scene, path)
	if save_error != OK:
		return save_error
	if uid != ResourceUID.INVALID_ID:
		return ResourceSaver.set_uid(path, uid)
	return OK


func _validate_saved_scene_files(
	host_path: String,
	source_path: String,
	instance_path_from_host: NodePath,
	entries: Array,
	host_uid: int,
	source_uid: int
) -> Dictionary:
	if not FileAccess.file_exists(host_path) or not FileAccess.file_exists(source_path):
		return _failure_result("The host or base scene file was not found after saving.")
	if host_uid != ResourceUID.INVALID_ID and ResourceLoader.get_resource_uid(host_path) != host_uid:
		return _failure_result("The host scene UID changed during the save operation.")
	if source_uid != ResourceUID.INVALID_ID and ResourceLoader.get_resource_uid(source_path) != source_uid:
		return _failure_result("The base scene UID changed during the save operation.")

	var source_resource: Resource = ResourceLoader.load(
		source_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	if source_resource == null or not source_resource is PackedScene:
		return _failure_result("Failed to reload the saved base scene: %s" % source_path)
	var source_root: Node = (source_resource as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if source_root == null:
		return _failure_result("Could not instantiate the saved base scene for validation: %s" % source_path)
	var source_effect_result := _validate_entry_effects_on_root(source_root, entries, true)
	source_root.free()
	if not source_effect_result.get("ok", false):
		return _failure_result(
			"Validation of the selected entries in the saved base scene failed: %s" % source_effect_result.get("message", "")
		)

	var host_resource: Resource = ResourceLoader.load(
		host_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	if host_resource == null or not host_resource is PackedScene:
		return _failure_result("Failed to reload the saved host scene: %s" % host_path)
	var host_root: Node = (host_resource as PackedScene).instantiate(PackedScene.GEN_EDIT_STATE_DISABLED)
	if host_root == null:
		return _failure_result("Could not instantiate the saved host scene for validation: %s" % host_path)
	var host_instance: Node = host_root.get_node_or_null(instance_path_from_host)
	if host_instance == null:
		host_root.free()
		return _failure_result("Could not find the Apply target instance in the saved host scene.")
	var host_effect_result := _validate_entry_effects_on_root(host_instance, entries, true)
	host_root.free()
	if not host_effect_result.get("ok", false):
		return _failure_result(
			"Could not confirm propagation of the new base values in the saved host scene: %s" % host_effect_result.get("message", "")
		)
	return {"ok": true, "success": true}


func _validate_saved_source_scene_file(
		source_path: String,
		entries: Array,
		source_uid: int
	) -> Dictionary:
	if not FileAccess.file_exists(source_path):
		return _failure_result("The base scene file was not found after saving.")
	if (
		source_uid != ResourceUID.INVALID_ID
		and ResourceLoader.get_resource_uid(source_path) != source_uid
	):
		return _failure_result("The base scene UID changed during the save operation.")
	var source_resource: Resource = ResourceLoader.load(
		source_path,
		"PackedScene",
		ResourceLoader.CACHE_MODE_IGNORE_DEEP
	)
	if source_resource == null or not source_resource is PackedScene:
		return _failure_result("Failed to reload the saved base scene: %s" % source_path)
	var source_root: Node = (source_resource as PackedScene).instantiate(
		PackedScene.GEN_EDIT_STATE_DISABLED
	)
	if source_root == null:
		return _failure_result(
			"Could not instantiate the saved base scene for validation: %s"
			% source_path
		)
	var source_effect_result := _validate_entry_effects_on_root(
		source_root,
		entries,
		true
	)
	source_root.free()
	if not source_effect_result.get("ok", false):
		return _failure_result(
			"Validation of the selected entries in the saved base scene failed: %s"
			% source_effect_result.get("message", "")
		)
	return {"ok": true, "success": true}


func _rollback_failed_apply(manifest: Dictionary, manifest_path: String, failure_message: String) -> Dictionary:
	var restore_result: Dictionary = _restore_files_from_manifest(manifest, "before")
	if restore_result.get("ok", false):
		manifest["status"] = "rolled_back"
		manifest["failure_message"] = failure_message
		_write_manifest_file(manifest_path, manifest)
		var host_path: String = str(manifest.get("host_path", ""))
		var source_path: String = str(manifest.get("source_path", ""))
		_refresh_saved_scene_files(host_path, source_path)
		push_error("%s The host and base scenes were restored from backup." % failure_message)
		return _failure_result(
			"%s The host and base scenes were restored from backup." % failure_message,
			{"rolled_back": true, "backup_id": str(manifest.get("backup_id", ""))}
		)

	manifest["status"] = "rollback_failed"
	manifest["failure_message"] = failure_message
	manifest["rollback_error"] = str(restore_result.get("message", "Unknown restoration error"))
	_write_manifest_file(manifest_path, manifest)
	push_error("%s Automatic rollback also failed." % failure_message)
	return _failure_result(
		"%s Automatic rollback also failed. Manual restoration is required using backup ID %s: %s" % [
			failure_message,
			str(manifest.get("backup_id", "")),
			str(restore_result.get("message", "Unknown restoration error")),
		],
		{"rolled_back": false, "backup_id": str(manifest.get("backup_id", ""))}
	)


func _rollback_failed_source_only_apply(
		manifest: Dictionary,
		manifest_path: String,
		failure_message: String
	) -> Dictionary:
	var backup_id: String = str(manifest.get("backup_id", ""))
	var source_path: String = _normalize_resource_path(
		str(manifest.get("source_path", ""))
	)
	if backup_id.is_empty() or backup_id.get_file() != backup_id:
		return _failure_result(
			"%s The base scene backup ID is invalid." % failure_message,
			{"rolled_back": false}
		)
	var source_backup_path: String = ProjectSettings.globalize_path(
		BACKUP_DIRECTORY_PATH
	).path_join(backup_id).path_join(SOURCE_BACKUP_FILE_NAME)
	var source_uid: int = int(str(manifest.get("source_uid", ResourceUID.INVALID_ID)))
	var restore_result := _restore_single_file_from_backup(
		source_backup_path,
		source_path,
		source_uid
	)
	if restore_result.get("ok", false):
		manifest["status"] = "rolled_back"
		manifest["failure_message"] = failure_message
		_write_manifest_file(manifest_path, manifest)
		_refresh_saved_scene_files(str(manifest.get("host_path", "")), source_path)
		push_error("%s The base scene was restored from backup." % failure_message)
		return _failure_result(
			"%s The base scene was restored from backup." % failure_message,
			{"rolled_back": true, "backup_id": backup_id}
		)

	manifest["status"] = "rollback_failed"
	manifest["failure_message"] = failure_message
	manifest["rollback_error"] = str(
		restore_result.get("message", "Unknown restoration error")
	)
	_write_manifest_file(manifest_path, manifest)
	push_error("%s Automatic base scene rollback also failed." % failure_message)
	return _failure_result(
		"%s Automatic base scene rollback also failed. Manual restoration is required using backup ID %s: %s"
		% [
			failure_message,
			backup_id,
			str(restore_result.get("message", "Unknown restoration error")),
		],
		{"rolled_back": false, "backup_id": backup_id}
	)


func _restore_files_from_manifest(manifest: Dictionary, hash_stage: String) -> Dictionary:
	var backup_id: String = str(manifest.get("backup_id", ""))
	if backup_id.is_empty() or backup_id.get_file() != backup_id:
		return _failure_result("The backup ID is invalid.")
	var backup_directory: String = ProjectSettings.globalize_path(BACKUP_DIRECTORY_PATH).path_join(backup_id)
	var host_backup_path: String = backup_directory.path_join(HOST_BACKUP_FILE_NAME)
	var source_backup_path: String = backup_directory.path_join(SOURCE_BACKUP_FILE_NAME)
	var host_path: String = _normalize_resource_path(str(manifest.get("host_path", "")))
	var source_path: String = _normalize_resource_path(str(manifest.get("source_path", "")))
	if not _is_supported_scene_file_path(host_path) or not _is_supported_scene_file_path(source_path):
		return _failure_result("The scene paths in the backup record are invalid.")
	var host_backup_bytes_result: Dictionary = _read_file_bytes(host_backup_path)
	if not host_backup_bytes_result.get("ok", false):
		return host_backup_bytes_result
	var source_backup_bytes_result: Dictionary = _read_file_bytes(source_backup_path)
	if not source_backup_bytes_result.get("ok", false):
		return source_backup_bytes_result
	if (
		_calculate_bytes_sha256(host_backup_bytes_result["bytes"])
		!= str(manifest.get("host_%s_sha256" % hash_stage, ""))
		or _calculate_bytes_sha256(source_backup_bytes_result["bytes"])
		!= str(manifest.get("source_%s_sha256" % hash_stage, ""))
	):
		return _failure_result("Restoration was stopped because the backup file SHA-256 does not match the record.")

	var host_restore_result: Dictionary = _restore_single_file_from_backup(
		host_backup_path,
		host_path,
		int(str(manifest.get("host_uid", ResourceUID.INVALID_ID)))
	)
	if not host_restore_result.get("ok", false):
		return host_restore_result
	var source_restore_result: Dictionary = _restore_single_file_from_backup(
		source_backup_path,
		source_path,
		int(str(manifest.get("source_uid", ResourceUID.INVALID_ID)))
	)
	if not source_restore_result.get("ok", false):
		return source_restore_result

	var verification_result: Dictionary = _verify_files_match_manifest_hashes(manifest, hash_stage)
	if not verification_result.get("ok", false):
		return _failure_result(
			"The backup bytes were restored, but file hash validation failed.",
			{"restore_hash_failed": true}
		)
	return {"ok": true, "success": true}


func _restore_single_file_from_backup(backup_path: String, target_path: String, uid: int) -> Dictionary:
	var backup_bytes_result: Dictionary = _read_file_bytes(backup_path)
	if not backup_bytes_result.get("ok", false):
		return backup_bytes_result
	var backup_bytes: PackedByteArray = backup_bytes_result["bytes"]
	var write_error: int = _write_file_bytes(target_path, backup_bytes)
	if write_error != OK:
		return _failure_result("Failed to restore the backup file: %s (%s)" % [target_path, error_string(write_error)])

	if uid != ResourceUID.INVALID_ID:
		# set_uid may serialize the file again, so refresh the UID cache and restore the original bytes once more.
		var uid_error: int = ResourceSaver.set_uid(target_path, uid)
		if uid_error != OK:
			return _failure_result("Failed to restore the UID of the restored file: %s" % target_path)
		if ResourceUID.has_id(uid):
			ResourceUID.set_id(uid, target_path)
		else:
			ResourceUID.add_id(uid, target_path)
		write_error = _write_file_bytes(target_path, backup_bytes)
		if write_error != OK:
			return _failure_result("Failed to rewrite the original bytes after restoring the UID: %s" % target_path)
	return {"ok": true, "success": true}


func _verify_files_match_manifest_hashes(manifest: Dictionary, hash_stage: String) -> Dictionary:
	var host_path: String = str(manifest.get("host_path", ""))
	var source_path: String = str(manifest.get("source_path", ""))
	var host_expected_hash: String = str(manifest.get("host_%s_sha256" % hash_stage, ""))
	var source_expected_hash: String = str(manifest.get("source_%s_sha256" % hash_stage, ""))
	if host_expected_hash.is_empty() or source_expected_hash.is_empty():
		return _failure_result("The backup record does not contain file hashes for the %s stage." % hash_stage)
	var host_actual_hash: String = _get_file_sha256(host_path)
	var source_actual_hash: String = _get_file_sha256(source_path)
	if host_actual_hash != host_expected_hash or source_actual_hash != source_expected_hash:
		return _failure_result(
			"The host or base scene file hash does not match the backup record.",
			{
				"host_hash_matches": host_actual_hash == host_expected_hash,
				"source_hash_matches": source_actual_hash == source_expected_hash,
			}
		)
	return {"ok": true, "success": true}


func _capture_initial_scene_file_hashes(
		host_path: String,
		source_path: String
	) -> Dictionary:
	var host_sha256: String = _get_file_sha256(host_path)
	var source_sha256: String = _get_file_sha256(source_path)
	if host_sha256.is_empty() or source_sha256.is_empty():
		return _failure_result(
			"Apply was stopped because the current host or base scene file could not be hashed."
		)
	return {
		"ok": true,
		"success": true,
		"host_sha256": host_sha256,
		"source_sha256": source_sha256,
	}


func _verify_backup_matches_initial_scene_file_hashes(
		manifest: Dictionary,
		initial_file_hashes: Dictionary
	) -> Dictionary:
	var initial_host_sha256: String = str(
		initial_file_hashes.get("host_sha256", "")
	)
	var initial_source_sha256: String = str(
		initial_file_hashes.get("source_sha256", "")
	)
	var backup_host_sha256: String = str(
		manifest.get("host_before_sha256", "")
	)
	var backup_source_sha256: String = str(
		manifest.get("source_before_sha256", "")
	)
	if (
		initial_host_sha256.is_empty()
		or initial_source_sha256.is_empty()
		or backup_host_sha256.is_empty()
		or backup_source_sha256.is_empty()
	):
		return _failure_result(
			"Apply was stopped because the candidate input hashes are incomplete."
		)
	if (
		backup_host_sha256 != initial_host_sha256
		or backup_source_sha256 != initial_source_sha256
	):
		return _failure_result(
			"Apply was stopped because the host or base scene file changed while preparing the candidate. No scene files were written.",
			{
				"host_hash_matches": backup_host_sha256 == initial_host_sha256,
				"source_hash_matches": backup_source_sha256 == initial_source_sha256,
			}
		)
	return {"ok": true, "success": true}


func _register_revert_undo_operations(
	undo_redo: EditorUndoRedoManager,
	instance_root: Node,
	edited_scene_root: Node,
	entries: Array
) -> Dictionary:
	var property_operations: Array = []
	var added_node_operations: Array = []
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		var kind: String = _normalize_entry_kind(str(entry.get("kind", "")))
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		var target_node: Node = _find_relative_node(instance_root, node_path)
		if target_node == null:
			return _failure_result("Could not find the target to revert in the current instance: %s" % node_path)

		if kind == "property":
			var property_name := StringName(str(entry.get("property_name", "")))
			if not _object_has_property(target_node, property_name):
				return _failure_result("The property does not exist in the current instance: %s.%s" % [node_path, property_name])
			property_operations.append({
				"node": target_node,
				"property_name": property_name,
				"revert_value": entry.get("base_value"),
				"original_value": target_node.get(property_name),
			})
		elif kind == "added_node":
			if not instance_root.is_ancestor_of(target_node):
				return _failure_result("The added node to revert is outside the instance boundary: %s" % node_path)
			var parent: Node = target_node.get_parent()
			if parent == null:
				return _failure_result("The parent of the added node to revert is missing: %s" % node_path)
			added_node_operations.append({
				"node": target_node,
				"parent": parent,
				"index": target_node.get_index(),
				"owner_records": _capture_subtree_owner_records(target_node, edited_scene_root),
			})

	undo_redo.create_action(
		"Revert Scene Instance Overrides",
		UndoRedo.MERGE_DISABLE,
		edited_scene_root
	)
	for operation_value: Variant in property_operations:
		var operation: Dictionary = operation_value
		var node: Node = operation["node"]
		var property_name: StringName = operation["property_name"]
		undo_redo.add_do_property(node, property_name, operation.get("revert_value"))
		undo_redo.add_undo_property(node, property_name, operation.get("original_value"))

	# Remove children first so parent references remain stable across separate added subtrees.
	added_node_operations.sort_custom(_sort_node_operations_deepest_first)
	for operation_value: Variant in added_node_operations:
		var operation: Dictionary = operation_value
		var node: Node = operation["node"]
		var parent: Node = operation["parent"]
		undo_redo.add_do_method(parent, "remove_child", node)
		undo_redo.add_undo_method(parent, "add_child", node)
		undo_redo.add_undo_method(parent, "move_child", node, int(operation["index"]))
		undo_redo.add_undo_method(
			self,
			"_restore_removed_subtree_owners",
			node,
			edited_scene_root,
			operation["owner_records"]
		)
		undo_redo.add_undo_reference(node)
	return {"ok": true, "success": true}


func _capture_subtree_owner_records(subtree_root: Node, edited_scene_root: Node) -> Array:
	var records: Array = []
	var subtree_nodes: Array[Node] = [subtree_root]
	subtree_nodes.append_array(subtree_root.find_children("*", "Node", true, false))
	for subtree_node: Node in subtree_nodes:
		var owner: Node = subtree_node.owner
		var record: Dictionary = {
			"node_path": str(subtree_root.get_path_to(subtree_node)),
			"owner_mode": "none",
			"owner_path": "",
		}
		if owner == null:
			record["owner_mode"] = "none"
		elif owner == edited_scene_root or edited_scene_root.is_ancestor_of(owner):
			record["owner_mode"] = "scene"
			record["owner_path"] = str(edited_scene_root.get_path_to(owner))
		elif owner == subtree_root or subtree_root.is_ancestor_of(owner):
			record["owner_mode"] = "subtree"
			record["owner_path"] = str(subtree_root.get_path_to(owner))
		records.append(record)
	return records


func _restore_removed_subtree_owners(subtree_root: Node, edited_scene_root: Node, records: Array) -> void:
	if not is_instance_valid(subtree_root) or not is_instance_valid(edited_scene_root):
		return
	for record_value: Variant in records:
		if not record_value is Dictionary:
			continue
		var record: Dictionary = record_value
		var node_path: String = _normalize_relative_node_path(str(record.get("node_path", ".")))
		var subtree_node: Node = _find_relative_node(subtree_root, node_path)
		if subtree_node == null:
			continue
		var owner_mode: String = str(record.get("owner_mode", "none"))
		if owner_mode == "none":
			subtree_node.owner = null
		elif owner_mode == "scene":
			var scene_owner: Node = _find_relative_node(
				edited_scene_root,
				_normalize_relative_node_path(str(record.get("owner_path", ".")))
			)
			if scene_owner != null:
				subtree_node.owner = scene_owner
		elif owner_mode == "subtree":
			var subtree_owner: Node = _find_relative_node(
				subtree_root,
				_normalize_relative_node_path(str(record.get("owner_path", ".")))
			)
			if subtree_owner != null:
				subtree_node.owner = subtree_owner


func _load_latest_applied_manifest() -> Dictionary:
	if not _last_apply_manifest_path.is_empty() and FileAccess.file_exists(_last_apply_manifest_path):
		var remembered_result: Dictionary = _read_manifest_file(_last_apply_manifest_path)
		if remembered_result.get("ok", false):
			var remembered_manifest: Dictionary = remembered_result["manifest"]
			var remembered_status: String = str(remembered_manifest.get("status", ""))
			if remembered_status == "applied":
				remembered_result["manifest_path"] = _last_apply_manifest_path
				return remembered_result
			if remembered_status == "applied_without_saving_host":
				return _failure_result(
					"The latest Apply kept the parent scene unsaved, so it has no disk restoration action."
				)

	var backup_root_absolute_path: String = ProjectSettings.globalize_path(BACKUP_DIRECTORY_PATH)
	var directory: DirAccess = DirAccess.open(backup_root_absolute_path)
	if directory == null:
		return _failure_result("No Apply backup is available to undo.")
	var backup_directories: PackedStringArray = directory.get_directories()
	backup_directories.sort()
	backup_directories.reverse()
	for backup_id: String in backup_directories:
		if backup_id.get_file() != backup_id:
			continue
		var manifest_path: String = backup_root_absolute_path.path_join(backup_id).path_join(BACKUP_MANIFEST_FILE_NAME)
		if not FileAccess.file_exists(manifest_path):
			continue
		var manifest_result: Dictionary = _read_manifest_file(manifest_path)
		if not manifest_result.get("ok", false):
			continue
		var manifest: Dictionary = manifest_result["manifest"]
		var status: String = str(manifest.get("status", ""))
		if status == "applied_without_saving_host":
			return _failure_result(
				"The latest Apply kept the parent scene unsaved, so it has no disk restoration action."
			)
		if status != "applied":
			continue
		_last_apply_manifest_path = manifest_path
		manifest_result["manifest_path"] = manifest_path
		return manifest_result
	return _failure_result("No recent Apply backup can be undone.")


func _read_manifest_file(manifest_path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return _failure_result("Failed to open the Apply backup record: %s" % manifest_path)
	var json_text: String = file.get_as_text()
	var read_error: int = file.get_error()
	file.close()
	if read_error != OK:
		return _failure_result("Failed to read the Apply backup record: %s" % manifest_path)
	var json := JSON.new()
	var parse_error: int = json.parse(json_text)
	if parse_error != OK or not json.data is Dictionary:
		return _failure_result("The Apply backup record JSON is corrupt: %s" % manifest_path)
	return {"ok": true, "success": true, "manifest": json.data}


func _write_manifest_file(manifest_path: String, manifest: Dictionary) -> int:
	var file: FileAccess = FileAccess.open(manifest_path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(manifest, "\t", true, false))
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	return write_error


func _prune_old_transaction_backups() -> void:
	var backup_root_absolute_path: String = ProjectSettings.globalize_path(BACKUP_DIRECTORY_PATH)
	var directory: DirAccess = DirAccess.open(backup_root_absolute_path)
	if directory == null:
		return
	var backup_directories: PackedStringArray = directory.get_directories()
	backup_directories.sort()
	backup_directories.reverse()
	for index: int in range(MAX_BACKUP_COUNT, backup_directories.size()):
		var backup_id: String = backup_directories[index]
		if backup_id.get_file() != backup_id:
			continue
		var backup_directory: String = backup_root_absolute_path.path_join(backup_id)
		# Remove only the known files created by this plugin, and preserve the directory if it contains unknown files.
		for backup_file_name: String in PackedStringArray([
			HOST_BACKUP_FILE_NAME,
			SOURCE_BACKUP_FILE_NAME,
			BACKUP_MANIFEST_FILE_NAME,
		]):
			var backup_file_path: String = backup_directory.path_join(backup_file_name)
			if FileAccess.file_exists(backup_file_path):
				DirAccess.remove_absolute(backup_file_path)
		DirAccess.remove_absolute(backup_directory)


func _create_unique_backup_id(backup_root_absolute_path: String) -> String:
	var unix_msec: int = int(Time.get_unix_time_from_system() * 1000.0)
	var tick_suffix: int = int(Time.get_ticks_usec() % 1000000)
	var base_id: String = "%013d_%06d" % [unix_msec, tick_suffix]
	var candidate_id := base_id
	var collision_index := 1
	while DirAccess.dir_exists_absolute(backup_root_absolute_path.path_join(candidate_id)):
		candidate_id = "%s_%02d" % [base_id, collision_index]
		collision_index += 1
	return candidate_id


func _read_file_bytes(path: String) -> Dictionary:
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _failure_result("Failed to open the file: %s (%s)" % [path, error_string(FileAccess.get_open_error())])
	var length: int = file.get_length()
	var bytes: PackedByteArray = file.get_buffer(length)
	var read_error: int = file.get_error()
	file.close()
	if read_error != OK:
		return _failure_result("Failed to read the entire file: %s (%s)" % [path, error_string(read_error)])
	if bytes.size() != length:
		return _failure_result("The file byte count does not match the expected size: %s" % path)
	return {"ok": true, "success": true, "bytes": bytes}


func _write_file_bytes(path: String, bytes: PackedByteArray) -> int:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_buffer(bytes)
	file.flush()
	var write_error: int = file.get_error()
	file.close()
	return write_error


func _get_file_sha256(path: String) -> String:
	var bytes_result: Dictionary = _read_file_bytes(path)
	if not bytes_result.get("ok", false):
		return ""
	var bytes: PackedByteArray = bytes_result["bytes"]
	return _calculate_bytes_sha256(bytes)


func _calculate_bytes_sha256(bytes: PackedByteArray) -> String:
	var hashing_context := HashingContext.new()
	if hashing_context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	if hashing_context.update(bytes) != OK:
		return ""
	return hashing_context.finish().hex_encode()


func _refresh_saved_scene_files(host_path: String, source_path: String) -> PackedStringArray:
	if not Engine.is_editor_hint():
		ResourceLoader.load(source_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		ResourceLoader.load(host_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
		return PackedStringArray()

	var related_context := {"host_path": host_path, "source_path": source_path}
	var reload_paths: PackedStringArray = find_open_dependency_scene_paths(related_context)
	var dirty_paths: PackedStringArray = find_open_dirty_dependency_paths(related_context)
	for dirty_path: String in dirty_paths:
		reload_paths.erase(dirty_path)

	var file_system: EditorFileSystem = EditorInterface.get_resource_filesystem()
	if file_system != null:
		file_system.update_file(source_path)
		file_system.update_file(host_path)

	# Replace the scene and external dependency caches together, then reload the open dependent scenes.
	ResourceLoader.load(source_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	ResourceLoader.load(host_path, "PackedScene", ResourceLoader.CACHE_MODE_REPLACE_DEEP)
	_clear_open_scene_undo_histories(reload_paths)

	var ordered_paths := PackedStringArray()
	if reload_paths.has(source_path):
		ordered_paths.append(source_path)
	for reload_path: String in reload_paths:
		if reload_path != source_path and reload_path != host_path:
			ordered_paths.append(reload_path)
	if reload_paths.has(host_path):
		ordered_paths.append(host_path)
	for reload_path: String in ordered_paths:
		EditorInterface.reload_scene_from_path(reload_path)
	return ordered_paths


func _clear_open_scene_undo_histories(scene_paths: PackedStringArray) -> void:
	var undo_redo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	if undo_redo == null:
		return
	for root: Node in EditorInterface.get_open_scene_roots():
		if root == null or not is_instance_valid(root):
			continue
		var root_path: String = _normalize_resource_path(root.scene_file_path)
		if not scene_paths.has(root_path):
			continue
		var history_id: int = undo_redo.get_object_history_id(root)
		if history_id != EditorUndoRedoManager.INVALID_HISTORY:
			undo_redo.clear_history(history_id, false)


func _scene_file_depends_on(scene_path: String, target_path: String) -> bool:
	var visited := {}
	return _resource_file_depends_on_recursive(scene_path, target_path, visited)


func _resource_file_depends_on_recursive(
	resource_path: String,
	target_path: String,
	visited: Dictionary
) -> bool:
	var normalized_resource_path: String = _normalize_resource_path(resource_path)
	if normalized_resource_path.is_empty() or visited.has(normalized_resource_path):
		return false
	visited[normalized_resource_path] = true
	if not FileAccess.file_exists(normalized_resource_path):
		return false

	for dependency_descriptor: String in ResourceLoader.get_dependencies(normalized_resource_path):
		var dependency_path: String = _extract_dependency_path(dependency_descriptor)
		if dependency_path.is_empty():
			continue
		if dependency_path == target_path:
			return true
		if dependency_path.begins_with("res://") and _resource_file_depends_on_recursive(
			dependency_path,
			target_path,
			visited
		):
			return true
	return false


func _extract_dependency_path(dependency_descriptor: String) -> String:
	if dependency_descriptor.contains("::"):
		return _normalize_resource_path(dependency_descriptor.get_slice("::", 2))
	return _normalize_resource_path(dependency_descriptor)


func _find_overlapping_added_node_paths(entries: Array) -> String:
	var added_paths := PackedStringArray()
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		if _normalize_entry_kind(str(entry.get("kind", ""))) != "added_node":
			continue
		var node_path: String = _normalize_relative_node_path(str(entry.get("node_path", ".")))
		for existing_path: String in added_paths:
			if node_path == existing_path or node_path.begins_with(existing_path + "/") or existing_path.begins_with(node_path + "/"):
				return "A parent and its added child node cannot be selected together: %s / %s" % [existing_path, node_path]
		added_paths.append(node_path)
	return ""


func _find_relative_node(root: Node, relative_path: String) -> Node:
	if root == null or not is_instance_valid(root):
		return null
	var normalized_path: String = _normalize_relative_node_path(relative_path)
	if normalized_path == ".":
		return root
	return root.get_node_or_null(NodePath(normalized_path))


func _get_relative_parent_path(relative_path: String) -> String:
	var normalized_path: String = _normalize_relative_node_path(relative_path)
	var slash_index: int = normalized_path.rfind("/")
	if slash_index < 0:
		return "."
	var parent_path: String = normalized_path.substr(0, slash_index)
	return "." if parent_path.is_empty() else parent_path


func _normalize_entry_kind(kind: String) -> String:
	match kind:
		"property", "supported_property":
			return "property"
		"added_node", "added":
			return "added_node"
		"unsupported":
			return "unsupported"
		_:
			return kind


func _normalize_resource_path(path: String) -> String:
	if path.is_empty():
		return ""
	return path.replace("\\", "/").simplify_path()


func _normalize_relative_node_path(path: String) -> String:
	var normalized_path: String = path.replace("\\", "/").strip_edges()
	if normalized_path.is_empty() or normalized_path == "./":
		return "."
	while normalized_path.begins_with("./"):
		normalized_path = normalized_path.substr(2)
	while normalized_path.ends_with("/"):
		normalized_path = normalized_path.left(-1)
	return "." if normalized_path.is_empty() else normalized_path


func _is_safe_relative_node_path(path: String) -> bool:
	if path.is_empty() or path.begins_with("/"):
		return false
	var path_parts: PackedStringArray = path.split("/", false)
	for path_part: String in path_parts:
		if path_part == ".." or path_part.is_empty():
			return false
	return true


func _is_supported_scene_file_path(path: String) -> bool:
	if not path.begins_with("res://"):
		return false
	return SUPPORTED_SCENE_EXTENSIONS.has(path.get_extension().to_lower())


func _object_has_property(object: Object, property_name: StringName) -> bool:
	for property_value: Variant in object.get_property_list():
		var property_info: Dictionary = property_value
		if StringName(property_info.get("name", "")) == property_name:
			return true
	return false


func _variant_values_match(actual_value: Variant, expected_value: Variant) -> bool:
	if typeof(actual_value) != typeof(expected_value):
		return false
	if actual_value is float:
		return is_equal_approx(float(actual_value), float(expected_value))
	if actual_value is Resource:
		var actual_resource: Resource = actual_value
		var expected_resource: Resource = expected_value
		if actual_resource == null or expected_resource == null:
			return actual_resource == expected_resource
		if not actual_resource.resource_path.is_empty() or not expected_resource.resource_path.is_empty():
			return actual_resource.resource_path == expected_resource.resource_path
		return is_same(actual_resource, expected_resource)
	return actual_value == expected_value


func _collect_entry_ids(entries: Array) -> PackedStringArray:
	var entry_ids := PackedStringArray()
	for entry_value: Variant in entries:
		var entry: Dictionary = entry_value
		entry_ids.append(str(entry.get("id", "")))
	return entry_ids


func _sort_entry_paths_shallowest_first(first: Dictionary, second: Dictionary) -> bool:
	var first_path: String = _normalize_relative_node_path(str(first.get("node_path", ".")))
	var second_path: String = _normalize_relative_node_path(str(second.get("node_path", ".")))
	return first_path.get_slice_count("/") < second_path.get_slice_count("/")


func _sort_entry_paths_deepest_first(first: Dictionary, second: Dictionary) -> bool:
	var first_path: String = _normalize_relative_node_path(str(first.get("node_path", ".")))
	var second_path: String = _normalize_relative_node_path(str(second.get("node_path", ".")))
	return first_path.get_slice_count("/") > second_path.get_slice_count("/")


func _sort_node_operations_deepest_first(first: Dictionary, second: Dictionary) -> bool:
	var first_node: Node = first["node"]
	var second_node: Node = second["node"]
	return str(first_node.get_path()).get_slice_count("/") > str(second_node.get_path()).get_slice_count("/")


func _success_result(message: String, extra_fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": true,
		"success": true,
		"message": message,
	}
	result.merge(extra_fields, true)
	return result


func _failure_result(message: String, extra_fields: Dictionary = {}) -> Dictionary:
	var result: Dictionary = {
		"ok": false,
		"success": false,
		"error": message,
		"message": message,
	}
	result.merge(extra_fields, true)
	return result
