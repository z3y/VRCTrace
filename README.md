## VRCTrace

Software GPU Ray Tracing for VRChat using CWBVH (https://github.com/jbikker/tinybvh)

[See it in VRChat](https://vrchat.com/home/world/wrld_f7fa38b7-947a-4e34-a3e1-e082a4eb5b39/info)

### How to use

Add VRCTraceManager to a gameobject and press Generate Buffers to create a BVH for static objects in the scene.


### Example Shader

```c

#include "Packages/com.z3y.vrctrace/Runtime/Shaders/VRCTrace.hlsl"

...


Ray ray;
ray.D = rayDirection;
ray.P = RayOffset(positionWS, normalWS);
ray.tMin = 0;
ray.tMax = 10000;

Intersection intersection;
if (SceneIntersects(ray, intersection))
{
    float3 hitP, hitN;
    TrianglePointNormal(intersection, hitP, hitN);
}
```

### Raytraced Reflections

- Requires one baked lightmap referenced on the VRCTraceManager and a skybox cubemap for miss
- Press Generate Combined Atlas
- This will create a new combined texture using the meta pass (lightmap * albedo + emission)
- Shaders can then sample this atlas using hit UVs for the reflection

<img width="3840" height="2160" alt="VRChat_2025-10-06_19-43-12 543_3840x2160" src="https://github.com/user-attachments/assets/368e7015-e281-4b57-a486-475b07a4b36a" />
