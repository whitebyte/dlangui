// Written in the D programming language.

/**
This module contains OpenGL access layer.

To enable OpenGL support, build with version(USE_OPENGL);

Synopsis:

----
import dlangui.graphics.glsupport;

----

Copyright: Vadim Lopatin, 2014
License:   Boost License 1.0
Authors:   Vadim Lopatin, coolreader.org@gmail.com
*/
module dlangui.graphics.glsupport;

public import dlangui.core.config;
static if (ENABLE_OPENGL):

public import dlangui.core.math3d;

import dlangui.core.logger;
import dlangui.core.types;
import dlangui.core.math3d;

import std.conv;
import std.string;
import std.array;
import std.algorithm : any;

enum SUPPORT_LEGACY_OPENGL = false; //true;
public import bindbc.opengl;
import bindbc.loader : ErrorInfo, errors;


private void gl3CheckMissingSymFunc(const(ErrorInfo)[] errors)
{
    import std.algorithm : equal;
    immutable names = ["glGetError", "glShaderSource", "glCompileShader",
            "glGetShaderiv", "glGetShaderInfoLog", "glGetString",
            "glCreateProgram", "glUseProgram", "glDeleteProgram",
            "glDeleteShader", "glEnable", "glDisable", "glBlendFunc",
            "glUniformMatrix4fv", "glGetAttribLocation", "glGetUniformLocation",
            "glGenVertexArrays", "glBindVertexArray", "glBufferData",
            "glBindBuffer", "glBufferSubData"];
    foreach(info; errors)
    {
        import std.array;
        import std.algorithm;
        import std.exception;
        import core.stdc.string;
        // NOTE: this has crappy complexity as it was just updated as is
        //     it also does not checks if the symbol was actually loaded
        auto errMsg = cast(string) info.message[0 .. info.message.strlen];
        bool found = names.any!(s => s.indexOf(errMsg) != -1);
        enforce(!found, { return errMsg.idup; });
    }
}

/// Reference counted Mesh object
alias MeshRef = Ref!Mesh;

/// Base class for graphics effect / program - e.g. for OpenGL shader program
abstract class GraphicsEffect : RefCountedObject {
    /// get location for vertex attribute
    int getVertexElementLocation(VertexElementType type);

    void setUniform(string uniformName, ref const(mat4) matrix);
    void setUniform(string uniformName, const(mat4)[] matrix);
    void setUniform(string uniformName, float v);
    void setUniform(string uniformName, const float[] v);
    void setUniform(string uniformName, vec2 vec);
    void setUniform(string uniformName, const vec2[] vec);
    void setUniform(string uniformName, vec3 vec);
    void setUniform(string uniformName, const vec3[] vec);
    void setUniform(string uniformName, vec4 vec);
    void setUniform(string uniformName, const vec4[] vec);

    void setUniform(DefaultUniform id, ref const(mat4) matrix);
    void setUniform(DefaultUniform id, const(mat4)[] matrix);
    void setUniform(DefaultUniform id, float v);
    void setUniform(DefaultUniform id, const float[] v);
    void setUniform(DefaultUniform id, vec2 vec);
    void setUniform(DefaultUniform id, const vec2[] vec);
    void setUniform(DefaultUniform id, vec3 vec);
    void setUniform(DefaultUniform id, const vec3[] vec);
    void setUniform(DefaultUniform id, vec4 vec);
    void setUniform(DefaultUniform id, const vec4[] vec);

    /// returns true if effect has uniform
    bool hasUniform(DefaultUniform id);
    /// returns true if effect has uniform
    bool hasUniform(string uniformName);

    void draw(Mesh mesh, bool wireframe);
}

enum DefaultUniform : int {
    // colors
    u_ambientColor, // vec3
    u_diffuseColor, // vec4

    // textures
    u_diffuseTexture,
    u_lightmapTexture,
    u_normalmapTexture,

    // lights
    u_directionalLightColor,
    u_directionalLightDirection,
    u_pointLightColor,
    u_pointLightPosition,
    u_pointLightRangeInverse,
    u_spotLightColor,
    u_spotLightRangeInverse,
    u_spotLightInnerAngleCos,
    u_spotLightOuterAngleCos,
    u_spotLightPosition,
    u_spotLightDirection,

    u_specularExponent,
    u_modulateColor,
    u_modulateAlpha,

    // fog
    u_fogColor,
    u_fogMinDistance,
    u_fogMaxDistance,

    // matrix
    u_worldViewProjectionMatrix,
    u_inverseTransposeWorldViewMatrix,
    u_worldMatrix,
    u_worldViewMatrix,
    u_cameraPosition,

    u_matrixPalette,
    u_clipPlane,
}

enum DefaultAttribute : int {
    a_position,
    a_blendWeights,
    a_blendIndices,
    a_texCoord,
    a_texCoord1,
    a_normal,
    a_color,
    a_tangent,
    a_binormal,
}

/// vertex element type
enum VertexElementType : ubyte {
    POSITION = 0,
    NORMAL,
    COLOR,
    TANGENT,
    BINORMAL,
    BLENDWEIGHTS,
    BLENDINDICES,
    TEXCOORD0,
    TEXCOORD1,
    TEXCOORD2,
    TEXCOORD3,
    TEXCOORD4,
    TEXCOORD5,
    TEXCOORD6,
    TEXCOORD7,
}

static assert(VertexElementType.max == VertexElementType.TEXCOORD7);

/// Graphics primitive type
enum PrimitiveType : int {
    triangles,
    triangleStripes,
    lines,
    lineStripes,
    points,
}

/// Vertex buffer object base class
class VertexBuffer {
    /// set or change data
    void setData(Mesh mesh) { }
    /// draw mesh using specified effect
    void draw(GraphicsEffect effect, bool wireframe) { }
}

/// location for element is not found
enum VERTEX_ELEMENT_NOT_FOUND = -1;

/// vertex attribute properties
struct VertexElement {
    private VertexElementType _type;
    private ubyte _size;
    /// returns element type
    @property VertexElementType type() const { return _type; }
    /// return element size in floats
    @property ubyte size() const { return _size; }
    /// return element size in bytes
    @property ubyte byteSize() const { return cast(ubyte)(_size * float.sizeof); }

    this(VertexElementType type, ubyte size = 0) {
        if (size == 0) {
            switch(type) with (VertexElementType) {
                case POSITION:
                case NORMAL:
                case TANGENT:
                case BINORMAL:
                    size = 3;
                    break;
                case BLENDWEIGHTS:
                case BLENDINDICES:
                case COLOR:
                    size = 4;
                    break;
                default: // tx coords
                    size = 2;
                    break;
            }
        }
        _type = type;
        _size = size;
    }
}

/// Vertex format elements list
struct VertexFormat {
    private VertexElement[] _elements;
    private byte[16] _elementOffset = [-1, -1, -1, -1,  -1, -1, -1, -1,  -1, -1, -1, -1,  -1, -1, -1, -1];
    private int _vertexSize; // vertex size in floats
    /// make using element list
    this(inout VertexElement[] elems...) {
        _elements = elems.dup;
        foreach(elem; elems) {
            _elementOffset[elem.type] = cast(byte)_vertexSize;
            _vertexSize += elem.size;
        }
    }
    /// init from vertex element types, using default sizes for types
    this(inout VertexElementType[] types...) {
        foreach(t; types) {
            _elementOffset[t] = cast(byte)_vertexSize;
            VertexElement elem = VertexElement(t);
            _elements ~= elem;
            _vertexSize += elem.size;
        }
    }
    int elementOffset(VertexElementType type) const {
        return _elementOffset[type];
    }
    bool hasElement(VertexElementType type) const {
        return _elementOffset[type] >= 0;
    }
    /// set vec2 component value of vertex
    void set(float * vertex, VertexElementType type, vec2 value) const {
        int start = _elementOffset[type];
        if (start >= 0) {
            vertex += start;
            vertex[0] = value.vec[0];
            vertex[1] = value.vec[1];
        }
    }
    /// set vec3 component value of vertex
    void set(float * vertex, VertexElementType type, vec3 value) const {
        int start = _elementOffset[type];
        if (start >= 0) {
            vertex += start;
            vertex[0] = value.vec[0];
            vertex[1] = value.vec[1];
            vertex[2] = value.vec[2];
        }
    }
    /// set vec4 component value of vertex
    void set(float * vertex, VertexElementType type, vec4 value) const {
        int start = _elementOffset[type];
        if (start >= 0) {
            vertex += start;
            vertex[0] = value.vec[0];
            vertex[1] = value.vec[1];
            vertex[2] = value.vec[2];
            vertex[3] = value.vec[3];
        }
    }
    /// get number of elements
    @property int length() const {
        return cast(int)_elements.length;
    }
    /// get element by index
    VertexElement opIndex(int index) const {
        return _elements[index];
    }
    /// returns vertex size in bytes
    @property int vertexSize() const {
        return _vertexSize * cast(int)float.sizeof;
    }
    /// returns vertex size in floats
    @property int vertexFloats() const {
        return _vertexSize;
    }
    /// returns true if it's valid vertex format
    @property bool isValid() const {
        if (!_vertexSize)
            return false;
        foreach(elem; _elements) {
            if (elem.type == VertexElementType.POSITION)
                return true;
        }
        return false;
    }
    /// compare
    bool opEquals(immutable ref VertexFormat fmt) const {
        if (_vertexSize != fmt._vertexSize)
            return false;
        for(int i = 0; i < _elements.length; i++)
            if (_elements[i] != fmt._elements[i])
                return false;
        return true;
    }
    string dump(float * data) {
        import std.conv : to;
        char[] buf;
        int pos = 0;
        foreach(VertexElement e; _elements) {
            buf ~= data[pos .. pos + e.size].to!string;
            pos += e.size;
        }
        return buf.dup;
    }
}

