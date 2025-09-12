#if UNITY_EDITOR && !COMPILER_UDONSHARP
using UnityEngine;

public readonly struct Triangle
{
    public readonly Vector3 PosA;
    public readonly Vector3 PosB;
    public readonly Vector3 PosC;

    public readonly Vector3 NormalA;
    public readonly Vector3 NormalB;
    public readonly Vector3 NormalC;

    public readonly Vector2 UvA;
    public readonly Vector2 UvB;
    public readonly Vector2 UvC;

    public readonly int ObjectId;

    public Triangle(Vector3 posA, Vector3 posB, Vector3 posC, Vector3 normalA, Vector3 normalB, Vector3 normalC, Vector2 uvA, Vector2 uvB, Vector2 uvC, int ObjectId)
    {
        this.PosA = posA;
        this.PosB = posB;
        this.PosC = posC;
        this.NormalA = normalA;
        this.NormalB = normalB;
        this.NormalC = normalC;
        this.ObjectId = ObjectId;

        this.UvA = uvA;
        this.UvB = uvB;
        this.UvC = uvC;
    }
}
#endif