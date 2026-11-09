"""Render a car's car select picture: one three-quarter view from behind, on a stretch of
coastal road, with the race strips' paint and lights (render_car.py, car_looks.py).

    blender -b --factory-startup -P tools/blender/render_car_hero.py -- \
        --model assets/models/vega.glb --car vega --out build/car_heroes/vega.png

Every car gets the same camera, sun and road, so the twelve pictures compare side by side and
each shows the car the player then drives. The sky is left transparent:
tools/make_car_heroes.py puts the title screen's coast behind it and cuts it to size.
"""

import argparse
import math
import os
import sys

import bpy
from bpy_extras.object_utils import world_to_camera_view
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import render_car as rc  # noqa: E402
from car_looks import look  # noqa: E402

# Output: 4x the picture (CAR_SIZE in tools/make_ui_sprites.py, 304 x 141)
WIDTH, HEIGHT = 1216, 564
# The camera: behind the car and off to its left, low, as a photographer crouched at the kerb.
# Azimuth is degrees round from straight behind (+ shows the left flank), elevation above level.
CAMERA_AZIMUTH = 32.0
CAMERA_ELEVATION = 5.0
CAMERA_DISTANCE = 8.8
CAMERA_LENS = 40.0  # mm
# Framing, whatever the car's shape: its bounds fill at most this share of the picture's width
# and height, centred here (0 left/top .. 1 right/bottom). A van and a trike come out the same
# size on screen, where one length of camera distance would make the van loom.
FILL = (0.6, 0.55)
MAX_FILL = (0.78, 0.74)
CENTRE = (0.54, 0.6)
# The road: lanes either side of a dashed line, red and white kerbs, as on Palm Coast
ROAD_HALF_WIDTH = 7.0  # metres
KERB_WIDTH = 0.9
KERB_STRIPE = 1.6
DASH_LENGTH, DASH_GAP, DASH_WIDTH = 3.0, 4.0, 0.16
ROAD_LENGTH = 3000.0
# Sand either side of the kerbs; past it the coast behind shows through
VERGE = 9.0
SAND = (0.8, 0.6, 0.38)
ASPHALT = (0.055, 0.05, 0.058)
LINE = (0.85, 0.83, 0.78)
KERB_RED = (0.65, 0.06, 0.05)
KERB_WHITE = (0.85, 0.83, 0.8)
# Where the car sits across the road: the right-hand lane, metres from the centre line
LANE_X = 2.2


def args():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True, help="the PNG to write")
    ap.add_argument("--car", default="")
    ap.add_argument("--azimuth", type=float, default=CAMERA_AZIMUTH)
    ap.add_argument("--elevation", type=float, default=CAMERA_ELEVATION)
    ap.add_argument("--samples", type=int, default=96)
    return ap.parse_args(argv)


