
#include "cuda_runtime.h"
#include "device_launch_parameters.h"

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#define WIDTH (short)1
#define HEIGHT (short)1

// TARGA macros
#define VERSION (char)0
#define IDLENGTH (char)31
#define IDMSG "jefff-generated raytraced image"
#define CMT (char)0
#define ITC (char)2
#define XORIGIN (short)0
#define YORIGIN (short)0
#define IPS (char)24
#define IDB (char)0b00010000

typedef struct {
    float r;
    float g;
    float b;
} PIXEL;

/* Writes a list of pixels to a TGA
* const char* fn: c-string of the filename
* const PIXEL* pixels: array of pixels to write
* const unsigned int pixel_len: number of pixels (prevent overflows)
* Writes a type 2 TARGA 24 file
*/
unsigned int writeTGA(const char* fn, const PIXEL* pixels, const unsigned int pixel_len);

int main(int argc, char* argv[])
{
    printf("Running with args: ");
    for (unsigned int i = 0; i < argc; i++) { printf(argv[i]); printf(argv[i]); }
    printf(" \n");
    if (argc <= 1) {
        printf("Must provide filename as argument! \n(If you did provide a filename as an argument, simply move the name such that it is the second argument. This is due to the fact some systems provide the command path as the first argument, whereas some may not.) \n");
        exit(-1);
    }
    const unsigned int pixel_len = WIDTH * HEIGHT;
    PIXEL image[pixel_len] = {{1.0f, 0.7f, 0.9f}};

    switch (writeTGA(argv[1], image, pixel_len)) {
        case 0: printf("TGA written succesfully! \n"); break;
        case 1: printf("TGA file couldn't be opened/created! \n"); break;
        default: printf("Unknown error when writing TGA! \n"); break;
    }

    return 0;
}

unsigned int writeTGA(const char* fn, const PIXEL* pixels, const unsigned int pixel_len) {
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
    fputc((WIDTH & 0x00FF), targa); fputc((WIDTH & 0xFF00) / 256, targa); // width and height using same bitmapping technique
    fputc((HEIGHT & 0x00FF), targa); fputc((HEIGHT & 0xFF00) / 256, targa);
    fputc(IPS, targa);
    fputc(IDB, targa);
    const char* idmsg = IDMSG;
    for (unsigned int i = 0; i < IDLENGTH; i++) {
        fputc(idmsg[i], targa);
    }
    for (unsigned int i = 0; i < pixel_len; i++) {
        fputc((char)roundf(pixels[i].b), targa);
        fputc((char)roundf(pixels[i].g), targa);
        fputc((char)roundf(pixels[i].r), targa);
    }
    return 0;
}