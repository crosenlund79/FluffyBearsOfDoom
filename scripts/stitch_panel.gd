## A PanelContainer with a stitched seam just inside its edge.
extends PanelContainer

const UiStyle = preload("res://scripts/ui_style.gd")

var stitch_color := UiStyle.ROSE.lerp(UiStyle.INK_SOFT, 0.4)


func _draw() -> void:
	var r := Rect2(Vector2(7, 7), size - Vector2(14, 14))
	UiStyle.stitch_rect(self, r, stitch_color, 1.6, 6.0)
