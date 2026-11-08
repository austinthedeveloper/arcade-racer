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

import bmesh
import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from car_looks import in_part, look, part_lift  # noqa: E402

CAR_LENGTH = 4.4  # metres, nose to tail, after import
# Turn of the car at each steering frame, degrees, + is left (counter-clockwise from above).
# Frame 0 is hard left; these match the turn the concept steering sheets show.
STEER_YAW = [20, 13, 6, 0, -6, -13, -20]
# Nose-up (uphill) and nose-down (downhill) tilt, degrees; the game swaps to these strips past
# CarSprites.PITCH_SWITCH.
PITCH = {"level": 0.0, "up": 9.0, "down": -9.0}
# Camera: behind the car and above it, looking down at the car's tilt (car_looks.py). The race
# camera sees the road under the car from atan(camera/height / Cfg.PLAYER_Z) = 34 degrees; a car
# drawn from much lower than that doesn't sit on the road, it floats. Too steep and the bumper
# hides the tires, and it floats anyway.
CAMERA_DISTANCE = 10.0
CAMERA_LENS = 85.0  # mm
# The sun (docs/03-art-direction.md: upper left): behind the camera, so it lights the tail and
# the deck, the parts the player sees. Ahead of the car it leaves all of those in shade.
SUN_ROTATION = (65.0, 0.0, -25.0)  # degrees
SUN_ENERGY = 3.8
RIM_ENERGY = 1.5
# From the camera's right, the side away from the sun, or a hard turn right shows a flank in shade
FILL_ROTATION = (70.0, 0.0, 40.0)  # degrees
FILL_ENERGY = 1.3
# What the paint and glass reflect: a postcard sky, height (-1 straight down .. 1 straight up)
# to color. A flat world leaves gloss with nothing to show, and the car looks matte.
SKY = [(-1.0, (0.3, 0.3, 0.32)), (-0.02, (0.4, 0.38, 0.38)), (0.0, (1.0, 0.72, 0.45)),
       (0.12, (0.55, 0.8, 1.0)), (1.0, (0.16, 0.42, 1.0))]
SKY_STRENGTH = 0.5
# The paint, whatever the model's texture says; how rich is per car (car_looks.py).
PAINT_VALUE = 1.0
PAINT_ROUGHNESS = 0.8  # times the model's roughness
# Times the model's metallic. An AI-made model is about 0.7 metallic all over, stripes too: a
# white stripe then shows the sky, not white, and the paint shows every lump in the mesh.
PAINT_METALLIC = 0.25
PAINT_COAT = 0.3  # clear coat over it
PAINT_COAT_ROUGHNESS = 0.25
# Lamps glow: base-color texels that are orange to amber (green between the car's glow_green
# shares of the red, tools/blender/car_looks.py; red at least GLOW_MIN_RED, blue under
# GLOW_MAX_BLUE of the red) emit at GLOW_STRENGTH. Warm chrome has too much blue, so it stays
# out. An AI-made model's lamps are only painted on, and the concept art lights them.
GLOW_MIN_RED = 0.15
GLOW_STRENGTH = 5.5
# Cel style (--style=cel): the light on a face, 0 dark .. about 1.5 full sun, picks one of
# these flat shares of its color; a highlight band adds CEL_SHINE's white where the gloss is
# brightest.
CEL_BANDS = [(0.0, 0.4), (0.6, 0.7), (1.2, 0.95)]
CEL_SHINE = [(0.0, 0.0), (1.2, 0.4)]
CEL_GLOSS_ROUGHNESS = 0.2


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--car", default="", help="the car's strip name, for its settings in car_looks.py")
    ap.add_argument("--forward", default="", help="axis the nose points along after import: x, -x, y, -y (default: the car's)")
    ap.add_argument("--only", default="", help="render just these frames, comma-separated: level_3,up_0")
    ap.add_argument("--size", type=int, default=720, help="render width in pixels")
    ap.add_argument("--engine", default="CYCLES", help="or BLENDER_EEVEE, quicker with duller gloss")
    ap.add_argument("--tilt", type=float, default=None, help="camera degrees below level (default: the car's)")
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