def road_material():
    mat = bpy.data.materials.new("road")
    mat.use_nodes = True
    nodes, links = mat.node_tree.nodes, mat.node_tree.links
    bsdf = nodes["Principled BSDF"]
    bsdf.inputs["Roughness"].default_value = 0.85
    coord = nodes.new("ShaderNodeTexCoord")
    xyz = nodes.new("ShaderNodeSeparateXYZ")
    links.new(coord.outputs["Object"], xyz.inputs[0])
    m = lambda op, a, b=None: rc.math_node(nodes, links, op, a, b)  # noqa: E731
    ax = m("ABSOLUTE", xyz.outputs["X"])
    y = xyz.outputs["Y"]
    # Asphalt with a little grain
    noise = nodes.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 40.0
    links.new(coord.outputs["Object"], noise.inputs["Vector"])
    grain = m("ADD", m("MULTIPLY", noise.outputs["Fac"], 0.5), 0.75)
    asphalt = nodes.new("ShaderNodeMix")
    asphalt.data_type = "RGBA"
    asphalt.blend_type = "MULTIPLY"
    asphalt.inputs["Factor"].default_value = 1.0
    asphalt.inputs[6].default_value = ASPHALT + (1.0,)
    links.new(grain, asphalt.inputs[7])
    color = asphalt.outputs[2]
    # Dashed centre line
    dash = m("MULTIPLY", m("LESS_THAN", ax, DASH_WIDTH / 2),
             m("LESS_THAN", m("FLOORED_MODULO", y, DASH_LENGTH + DASH_GAP), DASH_LENGTH))
    color = mix(nodes, links, dash, color, LINE)
    # Edge lines, then the kerbs past them
    edge = m("MULTIPLY", m("GREATER_THAN", ax, ROAD_HALF_WIDTH - 0.35), m("LESS_THAN", ax, ROAD_HALF_WIDTH - 0.2))
    color = mix(nodes, links, edge, color, LINE)
    kerb = m("GREATER_THAN", ax, ROAD_HALF_WIDTH)
    red = m("LESS_THAN", m("FLOORED_MODULO", y, KERB_STRIPE * 2), KERB_STRIPE)
    kerb_color = mix(nodes, links, red, KERB_WHITE, KERB_RED)
    mixer = nodes.new("ShaderNodeMix")
    mixer.data_type = "RGBA"
    links.new(kerb, mixer.inputs["Factor"])
    links.new(color, mixer.inputs[6])
    links.new(kerb_color, mixer.inputs[7])
    links.new(mixer.outputs[2], bsdf.inputs["Base Color"])
    return mat


def mix(nodes, links, fac, a, b):
    """a where fac is 0, b where it is 1; a and b are sockets or RGB tuples."""
    node = nodes.new("ShaderNodeMix")
    node.data_type = "RGBA"
    links.new(fac, node.inputs["Factor"])
    for socket, value in ((node.inputs[6], a), (node.inputs[7], b)):
        if isinstance(value, tuple):
            socket.default_value = value + (1.0,)
        else:
            links.new(value, socket)
    return node.outputs[2]


