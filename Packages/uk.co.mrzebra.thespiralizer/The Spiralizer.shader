Shader "Zebra North/The Spiralizer"
{

    Properties
    {
        // The blending mode.
        [KeywordEnum(Opaque, Transparent, Additive)] _BlendMode ("Blend Mode", Float) = 0

        // Hidden variables set by changing the blending mode.
        [HideInInspector] _ZWrite("", Float) = 1
        [HideInInspector] _BlendSrc("", Float) = 1
        [HideInInspector] _BlendDst("", Float) = 1
        [HideInInspector] _RenderQueue("", Float) = 123

        // Read from the Z-Buffer.
        [Enum(Normal, 4, Always On Top, 8)] _ZTest("Depth Test", Float) = 4

        // The overlay texture.
        [Space] [Toggle(TEXTURE_ENABLED)] _TextureEnabled("Enable Texture", Float) = 0
        [NoScaleOffset] _MainTex ("Image Texture", 2D) = "white" {}
        imageScale("Image Scale", Range(0, 1)) = 1
        imageLeft("Image Crop Left", Range(0, 1)) = 0
        imageRight("Image Crop Right", Range(0, 1)) = 1
        imageBottom("Image Crop Bottom", Range(0, 1)) = 0
        imageTop("Image Crop Top", Range(0, 1)) = 1
        imageX("Image X", Range(-1, 1)) = 0
        imageY("Image Y", Range(-1, 1)) = 0

        // The opacity of the image.
        imageOpacity("Image Opacity", Range(0, 1)) = 1

        // How many arms the spiral should have.
        [Space] arms("Arms", Float) = 1

        // How tightly the spiral is wound.
        tightness("Tightness", Range(0, 100)) = 10

        // Change in tightness with distance.
        lensing("Lensing", Range(0.01, 2)) = 1

        // How thick the arms are.
        width("Width", Range(0, 1)) = 0.5

        // How fast the spiral rotates.
        rotationSpeed("Rotation Speed", Float) = 2

        // The background colour RGB.
        [HDR] backgroundColour("Background Colour", Color) = (1.0, 1.0, 1.0, 1.0)

        // The foreground colour RGB.
        [HDR] foregroundColour("Foreground Colour", Color) = (1.0, 0.41, 1.0, 1.0)

        // The centre of rotation.
        centre("Centre and Scale", Vector) = (0, 0, 1, 1)

        // The opacity of the spiral.
        spiralOpacity("Spiral Opacity", Range(0, 1)) = 0.1

        // The noise opacity.
        [Space] [Toggle(NOISE_ENABLED)] _NoiseEnabled("Enable Noise", Float) = 0
        noiseScale("Noise Scale", Range(0, 1)) = 0.1
        noiseOpacity("Noise Opacity", Range(0, 1)) = 0.1

        // The opacity of the vignette.
        [Space] [Toggle(VIGNETTE_ENABLED)] _VignetteEnabled("Enable Vignette", Float) = 0
        vignetteOpacity("Vignette Opacity", Range(0, 1)) = 0.1
        vignetteColour("Vignette Colour", Color) = (1.0, 1.0, 1.0, 1.0)
    }

    SubShader
    {
        Tags
        {
            "RenderType" = "Transparent"
            "Queue" = "Geometry"
            "PreviewType" = "Plane"
            "IgnoreProjector" = "True"
        }

        LOD 100
        Blend [_BlendSrc] [_BlendDst]
        ZTest [_ZTest]
        ZWrite [_ZWrite]

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            #pragma shader_feature_local _BLENDMODE_OPAQUE _BLENDMODE_TRANSPARENT _BLENDMODE_ADDITIVE
            #pragma shader_feature_local TEXTURE_ENABLED
            #pragma shader_feature_local NOISE_ENABLED
            #pragma shader_feature_local VIGNETTE_ENABLED

            #include "UnityCG.cginc"

            #define PI 3.1415926535897932384626433832795

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(2)
                float4 vertex : SV_POSITION;
            };

            // Material properties.
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float arms;
            float tightness;
            float lensing;
            float width;
            float rotationSpeed;
            float4 backgroundColour;
            float4 foregroundColour;
            float noiseScale;
            float noiseOpacity;
            float vignetteOpacity;
            float4 vignetteColour;
            float spiralOpacity;
            float imageScale;
            float imageTop;
            float imageLeft;
            float imageBottom;
            float imageRight;
            float imageOpacity;
            float imageX;
            float imageY;
            float4 centre;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o, o.vertex);

                return o;
            }

            /**
            * Remap a value from one range to another.
            *
            * For example, to remap a number 'n' from the range 0..1 to -2..+2, use:
            * map(0, 1, -2, 2, n);
            *
            * @param float inLow    The lower bound of the input range.
            * @param float inHight  The upper bound of the input range.
            * @param float outLow   The lower bound of the output range.
            * @param float outHight The upper bound of the output range.
            * @param float value    The value to remap, from within the input range.
            *
            * @return float Returns the input value remapped from the input range to the output range.
            */
            float map(float inLow, float inHigh, float outLow, float outHigh, float value)
            {
                float inRange = inHigh - inLow;
                float outRange = outHigh - outLow;

                return (value - inLow) / inRange * outRange + outLow;
            }

            /**
            * Get the angle of the input coordinate, normalized
            * into the range 0..1.
            *
            * @param float2 uv The input point.
            *
            * @return float Returns the angle of the input point around the origin.
            */
            float radialGradient(float2 uv)
            {
                return map(-PI, PI, 0.0, 1.0, atan2(uv.x, uv.y));
            }

            /**
            * Get the distance of the input point from the origin.
            *
            * @param float2 uv The input point.
            *
            * @return float Returns the distance of the point from the origin.
            */
            float sphericalGradient(float2 uv)
            {
                return length(uv);
            }

            /**
            * Rotate a point in 2D around the origin.
            *
            * @param float2  position The point to rotate.
            * @param float angle    The angle in radians.
            *
            * @return float2 Returns the rotated point.
            */
            float2 rotate2d(float2 position, float angle)
            {
                float cosA = cos(angle);
                float sinA = sin(angle);

                float2x2 rotation = float2x2(cosA, -sinA, sinA, cosA);

                return mul(position, rotation);
            }

            /**
            * Given a value in the range 0..1, mask off the edges.
            * The mask is "width" wide, where width is between 0 and 1.
            * A mask of zero width includes nothing, a mask of one width includes everything.
            *
            * The mask is smoothed outside the range over a distance of transitionWidth.
            *    ____
            * __/    \__
            * a bc  de  f
            *
            * a = 0.0
            * b = 0.5 - width/2 - transitionWidth
            * c = 0.5 - width/2
            * d = 0.5 + width/2
            * e = 0.5 + width/2 + transitionWidth
            * f = 1.0
            *
            * If "value" is outside the range 0 to 1 then the function will return zero.
            *
            * @param float width           The width of the mask, in the range 0 to 1.
            * @param float transitionWidth The width of the smooth transition.
            * @param float value           The value to mask.
            *
            * @return value Returns the mask value at position "value".
            */
            float maskCentre(float width, float transitionWidth, float value)
            {
                float lowerEdge = 0.5 - width / 2.0;
                float upperEdge = 0.5 + width / 2.0;

                lowerEdge = smoothstep(lowerEdge - transitionWidth, lowerEdge, value);
                upperEdge = smoothstep(upperEdge + transitionWidth, upperEdge, value);

                return lowerEdge * upperEdge;
            }

            /**
            * Compute x modulus y.
            *
            * @return float Returns the floating point modulus.
            */
            float mod(float x, float y)
            {
                return x - y * floor(x / y);
            }

            /**
            * Two dimensional random noise.
            *
            * From http://byteblacksmith.com/improvements-to-the-canonical-one-liner-glsl-rand-for-opengl-es-2-0/
            *
            * @param float2 co The noise location.
            *
            * @return float Returns a random number in the range 0 to 1.
            */
            float rand(float2 co)
            {
                float a = 12.9898;
                float b = 78.233;
                float c = 43758.5453;
                float dt = dot(co.xy, float2(a, b));
                float sn = mod(dt, 3.14);

                return frac(sin(sn) * c);
            }

            /**
            * Alpha blend colour a on top of colour b.
            *
            * @param float4 a The top colour.
            * @param float4 b The bottom colour.
            *
            * @return float4 Returns the two colours blended together.
            */
            float4 over(float4 a, float4 b)
            {
                float4 result;
                result.a = a.a + b.a * (1.0 - a.a);
                result.rgb = (a.rgb * a.a + b.rgb * b.a * (1.0 - a.a)) / result.a;

                return result;
            }

            /**
            * Draw a spiral.
            *
            * @param float4 fragColor The output colour.
            * @param float2 fragCoord The input UV coordinate.
            *
            * @return void
            */
            fixed4 frag(v2f i) : SV_Target
            {
                // Normalise so that x is in the range -1 to +1.
                float2 uv = (i.uv * 2.0 - 1.0) * centre.zw + centre.xy;
                float iTime = _Time.z;

                // Calculate how much rotation there should be at the current UV.
                float rotation = 1.0 - pow(sphericalGradient(uv), lensing) * tightness + iTime * rotationSpeed;

                // Generate the arms of the spiral and rotate by the given rotation.
                float value = frac(radialGradient(rotate2d(uv, rotation)) * arms);

                // Mask out the width of the arm.
                value = maskCentre(width, 0.07, value);

                // Generate the spiral colour.
                float4 spiral = lerp(backgroundColour, foregroundColour, value);
                spiral.a = spiralOpacity;

                // Mix to the screen.
                fixed4 output = spiral;

                #if NOISE_ENABLED
                    // Generate static noise.
                    float4 noise = frac(rand(floor((uv + mod(floor(iTime * 23.0), 10.0)) * 400.0 * noiseScale)));
                    noise.a = noiseOpacity;
                    output = over(noise, output);
                #endif

                #if TEXTURE_ENABLED
                    if (imageScale != 0) {
                        float2 sourceCentre = float2(imageLeft + imageRight, imageBottom + imageTop) / 2;
                        float2 position = float2(imageX, imageY);
                        float2 tuv = (i.uv - 0.5 - position) / imageScale + sourceCentre;

                        // Clip around the image.
                        if (tuv.x >= imageLeft && tuv.x < imageRight && tuv.y >= imageBottom && tuv.y < imageTop) {
                            float4 image = tex2D(_MainTex, tuv);
                            image.a *= imageOpacity;
                            output = over(image, output);
                        }
                    }
                #endif

                #if VIGNETTE_ENABLED
                    #if _BLENDMODE_OPAQUE
                        output = lerp(output, vignetteColour, smoothstep(0.5, 1, length(uv) * vignetteOpacity));
                    #else
                        output.a *= 1.0 - smoothstep(0.5, 1, length(uv) * vignetteOpacity);
                    #endif
                #endif

                // Apply fog.
                UNITY_APPLY_FOG(i.fogCoord, output);

                return output;
            }

            ENDCG
        }
    }

    CustomEditor "TheSpiralizer"
}