def lamp_mask(nodes, links, color, car):
    """1 where `color` is a lamp's color (the car's glow_green and glow_blue, GLOW_*), else 0."""
    glow_green = car["glow_green"]
    rgb = nodes.new("ShaderNodeSeparateColor")
    links.new(color, rgb.inputs[0])
    r, g, b = rgb.outputs[0], rgb.outputs[1], rgb.outputs[2]
    red = math_node(nodes, links, "MAXIMUM", r, 0.001)
    share = math_node(nodes, links, "DIVIDE", g, red)
    mask = math_node(nodes, links, "MULTIPLY",
                     math_node(nodes, links, "GREATER_THAN", share, glow_green[0]),
                     math_node(nodes, links, "LESS_THAN", share, glow_green[1]))
    mask = math_node(nodes, links, "MULTIPLY", mask, math_node(nodes, links, "GREATER_THAN", r, GLOW_MIN_RED))
    return math_node(nodes, links, "MULTIPLY", mask,
                     math_node(nodes, links, "LESS_THAN", math_node(nodes, links, "DIVIDE", b, red), car["glow_blue"]))


def neutral_mask(nodes, links, color, neutral):
    """1 for chrome and white texels, under the car's `neutral` saturation, fading to 0 for
    paint at its second number; and the texel's value as a socket: (mask, value)."""
    hsv = nodes.new("ShaderNodeSeparateColor")
    hsv.mode = "HSV"
    links.new(color, hsv.inputs[0])
    fade = nodes.new("ShaderNodeMapRange")
    links.new(hsv.outputs[1], fade.inputs["Value"])
    fade.inputs["From Min"].default_value = neutral[0]
    fade.inputs["From Max"].default_value = neutral[1]
    fade.inputs["To Min"].default_value = 1.0
    fade.inputs["To Max"].default_value = 0.0
    return fade.outputs[0], hsv.outputs[2]


def polish_paint(meshes, car):
    """Every textured material richer in color and glossier, under a clear coat, by the car's
    hue, saturation, gamma and neutral (car_looks.py)."""
    for nodes, links, bsdf, color in textured_materials(meshes):
        hsv = nodes.new("ShaderNodeHueSaturation")
        hsv.inputs["Hue"].default_value = 0.5 + car["hue"]
        hsv.inputs["Saturation"].default_value = car["saturation"]
        hsv.inputs["Value"].default_value = PAINT_VALUE
        links.new(color, hsv.inputs["Color"])
        deep = nodes.new("ShaderNodeGamma")
        deep.inputs["Gamma"].default_value = car["gamma"]
        links.new(hsv.outputs[0], deep.inputs["Color"])
        neutral, value = neutral_mask(nodes, links, color, car["neutral"])
        grey = nodes.new("ShaderNodeCombineColor")
        for i in range(3):
            links.new(value, grey.inputs[i])
        base = nodes.new("ShaderNodeMix")
        base.data_type = "RGBA"
        links.new(neutral, base.inputs["Factor"])
        links.new(deep.outputs[0], base.inputs[6])
        links.new(grey.outputs[0], base.inputs[7])
        links.new(base.outputs[2], bsdf.inputs["Base Color"])
        rough = bsdf.inputs["Roughness"]
        if rough.is_linked:
            links.new(math_node(nodes, links, "MULTIPLY", rough.links[0].from_socket, PAINT_ROUGHNESS), rough)
        else:
            rough.default_value *= PAINT_ROUGHNESS
        metal = bsdf.inputs["Metallic"]
        if metal.is_linked:
            links.new(math_node(nodes, links, "MULTIPLY", metal.links[0].from_socket, PAINT_METALLIC), metal)
        else:
            metal.default_value *= PAINT_METALLIC
        bsdf.inputs["Coat Weight"].default_value = PAINT_COAT


