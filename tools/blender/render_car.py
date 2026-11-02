"""Render a player car's steering frames from a 3D model (CP-1), in Blender without its window.

    blender -b --factory-startup -P tools/blender/render_car.py -- \
        --model assets/models/vega.glb --out build/car_renders/vega [--forward=-y] [--size=720]

Writes <out>/<pitch>_<frame>.png: pitch is level, up (nose up, uphill) or down (nose down,
downhill), frame 0 hard left .. 3 straight .. 6 hard right, like the concept steering sheets.
Each is a full-size render on a transparent background; tools/make_car_renders.py shrinks
them into the game's strips. The model is any .glb, .gltf, .fbx or .obj; it is turned so its
nose points along +Y (--forward names the axis the nose points along as it comes in, after
Blender's import), scaled to CAR_LENGTH, centred and stood on the ground.

The camera sits behind the car, a little above it, looking slightly down, like the race camera
on level road. Steering turns the car, not the camera: hard left shows the left flank.
"""
import argparse
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

CAR_LENGTH = 4.4  # metres, nose to tail, after import
# Turn of the car at each steering frame, degrees, + is left (counter-clockwise from above).
# Frame 0 is hard left; these match the turn the concept steering sheets show.
STEER_YAW = [20, 13, 6, 0, -6, -13, -20]
# Nose-up (uphill) and nose-down (downhill) tilt, degrees; the game swaps to these strips past
# CarSprites.PITCH_SWITCH.
PITCH = {"level": 0.0, "up": 9.0, "down": -9.0}
# Camera: behind the car and above it, looking down at CAMERA_TILT, at a long lens so the
# perspective stays mild (the race draws the car flat, at one scale).
CAMERA_DISTANCE = 13.0
CAMERA_TILT = 6.0  # degrees below level
CAMERA_LENS = 135.0  # mm
# The sun (docs/03-art-direction.md: upper left)
SUN_ROTATION = (-50.0, 0.0, 30.0)  # degrees: the sun ahead of the car and to its left, low, as in the hero art (it drives into the sunset), so the tail is in shade with lit edges
SUN_ENERGY = 5.0
RIM_ENERGY = 2.0
# Lamps glow: base-color texels that are orange to amber (green between these shares of the
# red, red at least GLOW_MIN_RED, blue under GLOW_MAX_BLUE of the red) emit at GLOW_STRENGTH.
# The body red has almost no green, and warm chrome has too much blue, so both stay out. An
# AI-made model's lamps are only painted on, and the concept art lights them.
GLOW_GREEN = (0.05, 0.9)
GLOW_MIN_RED = 0.3
GLOW_MAX_BLUE = 0.2
GLOW_STRENGTH = 3.0
# Cel style (--style=cel): the light on a face, 0 dark .. about 1.5 full sun, picks one of
# these flat shares of its color; a highlight band adds CEL_SHINE's white where the gloss is
# brightest.
CEL_BANDS = [(0.0, 0.4), (0.6, 0.7), (1.2, 0.95)]
CEL_SHINE = [(0.0, 0.0), (1.2, 0.4)]
CEL_GLOSS_ROUGHNESS = 0.2
# Sky light: low, so the faces away from the sun go dark like the concept art's lower panels
AMBIENT = 0.25


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--forward", default="y", help="axis the nose points along after import: x, -x, y, -y")
    ap.add_argument("--size", type=int, default=720, help="render width in pixels")
    ap.add_argument("--engine", default="BLENDER_EEVEE", help="or CYCLES")
    ap.add_argument("--style", default="shaded", choices=["shaded", "cel"],
                    help="shaded: the model's own materials; cel: flat bands (cel_shade)")
    return ap.parse_args(argv)


def clear_scene():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def import_model(path):
    ext = os.path.splitext(path)[1].lower()
    before = set(bpy.data.objects)
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=path)
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=path)
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=path)
    elif ext == ".blend":
        with bpy.data.libraries.load(path) as (src, dst):
            dst.objects = src.objects
        for ob in dst.objects:
            bpy.context.scene.collection.objects.link(ob)
    else:
        sys.exit("unknown model type: " + path)
    meshes = [ob for ob in set(bpy.data.objects) - before if ob.type == "MESH"]
    if not meshes:
        sys.exit("no meshes in " + path)
    return meshes


