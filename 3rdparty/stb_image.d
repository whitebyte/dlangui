module stb_image;

extern(C) @nogc nothrow:

ubyte* stbi_load_from_memory(const(ubyte)* buffer, int len,
                             int* x, int* y, int* channels_in_file,
                             int desired_channels);
void stbi_image_free(void* retval_from_stbi_load);
