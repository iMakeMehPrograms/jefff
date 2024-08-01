
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <stdlib.h>
#include <math.h>

// General macros
#define DEFR 0.73f // default colors (chartruese)
#define DEFG 0.65f
#define DEFB 0.06f

// TARGA macros
#define IDLENGTH (char)31
#define IDMSG "jefff-generated raytraced image"
#define CMT (char)0
#define ITC (char)2
#define XORIGIN (short)0
#define YORIGIN (short)0
#define IPS (char)24
#define IDB (char)0b00010000

typedef struct {
    float* r; // individual channels
    float* b;
    float* g; 
    unsigned int width;
    unsigned int height;
} IMAGE;

typedef float VECTOR4[4];
typedef float MATRIX4[4][4];

/* Generic CUDA setup/run
* IMAGE* canvas: image to give to the gpu
* Will make a UV display on the canvas (right now)
*/
unsigned int cudaSetup(IMAGE* canvas);

/* Writes a list of pixels to a TGA
* const char* fn: c-string of the filename
* const PIXEL* pixels: array of pixels to write
* const unsigned int pixel_len: number of pixels (prevent overflows)
* Writes a type 2 TARGA 24 file
*/
unsigned int writeTGA(const char* fn, IMAGE* pixels);

__global__ void uvFill(float* r, float* g, float* b, unsigned int* width, unsigned int* height) {
    unsigned int index = blockIdx.x + (blockIdx.y * width[0]); // terrible, i know
    r[index] = (float)blockIdx.x / (float)width[0]; 
    g[index] = (float)blockIdx.y / (float)height[0];
    b[index] = 0.5f;
}

int main(int argc, char* argv[]) {
    bool err = false;

    printf("Running with args: "); // handling the filename and args
    for (unsigned int i = 0; i < argc; i++) { printf(argv[i]); printf(" "); }
    printf(" \n");
    if (argc <= 1) {
        printf("Must provide filename as argument! \n(If you did provide a filename as an argument, simply move the name such that it is the second argument. This is due to the fact some systems provide the command path as the first argument, whereas some may not.) \n");
        err = true;
        goto MAINERR;
    }

    IMAGE image{};
    image.width = 1280; image.height = 720; // 720p

    image.r = (float*)malloc(sizeof(float) * (image.width * image.height));
    image.g = (float*)malloc(sizeof(float) * (image.width * image.height));
    image.b = (float*)malloc(sizeof(float) * (image.width * image.height));

    if (image.r == NULL || image.g == NULL || image.b == NULL) {
        printf("NULL pointer when allocating image! r: %p g: %p b: %p\n", image.r, image.g, image.b);
        err = true;
        goto MAINERR;
    }

    for (unsigned int i = 0; i < image.width * image.height; i++) {
        image.r[i] = DEFR;
        image.g[i] = DEFG;
        image.b[i] = DEFB;
    }

    switch (cudaSetup(&image)) {
        case 0: break;
        default: printf("Error in cudaSetup()\n");  err = true; break;
    }

    if(err) goto MAINERR;

    switch (writeTGA(argv[1], &image)) {
        case 0: printf("TGA written succesfully! \n"); break;
        case 1: printf("TGA file couldn't be opened/created! \n"); err = true; break;
        default: printf("Unknown error when writing TGA! \n"); err = true; break;
    }

    if(err) goto MAINERR;

    MAINERR:
    free(image.r);
    free(image.g);
    free(image.b);
    if (err) {
        printf("Returning with an error!\n");
        return -1;
    }

    return 0;
}

