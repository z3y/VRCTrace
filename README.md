## VRCTrace

Software GPU Ray Tracing for VRChat

### How to use

Add VRCTraceManager to a gameobject and generate buffers to create a BVH for static objects in the scene

### Example Shader

```c

#include "Packages/com.z3y.vrctrace/Runtime/Shaders/VRCTrace.hlsl"

...

Ray ray;
ray.D = N;
ray.P = RayOffset(P, N);

Intersection intersection;
if (SceneIntersects(ray, intersection))
{
    float3 hitP, hitN;
    TrianglePointNormal(intersection, hitP, hitN);
}
```

Adapted from Sebastian Lague's ray tracing tutorials
