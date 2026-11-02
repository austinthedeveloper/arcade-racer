"""A rough stand-in Vega made of boxes (CP-1), to try tools/blender/render_car.py and
tools/make_car_renders.py before the real model exists. Not for the game.

    blender -b --factory-startup -P tools/blender/blockout_vega.py -- --out build/vega_blockout.glb

Nose along +Y, wheels on z = 0, metres.
"""
import math
import sys

import bpy


def material(name, color, metallic=0.0, rough=0.35, emit=0.0):
    m = bpy.data.materials.new(name)
    p = m.node_tree.nodes["Principled BSDF"]
    p.inputs["Base Color"].default_value = (*color, 1.0)
    p.inputs["Metallic"].default_value = metallic
    p.inputs["Roughness"].default_value = rough
    if emit:
        p.inputs["Emission Color"].default_value = (*color, 1.0)
        p.inputs["Emission Strength"].default_value = emit
    return m


def box(name, loc, size, mat, bevel=0.06, taper=None):
    """A bevelled box; taper (x, y) scales the top face, for a wedge or a cabin."""
    bpy.ops.mesh.primitive_cube_add(location=loc)
    ob = bpy.context.object
    ob.name = name
    ob.scale = (size[0] / 2, size[1] / 2, size[2] / 2)
    bpy.ops.object.transform_apply(scale=True)
    if taper:
        for v in ob.data.vertices:
            if v.co.z > 0:
                v.co.x *= taper[0]
                v.co.y = v.co.y * taper[1] + (taper[2] if len(taper) > 2 else 0.0)
    if bevel:
        mod = ob.modifiers.new("bevel", "BEVEL")
        mod.width = bevel
        mod.segments = 2
    ob.data.materials.append(mat)
    return ob


def wheel(x, y, mat_tyre, mat_rim):
    bpy.ops.mesh.primitive_cylinder_add(vertices=24, radius=0.36, depth=0.3, location=(x, y, 0.36),
                                        rotation=(0, math.pi / 2, 0))
    t = bpy.context.object
    t.data.materials.append(mat_tyre)
    side = 1 if x > 0 else -1
    bpy.ops.mesh.primitive_cylinder_add(vertices=12, radius=0.24, depth=0.04, location=(x + side * 0.15, y, 0.36),
                                        rotation=(0, math.pi / 2, 0))
    bpy.context.object.data.materials.append(mat_rim)


def main():
    out = sys.argv[sys.argv.index("--out") + 1]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    red = material("paint", (0.75, 0.04, 0.02), metallic=0.3, rough=0.25)
    glass = material("glass", (0.05, 0.08, 0.18), rough=0.05)
    black = material("trim", (0.02, 0.02, 0.025), rough=0.6)
    tyre = material("tyre", (0.015, 0.015, 0.015), rough=0.9)
    rim = material("rim", (0.5, 0.5, 0.55), metallic=1.0, rough=0.3)
    lamp = material("taillight", (1.0, 0.35, 0.05), emit=6.0)
    # Lower body: a long wedge, low at the nose
    box("body", (0, 0, 0.55), (1.95, 4.4, 0.62), red, taper=(0.97, 0.98))
    box("nose", (0, 1.6, 0.42), (1.85, 1.2, 0.36), red, taper=(0.95, 0.8, -0.1))
    # Cabin: set back, tapering to a narrow roof
    box("cabin", (0, -0.15, 1.08), (1.5, 2.0, 0.46), glass, bevel=0.1, taper=(0.72, 0.62, -0.15))
    # Rear deck and the two fins
    box("deck", (0, -1.5, 0.95), (1.85, 1.3, 0.2), red, taper=(0.95, 0.9))
    for x in (-0.68, 0.68):
        box("fin", (x, -1.95, 1.22), (0.12, 0.45, 0.42), red, bevel=0.02, taper=(0.5, 0.4, -0.12))
    # Tail panel: the taillight bar and the triangle lamps either side, the diffuser below
    box("tail", (0, -2.2, 0.62), (1.9, 0.06, 0.5), black, bevel=0.02)
    box("bar", (0, -2.235, 0.74), (1.3, 0.03, 0.05), lamp, bevel=0)
    for x in (-0.72, 0.72):
        for k in (-1, 0, 1):
            box("lamp", (x + k * 0.13, -2.235, 0.74), (0.1, 0.03, 0.12), lamp, bevel=0, taper=(0.1, 1.0))
    box("exhaust", (0, -2.24, 0.45), (0.42, 0.04, 0.18), rim, bevel=0.03)
    for x in (-0.86, 0.86):
        for y in (1.35, -1.35):
            wheel(x, y, tyre, rim)
    for ob in bpy.context.scene.objects:
        ob.select_set(True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", use_selection=True, export_apply=True)
    print("wrote", out)


main()
