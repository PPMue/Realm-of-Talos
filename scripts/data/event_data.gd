class_name EventData
extends Resource
## An event day: a short text and 2 or 3 choices. Add new events to RunContent.events; no code needed.

@export var title: String = ""
@export_multiline var text: String = ""
@export var choices: Array[EventChoiceData] = []
