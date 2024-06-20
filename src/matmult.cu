#include <assert.h>
#include <math.h>
#include <stdio.h>

#include <cuda_runtime.h>

#include "matmult.cuh"

__device__ __host__ void MatInit(Matrix* X, int height, int width)
{
    X->height   = height;
    X->width    = width;
    X->stride   = width;
    X->size     = height * width * sizeof(float);
    X->elements = NULL;
}

void MatInitHost(Matrix* X, int height, int width)
{
    MatInit(X, height, width);
    X->elements = (float*)malloc(X->size);
    memset(X->elements, 0, X->size);
}

void MatInitGPU(Matrix* X, int height, int width)
{
    MatInit(X, height, width);
    cudaMalloc(&X->elements, X->size);
    cudaMemset(X->elements, 0, X->size);
}

__device__ __host__ Matrix GetSubMatrix(Matrix A, int R, int C, int blockSize)
{
    Matrix Asub;

    MatInit(&Asub, blockSize, blockSize);
    Asub.stride   = A.stride;
    Asub.elements = &(A.elements[R * A.stride * blockSize + C * blockSize]);
    return Asub;
}

// Matrix multiplication kernel called by MatMultGPU() - basic version
__global__ void MatMult_k0(Matrix A, Matrix B, Matrix C)
{
    // Each thread computes one element of C
    int r = blockIdx.y * blockDim.y + threadIdx.y;
    int c = blockIdx.x * blockDim.x + threadIdx.x;
    SetElement(C, r, c, MatMultElement(A, B, r, c));
}

// Matrix multiplication kernel called by MatMultGPU() - optimized version
// Should be run this way:
// size_t sharedMemSize = 2 * BLOCK_SIZE * BLOCK_SIZE * sizeof(float); // Total size for As and Bs
// MatMulKernel<<<gridDim, blockDim, sharedMemSize>>>(A, B, C);
__global__ void MatMult_k1(Matrix MatA, Matrix MatB, Matrix MatC)
{
    extern __shared__ char sharedMemory[];
    int                    R     = blockIdx.y;
    int                    C     = blockIdx.x;
    int                    r     = threadIdx.y;
    int                    c     = threadIdx.x;
    int                    w     = blockDim.x;
    int                    W     = MatA.width / w;
    float*                 Asubs = (float*)sharedMemory;
    float*                 Bsubs = (float*)&(sharedMemory[w * w * sizeof(float)]);
    Matrix                 Csub  = GetSubMatrix(MatC, R, C, w);
    // Each thread computes one element of Csub
    float Csub_rc = 0;
    // C_{R,C} = \sum_{K=0}^{W-1} A_{R,K} B_{K,C}
    for (int K = 0; K < W; K++) {
        Matrix Asub = GetSubMatrix(MatA, R, K, w);
        Matrix Bsub = GetSubMatrix(MatB, K, C, w);
        __syncthreads();
        Asubs[r * w + c] = GetElement(Asub, r, c);
        Bsubs[r * w + c] = GetElement(Bsub, r, c);
        __syncthreads();
        // Csub_{r,c} = \sum_{k=0}^{w-1} A_{r,k} B_{k,c}
        for (int k = 0; k < w; k++) {
            Csub_rc += Asubs[r * w + k] * Bsubs[k * w + c];
        }
    }
    SetElement(Csub, r, c, Csub_rc);
}

void MatMultGPU(const Matrix A, const Matrix B, Matrix C, bool optimized)
{
    assert(A.width == B.height);
    assert(A.height == C.height);
    assert(B.width == C.width);

    // Load A to device memory
    Matrix d_A;
    MatInitGPU(&d_A, A.height, A.width);
    cudaMemcpy(d_A.elements, A.elements, A.size, cudaMemcpyHostToDevice);

    // Load B to device memory
    Matrix d_B;
    MatInitGPU(&d_B, B.height, B.width);
    cudaMemcpy(d_B.elements, B.elements, B.size, cudaMemcpyHostToDevice);

    // Allocate C in device memory
    Matrix d_C;
    MatInitGPU(&d_C, C.height, C.width);

    // Invoke kernel
    dim3 dimBlock(BLOCK_SIZE, BLOCK_SIZE);
    dim3 dimGrid(B.width / dimBlock.x, A.height / dimBlock.y);
    if (optimized) {
        size_t sharedMemSize = 2 * dimBlock.x * dimBlock.y * sizeof(float); // Total size for As and Bs
        MatMult_k1<<<dimGrid, dimBlock, sharedMemSize>>>(d_A, d_B, d_C);
    } else {
        MatMult_k0<<<dimGrid, dimBlock>>>(d_A, d_B, d_C);
    }

    // Read C from device memory
    cudaMemcpy(C.elements, d_C.elements, C.size, cudaMemcpyDeviceToHost);

    // Free device memory
    cudaFree(d_A.elements);
    cudaFree(d_B.elements);
    cudaFree(d_C.elements);
}

void MatMultHost(const Matrix A, const Matrix B, Matrix C)
{
    assert(A.width == B.height);
    assert(A.height == C.height);
    assert(B.width == C.width);

    for (int r = 0; r < A.height; r++)
        for (int c = 0; c < B.width; c++) {
            SetElement(C, r, c, MatMultElement(A, B, r, c));
        }
}

void MatPrint(Matrix A, const char name[])
{
    printf("%s = [\n", name);
    for (int i = 0; i < A.height; i++) {
        int j = 0;
        for (; j < A.width - 1; j++) {
            printf("% 5.1f ", GetElement(A, i, j));
        }
        printf("% 5.1f\n", GetElement(A, i, j));
    }
    printf("]\n");
}

bool MatEqual(Matrix A, Matrix B, float tol)
{
    if (A.height != B.height || A.width != B.width)
        return false;
    for (int r = 0; r < A.height; r++)
        for (int c = 0; c < A.width; c++) {
            if (fabs(GetElement(A, r, c) - GetElement(B, r, c)) > tol)
                return false;
        }
    return true;
}
