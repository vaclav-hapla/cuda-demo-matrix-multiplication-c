#include <assert.h>

#include "matmult.cuh"

// TODO this could be .c not .cu if the API was more isolated from CUDA

void MatFillX(Matrix* X)
{
    for (int r = 0; r < X->height; r++)
        for (int c = 0; c < X->width; c++) {
            SetElement(X, r, c, (r + c == X->width - 1) ? 1.0 : 0.0);
        }
}

void MatFillY(Matrix* X)
{
    for (int r = 0; r < X->height; r++)
        for (int c = 0; c < X->width; c++) {
            SetElement(X, r, c, (float)r * X->width + c);
        }
}

int main()
{
    int M = 8, N = 12;

    Matrix* X = MatCreateHost(M, M);
    MatFillX(X);
    MatPrint(X, "X");

    Matrix* Y = MatCreateHost(M, N);
    MatFillY(Y);
    MatPrint(Y, "Y");

    Matrix* Z = MatCreateHost(M, N);
    MatMultHost(X, Y, Z);
    MatPrint(Z, "Z");

    assert(!MatEqual(Y, Z, 1e-10));

    Matrix* Y1 = MatCreateHost(M, N);
    MatMultHost(X, Z, Y1);
    assert(MatEqual(Y1, Y, 1e-10));

    Matrix* Z_gpu_0 = MatCreateHost(M, N);
    MatMultGPU(X, Y, Z_gpu_0, false);
    MatPrint(Z_gpu_0, "Z_gpu_0");
    assert(MatEqual(Z_gpu_0, Z, 1e-10));

    Matrix* Z_gpu_1 = MatCreateHost(M, N);
    MatMultGPU(X, Y, Z_gpu_1, true);
    assert(MatEqual(Z_gpu_1, Z, 1e-10));

    MatFree(&X);
    MatFree(&Y);
    MatFree(&Z);
    MatFree(&Y1);
    MatFree(&Z_gpu_0);
    MatFree(&Z_gpu_1);
    return 0;
}