struct IndexFragment {
    PrimitiveType type;
    ushort start;
    ushort end;
    this(PrimitiveType type, int start, int end) {
        this.type = type;
        this.start = cast(ushort)start;
        this.end = cast(ushort)end;
    }
}

/// Mesh
class Mesh : RefCountedObject {
    protected VertexFormat _vertexFormat;
    protected int _vertexCount;
    protected float[] _vertexData;
    protected MeshPart[] _parts;
    protected VertexBuffer _vertexBuffer;
    protected bool _dirtyVertexBuffer = true;

    @property ref VertexFormat vertexFormat() { return _vertexFormat; }
    @property const(VertexFormat) * vertexFormatPtr() { return &_vertexFormat; }

    bool hasElement(VertexElementType type) const {
        return _vertexFormat.hasElement(type);
    }

    @property void vertexFormat(VertexFormat format) {
        assert(_vertexCount == 0);
        _vertexFormat = format;
        _dirtyVertexBuffer = true;
    }

    const(float[]) vertex(int index) {
        int i = _vertexFormat.vertexFloats * index;
        return _vertexData[i .. i + _vertexFormat.vertexFloats];
    }

    void reset() {
        _vertexCount = 0;
        _vertexData.length = 0;
        _dirtyVertexBuffer = true;
        if (_vertexBuffer) {
            destroy(_vertexBuffer);
            _vertexBuffer = null;
        }
        if (_parts.length) {
            foreach(p; _parts)
                destroy(p);
            _parts.length = 0;
        }
    }

    string dumpVertexes(int maxCount = 30) {
        char[] buf;
        int count = 0;
        for(int i = 0; i < _vertexData.length; i+= _vertexFormat.vertexFloats) {
            buf ~= "\n";
            buf ~= _vertexFormat.dump(_vertexData.ptr + i);
            if (++count >= maxCount)
                break;
        }
        return buf.dup;
    }

    @property int vertexCount() const { return _vertexCount; }
    @property const(float[]) vertexData() const { return _vertexData; }

    @property const(ushort[]) indexData() const {
        if (!_parts)
            return null;
        if (_parts.length == 1)
            return _parts[0].data;
        int sz = 0;
        foreach(p; _parts)
            sz += p.length;
        ushort[] res;
        res.length = 0;
        int pos = 0;
        foreach(p; _parts) {
            res[pos .. pos + p.length] = p.data[0 .. $];
            pos += p.length;
        }
        return res;
    }

    @property IndexFragment[] indexFragments() const {
        IndexFragment[] res;
        int pos = 0;
        foreach(p; _parts) {
            res ~= IndexFragment(p.type, pos, pos + p.length);
            pos += p.length;
        }
        return res;
    }

    @property VertexBuffer vertexBuffer() {
        if (_dirtyVertexBuffer && _vertexBuffer) {
            _vertexBuffer.setData(this);
            _dirtyVertexBuffer = false;
        }
        return _vertexBuffer;
    }

    @property void vertexBuffer(VertexBuffer buffer) {
        if (_vertexBuffer) {
            _vertexBuffer.destroy;
            _vertexBuffer = null;
        }
        _vertexBuffer = buffer;
        if (_vertexBuffer) {
            _vertexBuffer.setData(this);
            _dirtyVertexBuffer = false;
        }
    }

    @property int partCount() const { return cast(int)_parts.length; }
    MeshPart part(int index) { return _parts[index]; }

    MeshPart addPart(MeshPart meshPart) {
        _parts ~= meshPart;
        _dirtyVertexBuffer = true;
        return meshPart;
    }

    MeshPart addPart(PrimitiveType type, ushort[] indexes) {
        MeshPart lastPart = _parts.length > 0 ? _parts[$ - 1] : null;
        if (!lastPart || lastPart.type != type)
            return addPart(new MeshPart(type, indexes));
        lastPart.add(indexes);
        return lastPart;
    }

    int addVertex(float[] data) {
        assert(_vertexFormat.isValid && data.length == _vertexFormat.vertexFloats);
        int res = _vertexCount;
        _vertexData.assumeSafeAppend();
        _vertexData ~= data;
        _vertexCount++;
        _dirtyVertexBuffer = true;
        return res;
    }

    int addVertexes(float[] data) {
        assert(_vertexFormat.isValid && (data.length > 0) && (data.length % _vertexFormat.vertexFloats == 0));
        int res = _vertexCount;
        _vertexData.assumeSafeAppend();
        _vertexData ~= data;
        _vertexCount += cast(int)(data.length / _vertexFormat.vertexFloats);
        _dirtyVertexBuffer = true;
        return res;
    }

    this() {
    }

    this(VertexFormat vertexFormat) {
        _vertexFormat = vertexFormat;
    }

    ~this() {
        if (_vertexBuffer) {
            _vertexBuffer.destroy;
            _vertexBuffer = null;
        }
    }

    void addQuad(ref vec3 v0, ref vec3 v1, ref vec3 v2, ref vec3 v3, ref vec4 color) {
        ushort startVertex = cast(ushort)vertexCount;
        if (hasElement(VertexElementType.NORMAL)) {
            vec3 normal = vec3.crossProduct((v1 - v0), (v3 - v0)).normalized;
            if (hasElement(VertexElementType.TANGENT)) {
                vec3 tangent = (v1 - v0).normalized;
                vec3 binormal = (v3 - v0).normalized;
                addVertex([v0.x, v0.y, v0.z, color.r, color.g, color.b, color.a, 0, 0, normal.x, normal.y, normal.z, tangent.x, tangent.y, tangent.z, binormal.x, binormal.y, binormal.z]);
                addVertex([v1.x, v1.y, v1.z, color.r, color.g, color.b, color.a, 1, 0, normal.x, normal.y, normal.z, tangent.x, tangent.y, tangent.z, binormal.x, binormal.y, binormal.z]);
                addVertex([v2.x, v2.y, v2.z, color.r, color.g, color.b, color.a, 1, 1, normal.x, normal.y, normal.z, tangent.x, tangent.y, tangent.z, binormal.x, binormal.y, binormal.z]);
                addVertex([v3.x, v3.y, v3.z, color.r, color.g, color.b, color.a, 0, 1, normal.x, normal.y, normal.z, tangent.x, tangent.y, tangent.z, binormal.x, binormal.y, binormal.z]);
            } else {
                addVertex([v0.x, v0.y, v0.z, color.r, color.g, color.b, color.a, 0, 0, normal.x, normal.y, normal.z]);
                addVertex([v1.x, v1.y, v1.z, color.r, color.g, color.b, color.a, 1, 0, normal.x, normal.y, normal.z]);
                addVertex([v2.x, v2.y, v2.z, color.r, color.g, color.b, color.a, 1, 1, normal.x, normal.y, normal.z]);
                addVertex([v3.x, v3.y, v3.z, color.r, color.g, color.b, color.a, 0, 1, normal.x, normal.y, normal.z]);
            }
        } else {
            addVertex([v0.x, v0.y, v0.z, color.r, color.g, color.b, color.a, 0, 0]);
            addVertex([v1.x, v1.y, v1.z, color.r, color.g, color.b, color.a, 1, 0]);
            addVertex([v2.x, v2.y, v2.z, color.r, color.g, color.b, color.a, 1, 1]);
            addVertex([v3.x, v3.y, v3.z, color.r, color.g, color.b, color.a, 0, 1]);
        }
        addPart(PrimitiveType.triangles, [
            cast(ushort)(startVertex + 0),
            cast(ushort)(startVertex + 1),
            cast(ushort)(startVertex + 2),
            cast(ushort)(startVertex + 2),
            cast(ushort)(startVertex + 3),
            cast(ushort)(startVertex + 0)]);
    }

    void addCubeMesh(vec3 pos, float d=1, vec4 color = vec4(1,1,1,1)) {
        auto p000 = vec3(pos.x-d, pos.y-d, pos.z-d);
        auto p100 = vec3(pos.x+d, pos.y-d, pos.z-d);
        auto p010 = vec3(pos.x-d, pos.y+d, pos.z-d);
        auto p110 = vec3(pos.x+d, pos.y+d, pos.z-d);
        auto p001 = vec3(pos.x-d, pos.y-d, pos.z+d);
        auto p101 = vec3(pos.x+d, pos.y-d, pos.z+d);
        auto p011 = vec3(pos.x-d, pos.y+d, pos.z+d);
        auto p111 = vec3(pos.x+d, pos.y+d, pos.z+d);
        addQuad(p000, p010, p110, p100, color);
        addQuad(p101, p111, p011, p001, color);
        addQuad(p100, p110, p111, p101, color);
        addQuad(p001, p011, p010, p000, color);
        addQuad(p010, p011, p111, p110, color);
        addQuad(p001, p000, p100, p101, color);
    }