unsigned int cudaSetup(IMAGE* canvas) {
    dim3 blockSize(1, 1);
    dim3 numBlocks(canvas->width, canvas->height);

    printf("Running with:\nWidth/Height: %i * %i\nBlock Size: %i * %i\nBlock Grid: %i * %i\n", canvas->width, canvas->height, blockSize.x, blockSize.y, numBlocks.x, numBlocks.y);

    cudaError_t err = cudaSetDevice(0);
    if (err != cudaSuccess) {
        printf("Couldn't set device!\n");
        goto SETUPERR;
    }

    float* device_r;
    float* device_g;
    float* device_b;
    unsigned int* device_wi;
    unsigned int* device_hi;

    err = cudaMalloc((void**)&device_r, canvas->width * canvas->height * sizeof(float));
    err = cudaMalloc((void**)&device_g, canvas->width * canvas->height * sizeof(float));
    err = cudaMalloc((void**)&device_b, canvas->width * canvas->height * sizeof(float));
    if (err != cudaSuccess) {
        printf("Couldn't cudaMalloc() the rgb channels!\n");
        goto SETUPERR;
    }

    err = cudaMalloc((void**)&device_wi, sizeof(float));
    err = cudaMalloc((void**)&device_hi, sizeof(float));
    if (err != cudaSuccess) {
        printf("Couldn't cudaMalloc() the width/height!\n");
        goto SETUPERR;
    }

    err = cudaMemcpy(device_r, canvas->r, canvas->width * canvas->height * sizeof(float), cudaMemcpyHostToDevice);
    err = cudaMemcpy(device_g, canvas->g, canvas->width * canvas->height * sizeof(float), cudaMemcpyHostToDevice);
    err = cudaMemcpy(device_b, canvas->b, canvas->width * canvas->height * sizeof(float), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        printf("Couldn't cudaMemcpy() the rgb channels! (host >> device)\n");
        goto SETUPERR;
    }

    err = cudaMemcpy(device_wi, &canvas->width, sizeof(unsigned int), cudaMemcpyHostToDevice);
    err = cudaMemcpy(device_hi, &canvas->height, sizeof(unsigned int), cudaMemcpyHostToDevice);
    if (err != cudaSuccess) {
        printf("Couldn't cudaMemcpy() the width/height! (host >> device)\n");
        goto SETUPERR;
    }

    uvFill<<<blockSize, numBlocks>>>(device_r, device_g, device_b, device_wi, device_hi);

    err = cudaGetLastError();
    if (err != cudaSuccess) {
        printf("Error in kernel: %s, %s\n", cudaGetErrorName(err), cudaGetErrorString(err));
        goto SETUPERR;
    }

    err = cudaThreadSynchronize();
    if (err != cudaSuccess) {
        printf("Couldn't sync threads!\n");
        goto SETUPERR;
    }

    err = cudaMemcpy(canvas->r, device_r, canvas->width * canvas->height * sizeof(float), cudaMemcpyDeviceToHost);
    err = cudaMemcpy(canvas->g, device_g, canvas->width * canvas->height * sizeof(float), cudaMemcpyDeviceToHost);
    err = cudaMemcpy(canvas->b, device_b, canvas->width * canvas->height * sizeof(float), cudaMemcpyDeviceToHost);
    if (err != cudaSuccess) {
        printf("Couldn't cudaMemcpy() the rgb channels! (device >> host)\n");
        goto SETUPERR;
    }

    SETUPERR:
    err = cudaFree(device_r);
    err = cudaFree(device_g);
    err = cudaFree(device_b);
    err = cudaFree(device_wi);
    err = cudaFree(device_hi);
    if (err != cudaSuccess) return -1;
    return 0;
}

unsigned int writeTGA(const char* fn, IMAGE* pixels) {
    FILE* targa = fopen(fn, "wb");
    if (targa == NULL) {
        return 1;
    }
    fputc(IDLENGTH, targa); // length of identification msg
    fputc(CMT, targa); // color map type (0 = ignore)
    fputc(ITC, targa); // type of targa (2)
    for (unsigned int i = 0; i < 5; i++) { // generates blank area where the color map is, since it should be ignored
        fputc(0, targa);
    }
    fputc((XORIGIN & 0x00FF), targa); fputc((XORIGIN & 0xFF00) / 256, targa); // x and y origins, weird bitmapping is to concatenate the usually 2-byte short into a 1-byte char
    fputc((YORIGIN & 0x00FF), targa); fputc((YORIGIN & 0xFF00) / 256, targa);
    fputc((pixels->width & 0x00FF), targa); fputc((pixels->width & 0xFF00) / 256, targa); // width and height using same bitmapping technique
    fputc((pixels->height & 0x00FF), targa); fputc((pixels->height & 0xFF00) / 256, targa);
    fputc(IPS, targa);
    fputc(IDB, targa);
    const char* idmsg = IDMSG;
    for (unsigned int i = 0; i < IDLENGTH; i++) {
        fputc(idmsg[i], targa);
    }
    for (unsigned int i = 0; i < pixels->height * pixels->width; i++) {
        fputc((int)roundf(pixels->b[i] * 255), targa);
        fputc((int)roundf(pixels->g[i] * 255), targa);
        fputc((int)roundf(pixels->r[i] * 255), targa);
    }
    fclose(targa);
    return 0;
}