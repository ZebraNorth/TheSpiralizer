using UnityEditor;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;

/**
 * Custom user interface for "The Spiralizer" shader by Zebra North.
 */
public class TheSpiralizer : ShaderGUI
{
    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        var blendMode = FindProperty("_BlendMode", properties).floatValue;
        var textureEnabled = FindProperty("_TextureEnabled", properties).floatValue;
        var noiseEnabled = FindProperty("_NoiseEnabled", properties).floatValue;
        var vignetteEnabled = FindProperty("_VignetteEnabled", properties).floatValue;

        foreach (MaterialProperty property in properties)
        {
            if (property.flags == MaterialProperty.PropFlags.HideInInspector)
            {
                continue;
            }

            if (property.name == "_MainTex" && textureEnabled == 0)
            {
                continue;
            }

            if (property.name == "imageOpacity" && textureEnabled == 0)
            {
                continue;
            }

            if (property.name == "noiseOpacity" && noiseEnabled == 0)
            {
                continue;
            }

            if (property.name == "noiseScale" && noiseEnabled == 0)
            {
                continue;
            }

            if (property.name == "vignetteOpacity" && vignetteEnabled == 0)
            {
                continue;
            }

            if (property.name == "vignetteColour" && (vignetteEnabled == 0 || blendMode != 0))
            {
                continue;
            }

            if (property.name == "spiralOpacity" && blendMode == 0)
            {
                continue;
            }

            materialEditor.ShaderProperty(property, property.displayName);
        }

        // Show the render queue.
        MaterialProperty[] empty = new MaterialProperty[0];
        base.OnGUI(materialEditor, empty);
    }

    public override void ValidateMaterial(Material material)
    {
        if (material.GetInt("_BlendMode") == 0)
        {
            // Opaque.
            material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.Zero);
            material.SetInt("_ZWrite", 1);
            material.renderQueue = -1;
        }
        else if (material.GetInt("_BlendMode") == 1)
        {
            // Transparent.
            material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            material.SetInt("_ZWrite", 0);
            material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
        }
        else if (material.GetInt("_BlendMode") == 2)
        {
            // Additive.
            material.SetInt("_BlendSrc", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
            material.SetInt("_BlendDst", (int)UnityEngine.Rendering.BlendMode.One);
            material.SetInt("_ZWrite", 0);
            material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
        }

    }
}
