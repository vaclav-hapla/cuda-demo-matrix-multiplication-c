# CUDA Demo: Matrix Multiplication

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Makefile CI](https://github.com/vaclav-hapla/cuda-demo-matrix-multiplication-c/actions/workflows/makefile.yml/badge.svg)](https://github.com/vaclav-hapla/cuda-demo-matrix-multiplication-c/actions/workflows/makefile.yml)

* This is C-version of https://github.com/vaclav-hapla/cuda-demo-matrix-multiplication-cpp
* Serves mainly for demonstration
* There are three implementations of matrix-matrix multiply:
    1. host: `MatMultHost()`,
    2. naive GPU: `MatMultGPU()` with `MatMult_naive()` kernel
    3. optimized GPU: `MatMultGPU()` with `MatMult_optimized()` kernel (using blocks in shared memory)
* The repo also features:
    - [`Makefile`](Makefile)
      - working with a standard Linux directory structure
      - building a separate shared library `lib/libcudamatmult.so`
      - building and running a test suite (`make test`)
    - [`.clangd`](.clangd) file for smooth clangd operation with CUDA
    - [`.clang-format`](.clang-format) file for unified formatting using clang-format
    - [`.vscode/`](.vscode/) for convenient building and debugging in VS Code
    - [Gitlab Workflow](.github/workflows/makefile.yml) running `make test` in a self-hosted CUDA-enabled runner
      - I've set up such a runner on an ETH workstation and connected to [the project on GitHub](https://github.com/vaclav-hapla/cuda-demo-matrix-multiplication-cpp)
    - [MIT License](LICENSE)