def normalize(meshes, forward):
    """Parent everything to one empty, the car's pivot: nose along +Y, CAR_LENGTH long,
    centred on the origin, wheels on z = 0. Returns the pivot."""
    pivot = bpy.data.objects.new("car", None)
    bpy.context.scene.collection.objects.link(pivot)
    roots = {ob for ob in meshes}
    for ob in list(roots):
        top = ob
        while top.parent is not None:
            top = top.parent
        roots.add(top)
    for ob in roots:
        if ob.parent is None:
            ob.parent = pivot
    turn = {"y": 0.0, "-y": 180.0, "x": 90.0, "-x": -90.0}[forward]
    pivot.rotation_euler = Euler((0.0, 0.0, math.radians(turn)))
    bpy.context.view_layer.update()
    lo, hi = bounds(meshes)
    size = hi - lo
    scale = CAR_LENGTH / max(size.y, 1e-6)
    pivot.scale = (scale, scale, scale)
    bpy.context.view_layer.update()
    lo, hi = bounds(meshes)
    centre = (lo + hi) / 2
    pivot.location -= Vector((centre.x, centre.y, lo.z))
    bpy.context.view_layer.update()
    # A pivot at the car's middle, so turning and tilting it keeps the car in place
    lo, hi = bounds(meshes)
    mid_z = (hi.z - lo.z) / 2
    holder = bpy.data.objects.new("pose", None)
    bpy.context.scene.collection.objects.link(holder)
    holder.location = (0.0, 0.0, mid_z)
    pivot.parent = holder
    pivot.location.z -= mid_z
    bpy.context.view_layer.update()
    return holder, hi - lo