    static Mesh createCubeMesh(vec3 pos, float d=1, vec4 color = vec4(1,1,1,1)) {
        Mesh mesh = new Mesh(VertexFormat(VertexElementType.POSITION, VertexElementType.COLOR, VertexElementType.TEXCOORD0,
                                          VertexElementType.NORMAL, VertexElementType.TANGENT, VertexElementType.BINORMAL));
        mesh.addCubeMesh(pos, d, color);
        return mesh;
    }
}

/// Mesh part - set of vertex indexes with graphics primitive type
class MeshPart {
    protected PrimitiveType _type;
    protected ushort[] _indexData;
    this(PrimitiveType type, ushort[] indexes = null) {
        _type = type;
        _indexData.assumeSafeAppend;
        add(indexes);
    }

    void add(ushort[] indexes) {
        if (indexes.length)
            _indexData ~= indexes;
    }

    @property PrimitiveType type() const { return _type; }
    @property void type(PrimitiveType t) { _type = t; }
    @property int length() const { return cast(int)_indexData.length; }
    @property const(ushort[]) data() const { return _indexData; }
}


//extern (C) void func(int n);
//pragma(msg, __traits(identifier, func));

/**
 * Convenient wrapper around glGetError()
 * Using: checkgl!glFunction(funcParams);
 * TODO use one of the DEBUG extensions
 */
template checkgl(alias func)
{
    debug auto checkgl(string functionName=__FUNCTION__, int line=__LINE__, Args...)(Args args)
    {
        scope(success) checkError(__traits(identifier, func), functionName, line);
        return func(args);
    } else
        alias checkgl = func;
}
bool checkError(string context="", string functionName=__FUNCTION__, int line=__LINE__)
{
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        Log.e("OpenGL error ", glerrorToString(err), " at ", functionName, ":", line, " -- ", context);
        return true;
    }
    return false;
}

/**
* Convenient wrapper around glGetError()
* Using: checkgl!glFunction(funcParams);
* TODO use one of the DEBUG extensions
*/
template assertgl(alias func)
{
    auto assertgl(string functionName=__FUNCTION__, int line=__LINE__, Args...)(Args args)
    {
        scope(success) assertNoError(func.stringof, functionName, line);
        return func(args);
    }
}
void assertNoError(string context="", string functionName=__FUNCTION__, int line=__LINE__)
{
    GLenum err = glGetError();
    if (err != GL_NO_ERROR) {
        Log.e("fatal OpenGL error ", glerrorToString(err), " at ", functionName, ":", line, " -- ", context);
        assert(false);
    }
}

/* For reporting OpenGL errors, it's nicer to get a human-readable symbolic name for the
 * error instead of the numeric form. Derelict's GLenum is just an alias for uint, so we
 * can't depend on D's nice toString() for enums.
 */
string glerrorToString(in GLenum err) pure nothrow {
    switch(err) {
        case 0x0500: return "GL_INVALID_ENUM";
        case 0x0501: return "GL_INVALID_VALUE";
        case 0x0502: return "GL_INVALID_OPERATION";
        case 0x0505: return "GL_OUT_OF_MEMORY";
        case 0x0506: return "GL_INVALID_FRAMEBUFFER_OPERATION";
        case 0x0507: return "GL_CONTEXT_LOST";
        case GL_NO_ERROR: return "No GL error";
        default: return "Unknown GL error: " ~ to!string(err);
    }
}

class GLProgram : GraphicsEffect {
    @property abstract string vertexSource();
    @property abstract string fragmentSource();
    protected GLuint program;
    protected bool initialized;
    protected bool error;

    private GLuint vertexShader;
    private GLuint fragmentShader;
    private string glslversion;
    private int glslversionInt;
    private char[] glslversionString;

    private void compatibilityFixes(ref char[] code, GLuint type) {
        if (glslversionInt < 150)
            code = replace(code, " texture(", " texture2D(");
        if (glslversionInt < 140) {
            if(type == GL_VERTEX_SHADER) {
                code = replace(code, "in ", "attribute ");
                code = replace(code, "out ", "varying ");
            } else {
                code = replace(code, "in ", "varying ");
                code = replace(code, "out vec4 outColor;", "");
                code = replace(code, "outColor", "gl_FragColor");
            }
        }
    }

    private GLuint compileShader(string src, GLuint type) {
        import std.string : toStringz, fromStringz;

        char[] sourceCode;
        if (glslversionString.length) {
            sourceCode ~= "#version ";
            sourceCode ~= glslversionString;
            sourceCode ~= "\n";
        }
        sourceCode ~= src;
        compatibilityFixes(sourceCode, type);

        Log.d("compileShader: glslVersion = ", glslversion, ", type: ", (type == GL_VERTEX_SHADER ? "GL_VERTEX_SHADER" : (type == GL_FRAGMENT_SHADER ? "GL_FRAGMENT_SHADER" : "UNKNOWN")));
        GLuint shader = checkgl!glCreateShader(type);
        const char * psrc = sourceCode.toStringz;
        checkgl!glShaderSource(shader, 1, &psrc, null);
        checkgl!glCompileShader(shader);
        GLint compiled;
        checkgl!glGetShaderiv(shader, GL_COMPILE_STATUS, &compiled);
        if (compiled) {
            // compiled successfully
            return shader;
        } else {
            Log.e("Failed to compile shader source:\n", sourceCode);
            GLint blen = 0;
            GLsizei slen = 0;
            checkgl!glGetShaderiv(shader, GL_INFO_LOG_LENGTH , &blen);
            if (blen > 1)
            {
                GLchar[] msg = new GLchar[blen + 1];
                checkgl!glGetShaderInfoLog(shader, blen, &slen, msg.ptr);
                Log.e("Shader compilation error: ", fromStringz(msg.ptr));
            }
            return 0;
        }
    }

    bool compile() {
        glslversion = checkgl!fromStringz(cast(const char *)glGetString(GL_SHADING_LANGUAGE_VERSION)).dup;
        glslversionString.length = 0;
        glslversionInt = 0;
        foreach(ch; glslversion) {
            if (ch >= '0' && ch <= '9') {
                glslversionString ~= ch;
                glslversionInt = glslversionInt * 10 + (ch - '0');
            } else if (ch != '.')
                break;
        }
        vertexShader = compileShader(vertexSource, GL_VERTEX_SHADER);
        fragmentShader = compileShader(fragmentSource, GL_FRAGMENT_SHADER);
        if (!vertexShader || !fragmentShader) {
            error = true;
            return false;
        }
        program = checkgl!glCreateProgram();
        checkgl!glAttachShader(program, vertexShader);
        checkgl!glAttachShader(program, fragmentShader);
        checkgl!glLinkProgram(program);
        GLint isLinked = 0;
        checkgl!glGetProgramiv(program, GL_LINK_STATUS, &isLinked);
        if (!isLinked) {
            GLint maxLength = 0;
            checkgl!glGetProgramiv(program, GL_INFO_LOG_LENGTH, &maxLength);
            GLchar[] msg = new GLchar[maxLength + 1];
            checkgl!glGetProgramInfoLog(program, maxLength, &maxLength, msg.ptr);
            Log.e("Error while linking program: ", fromStringz(msg.ptr));
            error = true;
            return false;
        }
        Log.d("Program linked successfully");

        initStandardLocations();
        if (!initLocations()) {
            Log.e("some of locations were not found");
            error = true;
        }
        initialized = true;
        Log.v("Program is initialized successfully");
        return !error;
    }


    void initStandardLocations() {
        for(DefaultUniform id = DefaultUniform.min; id <= DefaultUniform.max; id++) {
            _uniformIdLocations[id] = getUniformLocation(to!string(id));
        }
        for(DefaultAttribute id = DefaultAttribute.min; id <= DefaultAttribute.max; id++) {
            _attribIdLocations[id] = getAttribLocation(to!string(id));
        }
    }

    /// override to init shader code locations
    abstract bool initLocations();

    ~this() {
        // TODO: cleanup
        if (program)
            glDeleteProgram(program);
        if (vertexShader)
            glDeleteShader(vertexShader);
        if (fragmentShader)
            glDeleteShader(fragmentShader);
        program = vertexShader = fragmentShader = 0;
        initialized = false;
    }

    /// returns true if program is ready for use
    bool check() {
        return !error && initialized;
    }

    static GLuint currentProgram;
    /// binds program to current context
    void bind() {
        if(program != currentProgram) {
            checkgl!glUseProgram(program);
            currentProgram = program;
        }
    }

    /// unbinds program from current context
    static void unbind() {
        checkgl!glUseProgram(0);
        currentProgram = 0;
    }

    protected int[string] _uniformLocations;
    protected int[string] _attribLocations;
    protected int[DefaultUniform.max + 1] _uniformIdLocations;
    protected int[DefaultAttribute.max + 1] _attribIdLocations;

    /// get location for vertex attribute
    override int getVertexElementLocation(VertexElementType type) {
        return VERTEX_ELEMENT_NOT_FOUND;
    }


    /// get uniform location from program by uniform id, returns -1 if location is not found
    int getUniformLocation(DefaultUniform uniform) {
        return _uniformIdLocations[uniform];
    }

