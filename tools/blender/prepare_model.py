"""Shrink a downloaded car model for the repository (CP-1): an image-to-3D tool's model has
millions of triangles, far more than a 180-pixel sprite can show.

    blender -b --factory-startup -P tools/blender/prepare_model.py -- \
        --model ~/Downloads/car.glb --out assets/models/vega.glb [--faces=250000]

Simplifies every mesh (Decimate, collapse) down to about --faces triangles in all, and writes a
.glb with its textures as JPEG: about 11 MB for the Vega, from 59. Much lower and the render
breaks up: at 150,000 the Vega's strips came out speckled with texels from the wrong part of
its patchwork texture, at 250,000 they match the full model's.
"""
import argparse
import os
import sys

import bpy


def main():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--out", required=True)
    ap.add_argument("--faces", type=int, default=250000)
    a = ap.parse_args(argv)
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.abspath(os.path.expanduser(a.model)))
    meshes = [ob for ob in bpy.data.objects if ob.type == "MESH"]
    before = sum(len(ob.data.polygons) for ob in meshes)
    ratio = min(1.0, a.faces / max(before, 1))
    for ob in meshes:
        bpy.context.view_layer.objects.active = ob
        mod = ob.modifiers.new("decimate", "DECIMATE")
        mod.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=mod.name)
        # The model's stored normals don't fit the simplified mesh: drop them and shade by angle.
        if ob.data.has_custom_normals:
            bpy.ops.mesh.customdata_custom_splitnormals_clear()
        bpy.ops.object.shade_auto_smooth(angle=0.6)
    after = sum(len(ob.data.polygons) for ob in meshes)
    out = os.path.abspath(a.out)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=out, export_format="GLB", export_image_format="JPEG")
    print("faces %d -> %d, wrote %s (%.1f MB)" % (before, after, a.out, os.path.getsize(out) / 1e6))


main()