def bounds(meshes):
    pts = [ob.matrix_world @ Vector(c) for ob in meshes for c in ob.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    return lo, hi


def math_node(nodes, links, op, a, b=None):
    n = nodes.new("ShaderNodeMath")
    n.operation = op
    for i, v in enumerate((a, b)):
        if v is None:
            continue
        if isinstance(v, float):
            n.inputs[i].default_value = v
        else:
            links.new(v, n.inputs[i])
    return n.outputs[0]


def textured_materials(meshes):
    """(nodes, links, bsdf, base color socket) for each material whose Principled BSDF takes
    its Base Color from a texture, once each."""
    done = set()
    for ob in meshes:
        for slot in ob.material_slots:
            mat = slot.material
            if mat is None or mat.name in done or mat.node_tree is None:
                continue
            done.add(mat.name)
            nodes, links = mat.node_tree.nodes, mat.node_tree.links
            bsdf = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None or not bsdf.inputs["Base Color"].is_linked:
                continue
            yield nodes, links, bsdf, bsdf.inputs["Base Color"].links[0].from_socket


def lamp_mask(nodes, links, color):
    """1 where `color` is a lamp's orange to amber (GLOW_*), else 0."""
    rgb = nodes.new("ShaderNodeSeparateColor")
    links.new(color, rgb.inputs[0])
    r, g, b = rgb.outputs[0], rgb.outputs[1], rgb.outputs[2]
    red = math_node(nodes, links, "MAXIMUM", r, 0.001)
    share = math_node(nodes, links, "DIVIDE", g, red)
    mask = math_node(nodes, links, "MULTIPLY",
                     math_node(nodes, links, "GREATER_THAN", share, GLOW_GREEN[0]),
                     math_node(nodes, links, "LESS_THAN", share, GLOW_GREEN[1]))
    mask = math_node(nodes, links, "MULTIPLY", mask, math_node(nodes, links, "GREATER_THAN", r, GLOW_MIN_RED))
    return math_node(nodes, links, "MULTIPLY", mask,
                     math_node(nodes, links, "LESS_THAN", math_node(nodes, links, "DIVIDE", b, red), GLOW_MAX_BLUE))


def add_lamp_glow(meshes):
    """Every textured material emits where its texture is a lamp's color: the taillights."""
    for nodes, links, bsdf, color in textured_materials(meshes):
        links.new(color, bsdf.inputs["Emission Color"])
        links.new(math_node(nodes, links, "MULTIPLY", lamp_mask(nodes, links, color), GLOW_STRENGTH),
                  bsdf.inputs["Emission Strength"])


def stepped(nodes, links, shader, stops):
    """The light a shader catches, cut into flat bands: stops are (position, value)."""
    to_rgb = nodes.new("ShaderNodeShaderToRGB")
    links.new(shader, to_rgb.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.interpolation = "CONSTANT"
    els = ramp.color_ramp.elements
    while len(els) < len(stops):
        els.new(0.5)
    for el, (pos, v) in zip(els, stops):
        el.position = pos
        el.color = (v, v, v, 1.0)
    links.new(to_rgb.outputs["Color"], ramp.inputs["Fac"])
    return ramp.outputs["Color"]


def mix_node(nodes, links, op, a, b):
    n = nodes.new("ShaderNodeMix")
    n.data_type = "RGBA"
    n.blend_type = op
    n.inputs["Factor"].default_value = 1.0
    for sock, v in ((n.inputs[6], a), (n.inputs[7], b)):
        if isinstance(v, tuple):
            sock.default_value = v
        else:
            links.new(v, sock)
    return n.outputs[2]


def cel_shade(meshes):
    """Flat-banded shading like the concept art's pixel painting: the texture's color times
    the sun's light cut into CEL_BANDS, a hard white highlight where the gloss catches it
    (CEL_SHINE), and the lamps lit. Emitted, so the bands come out exactly as set."""
    for nodes, links, bsdf, color in textured_materials(meshes):
        light = stepped(nodes, links, nodes.new("ShaderNodeBsdfDiffuse").outputs[0], CEL_BANDS)
        gloss = nodes.new("ShaderNodeBsdfGlossy")
        gloss.inputs["Roughness"].default_value = CEL_GLOSS_ROUGHNESS
        shine = stepped(nodes, links, gloss.outputs[0], CEL_SHINE)
        lit = mix_node(nodes, links, "MULTIPLY", color, light)
        lit = mix_node(nodes, links, "ADD", lit, shine)
        glow = mix_node(nodes, links, "MULTIPLY", color, (GLOW_STRENGTH,) * 3 + (1.0,))
        lamp = nodes.new("ShaderNodeMix")
        lamp.data_type = "RGBA"
        links.new(lamp_mask(nodes, links, color), lamp.inputs["Factor"])
        links.new(lit, lamp.inputs[6])
        links.new(glow, lamp.inputs[7])
        emit = nodes.new("ShaderNodeEmission")
        links.new(lamp.outputs[2], emit.inputs["Color"])
        out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        links.new(emit.outputs[0], out.inputs["Surface"])


def setup_camera(size):
    cam_data = bpy.data.cameras.new("camera")
    cam_data.lens = CAMERA_LENS
    cam = bpy.data.objects.new("camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    tilt = math.radians(CAMERA_TILT)
    target = Vector((0.0, 0.0, size.z * 0.45))
    cam.location = target + Vector((0.0, -math.cos(tilt), math.sin(tilt))) * CAMERA_DISTANCE
    cam.rotation_euler = Euler((math.pi / 2 - tilt, 0.0, 0.0))
    bpy.context.scene.camera = cam
    return cam


def setup_lights():
    sun_data = bpy.data.lights.new("sun", "SUN")
    sun_data.energy = SUN_ENERGY
    sun_data.angle = math.radians(8)
    sun = bpy.data.objects.new("sun", sun_data)
    sun.rotation_euler = Euler([math.radians(a) for a in SUN_ROTATION])
    bpy.context.scene.collection.objects.link(sun)
    # A cool rim from behind-right, for the glossy edge the concept art has
    rim_data = bpy.data.lights.new("rim", "SUN")
    rim_data.energy = RIM_ENERGY
    rim_data.color = (0.75, 0.85, 1.0)
    rim = bpy.data.objects.new("rim", rim_data)
    rim.rotation_euler = Euler((math.radians(60), 0.0, math.radians(-150)))
    bpy.context.scene.collection.objects.link(rim)
    world = bpy.data.worlds.new("sky")
    bg = world.node_tree.nodes["Background"]
    bg.inputs["Color"].default_value = (0.55, 0.62, 0.75, 1.0)
    bg.inputs["Strength"].default_value = AMBIENT
    bpy.context.scene.world = world


def setup_render(width, engine):
    scene = bpy.context.scene
    try:
        scene.render.engine = engine
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = 64
    scene.render.resolution_x = width
    scene.render.resolution_y = round(width * 0.75)
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # Standard, not AgX/Filmic: the saturated arcade colors of the concept art
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"


def main():
    a = args()
    clear_scene()
    meshes = import_model(os.path.abspath(a.model))
    holder, size = normalize(meshes, a.forward)
    if a.style == "cel":
        cel_shade(meshes)
    else:
        add_lamp_glow(meshes)
    setup_camera(size)
    setup_lights()
    setup_render(a.size, a.engine)
    os.makedirs(a.out, exist_ok=True)
    for pitch_name, pitch in PITCH.items():
        for i, yaw in enumerate(STEER_YAW):
            holder.rotation_euler = Euler((math.radians(pitch), 0.0, math.radians(yaw)), "ZXY")
            bpy.context.scene.render.filepath = os.path.join(os.path.abspath(a.out), "%s_%d.png" % (pitch_name, i))
            bpy.ops.render.render(write_still=True)
    print("rendered %d frames to %s" % (len(PITCH) * len(STEER_YAW), a.out))


main()