    /// get uniform location from program, returns -1 if location is not found
    int getUniformLocation(string variableName) {
        if (auto p = variableName in _uniformLocations)
            return *p;
        int res = checkgl!glGetUniformLocation(program, variableName.toStringz);
        _uniformLocations[variableName] = res;
        return res;
    }

    /// get attribute location from program by uniform id, returns -1 if location is not found
    int getAttribLocation(DefaultAttribute id) {
        return _attribIdLocations[id];
    }

    /// get attribute location from program, returns -1 if location is not found
    int getAttribLocation(string variableName) {
        if (auto p = variableName in _attribLocations)
            return *p;
        int res = checkgl!glGetAttribLocation(program, variableName.toStringz);
        _attribLocations[variableName] = res;
        return res;
    }

    override void setUniform(string uniformName, const vec2[] vec) {
        checkgl!glUniform2fv(getUniformLocation(uniformName), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(DefaultUniform id, const vec2[] vec) {
        checkgl!glUniform2fv(getUniformLocation(id), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(string uniformName, vec2 vec) {
        checkgl!glUniform2fv(getUniformLocation(uniformName), 1, vec.vec.ptr);
    }

    override void setUniform(DefaultUniform id, vec2 vec) {
        checkgl!glUniform2fv(getUniformLocation(id), 1, vec.vec.ptr);
    }

    override void setUniform(string uniformName, vec3 vec) {
        checkgl!glUniform3fv(getUniformLocation(uniformName), 1, vec.vec.ptr);
    }

    override void setUniform(DefaultUniform id, vec3 vec) {
        checkgl!glUniform3fv(getUniformLocation(id), 1, vec.vec.ptr);
    }

    override void setUniform(string uniformName, const vec3[] vec) {
        checkgl!glUniform3fv(getUniformLocation(uniformName), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(DefaultUniform id, const vec3[] vec) {
        checkgl!glUniform3fv(getUniformLocation(id), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(string uniformName, vec4 vec) {
        checkgl!glUniform4fv(getUniformLocation(uniformName), 1, vec.vec.ptr);
    }

    override void setUniform(DefaultUniform id, vec4 vec) {
        checkgl!glUniform4fv(getUniformLocation(id), 1, vec.vec.ptr);
    }

    override void setUniform(string uniformName, const vec4[] vec) {
        checkgl!glUniform4fv(getUniformLocation(uniformName), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(DefaultUniform id, const vec4[] vec) {
        checkgl!glUniform4fv(getUniformLocation(id), cast(int)vec.length, cast(const(float)*)vec.ptr);
    }

    override void setUniform(string uniformName, ref const(mat4) matrix) {
        checkgl!glUniformMatrix4fv(getUniformLocation(uniformName), 1, false, matrix.m.ptr);
    }

    override void setUniform(DefaultUniform id, ref const(mat4) matrix) {
        checkgl!glUniformMatrix4fv(getUniformLocation(id), 1, false, matrix.m.ptr);
    }

    override void setUniform(string uniformName, const(mat4)[] matrix) {
        checkgl!glUniformMatrix4fv(getUniformLocation(uniformName), cast(int)matrix.length, false, cast(const(float)*)matrix.ptr);
    }

    override void setUniform(DefaultUniform id, const(mat4)[] matrix) {
        checkgl!glUniformMatrix4fv(getUniformLocation(id), cast(int)matrix.length, false, cast(const(float)*)matrix.ptr);
    }

    override void setUniform(string uniformName, float v) {
        checkgl!glUniform1f(getUniformLocation(uniformName), v);
    }

    override void setUniform(DefaultUniform id, float v) {
        checkgl!glUniform1f(getUniformLocation(id), v);
    }

    override void setUniform(string uniformName, const float[] v) {
        checkgl!glUniform1fv(getUniformLocation(uniformName), cast(int)v.length, cast(const(float)*)v.ptr);
    }

    override void setUniform(DefaultUniform id, const float[] v) {
        checkgl!glUniform1fv(getUniformLocation(id), cast(int)v.length, cast(const(float)*)v.ptr);
    }

    /// returns true if effect has uniform
    override bool hasUniform(DefaultUniform id) {
        return getUniformLocation(id) >= 0;
    }

    /// returns true if effect has uniform
    override bool hasUniform(string uniformName) {
        return getUniformLocation(uniformName) >= 0;
    }

    /// draw mesh using this program (program should be bound by this time and all uniforms should be set)
    override void draw(Mesh mesh, bool wireframe) {
        VertexBuffer vb = mesh.vertexBuffer;
        if (!vb) {
            vb = new GLVertexBuffer();
            mesh.vertexBuffer = vb;
        }
        vb.draw(this, wireframe);
    }
}

class SolidFillProgram : GLProgram {
    @property override string vertexSource() {
        return q{
            in vec3 a_position;
            in vec4 a_color;
            out vec4 col;
            uniform mat4 u_worldViewProjectionMatrix;
            void main(void)
            {
                gl_Position = u_worldViewProjectionMatrix * vec4(a_position, 1);
                col = a_color;
            }
        };
    }

    @property override string fragmentSource() {
        return q{
            in vec4 col;
            out vec4 outColor;
            void main(void)
            {
                outColor = col;
            }
        };
    }

    protected GLint matrixLocation;
    protected GLint vertexLocation;
    protected GLint colAttrLocation;
    override bool initLocations() {
        matrixLocation = getUniformLocation(DefaultUniform.u_worldViewProjectionMatrix);
        vertexLocation = getAttribLocation(DefaultAttribute.a_position);
        colAttrLocation = getAttribLocation(DefaultAttribute.a_color);
        return matrixLocation >= 0 && vertexLocation >= 0 && colAttrLocation >= 0;
    }
    /// get location for vertex attribute
    override int getVertexElementLocation(VertexElementType type) {
        switch(type) with(VertexElementType) {
            case POSITION:
                return vertexLocation;
            case COLOR:
                return colAttrLocation;
            default:
                return VERTEX_ELEMENT_NOT_FOUND;
        }
    }

    VAO vao;

    protected void beforeExecute() {
        bind();
        setUniform(DefaultUniform.u_worldViewProjectionMatrix, glSupport.projectionMatrix);
    }

    protected void createVAO(size_t verticesBufferLength) {
        vao = new VAO;

        glVertexAttribPointer(vertexLocation, 3, GL_FLOAT, GL_FALSE, 0, cast(void*) 0);
        glVertexAttribPointer(colAttrLocation, 4, GL_FLOAT, GL_FALSE, 0, cast(void*) (verticesBufferLength * float.sizeof));

        glEnableVertexAttribArray(vertexLocation);
        glEnableVertexAttribArray(colAttrLocation);
    }

    bool drawBatch(int length, int start, bool areLines = false) {
        if(!check())
            return false;
        beforeExecute();

        vao.bind();

        checkgl!glDrawElements(areLines ? GL_LINES : GL_TRIANGLES, cast(int)length, GL_UNSIGNED_INT, cast(void*)(start * 4));

        return true;
    }

    void destroyBuffers() {
        destroy(vao);
        vao = null;
    }
}

class TextureProgram : SolidFillProgram {
    @property override string vertexSource() {
        return q{
            in vec3 a_position;
            in vec4 a_color;
            in vec2 a_texCoord;
            out vec4 col;
            out vec2 UV;
            uniform mat4 u_worldViewProjectionMatrix;
            void main(void)
            {
                gl_Position = u_worldViewProjectionMatrix * vec4(a_position, 1);
                col = a_color;
                UV = a_texCoord;
            }
        };
    }
    @property override string fragmentSource() {
        return q{
            uniform sampler2D tex;
            in vec4 col;
            in vec2 UV;
            out vec4 outColor;
            void main(void)
            {
                outColor = texture(tex, UV) * col;
            }
        };
    }

    GLint texCoordLocation;
    override bool initLocations() {
        bool res = super.initLocations();
        texCoordLocation = getAttribLocation(DefaultAttribute.a_texCoord);
        return res && texCoordLocation >= 0;
    }
    /// get location for vertex attribute
    override int getVertexElementLocation(VertexElementType type) {
        switch(type) with(VertexElementType) {
            case TEXCOORD0:
                return texCoordLocation;
            default:
                return super.getVertexElementLocation(type);
        }
    }

    protected void createVAO(size_t verticesBufferLength, size_t colorsBufferLength) {
        vao = new VAO;

        glVertexAttribPointer(vertexLocation, 3, GL_FLOAT, GL_FALSE, 0, cast(void*) 0);
        glVertexAttribPointer(colAttrLocation, 4, GL_FLOAT, GL_FALSE, 0, cast(void*) (verticesBufferLength * float.sizeof));
        glVertexAttribPointer(texCoordLocation, 2, GL_FLOAT, GL_FALSE, 0, cast(void*) ((verticesBufferLength + colorsBufferLength) * float.sizeof));

        glEnableVertexAttribArray(vertexLocation);
        glEnableVertexAttribArray(colAttrLocation);
        glEnableVertexAttribArray(texCoordLocation);
    }

    bool drawBatch(Tex2D texture, bool linear, int length, int start) {
        if(!check())
            return false;
        beforeExecute();

        texture.setup();
        texture.setSamplerParams(linear);

        vao.bind();

        checkgl!glDrawElements(GL_TRIANGLES, cast(int)length, GL_UNSIGNED_INT, cast(void*)(start * 4));

        texture.unbind();
        return true;
    }
}


struct Color
{
    float r, g, b, a;
}

// utility function to fill 4-float array of vertex colors with converted CR 32bit color
private void FillColor(uint color, Color[] buf_slice) {
    float r = ((color >> 16) & 255) / 255.0;
    float g = ((color >> 8) & 255) / 255.0;
    float b = ((color >> 0) & 255) / 255.0;
    float a = (((color >> 24) & 255) ^ 255) / 255.0;
    foreach(ref col; buf_slice) {
        col.r = r;
        col.g = g;
        col.b = b;
        col.a = a;
    }
}


import std.functional;
alias convertColors = memoize!(convertColorsImpl);

float[] convertColorsImpl(uint[] cols) pure nothrow {
    float[] colors;
    colors.length = cols.length * 4;
    foreach(i; 0 .. cols.length) {
        uint color = cols[i];
        float r = ((color >> 16) & 255) / 255.0;
        float g = ((color >> 8) & 255) / 255.0;
        float b = ((color >> 0) & 255) / 255.0;
        float a = (((color >> 24) & 255) ^ 255) / 255.0;
        colors[i * 4 + 0] = r;
        colors[i * 4 + 1] = g;
        colors[i * 4 + 2] = b;
        colors[i * 4 + 3] = a;
    }
    return colors;
}

private __gshared GLSupport _glSupport;
@property GLSupport glSupport() {
    if (!_glSupport) {
        Log.f("GLSupport is not initialized");
        assert(false, "GLSupport is not initialized");
    }
    if (!_glSupport.valid) {
        Log.e("GLSupport programs are not initialized");
    }
    return _glSupport;
}

__gshared bool glNoContext;

/// initialize OpenGL support helper (call when current OpenGL context is initialized)
bool initGLSupport(bool legacy = false) {
    import dlangui.platforms.common.platform : setOpenglEnabled;
    import bindbc.opengl.config : GLVersion = GLSupport;
    if (_glSupport && _glSupport.valid)
        return true;
    GLVersion res = loadOpenGL();
    if([GLVersion.badLibrary, GLVersion.noLibrary, GLVersion.noContext].any!(x => x == res))
    {
        Log.e("bindbc-opengl cannot load OpenGL library!");
    }
    if(res < GLVersion.gl30)
        legacy = true;
    gl3CheckMissingSymFunc(errors);
    if (!_glSupport) { // TODO_GRIM: Legacy looks very broken to me.
        Log.d("glSupport not initialized: trying to create");
        int major = *cast(int*)(glGetString(GL_VERSION)[0 .. 1].ptr);
        legacy = legacy || (major < 3);
        _glSupport = new GLSupport(legacy);
        if (!_glSupport.valid) {
            Log.e("Failed to compile shaders");
            // try opposite legacy flag
            if (_glSupport.legacyMode == legacy) {
                Log.i("Trying to reinit GLSupport with legacy flag ", !legacy);
                _glSupport = new GLSupport(!legacy);
                // Situation when opposite legacy flag is true and GL version is 3+ with no old functions
                if (_glSupport.legacyMode) {
                    if (major >= 3) {
                        Log.e("Try to create OpenGL context with <= 3.1 version");
                        return false;
                    }
                }
            }
        }
    }
    if (_glSupport.valid) {
        setOpenglEnabled();
        Log.v("OpenGL is initialized ok");
        return true;
    } else {
        Log.e("Failed to compile shaders");
        return false;
    }
}

/// OpenGL support helper
final class GLSupport {

    private bool _legacyMode;
    @property bool legacyMode() { return _legacyMode; }
    @property queue() { return _queue; }

    @property bool valid() {
        return _legacyMode || _shadersAreInitialized;
    }

    this(bool legacy = false) {
        _queue = new OpenGLQueue;
        if (legacy /*&& !glLightfv*/) {
            Log.w("GLSupport legacy API is not supported");
            legacy = false;
        }
        _legacyMode = legacy;
        if (!_legacyMode)
            _shadersAreInitialized = initShaders();
    }

    ~this() {
        uninitShaders();
    }

    private OpenGLQueue _queue;

    private SolidFillProgram _solidFillProgram;
    private TextureProgram _textureProgram;

    private bool _shadersAreInitialized;
    private bool initShaders() {
        if (_solidFillProgram is null) {
            Log.v("Compiling solid fill program");
            _solidFillProgram = new SolidFillProgram();
            _solidFillProgram.compile();
            if (!_solidFillProgram.check())
                return false;
        }
        if (_textureProgram is null) {
            Log.v("Compiling texture program");
            _textureProgram = new TextureProgram();
            _textureProgram.compile();
            if (!_textureProgram.check())
                return false;
        }
        Log.d("Shaders compiled successfully");
        return true;
    }

    private void uninitShaders() {
        Log.d("Uniniting shaders");
        if (_solidFillProgram !is null) {
            destroy(_solidFillProgram);
            _solidFillProgram = null;
        }
        if (_textureProgram !is null) {
            destroy(_textureProgram);
            _textureProgram = null;
        }
    }

    void beforeRenderGUI() {
        glEnable(GL_BLEND);
        checkgl!glDisable(GL_CULL_FACE);
        checkgl!glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    }

    private VBO vbo;
    private EBO ebo;

    private void fillBuffers(float[] vertices, float[] colors, float[] texcoords, int[] indices) {
        resetBindings();

        if(_legacyMode)
            return;

        vbo = new VBO;
        ebo = new EBO;

        vbo.bind();
        vbo.fill([vertices, colors, texcoords]);

        ebo.bind();
        ebo.fill(indices);

        // create vertex array objects and bind vertex buffers to them
        _solidFillProgram.createVAO(vertices.length);
        vbo.bind();
        ebo.bind();
        _textureProgram.createVAO(vertices.length, colors.length);
        vbo.bind();
        ebo.bind();
    }

    /// This function is needed to draw custom OpenGL scene correctly (especially on legacy API)
    private void resetBindings() {
        import std.traits : isFunction;
        if (isFunction!glUseProgram)
            GLProgram.unbind();
        if (isFunction!glBindVertexArray)
            VAO.unbind();
        if (isFunction!glBindBuffer)
            VBO.unbind();
    }

    private void destroyBuffers() {
        resetBindings();

        if(_legacyMode)
            return;

        if (_solidFillProgram)
            _solidFillProgram.destroyBuffers();
        if (_textureProgram)
            _textureProgram.destroyBuffers();

        destroy(vbo);
        destroy(ebo);
        vbo = null;
        ebo = null;
    }

    private void drawLines(int length, int start) {
        if (_legacyMode) {
            static if (SUPPORT_LEGACY_OPENGL) {
                glEnableClientState(GL_VERTEX_ARRAY);
                glEnableClientState(GL_COLOR_ARRAY);
                glVertexPointer(3, GL_FLOAT, 0, cast(void*)_queue._vertices.data.ptr);
                glColorPointer(4, GL_FLOAT, 0, cast(void*)_queue._colors.data.ptr);

                checkgl!glDrawElements(GL_LINES, cast(int)length, GL_UNSIGNED_INT, cast(void*)(_queue._indices.data[start .. start + length].ptr));

                glDisableClientState(GL_COLOR_ARRAY);
                glDisableClientState(GL_VERTEX_ARRAY);
            }
        } else {
            if (_solidFillProgram !is null) {
                _solidFillProgram.drawBatch(length, start, true);
            } else
                Log.e("No program");
        }
    }

    private void drawSolidFillTriangles(int length, int start) {
        if (_legacyMode) {
            static if (SUPPORT_LEGACY_OPENGL) {
                glEnableClientState(GL_VERTEX_ARRAY);
                glEnableClientState(GL_COLOR_ARRAY);
                glVertexPointer(3, GL_FLOAT, 0, cast(void*)_queue._vertices.data.ptr);
                glColorPointer(4, GL_FLOAT, 0, cast(void*)_queue._colors.data.ptr);

                checkgl!glDrawElements(GL_TRIANGLES, cast(int)length, GL_UNSIGNED_INT, cast(void*)(_queue._indices.data[start .. start + length].ptr));

                glDisableClientState(GL_COLOR_ARRAY);
                glDisableClientState(GL_VERTEX_ARRAY);
            }
        } else {
            if (_solidFillProgram !is null) {
                _solidFillProgram.drawBatch(length, start);
            } else
                Log.e("No program");
        }
    }

    private void drawColorAndTextureTriangles(Tex2D texture, bool linear, int length, int start) {
        if (_legacyMode) {
            static if (SUPPORT_LEGACY_OPENGL) {
                glEnable(GL_TEXTURE_2D);
                texture.setup();
                texture.setSamplerParams(linear);

                glEnableClientState(GL_COLOR_ARRAY);
                glEnableClientState(GL_VERTEX_ARRAY);
                glEnableClientState(GL_TEXTURE_COORD_ARRAY);
                glVertexPointer(3, GL_FLOAT, 0, cast(void*)_queue._vertices.data.ptr);
                glTexCoordPointer(2, GL_FLOAT, 0, cast(void*)_queue._texCoords.data.ptr);
                glColorPointer(4, GL_FLOAT, 0, cast(void*)_queue._colors.data.ptr);

                checkgl!glDrawElements(GL_TRIANGLES, cast(int)length, GL_UNSIGNED_INT, cast(void*)(_queue._indices.data[start .. start + length].ptr));

                glDisableClientState(GL_TEXTURE_COORD_ARRAY);
                glDisableClientState(GL_VERTEX_ARRAY);
                glDisableClientState(GL_COLOR_ARRAY);
                glDisable(GL_TEXTURE_2D);
            }
        } else {
            _textureProgram.drawBatch(texture, linear, length, start);
        }
    }

    /// call glFlush
    void flushGL() {
        // TODO: Is this really needed?
        // checkgl!glFlush();
    }

    bool generateMipmap(int dx, int dy, ubyte * pixels, int level, ref ubyte[] dst) {
        if ((dx & 1) || (dy & 1) || dx < 2 || dy < 2)
            return false; // size is not even
        int newdx = dx / 2;
        int newdy = dy / 2;
        int newlen = newdx * newdy * 4;
        if (newlen > dst.length)
            dst.length = newlen;
        ubyte * dstptr = dst.ptr;
        ubyte * srcptr = pixels;
        int srcstride = dx * 4;
        for (int y = 0; y < newdy; y++) {
            for (int x = 0; x < newdx; x++) {
                dstptr[0] = cast(ubyte)((srcptr[0+0] + srcptr[0+4] + srcptr[0+srcstride] + srcptr[0+srcstride + 4])>>2);
                dstptr[1] = cast(ubyte)((srcptr[1+0] + srcptr[1+4] + srcptr[1+srcstride] + srcptr[1+srcstride + 4])>>2);
                dstptr[2] = cast(ubyte)((srcptr[2+0] + srcptr[2+4] + srcptr[2+srcstride] + srcptr[2+srcstride + 4])>>2);
                dstptr[3] = cast(ubyte)((srcptr[3+0] + srcptr[3+4] + srcptr[3+srcstride] + srcptr[3+srcstride + 4])>>2);
                dstptr += 4;
                srcptr += 8;
            }
            srcptr += srcstride; // skip srcline
        }
        checkgl!glTexImage2D(GL_TEXTURE_2D, level, GL_RGBA, newdx, newdy, 0, GL_RGBA, GL_UNSIGNED_BYTE, dst.ptr);
        return true;
    }

    bool setTextureImage(Tex2D texture, int dx, int dy, ubyte * pixels, int mipmapLevels = 0) {
        checkError("before setTextureImage");
        texture.bind();
        checkgl!glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        texture.setSamplerParams(true, true);

        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_BASE_LEVEL, 0);
        glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAX_LEVEL, mipmapLevels > 0 ? mipmapLevels - 1 : 0);
        // ORIGINAL: glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, dx, dy, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        checkgl!glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, dx, dy, 0, GL_RGBA, GL_UNSIGNED_BYTE, pixels);
        if (checkError("updateTexture - glTexImage2D")) {
            Log.e("Cannot set image for texture");
            return false;
        }
        if (mipmapLevels > 1) {
            ubyte[] buffer;
            ubyte * src = pixels;
            int ndx = dx;
            int ndy = dy;
            for (int i = 1; i < mipmapLevels; i++) {
                if (!generateMipmap(ndx, ndy, src, i, buffer))
                    break;
                ndx /= 2;
                ndy /= 2;
                src = buffer.ptr;
            }
        }
        texture.unbind();
        return true;
    }

    bool setTextureImageAlpha(Tex2D texture, int dx, int dy, ubyte * pixels) {
        checkError("before setTextureImageAlpha");
        texture.bind();
        checkgl!glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
        texture.setSamplerParams(true, true);

        glTexImage2D(GL_TEXTURE_2D, 0, GL_ALPHA, dx, dy, 0, GL_ALPHA, GL_UNSIGNED_BYTE, pixels);
        if (checkError("setTextureImageAlpha - glTexImage2D")) {
            Log.e("Cannot set image for texture");
            return false;
        }
        texture.unbind();
        return true;
    }

    private FBO currentFBO;

    /// returns texture for buffer, null if failed
    bool createFramebuffer(out Tex2D texture, out FBO fbo, int dx, int dy) {
        checkError("before createFramebuffer");
        bool res = true;
        texture = new Tex2D();
        if (!texture.ID)
            return false;
        checkError("glBindTexture GL_TEXTURE_2D");
        FBO f = new FBO();
        if (!f.ID)
            return false;
        fbo = f;

        checkgl!glTexImage2D(GL_TEXTURE_2D, 0, GL_RGB, dx, dy, 0, GL_RGB, GL_UNSIGNED_SHORT_5_6_5, null);

        texture.setSamplerParams(true, true);

        checkgl!glFramebufferTexture2D(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_TEXTURE_2D, texture.ID, 0);
        // Always check that our framebuffer is ok
        if(checkgl!glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            Log.e("glFramebufferTexture2D failed");
            res = false;
        }
        checkgl!glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
        checkgl!glClear(GL_COLOR_BUFFER_BIT);
        currentFBO = fbo;

        texture.unbind();
        fbo.unbind();

        return res;
    }

    void deleteFramebuffer(ref FBO fbo) {
        if (fbo.ID != 0) {
            destroy(fbo);
        }
        currentFBO = null;
    }

    bool bindFramebuffer(FBO fbo) {
        fbo.bind();
        currentFBO = fbo;
        return !checkError("glBindFramebuffer");
    }

    void clearDepthBuffer() {
        glClear(GL_DEPTH_BUFFER_BIT);
        //glClear(GL_DEPTH_BUFFER_BIT | GL_COLOR_BUFFER_BIT | GL_STENCIL_BUFFER_BIT);
    }

    /// projection matrix
    /// current gl buffer width
    private int bufferDx;
    /// current gl buffer height
    private int bufferDy;
    private mat4 _projectionMatrix;

    @property ref mat4 projectionMatrix() {
        return _projectionMatrix;
    }

    void setOrthoProjection(Rect windowRect, Rect view) {
        flushGL();
        bufferDx = windowRect.width;
        bufferDy = windowRect.height;
        _projectionMatrix.setOrtho(view.left, view.right, view.top, view.bottom, 0.5f, 50.0f);

        if (_legacyMode) {
            static if (SUPPORT_LEGACY_OPENGL) {
                glMatrixMode(GL_PROJECTION);
                //checkgl!glPushMatrix();
                //glLoadIdentity();
                glLoadMatrixf(_projectionMatrix.m.ptr);
                //glOrthof(0, _dx, 0, _dy, -1.0f, 1.0f);
                glMatrixMode(GL_MODELVIEW);
                //checkgl!glPushMatrix();
                glLoadIdentity();
            }
        }
        checkgl!glViewport(view.left, currentFBO ? view.top : windowRect.height - view.bottom, view.width, view.height);
    }

    void setPerspectiveProjection(Rect windowRect, Rect view, float fieldOfView, float nearPlane, float farPlane) {
        flushGL();
        bufferDx = windowRect.width;
        bufferDy = windowRect.height;
        float aspectRatio = cast(float)view.width / cast(float)view.height;
        _projectionMatrix.setPerspective(fieldOfView, aspectRatio, nearPlane, farPlane);
        if (_legacyMode) {
            static if (SUPPORT_LEGACY_OPENGL) {
                glMatrixMode(GL_PROJECTION);
                //checkgl!glPushMatrix();
                //glLoadIdentity();
                glLoadMatrixf(_projectionMatrix.m.ptr);
                //glOrthof(0, _dx, 0, _dy, -1.0f, 1.0f);
                glMatrixMode(GL_MODELVIEW);
                //checkgl!glPushMatrix();
                glLoadIdentity();
            }
        }
        checkgl!glViewport(view.left, currentFBO ? view.top : windowRect.height - view.bottom, view.width, view.height);
    }
}

enum GLObjectTypes { Buffer, VertexArray, Texture, Framebuffer };
/** RAII OpenGL object template.
  * Note: on construction it binds itself to the target, and it binds 0 to target on destruction.
  * All methods (except ctor, dtor, bind(), unbind() and setup()) does not perform binding.
*/


class GLObject(GLObjectTypes type, GLuint target = 0) {
    immutable GLuint ID;
    //alias ID this; // good, but it confuses destroy()

    this() {
        GLuint handle;
        mixin("checkgl!glGen" ~ to!string(type) ~ "s(1, &handle);");
        ID = handle;
        bind();
    }

    ~this() {
        if (!glNoContext) {
            unbind();
            mixin("checkgl!glDelete" ~ to!string(type) ~ "s(1, &ID);");
        }
    }

    void bind() {
        static if(target != 0)
            mixin("glBind" ~ to!string(type) ~ "(" ~ to!string(target) ~ ", ID);");
        else
            mixin("glBind" ~ to!string(type) ~ "(ID);");
    }

    static void unbind() {
        static if(target != 0)
            mixin("checkgl!glBind" ~ to!string(type) ~ "(" ~ to!string(target) ~ ", 0);");
        else
            mixin("checkgl!glBind" ~ to!string(type) ~ "(0);");
    }

    static if(type == GLObjectTypes.Buffer)
    {
        void fill(float[][] buffs) {
            int length;
            foreach(b; buffs)
                length += b.length;
            checkgl!glBufferData(target,
                         length * float.sizeof,
                         null,
                         GL_STATIC_DRAW);
            int offset;
            foreach(b; buffs) {
                checkgl!glBufferSubData(target,
                                offset,
                                b.length * float.sizeof,
                                b.ptr);
                offset += b.length * float.sizeof;
            }
        }

        static if (target == GL_ELEMENT_ARRAY_BUFFER) {
            void fill(int[] indexes) {
                checkgl!glBufferData(target, cast(int)(indexes.length * int.sizeof), indexes.ptr, GL_STATIC_DRAW);
            }
        }
    }

    static if(type == GLObjectTypes.Texture)
    {
        void setSamplerParams(bool linear, bool clamp = false, bool mipmap = false) {
            glTexParameteri(target, GL_TEXTURE_MAG_FILTER, linear ? GL_LINEAR : GL_NEAREST);
            glTexParameteri(target, GL_TEXTURE_MIN_FILTER, linear ?
                            (!mipmap ? GL_LINEAR : GL_LINEAR_MIPMAP_LINEAR) :
                            (!mipmap ? GL_NEAREST : GL_NEAREST_MIPMAP_NEAREST)); //GL_NEAREST_MIPMAP_NEAREST
            checkError("filtering - glTexParameteri");
            if(clamp) {
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                checkError("clamp - glTexParameteri");
            }
        }

        void setup(GLuint binding = 0) {
            glActiveTexture(GL_TEXTURE0 + binding);
            glBindTexture(target, ID);
            checkError("setup texture");
        }
    }
}

alias VAO = GLObject!(GLObjectTypes.VertexArray);
alias VBO = GLObject!(GLObjectTypes.Buffer, GL_ARRAY_BUFFER);
alias EBO = GLObject!(GLObjectTypes.Buffer, GL_ELEMENT_ARRAY_BUFFER);
alias Tex2D = GLObject!(GLObjectTypes.Texture, GL_TEXTURE_2D);
alias FBO = GLObject!(GLObjectTypes.Framebuffer, GL_FRAMEBUFFER);

class GLVertexBuffer : VertexBuffer {
    protected VertexFormat _format;
    protected IndexFragment[] _indexFragments;
    protected int _vertexCount;
    protected GLuint _vertexBuffer;
    protected GLuint _indexBuffer;
    protected GLuint _vao;

    this() {
        assertgl!glGenBuffers(1, &_vertexBuffer);
        assertgl!glGenBuffers(1, &_indexBuffer);
        assertgl!glGenVertexArrays(1, &_vao);
    }

    ~this() {
        checkgl!glDeleteBuffers(1, &_vertexBuffer);
        checkgl!glDeleteBuffers(1, &_indexBuffer);
        checkgl!glDeleteVertexArrays(1, &_vao);
    }

    ///// bind into current context
    //override void bind() {
    //    checkgl!glBindVertexArray(_vao);
    //
    //    // TODO: is it necessary to bind vertex/index buffers?
    //    // specify vertex buffer
    //    checkgl!glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    //    // specify index buffer
    //    checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    //}
    //
    ///// unbind from current context
    //override void unbind() {
    //    checkgl!glBindVertexArray(0);
    //    checkgl!glBindBuffer(GL_ARRAY_BUFFER, 0);
    //    checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    //}

    /// update vertex element locations for effect/shader program
    void enableAttributes(GraphicsEffect effect) {
        checkgl!glBindVertexArray(_vao);
        // specify vertex buffer
        checkgl!glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        // specify index buffer
        checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        int offset = 0;
        for(int i = 0; i < _format.length; i++) {
            int loc = effect.getVertexElementLocation(_format[i].type);
            if (loc >= 0) {
                checkgl!glVertexAttribPointer(loc, _format[i].size, GL_FLOAT, cast(ubyte)GL_FALSE, _format.vertexSize, cast(char*)(offset));
                checkgl!glEnableVertexAttribArray(loc);
            }
            offset += _format[i].byteSize;
        }
    }

    void disableAttributes(GraphicsEffect effect) {
        for(int i = 0; i < _format.length; i++) {
            int loc = effect.getVertexElementLocation(_format[i].type);
            if (loc >= 0) {
                checkgl!glDisableVertexAttribArray(loc);
            }
        }
        checkgl!glBindVertexArray(0);
        checkgl!glBindBuffer(GL_ARRAY_BUFFER, 0);
        checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        //unbind();
    }

    /// set or change data
    override void setData(Mesh mesh) {
        _format = mesh.vertexFormat;
        _indexFragments = mesh.indexFragments;
        _vertexCount = mesh.vertexCount;
        const(ushort[]) indexData = mesh.indexData;

        Log.d("GLVertexBuffer.setData vertex data size=", mesh.vertexData.length, " index data size=", indexData.length, " vertex count=", _vertexCount, " indexBuffer=", _indexBuffer, " vertexBuffer=", _vertexBuffer, " vao=", _vao);

        // vertex buffer
        checkgl!glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        checkgl!glBufferData(GL_ARRAY_BUFFER, _format.vertexSize * mesh.vertexCount, mesh.vertexData.ptr, GL_STATIC_DRAW);
        checkgl!glBindBuffer(GL_ARRAY_BUFFER, 0);
        // index buffer
        checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
        checkgl!glBufferData(GL_ELEMENT_ARRAY_BUFFER, indexData.length * ushort.sizeof, indexData.ptr, GL_STATIC_DRAW);
        checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        // vertex layout
        //checkgl!glBindVertexArray(_vao);
        // specify vertex buffer
        //checkgl!glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
        // specify index buffer
        //checkgl!glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);

        //unbind();
    }

    /// draw mesh using specified effect
    override void draw(GraphicsEffect effect, bool wireframe) {
        //bind();
        enableAttributes(effect);
        foreach (fragment; _indexFragments) {
            if (wireframe && fragment.type == PrimitiveType.triangles) {
                // TODO: support wireframe not only for triangles
                int triangleCount = fragment.end - fragment.start;
                //triangleCount /= 3;
                //checkgl!glDisable(GL_CULL_FACE);
                for (int i = 0; i < triangleCount; i += 3) {
                    // GL line loop works strange; use GL_LINES instead
                    checkgl!glDrawRangeElements(GL_LINE_LOOP, //GL_TRIANGLES,
                                0, _vertexCount - 1, // The first to last vertex  start, end
                                3, // count of indexes used to draw elements
                                GL_UNSIGNED_SHORT,
                                cast(char*)((fragment.start + i) * short.sizeof) // offset from index buffer beginning to fragment start
                                    );
                    //checkgl!glDrawRangeElements(GL_LINES, //GL_TRIANGLES,
                    //            0, _vertexCount - 1, // The first to last vertex  start, end
                    //            2, // count of indexes used to draw elements
                    //            GL_UNSIGNED_SHORT,
                    //            cast(char*)((fragment.start + i + 1) * short.sizeof) // offset from index buffer beginning to fragment start
                    //                );
                }
                //checkgl!glEnable(GL_CULL_FACE);
            } else {
                checkgl!glDrawRangeElements(primitiveTypeToGL(fragment.type),
                        0, _vertexCount - 1, // The first to last vertex
                        fragment.end - fragment.start, // count of indexes used to draw elements
                        GL_UNSIGNED_SHORT,
                        cast(char*)(fragment.start * short.sizeof) // offset from index buffer beginning to fragment start
                );
            }
        }
        disableAttributes(effect);
        //unbind();
    }
}

class DummyVertexBuffer : VertexBuffer {
    protected VertexFormat _format;
    protected IndexFragment[] _indexFragments;
    protected int _vertexCount;
    protected const(float)[] _vertexData;
    protected const(ushort)[] _indexData;

    this() {
    }

    ~this() {
    }

    ///// bind into current context
    //override void bind() {
    //}
    //
    ///// unbind from current context
    //override void unbind() {
    //}

    /// update vertex element locations for effect/shader program
    void enableAttributes(GraphicsEffect effect) {
        int offset = 0;
        for(int i = 0; i < _format.length; i++) {
            int loc = effect.getVertexElementLocation(_format[i].type);
            if (loc >= 0) {
                checkgl!glVertexAttribPointer(loc, _format[i].size, GL_FLOAT, cast(ubyte)GL_FALSE, _format.vertexSize, cast(char*)(offset));
                checkgl!glEnableVertexAttribArray(loc);
            }
            offset += _format[i].byteSize;
        }
    }

    void disableAttributes(GraphicsEffect effect) {
        for(int i = 0; i < _format.length; i++) {
            int loc = effect.getVertexElementLocation(_format[i].type);
            if (loc >= 0) {
                checkgl!glDisableVertexAttribArray(loc);
            }
        }
    }

    /// set or change data
    override void setData(Mesh mesh) {
        _format = mesh.vertexFormat;
        _indexFragments = mesh.indexFragments;
        _vertexCount = mesh.vertexCount;
        _vertexData = mesh.vertexData;
        _indexData = mesh.indexData;
    }

    /// draw mesh using specified effect
    override void draw(GraphicsEffect effect, bool wireframe) {
        //bind();
        enableAttributes(effect);
        foreach (fragment; _indexFragments) {
            // TODO: support wireframe
            checkgl!glDrawRangeElements(primitiveTypeToGL(fragment.type),
                                        0, _vertexCount,
                                        fragment.end - fragment.start,
                                        GL_UNSIGNED_SHORT, cast(char*)(fragment.start * short.sizeof));
        }
        disableAttributes(effect);
        //unbind();
    }
}

GLenum primitiveTypeToGL(PrimitiveType type) {
    switch(type) with (PrimitiveType) {
        case triangles:
            return GL_TRIANGLES;
        case triangleStripes:
            return GL_TRIANGLE_STRIP;
        case lines:
            return GL_LINES;
        case lineStripes:
            return GL_LINE_STRIP;
        case points:
        default:
            return GL_POINTS;
    }
}



/// OpenGL GUI rendering queue. It collects gui draw calls, fills a big buffer for vertex data and draws everything
private final class OpenGLQueue {

    /// OpenGL batch structure - to draw several triangles in single OpenGL call
    private struct OpenGLBatch {

        enum BatchType { Line = 0, Rect, Triangle, TexturedRect }
        BatchType type;

        Tex2D texture;
        int textureDx;
        int textureDy;
        bool textureLinear;

        // length of batch in indices
        int length;
        // offset in index buffer
        int start;
    }

    import std.array: Appender;
    Appender!(OpenGLBatch[]) batches;
    // a big buffer
    Appender!(float[]) _vertices;
    Appender!(float[]) _colors;
    Appender!(float[]) _texCoords;
    Appender!(int[]) _indices;

    /// draw all
    void flush() {
        glSupport.fillBuffers(_vertices.data, _colors.data, _texCoords.data, _indices.data);
        foreach(b; batches.data) {
            switch(b.type) with(OpenGLBatch.BatchType)
            {
                case Line:          glSupport.drawLines(b.length, b.start); break;
                case Rect:          glSupport.drawSolidFillTriangles(b.length, b.start); break;
                case Triangle:      glSupport.drawSolidFillTriangles(b.length, b.start); break;
                case TexturedRect:  glSupport.drawColorAndTextureTriangles(b.texture, b.textureLinear, b.length, b.start); break;
                default: break;
            }
        }
        glSupport.destroyBuffers();
        batches.clear;
        _vertices.clear;
        _colors.clear;
        _texCoords.clear;
        _indices.clear;
    }

    static immutable float Z_2D = -2.0f;

    /// add textured rectangle to queue
    void addTexturedRect(Tex2D texture, int textureDx, int textureDy, uint color1, uint color2, uint color3, uint color4, Rect srcrc, Rect dstrc, bool linear) {
        if (batches.data.length == 0
            || batches.data[$-1].type != OpenGLBatch.BatchType.TexturedRect
            || batches.data[$-1].texture.ID != texture.ID
            || batches.data[$-1].textureLinear != linear)
        {
            batches ~= OpenGLBatch();
            batches.data[$-1].type = OpenGLBatch.BatchType.TexturedRect;
            batches.data[$-1].texture = texture;
            batches.data[$-1].textureDx = textureDx;
            batches.data[$-1].textureDy = textureDy;
            batches.data[$-1].textureLinear = linear;
            if(batches.data.length > 1)
                batches.data[$-1].start = batches.data[$-2].start + batches.data[$-2].length;
        }

        uint[4] colorsARGB = [color1, color2, color3, color4];
        float[] colors = convertColors(colorsARGB);

        float dstx0 = cast(float)dstrc.left;
        float dsty0 = cast(float)(glSupport.currentFBO ? dstrc.top : (glSupport.bufferDy - dstrc.top));
        float dstx1 = cast(float)dstrc.right;
        float dsty1 = cast(float)(glSupport.currentFBO ? dstrc.bottom : (glSupport.bufferDy - dstrc.bottom));

        float srcx0 = srcrc.left / cast(float)textureDx;
        float srcy0 = srcrc.top / cast(float)textureDy;
        float srcx1 = srcrc.right / cast(float)textureDx;
        float srcy1 = srcrc.bottom / cast(float)textureDy;

        float[3 * 4] vertices = [
            dstx0,dsty0,Z_2D,
            dstx0,dsty1,Z_2D,
            dstx1,dsty0,Z_2D,
            dstx1,dsty1,Z_2D ];

        float[2 * 4] texCoords = [srcx0,srcy0, srcx0,srcy1, srcx1,srcy0, srcx1,srcy1];

        enum verts = 4;
        mixin(add);
    }

    /// add solid rectangle to queue
    void addSolidRect(Rect dstRect, uint color) {
        addGradientRect(dstRect, color, color, color, color);
    }

    /// add gradient rectangle to queue
    void addGradientRect(Rect rc, uint color1, uint color2, uint color3, uint color4) {
        if (batches.data.length == 0 || batches.data[$-1].type != OpenGLBatch.BatchType.Rect) {
            batches ~= OpenGLBatch();
            batches.data[$-1].type = OpenGLBatch.BatchType.Rect;
            if(batches.data.length > 1)
                batches.data[$-1].start = batches.data[$-2].start + batches.data[$-2].length;
        }

        uint[4] colorsARGB = [color1, color2, color3, color4];
        float[] colors = convertColors(colorsARGB);

        float x0 = cast(float)(rc.left);
        float y0 = cast(float)(glSupport.currentFBO ? rc.top : (glSupport.bufferDy - rc.top));
        float x1 = cast(float)(rc.right);
        float y1 = cast(float)(glSupport.currentFBO ? rc.bottom : (glSupport.bufferDy - rc.bottom));

        float[3 * 4] vertices = [
            x0,y0,Z_2D,
            x0,y1,Z_2D,
            x1,y0,Z_2D,
            x1,y1,Z_2D ];
        // fill texture coords buffer with zeros
        float[2 * 4] texCoords = 0;

        enum verts = 4;
        mixin(add);
    }

    /// add triangle to queue
    void addTriangle(PointF p1, PointF p2, PointF p3, uint color1, uint color2, uint color3) {
        if (batches.data.length == 0 || batches.data[$-1].type != OpenGLBatch.BatchType.Triangle) {
            batches ~= OpenGLBatch();
            batches.data[$-1].type = OpenGLBatch.BatchType.Triangle;
            if(batches.data.length > 1)
                batches.data[$-1].start = batches.data[$-2].start + batches.data[$-2].length;
        }

        uint[3] colorsARGB = [color1, color2, color3];
        float[] colors = convertColors(colorsARGB);

        float x0 = p1.x;
        float y0 = glSupport.currentFBO ? p1.y : (glSupport.bufferDy - p1.y);
        float x1 = p2.x;
        float y1 = glSupport.currentFBO ? p2.y : (glSupport.bufferDy - p2.y);
        float x2 = p3.x;
        float y2 = glSupport.currentFBO ? p3.y : (glSupport.bufferDy - p3.y);

        float[3 * 3] vertices = [
            x0,y0,Z_2D,
            x1,y1,Z_2D,
            x2,y2,Z_2D ];
        // fill texture coords buffer with zeros
        float[2 * 3] texCoords = 0;

        enum verts = 3;
        mixin(add);
    }

    /// add line to queue
    /// rc is a line (left, top) - (right, bottom)
    void addLine(Rect rc, uint color1, uint color2) {
        if (batches.data.length == 0 || batches.data[$-1].type != OpenGLBatch.BatchType.Line) {
            batches ~= OpenGLBatch();
            batches.data[$-1].type = OpenGLBatch.BatchType.Line;
            if(batches.data.length > 1)
                batches.data[$-1].start = batches.data[$-2].start + batches.data[$-2].length;
        }

        uint[2] colorsARGB = [color1, color2];
        float[] colors = convertColors(colorsARGB);

        float x0 = cast(float)(rc.left);
        float y0 = cast(float)(glSupport.currentFBO ? rc.top : (glSupport.bufferDy - rc.top));
        float x1 = cast(float)(rc.right);
        float y1 = cast(float)(glSupport.currentFBO ? rc.bottom : (glSupport.bufferDy - rc.bottom));

        float[3 * 2] vertices = [
            x0, y0, Z_2D,
            x1, y1, Z_2D ];
        // fill texture coords buffer with zeros
        float[2 * 2] texCoords = 0;

        enum verts = 2;
        mixin(add);
    }

    enum add = q{
        int offset = cast(int)_vertices.data.length / 3;
        static if(verts == 4) {
            // make indices for rectangle (2 triangles == 6 vertexes per rect)
            int[6] indices = [
                offset + 0,
                offset + 1,
                offset + 2,
                offset + 1,
                offset + 2,
                offset + 3 ];
        } else
        static if(verts == 3) {
            // make indices for triangles
            int[3] indices = [
                offset + 0,
                offset + 1,
                offset + 2 ];
        } else
        static if(verts == 2) {
            // make indices for lines
            int[2] indices = [
                offset + 0,
                offset + 1 ];
        } else
            static assert(0);

        batches.data[$-1].length += cast(int)indices.length;

        _vertices ~= cast(float[])vertices;
        _colors ~= cast(float[])colors;
        _texCoords ~= cast(float[])texCoords;
        _indices ~= cast(int[])indices;
    };
}
