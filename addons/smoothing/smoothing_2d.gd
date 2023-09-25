#	Copyright (c) 2019 Lawnjelly
#
#	Permission is hereby granted, free of charge, to any person obtaining a copy
#	of this software and associated documentation files (the "Software"), to deal
#	in the Software without restriction, including without limitation the rights
#	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#	copies of the Software, and to permit persons to whom the Software is
#	furnished to do so, subject to the following conditions:
#
#	The above copyright notice and this permission notice shall be included in all
#	copies or substantial portions of the Software.
#
#	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#	SOFTWARE.

extends Node2D

export (NodePath) var target: NodePath setget set_target, get_target

var _m_Target: Node2D
var _m_Flip: bool = false

var _m_Trans_curr: Transform2D = Transform2D()
var _m_Trans_prev: Transform2D = Transform2D()

const SF_ENABLED = 1 << 0
const SF_GLOBAL_IN = 1 << 1
const SF_GLOBAL_OUT = 1 << 2
const SF_INVISIBLE = 1 << 3

export (int, FLAGS, "enabled", "global in", "global out") var flags: int = SF_ENABLED | SF_GLOBAL_IN | SF_GLOBAL_OUT setget _set_flags, _get_flags

##########################################################################################
# USER FUNCS


# call this on e.g. starting a level, AFTER moving the target
# so we can update both the previous and current values
func teleport():

	_RefreshTransform()
	_m_Trans_prev = _m_Trans_curr

	# call frame upate to make sure all components of the node are set
	_process(0)

func set_enabled(bEnable: bool):
	_ChangeFlags(SF_ENABLED, bEnable)
	_SetProcessing()


func is_enabled():
	return _TestFlags(SF_ENABLED)


##########################################################################################


func _ready():
	set_process_priority(100)
	Engine.set_physics_jitter_fix(0.0)


func set_target(new_value):
	target = new_value
	if is_inside_tree():
		_FindTarget()


func get_target():
	return target


func _set_flags(new_value):
	flags = new_value
	# we may have enabled or disabled
	_SetProcessing()


func _get_flags():
	return flags


func _SetProcessing():
	var bEnable = _TestFlags(SF_ENABLED)
	if _TestFlags(SF_INVISIBLE):
		bEnable = false

	set_process(bEnable)
	set_physics_process(bEnable)


func _enter_tree():
	# might have been moved
	_FindTarget()


func _notification(what):
	match what:
		# invisible turns off processing
		NOTIFICATION_VISIBILITY_CHANGED:
			_ChangeFlags(SF_INVISIBLE, is_visible_in_tree() == false)
			_SetProcessing()


func _RefreshTransform():

	if _HasTarget() == false:
		return

	_m_Trans_prev = _m_Trans_curr
	
	if _TestFlags(SF_GLOBAL_IN):
		_m_Trans_curr = _m_Target.get_global_transform()
	else:
		_m_Trans_curr = _m_Target.get_transform()
		
	_m_Flip = false
	if (_m_Trans_prev.determinant() < 0) != (_m_Trans_curr.determinant() < 0):
		_m_Flip = true

func _FindTarget():
	_m_Target = null
	
	# If no target has been assigned in the property,
	# default to using the parent as the target.
	if target.is_empty():
		var parent = get_parent()
		if parent and (parent is Node2D):
			_m_Target = parent
		return

	var targ = get_node(target)

	if ! targ:
		printerr("ERROR SmoothingNode2D : Target " + target + " not found")
		return

	if not targ is Node2D:
		printerr("ERROR SmoothingNode2D : Target " + target + " is not Node2D")
		target = ""
		return

	# if we got to here targ is correct type
	_m_Target = targ


func _HasTarget() -> bool:
	if _m_Target == null:
		return false

	# has not been deleted?
	if is_instance_valid(_m_Target):
		return true

	_m_Target = null
	return false


func _process(_delta):

	var f = Engine.get_physics_interpolation_fraction()

	var tr = Transform2D()
	tr.origin = lerp(_m_Trans_prev.origin, _m_Trans_curr.origin, f)
	tr.x = lerp(_m_Trans_prev.x, _m_Trans_curr.x, f)
	tr.y = lerp(_m_Trans_prev.y, _m_Trans_curr.y, f)

	# When a sprite flip is detected, turn off interpolation for that tick.
	if _m_Flip:
		tr = _m_Trans_curr
		
	if _TestFlags(SF_GLOBAL_OUT):
		set_global_transform(tr)
	else:
		set_transform(tr)

func _physics_process(_delta):
	_RefreshTransform()



func _SetFlags(f):
	flags |= f


func _ClearFlags(f):
	flags &= ~f


func _TestFlags(f):
	return (flags & f) == f


func _ChangeFlags(f, bSet):
	if bSet:
		_SetFlags(f)
	else:
		_ClearFlags(f)
