class_name NetLink
extends RefCounted
## One game's line into an online room (ON-2): the host's to its guests, or a guest's to the
## host. RelayLink goes through the relay; LoopLink through an in-memory one (tests). Guests
## only ever talk to the host, which passes on what the others need (OnlineSession).
##
## Messages are Arrays (var_to_bytes). receive() hands them over as [from, message]: from is
## the guest's number on the host, HOST on a guest. The room's comings and goings arrive the
## same way, as [guest, [JOINED, version]] and [guest, [LEFT]] on the host.

const HOST := -1
const ALL := 255  # the relay's "every guest" (host to guests)
const JOINED := "~JOINED"
const LEFT := "~LEFT"

var error := ""  # set once the line is gone or refused, in capitals for the screen
var room := ""  # the room's four letters, once the relay names it
var hosting := false
var you := -1  # a guest's number in the room, once in
var host_version := ""  # a guest's: the host's game version (from the relay's welcome)


## Whether the line is up: the host has its room, the guest is in it.
func ready() -> bool:
	return error == "" and (room != "" if hosting else you >= 0)


func poll() -> void:
	pass


## A message to guest `to` (or ALL) from the host; a guest's always go to the host.
func send_to(_to: int, _msg: Array) -> void:
	pass


## Everything that came in since the last call, as [from, message] pairs.
func receive() -> Array:
	return []


func close() -> void:
	pass