def red_as(nodes, links, color, tint):
    """A lamp color from `color`'s red alone, in `tint`'s hue: at GLOW_STRENGTH a red texel's
    small green and blue clip up with the red, and the lamp comes out pink."""
    rgb = nodes.new("ShaderNodeSeparateColor")
    links.new(color, rgb.inputs[0])
    grey = nodes.new("ShaderNodeCombineColor")
    for i in range(3):
        links.new(rgb.outputs[0], grey.inputs[i])
    return mix_node(nodes, links, "MULTIPLY", grey.outputs[0], tuple(tint) + (1.0,))


def add_lamp_glow(meshes, car):
    """Every textured material emits where its texture is a lamp's color: the taillights, in the
    car's glow_color (car_looks.py), or the texel's own for None. A lit lamp's base goes black,
    so the sky on the paint doesn't mix into the glow."""
    glow_color = car["glow_color"]
    for nodes, links, bsdf, color in textured_materials(meshes):
        mask = lamp_mask(nodes, links, color, car)
        links.new(red_as(nodes, links, color, glow_color) if glow_color else color, bsdf.inputs["Emission Color"])
        links.new(math_node(nodes, links, "MULTIPLY", mask, GLOW_STRENGTH), bsdf.inputs["Emission Strength"])
        lit = nodes.new("ShaderNodeMix")
        lit.data_type = "RGBA"
        links.new(mask, lit.inputs["Factor"])
        links.new(color, lit.inputs[6])
        lit.inputs[7].default_value = (0.0, 0.0, 0.0, 1.0)
        links.new(lit.outputs[2], bsdf.inputs["Base Color"])
        # Lit lamps catch no glints: on a lumpy mesh those are white streaks across the glow
        unlit = math_node(nodes, links, "SUBTRACT", 1.0, mask)
        links.new(math_node(nodes, links, "MULTIPLY", unlit, bsdf.inputs["Coat Weight"].default_value), bsdf.inputs["Coat Weight"])
        links.new(math_node(nodes, links, "MULTIPLY", unlit, bsdf.inputs["Specular IOR Level"].default_value), bsdf.inputs["Specular IOR Level"])


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


def cel_shade(meshes, car):
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
        links.new(lamp_mask(nodes, links, color, car), lamp.inputs["Factor"])
        links.new(lit, lamp.inputs[6])
        links.new(glow, lamp.inputs[7])
        emit = nodes.new("ShaderNodeEmission")
        links.new(lamp.outputs[2], emit.inputs["Color"])
        out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
        links.new(emit.outputs[0], out.inputs["Surface"])


def raise_part(meshes, size, part):
    """The car's raise_part lifted (car_looks.part_lift), on a car still facing +Y at rest."""
    for ob in meshes:
        to_world, to_local = ob.matrix_world, ob.matrix_world.inverted()
        for v in ob.data.vertices:
            p = to_world @ v.co
            by = part_lift(p.x / size.x, p.y / size.y, p.z / size.z, part)
            if by:
                v.co = to_local @ (p + Vector((0.0, 0.0, by * size.z)))
        ob.data.update()


def remove_part(meshes, size, part):
    """The car's remove_part cut out of the model (car_looks.in_part), on a car still at rest."""
    for ob in meshes:
        to_world = ob.matrix_world
        mesh = bmesh.new()
        mesh.from_mesh(ob.data)
        doomed = [v for v in mesh.verts if in_part(*(c / s for c, s in zip(to_world @ v.co, size)), part)]
        bmesh.ops.delete(mesh, geom=doomed, context="VERTS")
        mesh.to_mesh(ob.data)
        mesh.free()
        ob.data.update()


def add_cabin_wall(holder, size, wall):
    """An invisible wall across the cabin that cuts everything ahead of it out of the render,
    so tools/make_car_renders.py fills that with glass: seats stay, and the dash and engine
    seen through a model's glassless windows go. wall: (y, half width, z0, z1), shares of
    the car's size; y from its middle toward the nose (car_looks.py)."""
    y, half, z0, z1 = wall
    x = half * size.x
    y *= size.y
    lo, hi = (z0 - 0.5) * size.z, (z1 - 0.5) * size.z
    mesh = bpy.data.meshes.new("cabin_wall")
    mesh.from_pydata([(-x, y, lo), (x, y, lo), (x, y, hi), (-x, y, hi)], [], [(0, 1, 2, 3)])
    mat = bpy.data.materials.new("cabin_wall")
    mat.use_nodes = True
    nodes = mat.node_tree.nodes
    nodes.clear()
    mat.node_tree.links.new(nodes.new("ShaderNodeHoldout").outputs[0], nodes.new("ShaderNodeOutputMaterial").inputs["Surface"])
    mesh.materials.append(mat)
    ob = bpy.data.objects.new("cabin_wall", mesh)
    bpy.context.scene.collection.objects.link(ob)
    ob.parent = holder