def add_road():
    w = ROAD_HALF_WIDTH + KERB_WIDTH
    mesh = bpy.data.meshes.new("road")
    mesh.from_pydata([(-w, -40.0, 0.0), (w, -40.0, 0.0), (w, ROAD_LENGTH, 0.0), (-w, ROAD_LENGTH, 0.0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new("road", mesh)
    ob.location.x = -LANE_X
    ob.data.materials.append(road_material())
    bpy.context.scene.collection.objects.link(ob)
    sand = bpy.data.materials.new("sand")
    sand.use_nodes = True
    sand.node_tree.nodes["Principled BSDF"].inputs["Base Color"].default_value = SAND + (1.0,)
    sand.node_tree.nodes["Principled BSDF"].inputs["Roughness"].default_value = 1.0
    for side in (-1.0, 1.0):
        x0, x1 = sorted((side * w, side * (w + VERGE)))
        m = bpy.data.meshes.new("sand")
        m.from_pydata([(x0, -40.0, -0.01), (x1, -40.0, -0.01), (x1, ROAD_LENGTH, -0.01), (x0, ROAD_LENGTH, -0.01)], [], [(0, 1, 2, 3)])
        verge = bpy.data.objects.new("sand", m)
        verge.location.x = -LANE_X
        verge.data.materials.append(sand)
        bpy.context.scene.collection.objects.link(verge)


def warm_light():
    """The race strips' lights with a touch of late afternoon: any warmer and a cream van goes yellow."""
    sun = bpy.data.objects["sun"]
    sun.data.color = (1.0, 0.94, 0.86)
    sun.data.energy *= 1.1


def horizon_row(cam):
    """The row (0 top .. 1 bottom) of the horizon in the picture: a point far ahead at eye level."""
    scene = bpy.context.scene
    ahead = cam.matrix_world.to_3x3() @ Vector((0.0, 0.0, -1.0))
    ahead.z = 0.0
    far = cam.location + ahead.normalized() * 1e5
    far.z = cam.location.z
    return 1.0 - world_to_camera_view(scene, cam, far).y


def setup_camera(size, azimuth, elevation):
    cam_data = bpy.data.cameras.new("camera")
    cam_data.lens = CAMERA_LENS
    cam_data.sensor_fit = "HORIZONTAL"
    cam = bpy.data.objects.new("camera", cam_data)
    bpy.context.scene.collection.objects.link(cam)
    az, el = math.radians(azimuth), math.radians(elevation)
    target = Vector((0.0, 0.0, size.z * 0.4))
    # Behind is -Y; + azimuth swings the camera to the car's left (-X)
    offset = Vector((-math.sin(az) * math.cos(el), -math.cos(az) * math.cos(el), math.sin(el)))
    cam.location = target + offset * CAMERA_DISTANCE
    direction = target - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    bpy.context.scene.camera = cam
    return cam, target, offset


def frame(cam, target, offset, meshes):
    """Move the camera along its line to the car, and shift the lens, to fit FILL at CENTRE."""
    scene = bpy.context.scene
    bpy.context.view_layer.update()
    # The mesh itself, not its box: a tall car's box takes in air its corners never fill
    corners = [ob.matrix_world @ v.co for ob in meshes for i, v in enumerate(ob.data.vertices) if i % 40 == 0]
    distance = CAMERA_DISTANCE
    aspect = scene.render.resolution_y / scene.render.resolution_x
    for _ in range(6):
        cam.location = target + offset * distance
        bpy.context.view_layer.update()
        pts = [world_to_camera_view(scene, cam, c) for c in corners]
        # The body, not its outermost points: a whip aerial or a flag mustn't shrink the car
        xs, ys = sorted(p.x for p in pts), sorted(1.0 - p.y for p in pts)
        cut = len(pts) // 200
        xs, ys = xs[cut:len(xs) - cut], ys[cut:len(ys) - cut]
        w, h = xs[-1] - xs[0], ys[-1] - ys[0]
        # By area, so a long low car and a tall truck look as big as each other, but inside MAX_FILL
        distance *= max(math.sqrt(w * h / (FILL[0] * FILL[1])), w / MAX_FILL[0], h / MAX_FILL[1])
        cx, cy = (xs[-1] + xs[0]) / 2, (ys[-1] + ys[0]) / 2
        cam.data.shift_x += cx - CENTRE[0]
        cam.data.shift_y -= (cy - CENTRE[1]) * aspect
    print("framed: %.2f wide, %.2f tall, %.1f m away" % (w, h, distance))


def main():
    a = args()
    car = look(a.car)
    rc.clear_scene()
    meshes = rc.import_model(os.path.abspath(a.model))
    holder, size = rc.normalize(meshes, car["forward"])
    rc.polish_paint(meshes, car)
    rc.add_lamp_glow(meshes, car)
    if car["raise_part"]:
        rc.raise_part(meshes, size, car["raise_part"])
    if car["remove_part"]:
        rc.remove_part(meshes, size, car["remove_part"])
    if car["cabin_wall"]:
        rc.add_cabin_wall(holder, size, car["cabin_wall"])
    add_road()
    cam, target, offset = setup_camera(size, a.azimuth, a.elevation)
    rc.setup_lights()
    warm_light()
    rc.setup_render(WIDTH, "CYCLES", car["exposure"])
    scene = bpy.context.scene
    scene.render.resolution_y = HEIGHT
    frame(cam, target, offset, meshes)
    scene.cycles.samples = a.samples
    scene.render.filepath = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(scene.render.filepath), exist_ok=True)
    bpy.ops.render.render(write_still=True)
    with open(os.path.splitext(scene.render.filepath)[0] + ".horizon", "w") as f:
        f.write("%.4f\n" % horizon_row(cam))
    print("rendered to %s" % a.out)


main()
