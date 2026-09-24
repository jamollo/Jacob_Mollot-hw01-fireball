#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_time;

uniform float u_GROW;
uniform float u_RELAX;

in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.

out vec4 fs_Pos;

out float fs_Noise;



const vec4 lightPos = vec4(0, 50, 0, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.
                                    

float almostIdentity( float x, float m, float e )
{
    if( x>m ) return x;
    float a = 2.0*e - m;
    float b = 2.0*m - 3.0*e;
    float t = x/m;
    return (a*t+b)*t*t + e;
}

float coarseNoise(float amp, float freq, float y)
{
    vec3 p = vs_Pos.xyz;
    float topMask = smoothstep(-1.0, 0.5, y);
    float t = u_time * 20.0;

    float height = (
        sin(freq * p.x) * sin(t * 10.0) +
        sin(freq * p.y) * sin(t * 5.0) +
        sin(freq * p.z) * sin(t * 7.0)
    ) / 3.0;

    return amp * topMask * height;
}

float sinc( float x)
{
    if (x == 0.) {
        return 1.; 
    }
    float a = 3.14159*x;
    return mod(sin(a)/a, 1.5);
}



float fbm(vec4 pos, float H) {
    float G = exp2(-H);
    float f = 1.0;
    float a = 1.0;
    float t = 0.0;
    for(int i = 0; i < 4; i++)
    {
        t += 0.3333333 * (a*sinc(f * pos.x) + a*sinc(f * pos.y) + a*sinc(f * pos.z));
        f *= 2.0;
        a *= G;
    }
    return t;
}

float hash(float seed)
{
    return fract(sin(seed * 127.1 + 311.7) * 43758.5453);
}

float expImpulse(float x, float k)
{
    float h = k * x;
    return h * exp(1.0 - h);
}

// Returns upward displacement for an undeformed sphere of radius 1.
float flameDisplacement(vec3 basePos, float time)
{

    time *= 15.;

    const float EVENT_INTERVAL = 0.40;
    const float LIFETIME = 2.40;
    const float CENTER_RADIUS = 0.80;
    const float TWO_PI = 6.28318530718;

    float latestEvent = floor(time / EVENT_INTERVAL);
    float displacement = 0.0;

    // Sum recent events so multiple impulses can overlap.
    for (int i = 0; i < 8; ++i)
    {
        float eventID = latestEvent - float(i);

        if (eventID < 0.0)
            continue;

        float seed = eventID * 13.7;

        // Randomize timing within each interval.
        float startTime =
            (eventID + 0.8 * hash(seed + 1.0)) * EVENT_INTERVAL;

        float age = time - startTime;

        if (age < 0.0 || age >= LIFETIME)
            continue;

        // Random center distributed over an xz disk.
        float angle = TWO_PI * hash(seed + 2.0);
        float radius = CENTER_RADIUS * sqrt(hash(seed + 3.0));

        vec2 center = radius * vec2(cos(angle), sin(angle));

        // Random mound width and maximum height.
        float sigma  = mix(0.13, 0.23, hash(seed + 4.0));
        float height = mix(0.30, 0.65, hash(seed + 5.0));

        // Gaussian
        vec2 offset = basePos.xz - center;
        float spatialFalloff =
            exp(-dot(offset, offset) / (2.0 * sigma * sigma));

        // Each event rises quickly, then gradually subsides.
        // k controls speed; maximum occurs at 1 / k.
        float k = mix(3.5, 6.0, hash(seed + 6.0));
        float transient = expImpulse(age, k);

        // Finish at  zero before removing the old event.
        transient *=
            1.0 - smoothstep(LIFETIME - 0.5, LIFETIME, age);

        displacement += height * spatialFalloff * transient;
    }

    // xz alone also matches vertices underneath the sphere.
    // Restrict deformation to the upper surface.
    float topMask = smoothstep(0.10, 0.50, basePos.y);

    return topMask * displacement;
}


void main()
{

    vec3 basePos = vs_Pos.xyz;

    // coarse noise
    float height = coarseNoise(0.2, 3.14159 * 2., vs_Pos.y);
    fs_Noise = height;
    vec4 normDisplace = vec4(height * vec3(vs_Nor), 0.0);
    vec4 new_Pos = normDisplace + vs_Pos;

    float innerRadius = 0.25;
    float outerRadius = 2.7;
    float strength = 0.25;
    vec3 target = vec3(0.0, 2.0, 0.0);
    float d = length(new_Pos.xyz - target);

    // top jitter fbm noise
    height = fbm(new_Pos, 0.25 + mix(0.0, 0.75, u_RELAX));
    normDisplace = vec4(height * vec3(vs_Nor), 0.0);
    float weight = 1.0 - smoothstep(innerRadius, outerRadius, d);
    vec3 newPosition = mix(new_Pos.xyz, new_Pos.xyz + normDisplace.xyz, strength * weight *5.);
    new_Pos = vec4(newPosition, 1.);
    
    // squeeze to point
    innerRadius = 1.5 - u_GROW;
    outerRadius = 2.35;
    weight = 1.0 - smoothstep(innerRadius, outerRadius, d);
    newPosition = mix(new_Pos.xyz, target, strength * weight);
    new_Pos = vec4(newPosition, 1.); 

    // impulse
    new_Pos.y += flameDisplacement(basePos, u_time);

    fs_Pos = new_Pos;

    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0.0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.


    vec4 modelposition = u_Model * new_Pos;   // Temporarily store the transformed vertex positions for use below

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}
