@tool
extends Resource
class_name LevelPatchMeta

@export var name := ""
@export var chinese_name := ""
@export_range(0, 6) var star := 1
@export var level_maker := ""
@export var music_maker := ""
@export_multiline var introduction := ""
@export var background_path := ""
@export var roundphoto_path := ""
@export var color := Color(1, 1, 1, 1)
@export var unlock := true
@export var card_path := ""
@export var file_name := ""
@export var tiny_levels: Array[TinyLevelMeta] = []