def setup_camera(size, tilt_degrees):
    cam_data = bpy.data.cameras.new("camera")
    cam_data.lens = CAMERA_LENS
    cam = bpy.data.objects.new("camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    tilt = math.radians(tilt_degrees)
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
    fill_data = bpy.data.lights.new("fill", "SUN")
    fill_data.energy = FILL_ENERGY
    fill = bpy.data.objects.new("fill", fill_data)
    fill.rotation_euler = Euler([math.radians(a) for a in FILL_ROTATION])
    bpy.context.scene.collection.objects.link(fill)
    world = bpy.data.worlds.new("sky")
    world.use_nodes = True
    nodes, links = world.node_tree.nodes, world.node_tree.links
    bg = nodes["Background"]
    bg.inputs["Strength"].default_value = SKY_STRENGTH
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Generated"], xyz.inputs[0])
    ramp = nodes.new("ShaderNodeValToRGB")
    els = ramp.color_ramp.elements
    while len(els) < len(SKY):
        els.new(0.5)
    for el, (height, color) in zip(els, SKY):
        el.position = (height + 1.0) / 2.0
        el.color = color + (1.0,)
    links.new(math_node(nodes, links, "MULTIPLY", math_node(nodes, links, "ADD", xyz.outputs["Z"], 1.0), 0.5), ramp.inputs["Fac"])
    links.new(ramp.outputs["Color"], bg.inputs["Color"])
    bpy.context.scene.world = world


def setup_render(width, engine, exposure):
    scene = bpy.context.scene
    try:
        scene.render.engine = engine
    except TypeError:
        scene.render.engine = "BLENDER_EEVEE"
    if scene.render.engine == "CYCLES":
        scene.cycles.samples = 64
        scene.cycles.use_denoising = True
    scene.render.resolution_x = width
    scene.render.resolution_y = width  # square: a steep camera and a full turn both need the room
    scene.render.film_transparent = True
    scene.render.image_settings.file_format = "PNG"
    scene.render.image_settings.color_mode = "RGBA"
    # Standard, not AgX/Filmic: the saturated arcade colors of the concept art
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "None"
    scene.view_settings.exposure = exposure


def main():
    a = args()
    car = look(a.car)
    only = set(filter(None, a.only.split(",")))
    clear_scene()
    meshes = import_model(os.path.abspath(a.model))
    holder, size = normalize(meshes, a.forward or car["forward"])
    if a.style == "cel":
        cel_shade(meshes, car)
    else:
        polish_paint(meshes, car)
        add_lamp_glow(meshes, car)
    if car["raise_part"]:
        raise_part(meshes, size, car["raise_part"])
    if car["remove_part"]:
        remove_part(meshes, size, car["remove_part"])
    if car["cabin_wall"]:
        add_cabin_wall(holder, size, car["cabin_wall"])
    setup_camera(size, a.tilt if a.tilt is not None else car["tilt"])
    setup_lights()
    setup_render(a.size, a.engine, car["exposure"])
    os.makedirs(a.out, exist_ok=True)
    for pitch_name, pitch in PITCH.items():
        for i, yaw in enumerate(STEER_YAW):
            if only and "%s_%d" % (pitch_name, i) not in only:
                continue
            holder.rotation_euler = Euler((math.radians(pitch), 0.0, math.radians(yaw)), "ZXY")
            bpy.context.scene.render.filepath = os.path.join(os.path.abspath(a.out), "%s_%d.png" % (pitch_name, i))
            bpy.ops.render.render(write_still=True)
    print("rendered to %s" % a.out)


main()
