#include <assert.h>
#include <cuda_runtime.h>
#include <stdio.h>

/*
For whole matrix A,
    A.stride = A.width
but for A's submatrix Asub
    Asub.stride = A.stride
    Asub.width  < A.width
Matrices are stored in row-major order:
    M(row, col) = *(M.elements + row * M.stride + col)
*/
typedef struct {
    int    width;
    int    height;
    size_t size;
    int    stride;
    float* elements;
    float* elements_malloc;
    float* elements_cudaMalloc;
} Mat;

// Thread block size
#define BLOCK_SIZE 4

__device__ __host__ inline void MatInit(Mat* X, int height, int width)
{
    X->height = height;
    X->width  = width;
    X->stride = width;
    X->size   = height * width * sizeof(float);

    X->elements            = NULL;
    X->elements_malloc     = NULL;
    X->elements_cudaMalloc = NULL;
}

// Get a matrix element
__device__ __host__ inline float MatGetElement(const Mat* A, int r, int c) { return A->elements[r * A->stride + c]; }

// Set a matrix element
__device__ __host__ inline void MatSetElement(Mat* A, int r, int c, float value) { A->elements[r * A->stride + c] = value; }

__device__ __host__ inline void MatGetSubMatrix(Mat* A, int R, int C, int blockSize, Mat* Asub)
{
    assert(Asub->elements_cudaMalloc == NULL && Asub->elements_malloc == NULL);
    Asub->stride   = A->stride;
    Asub->elements = &(A->elements[R * A->stride * blockSize + C * blockSize]);
}

// C_{r,c} = \sum_{k=0}^{w-1} A_{r,k} B_{k,c}
__device__ __host__ inline float MatMultElement(const Mat* A, const Mat* B, int r, int c)
{
    float C_rc = 0;
    for (int k = 0; k < A->width; k++) {
        C_rc += A->elements[r * A->stride + k] * B->elements[k * B->stride + c];
    }
    return C_rc;
}

Mat* MatCreateEmpty(int height, int width);

Mat* MatCreateHost(int height, int width);

Mat* MatCreateGPU(int height, int width);

void MatFree(Mat** X);

/*
Get the blockSize x blockSize sub-matrix Asub of A that is
located col sub-matrices to the right and row sub-matrices down
from the upper-left corner of A
*/
__device__ __host__ void MatGetSubMatrix(Mat* A, int R, int C, int blockSize, Mat* Asub);

// Matrix dimensions are assumed to be multiples of BLOCK_SIZE
void MatMultGPU(const Mat* A, const Mat* B, Mat* C, bool optimized);

void MatMultHost(const Mat* A, const Mat* B, Mat* C);

void MatPrint(Mat* A, const char name[]);

bool MatEqual(Mat* A, Mat* B, float tol);
