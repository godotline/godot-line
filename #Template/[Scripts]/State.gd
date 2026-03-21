extends Node

var main_line_transform 
var is_turn := false
var anim_time := 0.0
var is_end := false
var percent := 0

var line_crossing_crown := 0
var is_relive := false
#后续代码补充，如果玩家在本局有复活即is_live=true就在结算时 crown -= 1
var diamond := 0
var crown := 0
